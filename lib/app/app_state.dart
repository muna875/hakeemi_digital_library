import 'dart:io';
import 'package:flutter/foundation.dart';

import '../data/database/app_database.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/nuskha_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/storage/local_image_storage.dart';
import '../models/book/book_model.dart';
import '../models/chapter/chapter_model.dart';
import '../models/content_block/content_block_model.dart';
import '../models/nuskha/nuskha_model.dart';
import '../models/section/section_model.dart';
import '../models/settings/app_settings_model.dart';
import '../services/ai/future_ai_service.dart';
import '../services/backup/backup_service.dart';
import '../services/document_layout/document_layout_model.dart';
import '../services/fonts/font_service.dart';
import '../services/pagination/pagination_engine.dart';
import '../services/pdf/pdf_export_service.dart';
import '../services/search/search_service.dart';

class AppState extends ChangeNotifier {
  final AppDatabase database;
  final BookRepository bookRepo;
  final NuskhaRepository nuskhaRepo;
  final SettingsRepository settingsRepo;
  final LocalImageStorage imageStorage;
  final PaginationEngine paginationEngine;
  final SearchService searchService;
  final PdfExportService pdfExportService;
  final BackupService backupService;
  final FutureAiService aiService;

  bool _initialized = false;
  List<BookModel> _books = const [];
  final Map<String, List<ChapterModel>> _chaptersByBook = {};
  final Map<String, List<SectionModel>> _sectionsByBook = {};
  final Map<String, List<ContentBlockModel>> _blocksByBook = {};
  final Map<String, List<BookmarkModel>> _bookmarksByBook = {};
  final Map<String, PaginatedDocument> _paginatedByBook = {};
  List<NuskhaModel> _nuskhas = const [];
  AppSettingsModel _settings = const AppSettingsModel();

  AppState({
    required this.database,
    required this.bookRepo,
    required this.nuskhaRepo,
    required this.settingsRepo,
    required this.imageStorage,
    required this.paginationEngine,
    required this.searchService,
    required this.pdfExportService,
    required this.backupService,
    this.aiService = const OfflineDisabledAiService(),
  });

  factory AppState.createDefault({AppDatabase? customDb}) {
    final db = customDb ?? AppDatabase();
    final bookRepo = BookRepository(db);
    final nuskhaRepo = NuskhaRepository(db);
    final settingsRepo = SettingsRepository(db);
    final imageStorage = LocalImageStorage();
    const pagination = PaginationEngine();
    final search = SearchService(db, bookRepo);
    final pdf = PdfExportService(FontService());
    final backup = BackupService(db, imageStorage);
    return AppState(
      database: db,
      bookRepo: bookRepo,
      nuskhaRepo: nuskhaRepo,
      settingsRepo: settingsRepo,
      imageStorage: imageStorage,
      paginationEngine: pagination,
      searchService: search,
      pdfExportService: pdf,
      backupService: backup,
    );
  }

  bool get isInitialized => _initialized;
  List<BookModel> get books => _books;
  List<NuskhaModel> get nuskhas => _nuskhas;
  AppSettingsModel get settings => _settings;
  Map<String, PaginatedDocument> get paginatedByBook =>
      Map.unmodifiable(_paginatedByBook);

  BookModel? getBook(String bookId) {
    for (final b in _books) {
      if (b.id == bookId) return b;
    }
    return null;
  }

  List<ChapterModel> chaptersForBook(String bookId) =>
      _chaptersByBook[bookId] ?? const [];

  List<SectionModel> sectionsForBook(String bookId) =>
      _sectionsByBook[bookId] ?? const [];

  List<ContentBlockModel> blocksForBook(String bookId) =>
      _blocksByBook[bookId] ?? const [];

  List<BookmarkModel> bookmarksForBook(String bookId) =>
      _bookmarksByBook[bookId] ?? const [];

  PaginatedDocument? paginatedForBook(String bookId) =>
      _paginatedByBook[bookId];

  BookModel? get mostRecentlyModifiedBook {
    if (_books.isEmpty) return null;
    final sorted = [..._books]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.first;
  }

