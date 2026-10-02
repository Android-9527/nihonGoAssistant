import 'package:flutter_test/flutter_test.dart';

import 'package:nihon_go/models/word.dart';

void main() {
  test('Word.fromMap 解析', () {
    final w = Word.fromMap({
      'id': 1,
      'chapter': 2,
      'kana': 'わたし',
      'kanji': '私',
      'chinese': '我',
    });
    expect(w.display, '私');
    expect(w.chapter, 2);
  });
}
