import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../config.dart';
import '../models/grammar.dart';
import '../models/sentence.dart';
import '../models/word.dart';

/// 本地内容库访问：课本数据打包在 assets，首启复制到应用目录后只读查询
class DbHelper {
  DbHelper._();

  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'nihon_content.db');
    if (!await File(dbPath).exists()) {
      final data = await rootBundle.load(AppConfig.assetDbPath);
      await File(dbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return openDatabase(dbPath);
  }

  // ---------- 章节 ----------

  static Future<List<int>> getChapters() async {
    final rows = await (await db).query(
      'word',
      columns: ['chapter'],
      distinct: true,
      orderBy: 'chapter',
    );
    return rows.map((r) => r['chapter'] as int).toList();
  }

  // ---------- 单词 ----------

  static Future<List<Word>> getWords({int? chapter}) async {
    final rows = chapter == null
        ? await (await db).query('word', orderBy: 'chapter, id')
        : await (await db).query(
            'word',
            where: 'chapter = ?',
            whereArgs: [chapter],
            orderBy: 'id',
          );
    return rows.map(Word.fromMap).toList();
  }

  static Future<Word?> getWord(int id) async {
    final rows = await (await db).query('word', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Word.fromMap(rows.first);
  }

  /// 全局单词检索（假名 / 汉字 / 中文，最多 50 条）
  static Future<List<Word>> searchWords(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return const [];
    final rows = await (await db).query(
      'word',
      where: '(kana LIKE ? OR kanji LIKE ? OR chinese LIKE ?)',
      whereArgs: ['%$kw%', '%$kw%', '%$kw%'],
      orderBy: 'chapter, id',
      limit: 50,
    );
    return rows.map(Word.fromMap).toList();
  }

  /// 单词出现的例句（通过分词标注表反查）
  static Future<List<Sentence>> getWordSentences(int wordId) async {
    final d = await db;
    final ids = await d.query(
      'sentence_word_grammar',
      columns: ['sentence_id'],
      where: 'word_id = ?',
      whereArgs: [wordId],
      distinct: true,
      orderBy: 'sentence_id',
    );
    final result = <Sentence>[];
    for (final r in ids) {
      final sid = r['sentence_id'] as int;
      final s = await _sentenceWithTokens(d, sid);
      if (s != null) result.add(s);
    }
    return result;
  }

  // ---------- 语法 ----------

  static Future<List<Grammar>> getGrammar({int? chapter, String? keyword}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (chapter != null) {
      where.add('chapter = ?');
      args.add(chapter);
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      where.add('(template LIKE ? OR explanation LIKE ?)');
      final kw = '%${keyword.trim()}%';
      args.add(kw);
      args.add(kw);
    }
    final rows = await d.query(
      'grammar',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'chapter, id',
    );
    return rows.map(Grammar.fromMap).toList();
  }

  static Future<Grammar?> getGrammarDetail(int id) async {
    final d = await db;
    final rows = await d.query('grammar', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final g = Grammar.fromMap(rows.first);
    // 通过 grammar_group_sentence -> group 找例句
    final gids = await d.query(
      'grammar_group_sentence',
      columns: ['group_id'],
      where: 'grammar_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    final sentences = <Sentence>[];
    for (final r in gids) {
      final gid = r['group_id'] as int;
      final srows = await d.query(
        'sentence',
        where: 'group_id = ?',
        whereArgs: [gid],
        orderBy: 'seq_no, id',
      );
      for (final sr in srows) {
        final s = Sentence.fromMap(sr);
        sentences.add(await _attachTokens(d, s));
      }
    }
    return g.copyWith(examples: sentences);
  }

  // ---------- 句子 ----------

  static Future<List<Sentence>> getSentences({int? chapter, int? groupId}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (chapter != null) {
      where.add('chapter = ?');
      args.add(chapter);
    }
    if (groupId != null) {
      where.add('group_id = ?');
      args.add(groupId);
    }
    final rows = await d.query(
      'sentence',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'chapter, group_id, seq_no, id',
    );
    final result = <Sentence>[];
    for (final r in rows) {
      result.add(await _attachTokens(d, Sentence.fromMap(r)));
    }
    return result;
  }

  static Future<List<Sentence>> getChapterGroupSentences(int chapter) async {
    final d = await db;
    final groups = await d.query(
      'sentence_group',
      where: 'chapter = ? AND type IN (?, ?)',
      whereArgs: [chapter, 'dialogue', 'essay'],
      orderBy: 'group_id',
    );
    final result = <Sentence>[];
    for (final g in groups) {
      final rows = await d.query(
        'sentence',
        where: 'group_id = ?',
        whereArgs: [g['group_id']],
        orderBy: 'seq_no, id',
      );
      for (final r in rows) {
        result.add(await _attachTokens(d, Sentence.fromMap(r)));
      }
    }
    return result;
  }

  /// 章节课文：按组返回（对话 / 短文 / 句子 / 语法例句 全部类型），带组标题
  static Future<List<({String title, String type, List<Sentence> sentences})>> getChapterTextGroups(int chapter) async {
    final d = await db;
    final groups = await d.query(
      'sentence_group',
      where: 'chapter = ?',
      whereArgs: [chapter],
      orderBy: 'group_id',
    );
    final result = <({String title, String type, List<Sentence> sentences})>[];
    for (final g in groups) {
      final gid = g['group_id'] as int;
      final type = (g['type'] as String?) ?? '';
      final rawTitle = (g['title'] as String?)?.trim() ?? '';
      final rows = await d.query(
        'sentence',
        where: 'group_id = ?',
        whereArgs: [gid],
        orderBy: 'seq_no, id',
      );
      final sentences = <Sentence>[];
      for (final r in rows) {
        sentences.add(await _attachTokens(d, Sentence.fromMap(r)));
      }
      if (sentences.isEmpty) continue;
      final title = rawTitle.isNotEmpty
          ? rawTitle
          : switch (type) {
              'dialogue' => '对话',
              'essay' => '短文',
              'grammar_example' => '语法例句',
              _ => '句子',
            };
      result.add((title: title, type: type, sentences: sentences));
    }
    return result;
  }

  // ---------- 音频 ----------

  /// 返回 tts_audio 的 asset 路径（如 audio/word/chapter_1/word_1.mp3），无音频返回 null
  static Future<String?> getAudioAssetPath(String entityType, int entityId) async {
    final rows = await (await db).query(
      'tts_audio',
      columns: ['file_path'],
      where: 'entity_type = ? AND entity_id = ? AND status = ?',
      whereArgs: [entityType, entityId, 'done'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = (rows.first['file_path'] as String?) ?? '';
    var rel = raw;
    if (rel.startsWith(AppConfig.audioPathPrefix)) {
      rel = rel.substring(AppConfig.audioPathPrefix.length);
    }
    rel = rel.replaceAll('\\', '/');
    if (rel.isEmpty) return null;
    return 'audio/$rel';
  }

  /// 按文本精确查找已生成的音频（供朗读按钮使用）
  static Future<(String, int)?> findAudioByText(String text) async {
    final rows = await (await db).query(
      'tts_audio',
      columns: ['entity_type', 'entity_id'],
      where: 'text_value = ? AND status = ?',
      whereArgs: [text, 'done'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ((rows.first['entity_type'] as String), rows.first['entity_id'] as int);
  }

  // ---------- 内部工具 ----------

  static Future<Sentence?> _sentenceWithTokens(Database d, int sid) async {
    final rows = await d.query('sentence', where: 'id = ?', whereArgs: [sid], limit: 1);
    if (rows.isEmpty) return null;
    return _attachTokens(d, Sentence.fromMap(rows.first));
  }

  static Future<Sentence> _attachTokens(Database d, Sentence s) async {
    final rows = await d.rawQuery(
      'SELECT st.token_index, st.surface, st.word_id, st.grammar_id, '
      "COALESCE(w.kana, '') AS kana, COALESCE(w.kanji, '') AS kanji, COALESCE(w.chinese, '') AS chinese "
      'FROM sentence_word_grammar st '
      'LEFT JOIN word w ON st.word_id = w.id '
      'WHERE st.sentence_id = ? ORDER BY st.token_index',
      [s.id],
    );
    return s.copyWith(tokens: rows.map(SentenceToken.fromMap).toList());
  }

  /// 关闭数据库（供测试/重置使用）
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
