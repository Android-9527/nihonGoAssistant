/// 课本（与网页端 DEFAULT_BOOKS 一致）
class Book {
  final String id;
  final String title;
  final int chapterStart;
  final int chapterEnd;

  const Book({
    required this.id,
    required this.title,
    required this.chapterStart,
    required this.chapterEnd,
  });

  List<int> get chapters => [for (int n = chapterStart; n <= chapterEnd; n++) n];
}

const defaultBooks = [
  Book(id: 'minna-nihongo-1', title: '大家的日语初级1', chapterStart: 1, chapterEnd: 25),
  Book(id: 'minna-nihongo-2', title: '大家的日语初级2', chapterStart: 26, chapterEnd: 50),
];
