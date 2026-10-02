import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/grammar.dart';
import '../models/sentence.dart';
import '../widgets/audio_button.dart';

/// 语法详情：解释 + 例句
class GrammarDetailPage extends StatelessWidget {
  final int grammarId;

  const GrammarDetailPage({super.key, required this.grammarId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Grammar?>(
      future: DbHelper.getGrammarDetail(grammarId),
      builder: (context, gs) {
        if (!gs.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final g = gs.data;
        if (g == null) return const Scaffold(body: Center(child: Text('语法不存在')));
        return Scaffold(
          appBar: AppBar(title: const Text('语法详解')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.template, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(g.explanation, style: const TextStyle(fontSize: 15, height: 1.6)),
                      const SizedBox(height: 8),
                      Text('第 ${g.chapter} 课', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('例句（${g.examples.length}）', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              if (g.examples.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('暂无例句', style: TextStyle(color: Colors.grey)),
                )
              else
                ...g.examples.map(_exampleCard),
            ],
          ),
        );
      },
    );
  }

  Widget _exampleCard(Sentence s) {
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
    );
  }
}
