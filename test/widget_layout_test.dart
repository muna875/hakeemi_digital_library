import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakeemi_digital_library/app/app.dart';
import 'package:hakeemi_digital_library/app/app_state.dart';
import 'package:hakeemi_digital_library/core/constants/default_books.dart';
import 'package:hakeemi_digital_library/data/database/app_database.dart';
import 'package:hakeemi_digital_library/data/repositories/book_repository.dart';
import 'package:hakeemi_digital_library/data/repositories/nuskha_repository.dart';
import 'package:hakeemi_digital_library/data/repositories/settings_repository.dart';
import 'package:hakeemi_digital_library/data/storage/local_image_storage.dart';
import 'package:hakeemi_digital_library/features/reader/book_reader_screen.dart';
import 'package:hakeemi_digital_library/models/content_block/content_block_model.dart';
import 'package:hakeemi_digital_library/services/backup/backup_service.dart';
import 'package:hakeemi_digital_library/services/fonts/font_service.dart';
import 'package:hakeemi_digital_library/services/pagination/pagination_engine.dart';
import 'package:hakeemi_digital_library/services/pdf/pdf_export_service.dart';
import 'package:hakeemi_digital_library/services/search/search_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('TEST I & N — RTL Urdu rendering & responsive Android screen sizes without overflow',
      (WidgetTester tester) async {
    final tempDir = await Directory.systemTemp.createTemp('hakeemi_widget_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    final db = AppDatabase(customPath: '${tempDir.path}/widget.db', useFfi: true);
    final bookRepo = BookRepository(db);
    final state = AppState(
      database: db,
      bookRepo: bookRepo,
      nuskhaRepo: NuskhaRepository(db),
      settingsRepo: SettingsRepository(db),
      imageStorage: LocalImageStorage(overrideDirectory: tempDir),
      paginationEngine: const PaginationEngine(measurer: MetricFallbackMeasurer()),
      searchService: SearchService(db, bookRepo),
      pdfExportService: PdfExportService(FontService()),
      backupService: BackupService(db, LocalImageStorage(overrideDirectory: tempDir)),
    );
    await state.initialize();

    final ch = await state.addChapter(
      bookId: DefaultBooks.book1Id,
      title: 'Urdu Test Chapter',
      urduTitle: 'اردو باب',
    );
    await state.addBlock(
      bookId: DefaultBooks.book1Id,
      chapterId: ch.id,
      type: ContentBlockType.paragraph,
      textContent: 'حکیمی کتابخانہ میں خوش آمدید۔ یہ اردو اور English متن ہے۔',
    );

    // Test common Android phone & tablet screen sizes (360x640, 390x844, 412x915)
    for (final size in const [Size(360, 640), Size(390, 844), Size(412, 915)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(HakeemiDigitalLibraryApp(appState: state));
      await tester.pumpAndSettle();

      expect(find.text('Hakeemi Nuskhe'), findsWidgets);
      expect(find.text('Mufradat-o-Advia'), findsWidgets);
      expect(find.text('Murakkabat'), findsWidgets);
      expect(find.text('Tibbi Maloomat'), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    // Verify RTL Urdu reader rendering
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: BookReaderScreen(bookId: DefaultBooks.book1Id, initialPage: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('حکیمی کتابخانہ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await db.close();
  });
}
