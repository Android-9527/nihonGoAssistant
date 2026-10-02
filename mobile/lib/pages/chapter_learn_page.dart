import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/book.dart';
import '../models/grammar.dart';
import '../models/sentence.dart';
import '../models/word.dart';
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
          title: Text('第 $chapter 章'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '单词'),
              Tab(text: '语法'),
              Tab(text: '课文'),
              Tab(text: '测试'),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分词：${token.surface}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (token.hasWord) ...[
              Text(
                '单词信息',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade800),
              ),
              const SizedBox(height: 4),
              Text('假名：${token.kana.isEmpty ? '-' : token.kana}'),
              Text('汉字：${token.kanji.isEmpty ? '-' : token.kanji}'),
              Text('中文：${token.chinese.isEmpty ? '-' : token.chinese}'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(pageContext).push(
                      MaterialPageRoute(builder: (_) => WordDetailPage(wordId: token.wordId!)),
                    );
                  },
                  child: const Text('查看单词详情'),
                ),
              ),
            ],
            if (token.hasGrammar) ...[
              const SizedBox(height: 8),
              Text(
                '语法信息',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.amber.shade900),
              ),
              const SizedBox(height: 4),
              FutureBuilder<Grammar?>(
                future: DbHelper.getGrammarDetail(token.grammarId!),
                builder: (context, snap) {
                  final g = snap.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('模板：${g?.template ?? (snap.hasError ? '加载失败' : '加载中…')}'),
                      Text('解释：${g?.explanation ?? ''}'),
                    ],
                  );
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(pageContext).push(
                      MaterialPageRoute(builder: (_) => GrammarDetailPage(grammarId: token.grammarId!)),
                    );
                  },
                  child: const Text('查看语法详情'),
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
              _toggleChip('隐藏假名', _hideKana, () => setState(() => _hideKana = !_hideKana)),
              _toggleChip('隐藏汉字', _hideKanji, () => setState(() => _hideKanji = !_hideKanji)),
              _toggleChip('隐藏中文', _hideChinese, () => setState(() => _hideChinese = !_hideChinese)),
              _toggleChip(_shuffled ? '恢复顺序' : '乱序', _shuffled, _toggleShuffle),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Word>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('加载失败：${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (_base.isEmpty) return const Center(child: Text('本章暂无单词'));
              final list = _shown;
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final w = list[i];
                  return ListTile(
                    title: _wordLine(w),
                    subtitle: Text('第 ${w.chapter} 课', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
    if (!_hideChinese) parts.add(w.chinese);
    if (parts.isEmpty) return const Text('（已全部隐藏，点击按钮显示）', style: TextStyle(color: Colors.grey));
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
        if (snap.hasError) return Center(child: Text('加载失败：${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) return const Center(child: Text('本章暂无语法'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final g = list[i];
            return ListTile(
              leading: const Icon(Icons.rule),
              title: Text(g.template, style: const TextStyle(fontSize: 16)),
              subtitle: Text(
                g.explanation,
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
        if (snap.hasError) return Center(child: Text('加载失败：${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final groups = snap.data!;
        if (groups.isEmpty) return const Center(child: Text('本章暂无课文'));
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
                      Text('（${group.sentences.length} 句）',
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
                            s.chinese,
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
    if (!clickable) {
      bg = Colors.grey.shade100;
      border = Colors.grey.shade300;
    } else if (t.hasGrammar) {
      bg = t.hasWord ? Colors.amber.shade50 : Colors.yellow.shade100;
      border = Colors.amber.shade300;
    } else {
      bg = Colors.green.shade50;
      border = Colors.green.shade300;
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
          style: TextStyle(
            fontSize: 13,
            color: !clickable
                ? Colors.grey.shade600
                : t.hasGrammar
                    ? const Color(0xFF854D0E)
                    : const Color(0xFF166534),
          ),
        ),
      ),
    );
  }

  /// 分词点击：单词 → 单词详情；语法 → 语法详情；两者都有 → 底部弹窗选择
  Future<void> _onTokenTap(BuildContext context, SentenceToken token) async {
    if (!token.hasWord && !token.hasGrammar) return;
    if (token.hasWord && !token.hasGrammar) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WordDetailPage(wordId: token.wordId!)),
      );
      return;
    }
    if (!token.hasWord && token.hasGrammar) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GrammarDetailPage(grammarId: token.grammarId!)),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
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
        Text('本章自测', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('测试需要登录，结果将同步到你的学习记录', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('单词测试'),
                subtitle: const Text('本章单词随机出题'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTest(context, 'word'),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.rule_outlined),
                title: const Text('语法测试'),
                subtitle: const Text('本章语法随机出题'),
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
