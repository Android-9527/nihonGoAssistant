import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/book.dart';
import '../models/sentence.dart';
import '../models/word.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
import '../widgets/audio_button.dart';
import 'grammar_detail_page.dart';
import 'test_page.dart';
import 'word_detail_page.dart';

/// 章节学习路径：单词 / 语法 / 课文 / 测试（与网页一致）
class ChapterLearnPage extends StatelessWidget {
  final Book book;
  final int chapter;

  const ChapterLearnPage({super.key, required this.book, required this.chapter});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(UiText.t('第 $chapter 章', 'Chapter $chapter')),
          bottom: TabBar(
            tabs: [
              Tab(text: UiText.t('单词', 'Words')),
              Tab(text: UiText.t('语法', 'Grammar')),
              Tab(text: UiText.t('课文', 'Texts')),
              Tab(text: UiText.t('测试', 'Test')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ChapterWordsTab(chapter: chapter),
            _ChapterGrammarTab(chapter: chapter),
            _ChapterTextsTab(chapter: chapter),
            _ChapterTestTab(chapter: chapter),
          ],
        ),
      ),
    );
  }
}

/// 分词同时命中「单词 + 语法」时的底部信息弹窗（对标网页的分词信息弹窗）
class _TokenInfoSheet extends StatelessWidget {
  final SentenceToken token;
  final BuildContext pageContext;

