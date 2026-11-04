import 'dart:math';

import 'package:flutter/material.dart';

import '../data/wordbook_store.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
import 'wordbook_select_page.dart';

/// 单词本复习（闪卡）：参考 web WordbookReviewPage，纯本地实现
///   - 取词：本地 70% 到期旧词 + 30% 新词随机（复刻后端调度）
///   - 正面显示假名并自动朗读；点击翻面显示汉字 + 释义 + 例句
///   - 记得/忘记 → 本地掌握度闭环（间隔递增 + 忘记次日重新入队）
class WordbookReviewPage extends StatefulWidget {
  const WordbookReviewPage({super.key});

  @override
  State<WordbookReviewPage> createState() => _WordbookReviewPageState();
}

class _WordbookReviewPageState extends State<WordbookReviewPage> {
  bool _loading = true;
  bool _noContent = false;
  bool _finished = false;
  String? _error;
  List<WordbookReviewItem> _deck = [];
  int _index = 0;
  bool _revealed = false;
  int _correctTotal = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  WordbookReviewItem? get _current => _index < _deck.length ? _deck[_index] : null;

  void _shuffle(List<WordbookReviewItem> items) {
    final r = Random();
    for (var i = items.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }

  Future<void> _loadDeck() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await WordbookStore.instance.getReviewDeck(limit: 30);
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() {
          _loading = false;
          _noContent = true;
        });
        return;
      }
      _shuffle(items);
      setState(() {
        _deck = items;
        _index = 0;
        _revealed = false;
        _correctTotal = 0;
        _noContent = false;
        _finished = false;
        _loading = false;
      });
      _speakCurrent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// 正面出现时自动朗读（本地 TTS 音频优先）
  void _speakCurrent() {
    final w = _current;
    if (w == null) return;
    final text = w.word.kana.isNotEmpty ? w.word.kana : w.word.kanji;
    if (text.isEmpty) return;
    AudioService.instance.playEntityAudio('word', w.word.id, fallbackText: text);
  }

  void _reveal() {
    if (_revealed) return;
    setState(() {
      _revealed = true;
    });
  }

  /// 记得 / 忘记：本地更新掌握度后立即进入下一张
  Future<void> _assess(bool correct) async {
    final w = _current;
    if (w == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await WordbookStore.instance.saveResult(w.word.id, correct: correct);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.t('保存失败：', 'Save failed: ') + '$e')),
      );
      return;
    }
    if (!mounted) return;
    if (correct) _correctTotal += 1;
    setState(() {
      _submitting = false;
      _index += 1;
      _revealed = false;
      if (_index >= _deck.length) _finished = true;
    });
    if (!_finished) _speakCurrent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(UiText.t('单词本复习', 'Wordbook Review'))),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(UiText.t('加载失败：', 'Load failed: ') + '$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadDeck, child: Text(UiText.t('重试', 'Retry'))),
          ],
        ),
      );
    }
    if (_noContent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(UiText.t('单词本还是空的，先去选词添加吧', 'Your wordbook is empty — select some words first.'),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WordbookSelectPage()),
                );
              },
              child: Text(UiText.t('去选词', 'Select Words')),
            ),
          ],
        ),
      );
    }
    if (_finished) return _buildDone(context);
    return _buildFlash(context);
  }

  Widget _buildFlash(BuildContext context) {
    final w = _current;
    if (w == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(UiText.t('单词 ${_index + 1} / ${_deck.length}', 'Word ${_index + 1} / ${_deck.length}'),
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          // 闪卡
          Expanded(
            child: GestureDetector(
              onTap: _reveal,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _revealed ? Colors.blueGrey.shade200 : Colors.blueGrey.shade300,
                    width: 1.5,
                  ),
                ),
                child: _revealed ? _buildBack(w) : _buildFront(w),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 反馈按钮（翻面后才出现，与 web 一致）
          if (_revealed)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    onPressed: _submitting ? null : () => _assess(false),
                    icon: const Icon(Icons.close),
                    label: Text(UiText.t('忘记', 'Forgot')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                    onPressed: _submitting ? null : () => _assess(true),
                    icon: const Icon(Icons.check),
                    label: Text(UiText.t('记得', 'Remembered')),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 正面：假名 + 提示点击 + 复习原因标签
  Widget _buildFront(WordbookReviewItem w) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(w.word.kana,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 14),
          Text(UiText.t('点击查看释义', 'Tap to reveal'),
              style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400)),
          if (w.reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(w.reason, style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
            ),
          ],
        ],
      ),
    );
  }

  /// 背面：汉字 + 释义 + 例句
  Widget _buildBack(WordbookReviewItem w) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (w.word.kanji.isNotEmpty && w.word.kanji != '/')
              Text(w.word.kanji,
                  style: const TextStyle(fontSize: 22, color: Colors.black54)),
            const SizedBox(height: 10),
            Text(LanguageSetting.t(w.word.chinese, w.word.english),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87),
                textAlign: TextAlign.center),
            if (w.example != null) ...[
              const SizedBox(height: 14),
              Text(w.example!.japanese,
                  style: TextStyle(fontSize: 18, color: Colors.teal.shade700),
                  textAlign: TextAlign.center),
              if (LanguageSetting.t(w.example!.chinese, w.example!.english).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(LanguageSetting.t(w.example!.chinese, w.example!.english),
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade500),
                    textAlign: TextAlign.center),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 完成页：答对统计 + 再来一轮 / 返回单词本
  Widget _buildDone(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 56, color: Colors.amber),
          const SizedBox(height: 12),
          Text(UiText.t('复习完成', 'Review Complete'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(UiText.t('答对 $_correctTotal / ${_deck.length}', 'Correct $_correctTotal / ${_deck.length}'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: () {
                  _shuffle(_deck);
                  setState(() {
                    _finished = false;
                    _index = 0;
                    _revealed = false;
                    _correctTotal = 0;
                  });
                  _speakCurrent();
                },
                child: Text(UiText.t('再来一轮', 'Review Again')),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(UiText.t('返回单词本', 'Back to Wordbook')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
