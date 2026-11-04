import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/book.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
import 'grammar_detail_page.dart';

/// 语法库：按 课本 → 章节 两级选择展开
class GrammarPage extends StatefulWidget {
  const GrammarPage({super.key});

  @override
  State<GrammarPage> createState() => _GrammarPageState();
}

class _GrammarPageState extends State<GrammarPage> {
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
      appBar: AppBar(title: Text(UiText.t('语法库', 'Grammar Bank'))),
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
                hintText: UiText.t('搜索本章句型或解释', 'Search patterns or explanations'),
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
      future: DbHelper.getGrammar(chapter: chapter),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(UiText.t('加载失败：', 'Load failed: ') + '${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var list = snap.data!;
        final kw = _keyword.trim();
        if (kw.isNotEmpty) {
          list = list
              .where((g) =>
                  g.template.contains(kw) ||
                  g.explanation.contains(kw) ||
                  g.explanationEn.contains(kw))
              .toList();
        }
        if (list.isEmpty) return Center(child: Text(UiText.t('本章暂无语法', 'No grammar in this chapter')));
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
          itemBuilder: (context, i) {
            final g = list[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                child: Text('${g.chapter}', style: const TextStyle(fontSize: 12)),
              ),
              title: Text(g.template, style: const TextStyle(fontSize: 16)),
              subtitle: Text(
                LanguageSetting.t(g.explanation, g.explanationEn),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GrammarDetailPage(grammarId: g.id)),
                );
              },
            );
          },
        );
      },
    );
  }
}
