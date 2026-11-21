import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/default_books.dart';
import '../../core/typography/bilingual_text_helper.dart';
import 'database_schema.dart';

class AppDatabase {
  Database? _db;
  final String? customPath;
  final bool useFfi;

  AppDatabase({this.customPath, this.useFfi = false});

  bool get isOpen => _db != null && _db!.isOpen;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    String dbPath;
    if (customPath != null) {
      dbPath = customPath!;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = p.join(dir.path, AppConstants.databaseFileName);
    }

    if (useFfi || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      return factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: AppConstants.databaseVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    return openDatabase(
      dbPath,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    for (final stmt in DatabaseSchema.createTableStatements) {
      await db.execute(stmt);
    }
    await _seedPermanentFourBooks(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations preserve all user data safely without dropping tables.
    await _seedPermanentFourBooks(db);
  }

  /// Ensures exactly four permanent books exist and never creates a fifth.
  Future<void> _seedPermanentFourBooks(Database db) async {
    final existing = await db.query('books', columns: ['id']);
    if (existing.length >= AppConstants.permanentBookCount) return;

    final existingIds = existing.map((e) => e['id'] as String).toSet();
    final now = DateTime.now();
    for (final book in DefaultBooks.createInitialBooks(now)) {
      if (!existingIds.contains(book.id)) {
        await db.insert(
          'books',
          book.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  /// Verifies SQLite PRAGMA integrity_check and 4-book invariant.
  Future<Map<String, dynamic>> runIntegrityCheck() async {
    final db = await database;
    final pragmaResult = await db.rawQuery('PRAGMA integrity_check');
    final integrityStatus = pragmaResult.isNotEmpty
        ? pragmaResult.first.values.first.toString()
        : 'unknown';
    final bookCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM books'),
        ) ??
        0;
    final chapterCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM chapters'),
        ) ??
        0;
    final blockCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM content_blocks'),
        ) ??
        0;
    final nuskhaCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM nuskhas'),
        ) ??
        0;

    return {
      'sqliteIntegrity': integrityStatus,
      'isHealthy': integrityStatus == 'ok' &&
          bookCount == AppConstants.permanentBookCount,
      'bookCount': bookCount,
      'chapterCount': chapterCount,
      'blockCount': blockCount,
      'nuskhaCount': nuskhaCount,
    };
  }

  /// Rebuilds the FTS5 search index from chapters, sections, content blocks, and nuskhas.
  Future<void> rebuildSearchIndex() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('search_index');

      final chapters = await txn.query('chapters');
      for (final ch in chapters) {
        final raw = '${ch['title'] ?? ''} ${ch['urdu_title'] ?? ''}'.trim();
        await txn.insert('search_index', {
          'entity_type': 'chapter',
          'entity_id': ch['id'],
          'book_id': ch['book_id'],
          'chapter_id': ch['id'],
          'section_id': '',
          'title': raw,
          'body_raw': raw,
          'body_normalized': BilingualTextHelper.normalizeForSearch(raw),
        });
      }

      final sections = await txn.query('sections');
      for (final sec in sections) {
        final raw = '${sec['title'] ?? ''} ${sec['urdu_title'] ?? ''}'.trim();
        await txn.insert('search_index', {
          'entity_type': 'section',
          'entity_id': sec['id'],
          'book_id': sec['book_id'],
          'chapter_id': sec['chapter_id'],
          'section_id': sec['id'],
          'title': raw,
          'body_raw': raw,
          'body_normalized': BilingualTextHelper.normalizeForSearch(raw),
        });
      }

      final blocks = await txn.query('content_blocks');
      for (final blk in blocks) {
        final raw =
            '${blk['text_content'] ?? ''} ${blk['metadata_json'] ?? ''}'.trim();
        await txn.insert('search_index', {
          'entity_type': 'block',
          'entity_id': blk['id'],
          'book_id': blk['book_id'],
          'chapter_id': blk['chapter_id'],
          'section_id': blk['section_id'] ?? '',
          'title': '',
          'body_raw': raw,
          'body_normalized': BilingualTextHelper.normalizeForSearch(raw),
        });
      }

      final nuskhas = await txn.query('nuskhas');
      for (final n in nuskhas) {
        final ings = await txn.query(
          'nuskha_ingredients',
          where: 'nuskha_id = ?',
          whereArgs: [n['id']],
        );
        final ingStr = ings
            .map((i) => '${i['name'] ?? ''} ${i['quantity'] ?? ''}')
            .join(' ');
        final raw = [
          n['name'],
          n['urdu_name'],
          n['english_name'],
          n['category'],
          ingStr,
          n['preparation_method'],
          n['usage_instructions'],
          n['personal_observations'],
          n['source_reference'],
          n['additional_notes'],
        ].where((e) => e != null && e.toString().isNotEmpty).join(' ');

        await txn.insert('search_index', {
          'entity_type': 'nuskha',
          'entity_id': n['id'],
          'book_id': n['linked_book_id'] ?? DefaultBooks.book1Id,
          'chapter_id': '',
          'section_id': '',
          'title': '${n['name'] ?? ''} ${n['urdu_name'] ?? ''}'.trim(),
          'body_raw': raw,
          'body_normalized': BilingualTextHelper.normalizeForSearch(raw),
        });
      }
    });
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
