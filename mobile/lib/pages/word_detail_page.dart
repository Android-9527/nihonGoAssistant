import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/sentence.dart';
import '../models/word.dart';
import '../widgets/audio_button.dart';

/// 单词详情：词义 + 出现的例句
class WordDetailPage extends StatelessWidget {
  final int wordId;

  const WordDetailPage({super.key, required this.wordId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Word?>(
      future: DbHelper.getWord(wordId),
      builder: (context, ws) {
        if (!ws.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final w = ws.data;
        if (w == null) return const Scaffold(body: Center(child: Text('单词不存在')));
        return Scaffold(
          appBar: AppBar(title: Text(w.display)),
          body: FutureBuilder<List<Sentence>>(
            future: DbHelper.getWordSentences(wordId),
            builder: (context, ss) {
              final sentences = ss.data ?? const <Sentence>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  w.display,
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                                ),
                              ),
                              AudioButton(entityType: 'word', entityId: w.id, size: 26, fallbackText: w.kana),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('读音：${w.kana}', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('释义：${w.chinese}', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('第 ${w.chapter} 课', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('例句（${sentences.length}）', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (sentences.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('暂无例句', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...sentences.map(
                      (s) => Card(
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
                                    Text(s.jpSentence, style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.chinese,
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                              AudioButton(entityType: 'sentence', entityId: s.id, fallbackText: s.jpSentence),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
