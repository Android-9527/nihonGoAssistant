import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/word.dart';
import '../services/api_client.dart';
import '../widgets/audio_button.dart';
import 'grammar_detail_page.dart';
import 'word_detail_page.dart';

/// 检索：单词检索（本地全局）+ 语法分析（调用后端，与网页一致）
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // 单词检索
  final _wordCtrl = TextEditingController();
  List<Word> _words = [];
  bool _wordLoaded = false;

  // 语法分析
  final _grammarCtrl = TextEditingController();
  bool _querying = false;
  String? _queryError;
  Map<String, dynamic>? _queryResult;

  @override
  void dispose() {
    _wordCtrl.dispose();
    _grammarCtrl.dispose();
    super.dispose();
  }

  Future<void> _onWordChanged(String kw) async {
    final list = await DbHelper.searchWords(kw);
    if (!mounted) return;
    setState(() {
      _words = list;
      _wordLoaded = true;
    });
  }

  Future<void> _runGrammarSearch() async {
    final sentence = _grammarCtrl.text.trim();
    if (sentence.isEmpty) return;
    setState(() {
      _querying = true;
      _queryError = null;
      _queryResult = null;
    });
    try {
      final r = await ApiClient.instance.grammarSearch(sentence);
      if (!mounted) return;
      setState(() {
        _queryResult = r;
        _querying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _queryError = e.toString();
        _querying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('检索')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildWordSearch(),
          const SizedBox(height: 14),
          _buildGrammarSearch(),
        ],
      ),
    );
  }

  Widget _buildWordSearch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('单词检索', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('支持假名、汉字、中文检索', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            TextField(
              controller: _wordCtrl,
              decoration: const InputDecoration(
                hintText: '例如：すもう / 相撲 / 相扑',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onWordChanged,
            ),
            const SizedBox(height: 8),
            if (!_wordLoaded)
              const SizedBox.shrink()
            else if (_words.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('未检索到匹配单词', style: TextStyle(color: Colors.grey.shade600)),
              )
            else
              for (final w in _words.take(20))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(w.kana, style: const TextStyle(fontSize: 15)),
                  subtitle: Text('汉字：${w.kanji.isEmpty ? '（无）' : w.kanji}  中文：${w.chinese}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('第${w.chapter}章', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      AudioButton(entityType: 'word', entityId: w.id, size: 18, fallbackText: w.kana),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => WordDetailPage(wordId: w.id)),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrammarSearch() {
    final llm = _queryResult?['llm'] as Map<String, dynamic>?;
    final results = (_queryResult?['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('语法分析', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('输入一句日语，自动分析并返回课本中最相关的 3 条语法',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _grammarCtrl,
                    decoration: const InputDecoration(
                      hintText: '例如：これはいくらですか',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _runGrammarSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _querying ? null : _runGrammarSearch,
                  child: _querying ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('查询'),
                ),
              ],
            ),
            if (_queryError != null) ...[
              const SizedBox(height: 10),
              Text(_queryError!, style: const TextStyle(color: Colors.red)),
            ],
            if (llm != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('语法模板：${llm['grammar_pattern'] ?? '（空）'}'),
                    const SizedBox(height: 6),
                    Text('语法解释：${llm['grammar_explanation'] ?? '（空）'}'),
                  ],
                ),
              ),
            ],
            if (results.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (var i = 0; i < results.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final gid = results[i]['grammar_id'];
                      if (gid is int) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => GrammarDetailPage(grammarId: gid)),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. 第${results[i]['chapter']}章 · Grammar ${results[i]['grammar_id']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text('${results[i]['template']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            '相关度：${((results[i]['final_score'] as num? ?? 0) * 100).toStringAsFixed(2)}%',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ] else if (_queryResult != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('没有检索到结果，可尝试更完整的句子', style: TextStyle(color: Colors.grey.shade600)),
              ),
          ],
        ),
      ),
    );
  }
}
