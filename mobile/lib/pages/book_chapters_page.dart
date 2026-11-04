import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/ui_text.dart';
import 'chapter_learn_page.dart';

/// 课本章节列表
class BookChaptersPage extends StatelessWidget {
  final Book book;

  const BookChaptersPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final chapters = book.chapters;
    return Scaffold(
      appBar: AppBar(title: Text(UiText.t(book.title, book.titleEn))),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
        ),
        itemCount: chapters.length,
        itemBuilder: (context, i) {
          final n = chapters[i];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChapterLearnPage(book: book, chapter: n)),
                );
              },
              child: Center(
                child: Text(UiText.t('第 $n 章', 'Chapter $n'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          );
        },
      ),
    );
  }
}
