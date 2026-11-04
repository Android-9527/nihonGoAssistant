import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../data/wordbook_store.dart';
import '../models/word.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
import '../widgets/audio_button.dart';

/// 选词页：参考 web 单词本「去选词」，纯本地实现
///   - 按章节浏览单词，勾选后批量「加入背单词」
///   - 取消勾选已收藏的词 = 从单词本移除（与 web 一致）
class WordbookSelectPage extends StatefulWidget {
  const WordbookSelectPage({super.key});

  @override
  State<WordbookSelectPage> createState() => _WordbookSelectPageState();
}

class _WordbookSelectPageState extends State<WordbookSelectPage> {
  int _chapter = 1;
  bool _loading = true;
  bool _busy = false;
  List<Word> _words = [];
  Set<int> _savedIds = {};
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadSavedIds();
    await _loadWords();
  }

  Future<void> _loadSavedIds() async {
    try {
      final items = await WordbookStore.instance.getSavedWords();
      if (!mounted) return;
      setState(() {
        _savedIds = items.map((w) => w.id).toSet();
        _selectedIds = {..._savedIds};
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedIds = {};
        _selectedIds = {};
      });
    }
  }

  Future<void> _loadWords() async {
    setState(() => _loading = true);
    final list = await DbHelper.getWords(chapter: _chapter);
    if (!mounted) return;
    setState(() {
      _words = list;
      _loading = false;
    });
  }

  void _toggleWord(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  bool get _allSelected => _words.isNotEmpty && _words.every((w) => _selectedIds.contains(w.id));

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        for (final w in _words) {
          _selectedIds.remove(w.id);
        }
      } else {
        for (final w in _words) {
          _selectedIds.add(w.id);
        }
      }
    });
  }

  /// 与服务器同步：新增未收藏的、移除已取消勾选的
  Future<void> _sync() async {
    if (_busy) return;
    final toAdd = _selectedIds.difference(_savedIds).toList();
    final toRemove = _savedIds.difference(_selectedIds).toList();
    if (toAdd.isEmpty && toRemove.isEmpty) return;
    setState(() => _busy = true);
    try {
      final byId = {for (final w in _words) w.id: w};
      for (final id in toAdd) {
        final w = byId[id];
        if (w == null) continue;
        await WordbookStore.instance.addWord(id, w.chapter);
      }
      for (final id in toRemove) {
        await WordbookStore.instance.removeWord(id);
      }
      if (!mounted) return;
      setState(() {
        _savedIds = {..._selectedIds};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(UiText.t('已保存（新增 ${toAdd.length}，移除 ${toRemove.length}）',
              'Saved (added ${toAdd.length}, removed ${toRemove.length})')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.t('保存失败：', 'Save failed: ') + '$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(UiText.t('选词', 'Select Words'))),
      body: Column(
        children: [
          // 章节切换 + 批量操作
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _chapter > 1 ? () => _changeChapter(_chapter - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _chapter,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: [
                      for (var n = 1; n <= 50; n++)
                        DropdownMenuItem(value: n, child: Text(UiText.t('第 $n 课', 'Lesson $n'))),
                    ],
                    onChanged: (v) => _changeChapter(v ?? 1),
                  ),
                ),
                IconButton(
                  onPressed: _chapter < 50 ? () => _changeChapter(_chapter + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(UiText.t('已添加 ${_savedIds.length} 个', 'Saved: ${_savedIds.length}'),
                    style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: _words.isEmpty || _loading ? null : _toggleAll,
                  child: Text(_allSelected ? UiText.t('取消全选', 'Deselect All') : UiText.t('全选', 'Select All')),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _words.isEmpty || _loading || _busy ? null : _sync,
                  child: Text(UiText.t('加入背单词（${_selectedIds.length}）', 'Add to Wordbook (${_selectedIds.length})')),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // 单词列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _words.isEmpty
                    ? Center(child: Text(UiText.t('该章没有单词', 'No words in this chapter')))
                    : ListView.builder(
                        itemCount: _words.length,
                        itemBuilder: (context, i) {
                          final w = _words[i];
                          final checked = _selectedIds.contains(w.id);
                          final saved = _savedIds.contains(w.id);
                          return ListTile(
                            dense: true,
                            leading: Checkbox(
                              value: checked,
                              onChanged: (_) => _toggleWord(w.id),
                            ),
                            title: Text('${w.kana}  ${w.kanji.isNotEmpty ? w.kanji : ''}'),
                            subtitle: Text(LanguageSetting.t(w.chinese, w.english)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (saved)
                                  Text(UiText.t('已加入', 'Saved'),
                                      style: TextStyle(color: Colors.green.shade600, fontSize: 12)),
                                AudioButton(entityType: 'word', entityId: w.id, size: 18, fallbackText: w.kana),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeChapter(int ch) async {
    if (ch == _chapter) return;
    setState(() => _chapter = ch);
    await _loadWords();
  }
}
