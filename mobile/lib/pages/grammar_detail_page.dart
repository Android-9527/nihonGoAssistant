import 'package:flutter/material.dart';

import '../data/db_helper.dart';
import '../models/grammar.dart';
import '../models/sentence.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
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
        if (g == null) {
          return Scaffold(
              body: Center(child: Text(UiText.t('语法不存在', 'Grammar not found'))));
        }
        return Scaffold(
          appBar: AppBar(title: Text(UiText.t('语法详解', 'Grammar Detail'))),
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
                      Text(LanguageSetting.t(g.explanation, g.explanationEn), style: const TextStyle(fontSize: 15, height: 1.6)),
                      const SizedBox(height: 8),
                      Text(UiText.t('第 ${g.chapter} 课', 'Lesson ${g.chapter}'),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(UiText.t('例句（${g.examples.length}）', 'Examples (${g.examples.length})'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              if (g.examples.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(UiText.t('暂无例句', 'No examples yet'),
                      style: const TextStyle(color: Colors.grey)),
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
  }
}
