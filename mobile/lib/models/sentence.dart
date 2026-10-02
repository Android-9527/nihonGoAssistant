/// 句子分词标注（sentence_word_grammar 表，LEFT JOIN word 补充单词信息）
class SentenceToken {
  final int tokenIndex;
  final String surface;
  final int? wordId;
  final int? grammarId;
  final String kana;
  final String kanji;
  final String chinese;

  const SentenceToken({
    required this.tokenIndex,
    required this.surface,
    this.wordId,
    this.grammarId,
    this.kana = '',
    this.kanji = '',
    this.chinese = '',
  });

  bool get hasWord => wordId != null;
  bool get hasGrammar => grammarId != null;

  factory SentenceToken.fromMap(Map<String, dynamic> m) => SentenceToken(
        tokenIndex: m['token_index'] as int,
        surface: (m['surface'] as String?) ?? '',
        wordId: m['word_id'] as int?,
        grammarId: m['grammar_id'] as int?,
        kana: (m['kana'] as String?) ?? '',
        kanji: (m['kanji'] as String?) ?? '',
        chinese: (m['chinese'] as String?) ?? '',
      );
}

/// 句子模型（sentence 表 + 分词）
class Sentence {
  final int id;
  final int chapter;
  final int groupId;
  final String jpSentence;
  final String jpSentenceSeg;
  final String chinese;
  final int? seqNo;
  final String? speaker;
  final List<SentenceToken> tokens;

  const Sentence({
    required this.id,
    required this.chapter,
    required this.groupId,
    required this.jpSentence,
    this.jpSentenceSeg = '',
    required this.chinese,
    this.seqNo,
    this.speaker,
    this.tokens = const [],
  });

  factory Sentence.fromMap(Map<String, dynamic> m) => Sentence(
        id: m['id'] as int,
        chapter: m['chapter'] as int,
        groupId: m['group_id'] as int,
        jpSentence: (m['jp_sentence'] as String?) ?? '',
        jpSentenceSeg: (m['jp_sentence_seg'] as String?) ?? '',
        chinese: (m['chinese'] as String?) ?? '',
        seqNo: m['seq_no'] as int?,
        speaker: m['speaker'] as String?,
      );

  Sentence copyWith({List<SentenceToken>? tokens}) => Sentence(
        id: id,
        chapter: chapter,
        groupId: groupId,
        jpSentence: jpSentence,
        jpSentenceSeg: jpSentenceSeg,
        chinese: chinese,
        seqNo: seqNo,
        speaker: speaker,
        tokens: tokens ?? this.tokens,
      );
}
