import 'dart:math';

import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/grammar.dart';
import '../models/user.dart';
import '../models/word.dart';
import '../services/api_client.dart';
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
  bool _submitting = false;
  List<SubmitResult> _results = [];
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
      _toast('请先选择章节');
      return;
    }
    final rand = Random();
    if (_type == 'word') {
      final all = await DbHelper.getWords(chapter: _chapter);
      if (all.isEmpty) {
        _toast('本章暂无单词题目');
        return;
      }
      all.shuffle(rand);
      _words = all.take(_count).toList();
    } else {
      final all = await DbHelper.getGrammar(chapter: _chapter);
      if (all.isEmpty) {
        _toast('本章暂无语法题目');
        return;
      }
      all.shuffle(rand);
      _grammar = all.take(_count).toList();
    }
    setState(() {
      _started = true;
      _index = 0;
      _revealed = false;
      _results = [];
      _correct = 0;
    });
  }

  bool get _finished => _started && _index >= (_type == 'word' ? _words.length : _grammar.length);

  Future<void> _answer(bool correct) async {
    setState(() {
      _submitting = true;
      _revealed = true;
    });
    try {
      final id = _type == 'word' ? _words[_index].id : _grammar[_index].id;
      final r = await ApiClient.instance.submitTest(
        elementType: _type,
        elementId: id,
        correct: correct,
        chapter: _chapter,
      );
      if (correct) _correct++;
      _results.add(r);
    } catch (e) {
      _toast('同步失败：$e（本次作答未记录）');
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _index++;
      _revealed = false;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('测试')),
      body: !_started ? _buildSetup() : _finished ? _buildResult() : _buildQuiz(),
    );
  }

  Widget _buildSetup() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('测试类型', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'word', label: Text('单词')),
            ButtonSegment(value: 'grammar', label: Text('语法')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 20),
        const Text('章节', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _chapter,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: const Text('选择章节'),
          items: _chapters.map((c) => DropdownMenuItem(value: c, child: Text('第 $c 课'))).toList(),
          onChanged: (v) => setState(() => _chapter = v),
        ),
        const SizedBox(height: 20),
        const Text('题量', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _count,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [5, 10, 20].map((n) => DropdownMenuItem(value: n, child: Text('$n 题'))).toList(),
          onChanged: (v) => setState(() => _count = v ?? 10),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _start,
          child: const Text('开始测试'),
        ),
      ],
    );
  }

  Widget _buildQuiz() {
    final isWord = _type == 'word';
    final title = isWord ? _words[_index].display : _grammar[_index].template;
    final answer = isWord
        ? '${_words[_index].kana}  ${_words[_index].chinese}'
        : _grammar[_index].explanation;
    final id = isWord ? _words[_index].id : _grammar[_index].id;
    final entityType = _type;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: (_index + 1) / (_type == 'word' ? _words.length : _grammar.length)),
          const SizedBox(height: 16),
          Text('第 ${_index + 1} 题', style: TextStyle(color: Colors.grey.shade600)),
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
                      child: const Text('显示答案'),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (!_revealed)
            FilledButton(
              onPressed: () => setState(() => _revealed = true),
              child: const Text('显示答案'),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
                    onPressed: _submitting ? null : () => _answer(false),
                    icon: const Icon(Icons.close),
                    label: const Text('答错了'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                    onPressed: _submitting ? null : () => _answer(true),
                    icon: const Icon(Icons.check),
                    label: const Text('答对了'),
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
    final total = _results.length;
    final acc = total == 0 ? 0 : (_correct / total * 100).round();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
          const SizedBox(height: 12),
          Text('测试完成', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('答对 $_correct / $total  正确率 $acc%',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => setState(() => _started = false),
            child: const Text('再来一组'),
          ),
        ],
      ),
    );
  }
}
