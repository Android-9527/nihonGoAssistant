import 'package:flutter/material.dart';

import '../models/book.dart';
import 'book_chapters_page.dart';

/// 我的课本：两本书入口
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的课本')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('当前在学课本', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          for (final book in defaultBooks)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(book.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                subtitle: Text('第 ${book.chapterStart} - ${book.chapterEnd} 课 · ${book.chapters.length} 章'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BookChaptersPage(book: book)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
