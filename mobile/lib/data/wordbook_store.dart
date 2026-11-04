import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/sentence.dart';
import '../models/word.dart';
import 'db_helper.dart';

/// 本地单词本存储：收藏 + 复习调度完全本地化（离线可用、无需登录）
///
/// 设计对齐 web 服务端行为（api.py）：
///   - 收藏列表存独立用户库 nihon_user.db（与内容库解耦，内容库升级不丢单词本）
///   - 复习调度复刻 70% 到期旧词 + 30% 新词随机：
///       到期来源 = word_review_queue(due_at<=now，上次忘记优先) ∪ word_mastery(到期/低掌握)
///   - 记得/忘记 复刻掌握度算法：MASTERY_INIT=50，答对 +10（连对≥3 次 +15），
///       答错 -25；间隔 = min(2^streak, 30) 天；忘记 → 次日重新入队 priority=100
class WordbookStore {
  WordbookStore._();

  static final WordbookStore instance = WordbookStore._();

  static Database? _db;

  // 与服务端 api.py 常量一致
  static const double _masteryInit = 50.0;
  static const double _masteryGain = 10.0;
  static const double _masteryGainStreak = 15.0;
  static const double _masteryPenalty = 25.0;
  static const double _masteryLow = 60.0;

  Future<Database> get _userDb async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'nihon_user.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_wordbook (
            word_id INTEGER PRIMARY KEY,
            chapter INTEGER NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS word_mastery (
            word_id INTEGER PRIMARY KEY,
            mastery REAL NOT NULL DEFAULT 50,
            correct_count INTEGER NOT NULL DEFAULT 0,
            wrong_count INTEGER NOT NULL DEFAULT 0,
            total_attempts INTEGER NOT NULL DEFAULT 0,
            streak INTEGER NOT NULL DEFAULT 0,
            next_review_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS word_review_queue (
            word_id INTEGER PRIMARY KEY,
            priority REAL NOT NULL DEFAULT 0,
            due_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  // ---------- 收藏 ----------

  /// 我的单词本（按章节排序）
  Future<List<Word>> getSavedWords() async {
    final d = await _userDb;
    final rows = await d.query(
      'user_wordbook',
      columns: ['word_id', 'chapter'],
      orderBy: 'chapter, word_id',
    );
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['word_id'] as int).toList();
    final words = await DbHelper.getWordsByIds(ids);
    final byId = {for (final w in words) w.id: w};
    return [
      for (final r in rows)
        if (byId[r['word_id'] as int] != null) byId[r['word_id'] as int]!,
    ];
  }

  /// 加入单词本（幂等）
  Future<void> addWord(int wordId, int chapter) async {
    final d = await _userDb;
    await d.insert(
      'user_wordbook',
      {'word_id': wordId, 'chapter': chapter},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 从单词本移除
  Future<void> removeWord(int wordId) async {
    final d = await _userDb;
    await d.delete('user_wordbook', where: 'word_id = ?', whereArgs: [wordId]);
  }

  // ---------- 复习调度（复刻 web 70/30） ----------

  /// 取复习牌堆：70% 到期旧词（忘记优先）+ 30% 新词随机
  Future<List<WordbookReviewItem>> getReviewDeck({int limit = 30}) async {
    final saved = await getSavedWords();
    if (saved.isEmpty) return const [];
    final d = await _userDb;
    final now = _nowIso();

    final dueReason = <int, String>{};
    // 到期来源 1：复习队列中到期的（上次忘记，priority 降序优先）
    final qrows = await d.query(
      'word_review_queue',
      columns: ['word_id'],
      where: 'due_at <= ?',
      whereArgs: [now],
      orderBy: 'priority DESC, due_at ASC',
    );
    for (final r in qrows) {
      dueReason[r['word_id'] as int] = '上次忘记，优先复习';
    }
    // 到期来源 2：掌握度低 / 到期未复习
    final mrows = await d.query(
      'word_mastery',
      columns: ['word_id'],
      where: 'next_review_at <= ? OR mastery < ?',
      whereArgs: [now, _masteryLow],
    );
    for (final r in mrows) {
      dueReason.putIfAbsent(r['word_id'] as int, () => '到期复习');
    }

    final dueSet = dueReason.keys.toSet();
    final dueWords = [for (final w in saved) if (dueSet.contains(w.id)) w];
    final newWords = [for (final w in saved) if (!dueSet.contains(w.id)) w];

    var dueQuota = (limit * 0.7).round();
    var newQuota = limit - dueQuota;
    if (dueWords.length < dueQuota) {
      // 到期词不足，剩余配额让给新词
      newQuota += dueQuota - dueWords.length;
      dueQuota = dueWords.length;
    }

    List<Word> picked = dueWords.take(dueQuota).toList();
    if (newQuota > 0 && newWords.isNotEmpty) {
      picked = [...picked, ..._sample(newWords, min(newQuota, newWords.length))];
    } else if (dueWords.length > dueQuota) {
      // 到期词太多且无新词可补时，多取到期词填满
      picked = dueWords.take(limit).toList();
    }

    final deck = <WordbookReviewItem>[];
    for (final w in picked) {
      deck.add(WordbookReviewItem(
        word: w,
        reason: dueReason[w.id] ?? '新词',
        example: await _pickExample(w.id),
      ));
    }
    return deck;
  }

  /// 随机抽样（不重复）
  List<T> _sample<T>(List<T> items, int count) {
    if (count >= items.length) return List.of(items);
    final copy = List.of(items);
    copy.shuffle(Random());
    return copy.take(count).toList();
  }

  /// 随机取该单词的一条例句（sentence_word_grammar 反查，无则 null）
  Future<WordbookExample?> _pickExample(int wordId) async {
    final d = await DbHelper.db;
    final rows = await d.rawQuery(
      'SELECT sentence_id FROM sentence_word_grammar WHERE word_id = ? ORDER BY RANDOM() LIMIT 1',
      [wordId],
    );
    if (rows.isEmpty) return null;
    final sid = rows.first['sentence_id'] as int;
    final srows = await d.query('sentence', where: 'id = ?', whereArgs: [sid], limit: 1);
    if (srows.isEmpty) return null;
    final s = Sentence.fromMap(srows.first);
    if (s.jpSentence.isEmpty) return null;
    return WordbookExample(japanese: s.jpSentence, chinese: s.chinese, english: s.english);
  }

  // ---------- 复习反馈（复刻服务端掌握度闭环） ----------

  /// 提交记得/忘记结果，更新掌握度与复习队列
  Future<void> saveResult(int wordId, {required bool correct}) async {
    final d = await _userDb;
    await d.transaction((txn) async {
      final now = _nowIso();
      var mastery = _masteryInit;
      var streak = 0;
      var correctCount = 0;
      var wrongCount = 0;
      var total = 0;

      final rows = await txn.query(
        'word_mastery',
        where: 'word_id = ?',
        whereArgs: [wordId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final m = rows.first;
        mastery = (m['mastery'] as num).toDouble();
        streak = m['streak'] as int;
        correctCount = m['correct_count'] as int;
        wrongCount = m['wrong_count'] as int;
        total = m['total_attempts'] as int;
      }

      String nextReview;
      if (correct) {
        streak += 1;
        mastery = min(100.0, mastery + (streak >= 3 ? _masteryGainStreak : _masteryGain));
        correctCount += 1;
        // 间隔递增复习：连对 streak 次 → 2^streak 天，封顶 30 天
        final gapDays = min(pow(2, streak).toInt(), 30);
        nextReview = DateTime.now().toUtc().add(Duration(days: gapDays)).toIso8601String();
      } else {
        streak = 0;
        mastery = max(0.0, mastery - _masteryPenalty);
        wrongCount += 1;
        // 忘记 → 次日立即再出现
        nextReview = DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String();
      }
      total += 1;

      await txn.insert(
        'word_mastery',
        {
          'word_id': wordId,
          'mastery': mastery,
          'correct_count': correctCount,
          'wrong_count': wrongCount,
          'total_attempts': total,
          'streak': streak,
          'next_review_at': nextReview,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 任何作答都清除队列项；忘记 → 重新入队，次日优先复习
      await txn.delete('word_review_queue', where: 'word_id = ?', whereArgs: [wordId]);
      if (!correct) {
        await txn.insert('word_review_queue', {
          'word_id': wordId,
          'priority': 100.0,
          'due_at': nextReview,
        });
      }
    });
  }
}