  const _TokenInfoSheet({required this.token, required this.pageContext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              UiText.t('分词：${token.surface}', 'Token: ${token.surface}'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (token.hasWord) ...[
              Text(
                UiText.t('单词信息', 'Word Info'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade800),
              ),
              const SizedBox(height: 4),
              Text(UiText.t('假名：${token.kana.isEmpty ? '-' : token.kana}', 'Kana: ${token.kana.isEmpty ? '-' : token.kana}')),
              Text(UiText.t('汉字：${token.kanji.isEmpty ? '-' : token.kanji}', 'Kanji: ${token.kanji.isEmpty ? '-' : token.kanji}')),
              Text(UiText.t('释义：${LanguageSetting.t(token.chinese, token.english).isEmpty ? '-' : LanguageSetting.t(token.chinese, token.english)}',
                  'Meaning: ${LanguageSetting.t(token.chinese, token.english).isEmpty ? '-' : LanguageSetting.t(token.chinese, token.english)}')),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(pageContext).push(
                      MaterialPageRoute(builder: (_) => WordDetailPage(wordId: token.wordId!)),
                    );
                  },
                  child: Text(UiText.t('查看单词详情', 'View Word Detail')),
                ),
              ),
            ],
            if (token.hasGrammar) ...[
              const SizedBox(height: 8),
              Text(
                UiText.t('语法信息', 'Grammar Info'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.amber.shade900),
              ),
              const SizedBox(height: 4),
              Text(UiText.t('语法单词：${token.grammarWord.isEmpty ? '-' : token.grammarWord}', 'Grammar Word: ${token.grammarWord.isEmpty ? '-' : token.grammarWord}')),
              Text(UiText.t('解释：${LanguageSetting.t(token.grammarExplain, token.grammarExplainEn).isEmpty ? '-' : LanguageSetting.t(token.grammarExplain, token.grammarExplainEn)}',
                  'Explanation: ${LanguageSetting.t(token.grammarExplain, token.grammarExplainEn).isEmpty ? '-' : LanguageSetting.t(token.grammarExplain, token.grammarExplainEn)}')),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(pageContext).push(
                      MaterialPageRoute(builder: (_) => GrammarDetailPage(grammarId: token.grammarId!)),
                    );
                  },
                  child: Text(UiText.t('查看语法详情', 'View Grammar Detail')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChapterWordsTab extends StatefulWidget {
  final int chapter;

  const _ChapterWordsTab({required this.chapter});

  @override
  State<_ChapterWordsTab> createState() => _ChapterWordsTabState();
}

class _ChapterWordsTabState extends State<_ChapterWordsTab> {
  bool _hideKana = false;
  bool _hideKanji = false;
  bool _hideChinese = false;
  bool _shuffled = false;
  late Future<List<Word>> _future;
  List<Word> _base = [];
  List<Word> _shown = [];

  @override
  void initState() {
    super.initState();
    _future = DbHelper.getWords(chapter: widget.chapter).then((list) {
      _base = list;
      _shown = [...list];
      return list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 显示控制：隐藏 假名/汉字/中文 + 乱序
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 8,
            children: [
              _toggleChip(UiText.t('隐藏假名', 'Hide Kana'), _hideKana, () => setState(() => _hideKana = !_hideKana)),
              _toggleChip(UiText.t('隐藏汉字', 'Hide Kanji'), _hideKanji, () => setState(() => _hideKanji = !_hideKanji)),
              _toggleChip(UiText.t('隐藏中文', 'Hide Meaning'), _hideChinese, () => setState(() => _hideChinese = !_hideChinese)),
              _toggleChip(_shuffled ? UiText.t('恢复顺序', 'Restore Order') : UiText.t('乱序', 'Shuffle'), _shuffled, _toggleShuffle),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Word>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text(UiText.t('加载失败：', 'Load failed: ') + '${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (_base.isEmpty) return Center(child: Text(UiText.t('本章暂无单词', 'No words in this chapter')));
              final list = _shown;
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final w = list[i];
                  return ListTile(
                    title: _wordLine(w),
                    subtitle: Text(UiText.t('第 ${w.chapter} 课', 'Lesson ${w.chapter}'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
          ),
        ),
      ],
    );
  }

  Widget _toggleChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );
  }

  void _toggleShuffle() {
    if (_shuffled) {
      setState(() {
        _shown = [..._base];
        _shuffled = false;
      });
    } else {
      final arr = [..._shown]..shuffle();
      setState(() {
        _shown = arr;
        _shuffled = true;
      });
    }
  }

  /// 单词按 假名 → 汉字 → 中文 顺序显示，被隐藏的字段不显示
  Widget _wordLine(Word w) {
    final parts = <String>[];
    if (!_hideKana) parts.add(w.kana);
    final kanji = w.kanji.isEmpty || w.kanji == '/' ? '' : w.kanji;
    if (!_hideKanji && kanji.isNotEmpty) parts.add(kanji);
    if (!_hideChinese) parts.add(LanguageSetting.t(w.chinese, w.english));
    if (parts.isEmpty) {
      return Text(UiText.t('（已全部隐藏，点击按钮显示）', '(All hidden — tap the chips to show)'),
          style: const TextStyle(color: Colors.grey));
    }
    return Text(
      parts.join('　'),
      style: const TextStyle(fontSize: 17),
    );
  }
}

class _ChapterGrammarTab extends StatelessWidget {
  final int chapter;

  const _ChapterGrammarTab({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: DbHelper.getGrammar(chapter: chapter),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(UiText.t('加载失败：', 'Load failed: ') + '${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) return Center(child: Text(UiText.t('本章暂无语法', 'No grammar in this chapter')));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final g = list[i];
            return ListTile(
              leading: const Icon(Icons.rule),
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

class _ChapterTextsTab extends StatelessWidget {
  final int chapter;

  const _ChapterTextsTab({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: DbHelper.getChapterTextGroups(chapter),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(UiText.t('加载失败：', 'Load failed: ') + '${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final groups = snap.data!;
        if (groups.isEmpty) return Center(child: Text(UiText.t('本章暂无课文', 'No texts in this chapter')));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: groups.length,
          itemBuilder: (context, gi) {
            final group = groups[gi];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(_groupIcon(group.type), size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        group.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(UiText.t('（${group.sentences.length} 句）', '(${group.sentences.length} sentences)'),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                for (final s in group.sentences)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (s.speaker != null && s.speaker!.trim().isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.cyan.shade50,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: Colors.cyan.shade200),
                                        ),
                                        child: Text(
                                          s.speaker!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      s.jpSentence,
                                      style: const TextStyle(fontSize: 18, height: 1.5),
                                    ),
                                  ],
                                ),
                              ),
                              AudioButton(entityType: 'sentence', entityId: s.id, fallbackText: s.jpSentence),
                            ],
                          ),
                          if (s.tokens.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [for (final t in s.tokens) _tokenChip(context, t)],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            LanguageSetting.t(s.chinese, s.english),
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }

  Widget _tokenChip(BuildContext context, SentenceToken t) {
    final clickable = t.hasWord || t.hasGrammar;
    final Color bg;
    final Color border;
    final Color fg;
    if (t.hasGrammar) {
      // 语法分词：黄色高亮（与网页 token-grammar 一致）
      bg = const Color(0xFFFEF9C3);
      border = const Color(0xFFFDE047);
      fg = const Color(0xFF854D0E);
    } else {
      // 单词/普通分词：灰底不高亮（与网页一致）
      bg = const Color(0xFFF3F4F6);
      border = const Color(0xFFD1D5DB);
      fg = Colors.grey.shade600;
    }
    return InkWell(
      onTap: clickable ? () => _onTokenTap(context, t) : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          t.surface,
          style: TextStyle(fontSize: 13, color: fg),
        ),
      ),
    );
  }

  /// 分词点击：统一弹出信息面板（单词假名/汉字/中文 + 语法单词/解释），与网页版一致
  Future<void> _onTokenTap(BuildContext context, SentenceToken token) async {
    if (!token.hasWord && !token.hasGrammar) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TokenInfoSheet(token: token, pageContext: context),
    );
  }

  IconData _groupIcon(String type) {
    return switch (type) {
      'dialogue' => Icons.forum_outlined,
      'essay' => Icons.article_outlined,
      'grammar_example' => Icons.rule_outlined,
      _ => Icons.format_quote_outlined,
    };
  }
}

class _ChapterTestTab extends StatelessWidget {
  final int chapter;

  const _ChapterTestTab({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(UiText.t('本章自测', 'Chapter Test'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(UiText.t('测试需要登录，结果将同步到你的学习记录', 'Tests require login; results will sync to your learning record'),
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(UiText.t('单词测试', 'Word Test')),
                subtitle: Text(UiText.t('本章单词随机出题', 'Random words from this chapter')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTest(context, 'word'),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.rule_outlined),
                title: Text(UiText.t('语法测试', 'Grammar Test')),
                subtitle: Text(UiText.t('本章语法随机出题', 'Random grammar from this chapter')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTest(context, 'grammar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openTest(BuildContext context, String type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TestPage(
          initialChapter: chapter,
          initialType: type,
        ),
      ),
    );
  }
}
