import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../data/database/app_database.dart';
import '../../data/storage/local_image_storage.dart';

class BackupSummary {
  final String filePath;
  final DateTime createdAt;
  final int bookCount;
  final int chapterCount;
  final int blockCount;
  final int nuskhaCount;
  final int imageCount;

  const BackupSummary({
    required this.filePath,
    required this.createdAt,
    required this.bookCount,
    required this.chapterCount,
    required this.blockCount,
    required this.nuskhaCount,
    required this.imageCount,
  });
}

/// Complete offline ZIP backup & restore service preserving all 4 books,
/// chapters, sections, content blocks, Nuskhas, bookmarks, settings, and local images.
class BackupService {
  final AppDatabase _appDb;
  final LocalImageStorage _imageStorage;

  BackupService(this._appDb, this._imageStorage);

  Future<BackupSummary> exportFullBackup({Directory? overrideDirectory}) async {
    final db = await _appDb.database;
    final now = DateTime.now();

    final books = await db.query('books', orderBy: 'slot_order ASC');
    final chapters = await db.query('chapters', orderBy: 'sort_order ASC');
    final sections = await db.query('sections', orderBy: 'sort_order ASC');
    final blocks = await db.query('content_blocks', orderBy: 'sort_order ASC');
    final nuskhas = await db.query('nuskhas');
    final ingredients =
        await db.query('nuskha_ingredients', orderBy: 'sort_order ASC');
    final bookmarks = await db.query('bookmarks');
    final settings = await db.query('app_settings');

    final payload = {
      'schemaVersion': AppConstants.databaseVersion,
      'app': AppConstants.appName,
      'exportedAt': now.toIso8601String(),
      'books': books,
      'chapters': chapters,
      'sections': sections,
      'content_blocks': blocks,
      'nuskhas': nuskhas,
      'nuskha_ingredients': ingredients,
      'bookmarks': bookmarks,
      'app_settings': settings,
    };

    final archive = Archive();
    final jsonBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(payload));
    archive.addFile(ArchiveFile('library_data.json', jsonBytes.length, jsonBytes));

    final storedImages = await _imageStorage.listStoredImages();
    for (final img in storedImages) {
      final bytes = await img.readAsBytes();
      archive.addFile(
        ArchiveFile('images/${p.basename(img.path)}', bytes.length, bytes),
      );
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw const AppException('Failed to encode backup archive.');
    }

    final baseDir = overrideDirectory ?? await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(baseDir.path, 'hakeemi_backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final fileName =
        'hakeemi_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.millisecondsSinceEpoch}.zip';
    final outFile = File(p.join(backupsDir.path, fileName));
    await outFile.writeAsBytes(zipBytes, flush: true);

    return BackupSummary(
      filePath: outFile.path,
      createdAt: now,
      bookCount: books.length,
      chapterCount: chapters.length,
      blockCount: blocks.length,
      nuskhaCount: nuskhas.length,
      imageCount: storedImages.length,
    );
  }

  Future<BackupSummary> restoreFromBackupFile(String zipFilePath) async {
    final file = File(zipFilePath);
    if (!await file.exists()) {
      throw const AppException('Selected backup file does not exist.');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? dataFile;
    for (final entry in archive) {
      if (entry.name == 'library_data.json') {
        dataFile = entry;
        break;
      }
    }
    if (dataFile == null) {
      throw const AppException('Invalid backup archive: missing library_data.json.');
    }

    final decoded =
        jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
    final books = (decoded['books'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (books.length != AppConstants.permanentBookCount) {
      throw AppException(
        'Backup integrity check failed: expected ${AppConstants.permanentBookCount} books, found ${books.length}.',
      );
    }

    // Restore images first
    final imgDir = await _imageStorage.getImagesDirectory();
    int restoredImages = 0;
    for (final entry in archive) {
      if (entry.isFile && entry.name.startsWith('images/')) {
        final outPath = p.join(imgDir.path, p.basename(entry.name));
        final outFile = File(outPath);
        await outFile.writeAsBytes(entry.content as List<int>, flush: true);
        restoredImages++;
      }
    }

    final chapters = (decoded['chapters'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final sections = (decoded['sections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final blocks = (decoded['content_blocks'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final nuskhas = (decoded['nuskhas'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final ingredients = (decoded['nuskha_ingredients'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final bookmarks = (decoded['bookmarks'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final settings = (decoded['app_settings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete('bookmarks');
      await txn.delete('nuskha_ingredients');
      await txn.delete('nuskhas');
      await txn.delete('content_blocks');
      await txn.delete('sections');
      await txn.delete('chapters');
      await txn.delete('books');
      await txn.delete('app_settings');

      for (final row in books) {
        await txn.insert('books', row);
      }
      for (final row in chapters) {
        await txn.insert('chapters', row);
      }
      for (final row in sections) {
        await txn.insert('sections', row);
      }
      for (final row in blocks) {
        await txn.insert('content_blocks', row);
      }
      for (final row in nuskhas) {
        await txn.insert('nuskhas', row);
      }
      for (final row in ingredients) {
        await txn.insert('nuskha_ingredients', row);
      }
      for (final row in bookmarks) {
        await txn.insert('bookmarks', row);
      }
      for (final row in settings) {
        await txn.insert('app_settings', row);
      }
    });

    await _appDb.rebuildSearchIndex();

    return BackupSummary(
      filePath: zipFilePath,
      createdAt: DateTime.now(),
      bookCount: books.length,
      chapterCount: chapters.length,
      blockCount: blocks.length,
      nuskhaCount: nuskhas.length,
      imageCount: restoredImages,
    );
  }
}
