import 'sentence.dart';
import '../services/ui_text.dart';

/// 语法模型（grammar 表 + 例句）
class Grammar {
  final int id;
  final int chapter;
  final String template;
  final String explanation;
  final String templateEn;
  final String explanationEn;
  final List<Sentence> examples;

  const Grammar({
    required this.id,
    required this.chapter,
    required this.template,
    required this.explanation,
    this.templateEn = '',
    this.explanationEn = '',
    this.examples = const [],
  });

  factory Grammar.fromMap(Map<String, dynamic> m) => Grammar(
        id: m['id'] as int,
        chapter: m['chapter'] as int,
        template: (m['template'] as String?) ?? '',
        explanation: (m['explanation'] as String?) ?? '',
        templateEn: (m['template_en'] as String?) ?? '',
        explanationEn: (m['explanation_en'] as String?) ?? '',
      );

  Grammar copyWith({List<Sentence>? examples}) => Grammar(
        id: id,
        chapter: chapter,
        template: template,
        explanation: explanation,
        templateEn: templateEn,
        explanationEn: explanationEn,
        examples: examples ?? this.examples,
      );
}

/// 句子组（sentence_group 表）：对话/短文/语法例句等分组
class SentenceGroup {
  final int groupId;
  final int chapter;
  final String type;
  final String? title;
  final List<Sentence> sentences;

  const SentenceGroup({
    required this.groupId,
    required this.chapter,
    required this.type,
    this.title,
    this.sentences = const [],
  });

  factory SentenceGroup.fromMap(Map<String, dynamic> m) => SentenceGroup(
        groupId: m['group_id'] as int,
        chapter: m['chapter'] as int,
        type: (m['type'] as String?) ?? '',
        title: m['title'] as String?,
      );

  String get typeLabel {
    switch (type) {
      case 'dialogue':
        return UiText.t('对话', 'Dialogue');
      case 'essay':
        return UiText.t('短文', 'Passage');
      case 'grammar_example':
        return UiText.t('语法例句', 'Grammar Examples');
      case 'mul_sentences':
        return UiText.t('多句', 'Multiple Sentences');
      default:
        return UiText.t('句子', 'Sentences');
    }
  }
}