  Future<void> initialize() async {
    await database.database;
    await refreshAll();
    _initialized = true;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    _settings = await settingsRepo.loadSettings();
    _books = await bookRepo.getAllBooks();
    _nuskhas = await nuskhaRepo.getAllNuskhas();

    for (final book in _books) {
      await _loadAndPaginateBook(book.id, notify: false);
    }
    notifyListeners();
  }

  Future<void> _loadAndPaginateBook(
    String bookId, {
    bool notify = true,
  }) async {
    final book = await bookRepo.getBookById(bookId);
    if (book == null) return;

    final chapters = await bookRepo.getChaptersForBook(bookId);
    final sections = await bookRepo.getSectionsForBook(bookId);
    final blocks = await bookRepo.getBlocksForBook(bookId);
    final bookmarks = await bookRepo.getBookmarksForBook(bookId);

    final paginated = paginationEngine.paginate(
      book: book,
      chapters: chapters,
      sections: sections,
      blocks: blocks,
      baseFontSize: _settings.defaultFontSize,
    );

    if (book.cachedPageCount != paginated.totalPages) {
      await bookRepo.updateReadingProgress(
        bookId: bookId,
        pageNumber: book.lastOpenedPage.clamp(
          1,
          paginated.totalPages > 0 ? paginated.totalPages : 1,
        ),
        cachedPageCount: paginated.totalPages,
      );
    }

    final refreshedBook = (await bookRepo.getBookById(bookId)) ?? book;
    _books = _books.map((b) => b.id == bookId ? refreshedBook : b).toList();
    _chaptersByBook[bookId] = chapters;
    _sectionsByBook[bookId] = sections;
    _blocksByBook[bookId] = blocks;
    _bookmarksByBook[bookId] = bookmarks;
    _paginatedByBook[bookId] = paginated;

    if (notify) notifyListeners();
  }

  // ---------------- BOOK OPERATIONS ----------------

  Future<void> updateBook(BookModel book) async {
    await bookRepo.updateBook(book);
    await _loadAndPaginateBook(book.id);
  }

  Future<void> recordReadingProgress({
    required String bookId,
    required int pageNumber,
    String? chapterId,
  }) async {
    final doc = _paginatedByBook[bookId];
    await bookRepo.updateReadingProgress(
      bookId: bookId,
      pageNumber: pageNumber,
      chapterId: chapterId,
      cachedPageCount: doc?.totalPages,
    );
    final updated = await bookRepo.getBookById(bookId);
    if (updated != null) {
      _books = _books.map((b) => b.id == bookId ? updated : b).toList();
      notifyListeners();
    }
  }

  // ---------------- CHAPTER / SECTION / BLOCK OPERATIONS ----------------

  Future<ChapterModel> addChapter({
    required String bookId,
    required String title,
    String? urduTitle,
    bool startsOnNewPage = true,
  }) async {
    final ch = await bookRepo.createChapter(
      bookId: bookId,
      title: title,
      urduTitle: urduTitle,
      startsOnNewPage: startsOnNewPage,
    );
    await _loadAndPaginateBook(bookId);
    return ch;
  }

  Future<void> updateChapter(ChapterModel chapter) async {
    await bookRepo.updateChapter(chapter);
    await _loadAndPaginateBook(chapter.bookId);
  }

  Future<void> reorderChapters(String bookId, List<ChapterModel> ordered) async {
    await bookRepo.reorderChapters(bookId, ordered);
    await _loadAndPaginateBook(bookId);
  }

  Future<void> deleteChapter(String bookId, String chapterId) async {
    await bookRepo.deleteChapter(bookId, chapterId);
    await _loadAndPaginateBook(bookId);
  }

  Future<SectionModel> addSection({
    required String bookId,
    required String chapterId,
    required String title,
    String? urduTitle,
  }) async {
    final sec = await bookRepo.createSection(
      bookId: bookId,
      chapterId: chapterId,
      title: title,
      urduTitle: urduTitle,
    );
    await _loadAndPaginateBook(bookId);
    return sec;
  }

  Future<void> updateSection(SectionModel section) async {
    await bookRepo.updateSection(section);
    await _loadAndPaginateBook(section.bookId);
  }

