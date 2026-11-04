import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/book.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
import '../widgets/audio_button.dart';
import 'word_detail_page.dart';

/// 单词库：按 课本 → 章节 两级选择展开
class WordsPage extends StatefulWidget {
  const WordsPage({super.key});

  @override
  State<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends State<WordsPage> {
  Book _book = defaultBooks.first;
  int? _chapter;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _chapter = _book.chapterStart;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(UiText.t('单词库', 'Word Bank'))),
      body: Column(
        children: [
          // 课本选择
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < defaultBooks.length; i++)
                  ButtonSegment(
                    value: i,
                    label: Text(
                      UiText.t(
                        defaultBooks[i].title.length > 6
                            ? defaultBooks[i].title.substring(0, 6)
                            : defaultBooks[i].title,
                        defaultBooks[i].titleEn.length > 12
                            ? defaultBooks[i].titleEn.substring(0, 12)
                            : defaultBooks[i].titleEn,
                      ),
                    ),
                  ),
              ],
              selected: {defaultBooks.indexOf(_book)},
              onSelectionChanged: (s) => setState(() {
                _book = defaultBooks[s.first];
                _chapter = _book.chapterStart;
                _keyword = '';
              }),
            ),
          ),
          // 章节选择
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final ch in _book.chapters)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(UiText.t('第$ch章', 'Ch.$ch')),
                      selected: _chapter == ch,
                      onSelected: (_) => setState(() => _chapter = ch),
                    ),
                  ),
              ],
            ),
          ),
          // 章节内搜索
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: UiText.t('搜索本章汉字 / 假名 / 释义', 'Search kanji / kana / meaning'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    final chapter = _chapter;
    if (chapter == null) {
      return Center(child: Text(UiText.t('请选择章节', 'Select a chapter')));
    }
    return FutureBuilder(
      future: DbHelper.getWords(chapter: chapter),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(UiText.t('加载失败：', 'Load failed: ') + '${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var list = snap.data!;
        final kw = _keyword.trim();
        if (kw.isNotEmpty) {
          list = list
              .where((w) =>
                  w.kanji.contains(kw) ||
                  w.kana.contains(kw) ||
                  w.chinese.contains(kw) ||
                  w.english.contains(kw))
              .toList();
        }
        if (list.isEmpty) return Center(child: Text(UiText.t('本章暂无单词', 'No words in this chapter')));
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, i) {
            final w = list[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Text('${w.chapter}', style: const TextStyle(fontSize: 12)),
              ),
              title: Text(w.display, style: const TextStyle(fontSize: 17)),
              subtitle: Text('${w.kana}  ${LanguageSetting.t(w.chinese, w.english)}'),
              trailing: AudioButton(entityType: 'word', entityId: w.id, fallbackText: w.kana),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WordDetailPage(wordId: w.id)),
                );
              },
            );
          },
        );
      },
    );
  }
}
