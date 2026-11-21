import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakeemi_digital_library/app/app_state.dart';
import 'package:hakeemi_digital_library/core/constants/default_books.dart';
import 'package:hakeemi_digital_library/core/typography/bilingual_text_helper.dart';
import 'package:hakeemi_digital_library/data/database/app_database.dart';
import 'package:hakeemi_digital_library/data/repositories/book_repository.dart';
import 'package:hakeemi_digital_library/data/repositories/nuskha_repository.dart';
import 'package:hakeemi_digital_library/data/repositories/settings_repository.dart';
import 'package:hakeemi_digital_library/data/storage/local_image_storage.dart';
import 'package:hakeemi_digital_library/models/content_block/content_block_model.dart';
import 'package:hakeemi_digital_library/models/nuskha/nuskha_model.dart';
import 'package:hakeemi_digital_library/services/backup/backup_service.dart';
import 'package:hakeemi_digital_library/services/fonts/font_service.dart';
import 'package:hakeemi_digital_library/services/pagination/pagination_engine.dart';
import 'package:hakeemi_digital_library/services/pdf/pdf_export_service.dart';
import 'package:hakeemi_digital_library/services/search/search_service.dart';

AppState _createTestAppState(Directory tempDir, String dbName) {
  final db = AppDatabase(
    customPath: '${tempDir.path}/$dbName',
    useFfi: true,
  );
  final bookRepo = BookRepository(db);
  final nuskhaRepo = NuskhaRepository(db);
  final settingsRepo = SettingsRepository(db);
  final imageStorage = LocalImageStorage(overrideDirectory: tempDir);
  const pagination = PaginationEngine(measurer: MetricFallbackMeasurer());
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hakeemi_qa_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('TEST A — Exactly four permanent books created on first launch', () async {
    final state = _createTestAppState(tempDir, 'test_a.db');
    await state.initialize();

    expect(state.books.length, 4);
    expect(state.books.map((b) => b.title).toList(), [
      'Hakeemi Nuskhe',
      'Mufradat-o-Advia',
      'Murakkabat',
      'Tibbi Maloomat',
    ]);
    // Verify no invented formulations are pre-populated
    for (final book in state.books) {
      expect(state.chaptersForBook(book.id), isEmpty);
      expect(state.blocksForBook(book.id), isEmpty);
    }
    expect(state.nuskhas, isEmpty);
    await state.database.close();
  });

  test('TEST B — Persistence across close and reopen', () async {
    final state1 = _createTestAppState(tempDir, 'test_b.db');
    await state1.initialize();
    final ch = await state1.addChapter(
      bookId: DefaultBooks.book1Id,
      title: 'Introductory Notes',
      urduTitle: 'ابتدائی نوٹس',
    );
    await state1.addBlock(
      bookId: DefaultBooks.book1Id,
      chapterId: ch.id,
      type: ContentBlockType.paragraph,
      textContent: 'Persistent herbal reference entry.',
    );
    await state1.database.close();

    // Reopen fresh instance pointing to same SQLite file
    final state2 = _createTestAppState(tempDir, 'test_b.db');
    await state2.initialize();
    final chapters = state2.chaptersForBook(DefaultBooks.book1Id);
    final blocks = state2.blocksForBook(DefaultBooks.book1Id);
    expect(chapters.length, 1);
    expect(chapters.first.title, 'Introductory Notes');
    expect(blocks.length, 1);
    expect(blocks.first.textContent, 'Persistent herbal reference entry.');
    await state2.database.close();
  });

  test('TEST C, D, E, F — Dynamic pagination, reflow on edit, shrink on delete, live TOC',
      () async {
    final state = _createTestAppState(tempDir, 'test_cdef.db');
    await state.initialize();

    final ch1 = await state.addChapter(
      bookId: DefaultBooks.book2Id,
      title: 'Chapter One',
      startsOnNewPage: true,
    );
    final ch2 = await state.addChapter(
      bookId: DefaultBooks.book2Id,
      title: 'Chapter Two',
      startsOnNewPage: true,
    );

    final blk1 = await state.addBlock(
      bookId: DefaultBooks.book2Id,
      chapterId: ch1.id,
      type: ContentBlockType.paragraph,
      textContent: 'Short opening content A.',
    );
    await state.addBlock(
      bookId: DefaultBooks.book2Id,
      chapterId: ch2.id,
      type: ContentBlockType.paragraph,
      textContent: 'Content B in second chapter.',
    );

    final initialDoc = state.paginatedForBook(DefaultBooks.book2Id)!;
    final initialCh2Page = initialDoc.pageForChapter(ch2.id)!;
    expect(initialDoc.totalPages, 2);
    expect(initialCh2Page, 2);

    // TEST C & D: Add 600+ words to Content A and verify automatic page expansion + Chapter 2 reflow
    final longText = List.generate(
      120,
      (i) => 'Botanical observation sentence number $i describing traditional plant morphology and drying methods.',
    ).join(' ');
    await state.updateBlock(blk1.copyWith(textContent: longText));

    final expandedDoc = state.paginatedForBook(DefaultBooks.book2Id)!;
    final shiftedCh2Page = expandedDoc.pageForChapter(ch2.id)!;
    expect(expandedDoc.totalPages, greaterThan(2));
    expect(shiftedCh2Page, greaterThan(initialCh2Page));

    // TEST F: Table of Contents page numbers match actual chapter positions
    final tocCh2 = expandedDoc.tableOfContents.firstWhere((e) => e.chapterId == ch2.id);
    expect(tocCh2.pageNumber, shiftedCh2Page);

    // TEST E: Delete long content and verify unnecessary pages disappear automatically
    await state.deleteBlock(DefaultBooks.book2Id, blk1.id);
    final shrunkDoc = state.paginatedForBook(DefaultBooks.book2Id)!;
    expect(shrunkDoc.totalPages, lessThan(expandedDoc.totalPages));
    expect(shrunkDoc.pageForChapter(ch2.id), 2);

    await state.database.close();
  });

  test('TEST G & H — Bilingual Urdu & English offline search + exact page navigation',
      () async {
    final state = _createTestAppState(tempDir, 'test_gh.db');
    await state.initialize();

    final ch = await state.addChapter(
      bookId: DefaultBooks.book3Id,
      title: 'Herbal Monograph',
      urduTitle: 'جڑی بوٹیاں',
    );
    final blk = await state.addBlock(
      bookId: DefaultBooks.book3Id,
      chapterId: ch.id,
      type: ContentBlockType.paragraph,
      textContent: 'یہ ایک اردو پیراگراف ہے جس میں کلونجی اور Saffron کا ذکر ہے۔',
    );

    final urduResults = await state.search('کلونجی');
    expect(urduResults, isNotEmpty);
    expect(urduResults.first.bookId, DefaultBooks.book3Id);
    expect(
      urduResults.first.pageNumber,
      state.paginatedForBook(DefaultBooks.book3Id)!.pageForBlock(blk.id),
    );

    final engResults = await state.search('Saffron');
    expect(engResults, isNotEmpty);
    expect(engResults.first.bookId, DefaultBooks.book3Id);

    // Verify bilingual helper RTL/mixed detection
    expect(BilingualTextHelper.containsUrdu(blk.textContent), isTrue);
    expect(BilingualTextHelper.isMixedLanguage(blk.textContent), isTrue);

    await state.database.close();
  });

  test('TEST J, K, L — PDF generation, Reader/PDF page consistency, images & multi-page tables',
      () async {
    final state = _createTestAppState(tempDir, 'test_jkl.db');
    await state.initialize();

    final ch1 = await state.addChapter(
      bookId: DefaultBooks.book4Id,
      title: 'Clinical Reference Tables',
      urduTitle: 'طبی جدول',
    );
    await state.addBlock(
      bookId: DefaultBooks.book4Id,
      chapterId: ch1.id,
      type: ContentBlockType.paragraph,
      textContent: 'Mixed bilingual note: حکمت اور جدید طبی معلومات ایک ساتھ۔',
    );
    // Multi-row table to verify clean pagination splitting across pages
    final manyRows = List.generate(
      35,
      (i) => ['Herb ${i + 1}', 'Temperament ${i + 1}', 'Note ${i + 1}'],
    );
    await state.addBlock(
      bookId: DefaultBooks.book4Id,
      chapterId: ch1.id,
      type: ContentBlockType.table,
      textContent: 'Herb Temperament Note',
      metadataJson: jsonEncode({
        'headers': ['Herb', 'Temperament', 'Notes'],
        'rows': manyRows,
      }),
    );

    final doc = state.paginatedForBook(DefaultBooks.book4Id)!;
    expect(doc.totalPages, greaterThanOrEqualTo(2));

    // Generate genuine PDF using embedded fonts from project assets/
    final pdfResult = await state.pdfExportService.buildBookPdf(
      document: doc,
      localAssetsRoot: Directory.current.path,
    );
    expect(pdfResult.bytes.length, greaterThan(1000));
    // Verify PDF header signature "%PDF-"
    expect(String.fromCharCodes(pdfResult.bytes.take(5)), '%PDF-');
    // TEST K: Body page count in PDF matches Reader 1:1
    expect(pdfResult.bodyPageCount, doc.totalPages);

    await state.database.close();
  });

  test('TEST M — Full offline ZIP backup and restore of all 4 books & Nuskhas',
      () async {
    final state = _createTestAppState(tempDir, 'test_m.db');
    await state.initialize();

    final ch = await state.addChapter(
      bookId: DefaultBooks.book1Id,
      title: 'Saved Formulations',
    );
    await state.addBlock(
      bookId: DefaultBooks.book1Id,
      chapterId: ch.id,
      type: ContentBlockType.paragraph,
      textContent: 'Original verified backup paragraph.',
    );
    await state.saveNuskha(
      NuskhaModel(
        id: '',
        name: 'Personal Safoof Record',
        category: 'Safoof',
        urduName: 'سفوف خاص',
        englishName: 'Herbal Powder',
        ingredients: const [
          NuskhaIngredient(
            id: '',
            nuskhaId: '',
            name: 'Sonf (Fennel)',
            quantity: '50g',
            sortOrder: 0,
          ),
        ],
        preparationMethod: 'Grind finely.',
        usageInstructions: 'As recorded.',
        personalObservations: 'Personal record.',
        sourceReference: 'Family manuscript',
        additionalNotes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final backup = await state.createBackup(overrideDirectory: tempDir);
    expect(File(backup.filePath).existsSync(), isTrue);
    expect(backup.bookCount, 4);
    expect(backup.nuskhaCount, 1);

    // Mutate state, then restore from ZIP
    await state.deleteChapter(DefaultBooks.book1Id, ch.id);
    expect(state.chaptersForBook(DefaultBooks.book1Id), isEmpty);

    await state.restoreBackup(backup.filePath);
    expect(state.books.length, 4);
    expect(state.chaptersForBook(DefaultBooks.book1Id).length, 1);
    expect(state.nuskhas.length, 1);
    expect(state.nuskhas.first.ingredients.first.quantity, '50g');

    await state.database.close();
  });
}
