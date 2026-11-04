/// 单词模型（word 表）
class Word {
  final int id;
  final int chapter;
  final String kana;
  final String kanji;
  final String chinese;
  final String english;

  const Word({
    required this.id,
    required this.chapter,
    required this.kana,
    required this.kanji,
    required this.chinese,
    this.english = '',
  });

  factory Word.fromMap(Map<String, dynamic> m) => Word(
        id: m['id'] as int,
        chapter: m['chapter'] as int,
        kana: (m['kana'] as String?) ?? '',
        kanji: (m['kanji'] as String?) ?? '',
        chinese: (m['chinese'] as String?) ?? '',
        english: (m['english'] as String?) ?? '',
      );

  /// 展示用词形：优先汉字，无汉字用假名
  String get display => kanji.isNotEmpty ? kanji : kana;
}

/// 单词例句（web 单词本复习接口返回的 example 字段）
class WordbookExample {
  final String japanese;
  final String chinese;
  final String english;

  const WordbookExample({
    required this.japanese,
    required this.chinese,
    required this.english,
  });

  factory WordbookExample.fromJson(Map<String, dynamic> m) => WordbookExample(
        japanese: (m['japanese'] as String?) ?? '',
        chinese: (m['chinese'] as String?) ?? '',
        english: (m['english'] as String?) ?? '',
      );
}

/// 单词本复习卡片（/api/wordbook/review 返回项：单词 + 复习原因 + 例句）
class WordbookReviewItem {
  final Word word;
  final String reason;
  final WordbookExample? example;

  const WordbookReviewItem({
    required this.word,
    required this.reason,
    this.example,
  });

  factory WordbookReviewItem.fromJson(Map<String, dynamic> m) => WordbookReviewItem(
        word: Word.fromMap(m),
        reason: (m['reason'] as String?) ?? '',
        example: m['example'] is Map<String, dynamic>
            ? WordbookExample.fromJson(m['example'] as Map<String, dynamic>)
            : null,
      );
}
