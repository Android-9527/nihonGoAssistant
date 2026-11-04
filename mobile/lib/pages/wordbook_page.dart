import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../data/wordbook_store.dart';
import '../models/word.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
import '../widgets/audio_button.dart';
import 'wordbook_review_page.dart';
import 'wordbook_select_page.dart';

/// 单词本（底部「单词本」Tab）：参考 web 单词本设计，纯本地实现
///   - 首页只保留搜索（假名/汉字/释义）与操作入口，不展示已选单词列表
///   - 已选单词的查看/管理（批量勾选、移除）在「去选词」页完成
///   - 入口：开始复习（本地闪卡 + 70/30 调度）/ 去选词（按章批量管理）
class WordbookPage extends StatefulWidget {
  const WordbookPage({super.key});

  @override
  State<WordbookPage> createState() => _WordbookPageState();
}

class _WordbookPageState extends State<WordbookPage> {
  bool _loading = true;
  String? _error;
  List<Word> _saved = [];
  Set<int> _savedIds = {};
  final _searchCtrl = TextEditingController();
  List<Word> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 加载我的单词本（本地存储）
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await WordbookStore.instance.getSavedWords();
      if (!mounted) return;
      setState(() {
        _saved = items;
        _savedIds = items.map((w) => w.id).toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// 本地搜索单词（假名 / 汉字 / 释义）
  Future<void> _onSearchChanged(String kw) async {
    if (kw.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final list = await DbHelper.searchWords(kw);
    if (!mounted) return;
    setState(() {
      _results = list;
      _searching = false;
    });
  }

  /// 加入单词本
  Future<void> _addWord(Word w) async {
    try {
      await WordbookStore.instance.addWord(w.id, w.chapter);
      if (!mounted) return;
      setState(() {
        _savedIds.add(w.id);
        if (!_saved.any((x) => x.id == w.id)) _saved.add(w);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.t('已加入单词本', 'Added to wordbook'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.t('添加失败：', 'Add failed: ') + '$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(UiText.t('单词本', 'Wordbook'))),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(UiText.t('加载失败：', 'Load failed: ') + '$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(UiText.t('重试', 'Retry'))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 操作区：开始复习 / 去选词
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                  onPressed: _saved.isEmpty ? null : () => _goReview(),
                  icon: const Icon(Icons.style_outlined),
                  label: Text(UiText.t('开始复习（${_saved.length}）', 'Review (${_saved.length})')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _goSelect(),
                  icon: const Icon(Icons.playlist_add),
                  label: Text(UiText.t('去选词', 'Select Words')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 搜索框
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: UiText.t('搜索单词（假名/汉字/释义）', 'Search kana / kanji / meaning'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 8),
          // 搜索中：显示检索结果
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_results.isNotEmpty) ...[
            Text(UiText.t('检索结果（${_results.length}）', 'Results (${_results.length})'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final w in _results)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${w.kana}  ${w.kanji.isNotEmpty ? w.kanji : ''}'),
                subtitle: Text(UiText.t('第${w.chapter}章 · ', 'Ch.${w.chapter} · ') +
                    LanguageSetting.t(w.chinese, w.english)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AudioButton(entityType: 'word', entityId: w.id, size: 18, fallbackText: w.kana),
                    if (_savedIds.contains(w.id))
                      Text(UiText.t('已加入', 'Added'),
                          style: TextStyle(color: Colors.green.shade600, fontSize: 12))
                    else
                      TextButton(
                        onPressed: () => _addWord(w),
                        child: Text(UiText.t('加入', 'Add')),
                      ),
                  ],
                ),
              ),
            const Divider(),
          ],
        ],
      ),
    );
  }

  Future<void> _goReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WordbookReviewPage()),
    );
    if (mounted) _load();
  }

  Future<void> _goSelect() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WordbookSelectPage()),
    );
    if (mounted) _load();
  }
}
