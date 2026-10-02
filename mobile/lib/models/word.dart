/// 单词模型（word 表）
class Word {
  final int id;
  final int chapter;
  final String kana;
  final String kanji;
  final String chinese;

  const Word({
    required this.id,
    required this.chapter,
    required this.kana,
    required this.kanji,
    required this.chinese,
  });

  factory Word.fromMap(Map<String, dynamic> m) => Word(
        id: m['id'] as int,
        chapter: m['chapter'] as int,
        kana: (m['kana'] as String?) ?? '',
        kanji: (m['kanji'] as String?) ?? '',
        chinese: (m['chinese'] as String?) ?? '',
      );

  /// 展示用词形：优先汉字，无汉字用假名
  String get display => kanji.isNotEmpty ? kanji : kana;
}
