import '../../core/typography/bilingual_text_helper.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/book_repository.dart';
import '../document_layout/document_layout_model.dart';

class SearchResultItem {
  final String entityType; // 'chapter', 'section', 'block', 'nuskha', 'page'
  final String entityId;
  final String bookId;
  final String bookTitle;
  final String? chapterId;
  final String chapterTitle;
  final int pageNumber;
  final String snippet;

  const SearchResultItem({
    required this.entityType,
    required this.entityId,
    required this.bookId,
    required this.bookTitle,
    this.chapterId,
    required this.chapterTitle,
    required this.pageNumber,
    required this.snippet,
  });
}

class SearchService {
  final AppDatabase _appDb;
  final BookRepository _bookRepo;

  SearchService(this._appDb, this._bookRepo);

  /// Searches across all four books (or a single book if [bookIdFilter] is provided).
  /// Supports Urdu Unicode, English, mixed language, Nuskha names/ingredients,
  /// chapters, sections, and direct page number queries.
  Future<List<SearchResultItem>> search({
    required String query,
    required Map<String, PaginatedDocument> paginatedByBook,
    String? bookIdFilter,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = <SearchResultItem>[];
    final books = await _bookRepo.getAllBooks();
    final bookTitleMap = {for (final b in books) b.id: b.title};

    // 1. Direct page number lookup (e.g., "5" or "page 5")
    final pageMatch = RegExp(r'^(?:page\s*)?(\d+)$', caseSensitive: false)
        .firstMatch(trimmed);
    if (pageMatch != null) {
      final requestedPage = int.tryParse(pageMatch.group(1)!);
      if (requestedPage != null && requestedPage >= 1) {
        for (final entry in paginatedByBook.entries) {
          if (bookIdFilter != null && entry.key != bookIdFilter) continue;
          final page = entry.value.getPage(requestedPage);
          if (page != null) {
            results.add(
              SearchResultItem(
                entityType: 'page',
                entityId: 'page_${entry.key}_$requestedPage',
                bookId: entry.key,
                bookTitle: bookTitleMap[entry.key] ?? entry.value.book.title,
                chapterId: page.chapterId,
                chapterTitle: page.chapterTitle ?? 'Page $requestedPage',
                pageNumber: requestedPage,
                snippet: page.previewText.isEmpty
                    ? 'Jump to Page $requestedPage'
                    : page.previewText,
              ),
            );
          }
        }
      }
    }

    // 2. SQLite FTS5 unicode61 + normalized Urdu/English fallback query
    final db = await _appDb.database;
    final normalized = BilingualTextHelper.normalizeForSearch(trimmed);

    final matchedRows = <Map<String, Object?>>[];
    final seenKeys = <String>{};

    // Build safe FTS5 token query
    final ftsTokens = normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '')}"*')
        .join(' AND ');

    if (ftsTokens.isNotEmpty) {
      try {
        final ftsSql = bookIdFilter != null
            ? 'SELECT * FROM search_index WHERE book_id = ? AND search_index MATCH ? LIMIT 60'
            : 'SELECT * FROM search_index WHERE search_index MATCH ? LIMIT 60';
        final ftsArgs =
            bookIdFilter != null ? [bookIdFilter, ftsTokens] : [ftsTokens];
        final rows = await db.rawQuery(ftsSql, ftsArgs);
        for (final r in rows) {
          final k = '${r['entity_type']}_${r['entity_id']}';
          if (seenKeys.add(k)) matchedRows.add(r);
        }
      } catch (_) {
        // Fallback below handles any special punctuation cleanly
      }
    }

    // Substring normalized LIKE query for partial Urdu/mixed matches
    final likeSql = bookIdFilter != null
        ? 'SELECT * FROM search_index WHERE book_id = ? AND (body_normalized LIKE ? OR body_raw LIKE ?) LIMIT 60'
        : 'SELECT * FROM search_index WHERE (body_normalized LIKE ? OR body_raw LIKE ?) LIMIT 60';
    final likeArgs = bookIdFilter != null
        ? [bookIdFilter, '%$normalized%', '%$trimmed%']
        : ['%$normalized%', '%$trimmed%'];
    final likeRows = await db.rawQuery(likeSql, likeArgs);
    for (final r in likeRows) {
      final k = '${r['entity_type']}_${r['entity_id']}';
      if (seenKeys.add(k)) matchedRows.add(r);
    }

    // Resolve chapter names and live page numbers from PaginatedDocument
    final chapterTitleCache = <String, String>{};
    for (final b in books) {
      final chapters = await _bookRepo.getChaptersForBook(b.id);
      for (final c in chapters) {
        chapterTitleCache[c.id] = c.displayTitle;
      }
    }

    for (final row in matchedRows) {
      final entityType = (row['entity_type'] as String?) ?? 'block';
      final entityId = (row['entity_id'] as String?) ?? '';
      final bookId = (row['book_id'] as String?) ?? '';
      final chapterId = (row['chapter_id'] as String?) ?? '';
      final sectionId = (row['section_id'] as String?) ?? '';
      final raw = (row['body_raw'] as String?) ?? '';

      final doc = paginatedByBook[bookId];
      int pageNum = 1;
      if (doc != null) {
        if (entityType == 'block') {
          pageNum = doc.pageForBlock(entityId) ??
              doc.pageForChapter(chapterId) ??
              1;
        } else if (entityType == 'chapter') {
          pageNum = doc.pageForChapter(chapterId) ?? 1;
        } else if (entityType == 'section') {
          pageNum = doc.pageForSection(sectionId) ??
              doc.pageForChapter(chapterId) ??
              1;
        }
      }

      results.add(
        SearchResultItem(
          entityType: entityType,
          entityId: entityId,
          bookId: bookId,
          bookTitle: bookTitleMap[bookId] ?? 'Library',
          chapterId: chapterId.isEmpty ? null : chapterId,
          chapterTitle: entityType == 'nuskha'
              ? 'Nuskha Entry'
              : (chapterTitleCache[chapterId] ?? 'General'),
          pageNumber: pageNum,
          snippet: _buildSnippet(raw, trimmed),
        ),
      );
    }

    return results;
  }

  String _buildSnippet(String raw, String query) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 130) return clean;
    final idx = clean.toLowerCase().indexOf(query.toLowerCase());
    if (idx < 0) return '${clean.substring(0, 130)}…';
    final start = (idx - 40).clamp(0, clean.length);
    final end = (idx + query.length + 70).clamp(0, clean.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < clean.length ? '…' : '';
    return '$prefix${clean.substring(start, end)}$suffix';
  }
}