  Future<void> reorderSections(
    String bookId,
    String chapterId,
    List<SectionModel> ordered,
  ) async {
    await bookRepo.reorderSections(bookId, chapterId, ordered);
    await _loadAndPaginateBook(bookId);
  }

  Future<void> deleteSection(String bookId, String sectionId) async {
    await bookRepo.deleteSection(bookId, sectionId);
    await _loadAndPaginateBook(bookId);
  }

  Future<ContentBlockModel> addBlock({
    required String bookId,
    required String chapterId,
    String? sectionId,
    required ContentBlockType type,
    required String textContent,
    String? metadataJson,
    BlockFormatting formatting = const BlockFormatting(),
    int? insertAtOrder,
  }) async {
    final blk = await bookRepo.createBlock(
      bookId: bookId,
      chapterId: chapterId,
      sectionId: sectionId,
      type: type,
      textContent: textContent,
      metadataJson: metadataJson,
      formatting: formatting,
      insertAtOrder: insertAtOrder,
    );
    await _loadAndPaginateBook(bookId);
    return blk;
  }

  Future<void> updateBlock(ContentBlockModel block) async {
    await bookRepo.updateBlock(block);
    await _loadAndPaginateBook(block.bookId);
  }

  Future<void> reorderBlocks(
    String bookId,
    String chapterId,
    List<ContentBlockModel> ordered,
  ) async {
    await bookRepo.reorderBlocks(bookId, chapterId, ordered);
    await _loadAndPaginateBook(bookId);
  }

  Future<void> deleteBlock(String bookId, String blockId) async {
    await bookRepo.deleteBlock(bookId, blockId);
    await _loadAndPaginateBook(bookId);
  }

  // ---------------- BOOKMARKS ----------------

  Future<void> toggleBookmark({
    required String bookId,
    required int pageNumber,
    String? chapterTitle,
  }) async {
    await bookRepo.toggleBookmark(
      bookId: bookId,
      pageNumber: pageNumber,
      chapterTitle: chapterTitle,
    );
    _bookmarksByBook[bookId] = await bookRepo.getBookmarksForBook(bookId);
    notifyListeners();
  }

  // ---------------- NUSKHA OPERATIONS ----------------

  Future<NuskhaModel> saveNuskha(NuskhaModel nuskha) async {
    final saved = await nuskhaRepo.saveNuskha(nuskha);
    _nuskhas = await nuskhaRepo.getAllNuskhas();
    notifyListeners();
    return saved;
  }

  Future<void> deleteNuskha(String nuskhaId) async {
    await nuskhaRepo.deleteNuskha(nuskhaId);
    _nuskhas = await nuskhaRepo.getAllNuskhas();
    notifyListeners();
  }

  Future<void> insertNuskhaIntoBook({
    required NuskhaModel nuskha,
    required String bookId,
    required String chapterId,
    String? sectionId,
  }) async {
    await addBlock(
      bookId: bookId,
      chapterId: chapterId,
      sectionId: sectionId,
      type: ContentBlockType.nuskhaEntry,
      textContent: nuskha.toStructuredText(),
      metadataJson: '{"nuskhaId":"${nuskha.id}"}',
    );
  }

  // ---------------- SEARCH, BACKUP, SETTINGS ----------------

  Future<List<SearchResultItem>> search(
    String query, {
    String? bookIdFilter,
  }) {
    return searchService.search(
      query: query,
      paginatedByBook: _paginatedByBook,
      bookIdFilter: bookIdFilter,
    );
  }

  Future<BackupSummary> createBackup({Directory? overrideDirectory}) {
    return backupService.exportFullBackup(overrideDirectory: overrideDirectory);
  }

  Future<BackupSummary> restoreBackup(String zipPath) async {
    final summary = await backupService.restoreFromBackupFile(zipPath);
    await refreshAll();
    return summary;
  }

  Future<void> updateSettings(AppSettingsModel updated) async {
    _settings = updated;
    await settingsRepo.saveSettings(updated);
    // Font size changes affect pagination globally across all 4 books
    for (final book in _books) {
      await _loadAndPaginateBook(book.id, notify: false);
    }
    notifyListeners();
  }
}
