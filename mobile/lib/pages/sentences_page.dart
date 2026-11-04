import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/book.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
import '../widgets/audio_button.dart';

/// 句子库（课文）：按 课本 → 章节 两级选择展开
class SentencesPage extends StatefulWidget {
  const SentencesPage({super.key});

  @override
  State<SentencesPage> createState() => _SentencesPageState();
}

class _SentencesPageState extends State<SentencesPage> {
  Book _book = defaultBooks.first;
  int? _chapter;

  @override
  void initState() {
    super.initState();
    _chapter = _book.chapterStart;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(UiText.t('句子库', 'Sentence Bank'))),
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
      future: DbHelper.getSentences(chapter: chapter),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(UiText.t('加载失败：', 'Load failed: ') + '${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) return Center(child: Text(UiText.t('本章暂无句子', 'No sentences in this chapter')));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final s = list[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.jpSentence, style: const TextStyle(fontSize: 17)),
                          const SizedBox(height: 4),
                          Text(
                            LanguageSetting.t(s.chinese, s.english),
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    AudioButton(entityType: 'sentence', entityId: s.id, fallbackText: s.jpSentence),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
