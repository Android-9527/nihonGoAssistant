import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/grammar.dart';
import '../models/word.dart';
import '../services/api_client.dart';
import '../services/audio_service.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
import '../widgets/audio_button.dart';

/// 测试：按章节随机出题（单词 / 语法），答完同步到服务器
class TestPage extends StatefulWidget {
  /// 从章节学习页进入时直接指定章节与类型
  final int? initialChapter;
  final String? initialType;

  const TestPage({super.key, this.initialChapter, this.initialType});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late String _type;
  int? _chapter;
  List<int> _chapters = [];
  int _count = 10;

  // 出题状态
  bool _started = false;
  List<Word> _words = [];
  List<Grammar> _grammar = [];
  int _index = 0;
  bool _revealed = false;
  int _answered = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 'word';
    _chapter = widget.initialChapter;
    DbHelper.getChapters().then((ch) {
      if (!mounted) return;
      setState(() => _chapters = ch);
      if (widget.initialChapter != null) _start();
    });
  }

  Future<void> _start() async {
    if (_chapter == null) {
      _toast(UiText.t('请先选择章节', 'Select a chapter first'));
      return;
    }
    final rand = Random();
    if (_type == 'word') {
      final all = await DbHelper.getWords(chapter: _chapter);
      if (all.isEmpty) {
        _toast(UiText.t('本章暂无单词题目', 'No word questions in this chapter'));
        return;
      }
      all.shuffle(rand);
      _words = all.take(_count).toList();
    } else {
      final all = await DbHelper.getGrammar(chapter: _chapter);
      if (all.isEmpty) {
        _toast(UiText.t('本章暂无语法题目', 'No grammar questions in this chapter'));
        return;
      }
      all.shuffle(rand);
      _grammar = all.take(_count).toList();
    }
    setState(() {
      _started = true;
      _index = 0;
      _revealed = false;
      _answered = 0;
      _correct = 0;
    });
    _playCurrent();
  }

  bool get _finished => _started && _index >= (_type == 'word' ? _words.length : _grammar.length);

  /// 自动播放当前题目的读音（仅单词测试；语法测试不自动朗读）
  Future<void> _playCurrent() async {
    if (_type != 'word') return;
    final id = _words[_index].id;
    final fallback = _words[_index].kana;
    await AudioService.instance.playEntityAudio('word', id, fallbackText: fallback);
  }

  /// 点击反馈：本地立即切换下一条并自动播放，服务器同步在后台进行
  void _answer(bool correct) {
    if (correct) _correct++;
    _answered++;
    final isWord = _type == 'word';
    final id = isWord ? _words[_index].id : _grammar[_index].id;
    // 后台同步（不阻塞 UI）
    unawaited(_submitResult(isWord, id, correct));
    if (!mounted) return;
    setState(() {
      _index++;
      _revealed = false;
    });
    // 未结束时自动播放下一条
    if (!_finished) _playCurrent();
  }

  Future<void> _submitResult(bool isWord, int id, bool correct) async {
    try {
      await ApiClient.instance.submitTest(
        elementType: isWord ? 'word' : 'grammar',
        elementId: id,
        correct: correct,
        chapter: _chapter,
      );
    } catch (e) {
      if (mounted) {
      _toast(UiText.t('答案已记录，同步服务器失败：', 'Answer recorded, but sync failed: ') + '$e');
    }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(UiText.t('测试', 'Test'))),
      body: !_started ? _buildSetup() : _finished ? _buildResult() : _buildQuiz(),
    );
  }

  Widget _buildSetup() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(UiText.t('测试类型', 'Test Type'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'word', label: Text(UiText.t('单词', 'Words'))),
            ButtonSegment(value: 'grammar', label: Text(UiText.t('语法', 'Grammar'))),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 20),
        Text(UiText.t('章节', 'Chapter'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _chapter,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: Text(UiText.t('选择章节', 'Select chapter')),
          items: _chapters
              .map((c) => DropdownMenuItem(value: c, child: Text(UiText.t('第 $c 课', 'Lesson $c'))))
              .toList(),
          onChanged: (v) => setState(() => _chapter = v),
        ),
        const SizedBox(height: 20),
        Text(UiText.t('题量', 'Questions'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _count,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [5, 10, 20]
              .map((n) => DropdownMenuItem(value: n, child: Text(UiText.t('$n 题', '$n questions'))))
              .toList(),
          onChanged: (v) => setState(() => _count = v ?? 10),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _start,
          child: Text(UiText.t('开始测试', 'Start Test')),
        ),
      ],
    );
  }

  Widget _buildQuiz() {
    final isWord = _type == 'word';
    // 单词题默认显示假名（不显示汉字），语法题显示模板
    final title = isWord ? _words[_index].kana : _grammar[_index].template;
    final answer = isWord
        ? '${_words[_index].kana}  ${LanguageSetting.t(_words[_index].chinese, _words[_index].english)}'
        : LanguageSetting.t(_grammar[_index].explanation, _grammar[_index].explanationEn);
    final id = isWord ? _words[_index].id : _grammar[_index].id;
    final entityType = _type;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: (_index + 1) / (_type == 'word' ? _words.length : _grammar.length)),
          const SizedBox(height: 16),
          Text(UiText.t('第 ${_index + 1} 题', 'Question ${_index + 1}'),
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (isWord)
                        AudioButton(
                          entityType: entityType,
                          entityId: id,
                          size: 26,
                          fallbackText: _words[_index].kana,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_revealed)
                    Text(
                      answer,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade800, height: 1.5),
                      textAlign: TextAlign.center,
                    )
                  else
                    TextButton(
                      onPressed: () => setState(() => _revealed = true),
                      child: Text(UiText.t('显示答案', 'Show Answer')),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (!_revealed)
            FilledButton(
              onPressed: () => setState(() => _revealed = true),
              child: Text(UiText.t('显示答案', 'Show Answer')),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
                    onPressed: () => _answer(false),
                    icon: const Icon(Icons.close),
                    label: Text(UiText.t('答错了', 'Wrong')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                    onPressed: () => _answer(true),
                    icon: const Icon(Icons.check),
                    label: Text(UiText.t('答对了', 'Correct')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResult() {
    final total = _answered;
    final acc = total == 0 ? 0 : (_correct / total * 100).round();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
          const SizedBox(height: 12),
          Text(UiText.t('测试完成', 'Test Complete'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(UiText.t('答对 $_correct / $total  正确率 $acc%',
              'Correct $_correct / $total  Accuracy $acc%'),
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => setState(() => _started = false),
            child: Text(UiText.t('再来一组', 'Try Again')),
          ),
        ],
      ),
    );
  }
}
