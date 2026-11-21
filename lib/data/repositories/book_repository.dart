import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/typography/bilingual_text_helper.dart';
import '../../models/book/book_model.dart';
import '../../models/chapter/chapter_model.dart';
import '../../models/content_block/content_block_model.dart';
import '../../models/section/section_model.dart';
import '../../models/settings/app_settings_model.dart';
import '../database/app_database.dart';

class BookRepository {
  final AppDatabase _appDb;
  final Uuid _uuid = const Uuid();

  BookRepository(this._appDb);

  // ---------------- BOOKS (Strictly 4 Permanent Slots) ----------------

  Future<List<BookModel>> getAllBooks() async {
    final db = await _appDb.database;
    final rows = await db.query(
      'books',
      orderBy: 'slot_order ASC',
      limit: AppConstants.permanentBookCount,
    );
    return rows.map(BookModel.fromMap).toList();
  }

  Future<BookModel?> getBookById(String bookId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BookModel.fromMap(rows.first);
  }

  Future<void> updateBook(BookModel book) async {
    final db = await _appDb.database;
    final updated = book.copyWith(updatedAt: DateTime.now());
    await db.update(
      'books',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> updateReadingProgress({
    required String bookId,
    required int pageNumber,
    String? chapterId,
    int? cachedPageCount,
  }) async {
    final db = await _appDb.database;
    final values = <String, dynamic>{
      'last_opened_page': pageNumber < 1 ? 1 : pageNumber,
    };
    if (chapterId != null) values['last_opened_chapter_id'] = chapterId;
    if (cachedPageCount != null) values['cached_page_count'] = cachedPageCount;
    await db.update('books', values, where: 'id = ?', whereArgs: [bookId]);
  }

  // ---------------- CHAPTERS ----------------

  Future<List<ChapterModel>> getChaptersForBook(String bookId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(ChapterModel.fromMap).toList();
  }

  Future<ChapterModel> createChapter({
    required String bookId,
    required String title,
    String? urduTitle,
    bool startsOnNewPage = true,
  }) async {
    final db = await _appDb.database;
    final existing = await getChaptersForBook(bookId);
    final now = DateTime.now();
    final chapter = ChapterModel(
      id: _uuid.v4(),
      bookId: bookId,
      title: title.trim(),
      urduTitle: urduTitle?.trim().isEmpty == true ? null : urduTitle?.trim(),
      sortOrder: existing.length,
      startsOnNewPage: startsOnNewPage,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('chapters', chapter.toMap());
    await _touchBook(db, bookId);
    await _upsertSearchRow(
      db,
      entityType: 'chapter',
      entityId: chapter.id,
      bookId: bookId,
      chapterId: chapter.id,
      sectionId: '',
      title: chapter.displayTitle,
      raw: chapter.displayTitle,
    );
    return chapter;
  }

  Future<void> updateChapter(ChapterModel chapter) async {
    final db = await _appDb.database;
    final updated = chapter.copyWith(updatedAt: DateTime.now());
    await db.update(
      'chapters',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [chapter.id],
    );
    await _touchBook(db, chapter.bookId);
    await _upsertSearchRow(
      db,
      entityType: 'chapter',
      entityId: updated.id,
      bookId: updated.bookId,
      chapterId: updated.id,
      sectionId: '',
      title: updated.displayTitle,
      raw: updated.displayTitle,
    );
  }

  Future<void> reorderChapters(String bookId, List<ChapterModel> ordered) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      for (int i = 0; i < ordered.length; i++) {
        await txn.update(
          'chapters',
          {'sort_order': i, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [ordered[i].id],
        );
      }
      await txn.update(
        'books',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    });
  }

  Future<void> deleteChapter(String bookId, String chapterId) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete(
        'search_index',
        where: 'chapter_id = ?',
        whereArgs: [chapterId],
      );
      await txn.delete('chapters', where: 'id = ?', whereArgs: [chapterId]);
    });
    await _touchBook(db, bookId);
  }

  // ---------------- SECTIONS ----------------

  Future<List<SectionModel>> getSectionsForBook(String bookId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'sections',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(SectionModel.fromMap).toList();
  }

  Future<List<SectionModel>> getSectionsForChapter(String chapterId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'sections',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(SectionModel.fromMap).toList();
  }

  Future<SectionModel> createSection({
    required String bookId,
    required String chapterId,
    required String title,
    String? urduTitle,
  }) async {
    final db = await _appDb.database;
    final existing = await getSectionsForChapter(chapterId);
    final now = DateTime.now();
    final section = SectionModel(
      id: _uuid.v4(),
      bookId: bookId,
      chapterId: chapterId,
      title: title.trim(),
      urduTitle: urduTitle?.trim().isEmpty == true ? null : urduTitle?.trim(),
      sortOrder: existing.length,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('sections', section.toMap());
    await _touchBook(db, bookId);
    await _upsertSearchRow(
      db,
      entityType: 'section',
      entityId: section.id,
      bookId: bookId,
      chapterId: chapterId,
      sectionId: section.id,
      title: section.displayTitle,
      raw: section.displayTitle,
    );
    return section;
  }

  Future<void> updateSection(SectionModel section) async {
    final db = await _appDb.database;
    final updated = section.copyWith(updatedAt: DateTime.now());
    await db.update(
      'sections',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [section.id],
    );
    await _touchBook(db, section.bookId);
    await _upsertSearchRow(
      db,
      entityType: 'section',
      entityId: updated.id,
      bookId: updated.bookId,
      chapterId: updated.chapterId,
      sectionId: updated.id,
      title: updated.displayTitle,
      raw: updated.displayTitle,
    );
  }

  Future<void> reorderSections(
    String bookId,
    String chapterId,
    List<SectionModel> ordered,
  ) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      for (int i = 0; i < ordered.length; i++) {
        await txn.update(
          'sections',
          {'sort_order': i, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [ordered[i].id],
        );
      }
      await txn.update(
        'books',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    });
  }

  Future<void> deleteSection(String bookId, String sectionId) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete(
        'search_index',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['section', sectionId],
      );
      await txn.delete('sections', where: 'id = ?', whereArgs: [sectionId]);
    });
    await _touchBook(db, bookId);
  }

  // ---------------- CONTENT BLOCKS ----------------

  Future<List<ContentBlockModel>> getBlocksForBook(String bookId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'content_blocks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(ContentBlockModel.fromMap).toList();
  }

  Future<List<ContentBlockModel>> getBlocksForChapter(String chapterId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'content_blocks',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(ContentBlockModel.fromMap).toList();
  }

  Future<ContentBlockModel> createBlock({
    required String bookId,
    required String chapterId,
    String? sectionId,
    required ContentBlockType type,
    required String textContent,
    String? metadataJson,
    BlockFormatting formatting = const BlockFormatting(),
    int? insertAtOrder,
  }) async {
    final db = await _appDb.database;
    final existing = await getBlocksForChapter(chapterId);
    final now = DateTime.now();
    final targetOrder = insertAtOrder ?? existing.length;

    final block = ContentBlockModel(
      id: _uuid.v4(),
      bookId: bookId,
      chapterId: chapterId,
      sectionId: sectionId,
      type: type,
      textContent: textContent,
      metadataJson: metadataJson,
      formatting: formatting,
      sortOrder: targetOrder,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      if (insertAtOrder != null && insertAtOrder < existing.length) {
        for (int i = existing.length - 1; i >= insertAtOrder; i--) {
          await txn.update(
            'content_blocks',
            {'sort_order': i + 1},
            where: 'id = ?',
            whereArgs: [existing[i].id],
          );
        }
      }
      await txn.insert('content_blocks', block.toMap());
    });

    await _touchBook(db, bookId);
    await _upsertSearchRow(
      db,
      entityType: 'block',
      entityId: block.id,
      bookId: bookId,
      chapterId: chapterId,
      sectionId: sectionId ?? '',
      title: '',
      raw: '$textContent ${metadataJson ?? ''}'.trim(),
    );
    return block;
  }

  Future<void> updateBlock(ContentBlockModel block) async {
    final db = await _appDb.database;
    final updated = block.copyWith(updatedAt: DateTime.now());
    await db.update(
      'content_blocks',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [block.id],
    );
    await _touchBook(db, block.bookId);
    await _upsertSearchRow(
      db,
      entityType: 'block',
      entityId: updated.id,
      bookId: updated.bookId,
      chapterId: updated.chapterId,
      sectionId: updated.sectionId ?? '',
      title: '',
      raw: '${updated.textContent} ${updated.metadataJson ?? ''}'.trim(),
    );
  }

  Future<void> reorderBlocks(
    String bookId,
    String chapterId,
    List<ContentBlockModel> ordered,
  ) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      for (int i = 0; i < ordered.length; i++) {
        await txn.update(
          'content_blocks',
          {'sort_order': i, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [ordered[i].id],
        );
      }
      await txn.update(
        'books',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    });
  }

  Future<void> deleteBlock(String bookId, String blockId) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete(
        'search_index',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['block', blockId],
      );
      await txn.delete('content_blocks', where: 'id = ?', whereArgs: [blockId]);
    });
    await _touchBook(db, bookId);
  }

  // ---------------- BOOKMARKS ----------------

  Future<List<BookmarkModel>> getBookmarksForBook(String bookId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'page_number ASC',
    );
    return rows.map(BookmarkModel.fromMap).toList();
  }

  Future<BookmarkModel> toggleBookmark({
    required String bookId,
    required int pageNumber,
    String? chapterTitle,
  }) async {
    final db = await _appDb.database;
    final existing = await db.query(
      'bookmarks',
      where: 'book_id = ? AND page_number = ?',
      whereArgs: [bookId, pageNumber],
    );
    if (existing.isNotEmpty) {
      await db.delete(
        'bookmarks',
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return BookmarkModel.fromMap(existing.first);
    }

    final bm = BookmarkModel(
      id: _uuid.v4(),
      bookId: bookId,
      pageNumber: pageNumber,
      chapterTitle: chapterTitle,
      label: chapterTitle != null
          ? 'Page $pageNumber — $chapterTitle'
          : 'Page $pageNumber',
      createdAt: DateTime.now(),
    );
    await db.insert('bookmarks', bm.toMap());
    return bm;
  }

  Future<void> deleteBookmark(String bookmarkId) async {
    final db = await _appDb.database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [bookmarkId]);
  }

  // ---------------- HELPERS ----------------

  Future<void> _touchBook(Database db, String bookId) async {
    await db.update(
      'books',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> _upsertSearchRow(
    Database db, {
    required String entityType,
    required String entityId,
    required String bookId,
    required String chapterId,
    required String sectionId,
    required String title,
    required String raw,
  }) async {
    await db.delete(
      'search_index',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
    );
    if (raw.trim().isEmpty) return;
    await db.insert('search_index', {
      'entity_type': entityType,
      'entity_id': entityId,
      'book_id': bookId,
      'chapter_id': chapterId,
      'section_id': sectionId,
      'title': title,
      'body_raw': raw,
      'body_normalized': BilingualTextHelper.normalizeForSearch(raw),
    });
  }
}
