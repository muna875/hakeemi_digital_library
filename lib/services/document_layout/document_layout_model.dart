import '../../core/constants/app_constants.dart';
import '../../models/book/book_model.dart';
import '../../models/content_block/content_block_model.dart';

/// Page geometry shared identically between BookReaderScreen and PdfExportService.
class PageGeometry {
  final double pageWidthPt;
  final double pageHeightPt;
  final double marginHorizontalPt;
  final double marginTopPt;
  final double marginBottomPt;
  final double headerHeightPt;
  final double footerHeightPt;

  const PageGeometry({
    this.pageWidthPt = AppConstants.pageWidthPt,
    this.pageHeightPt = AppConstants.pageHeightPt,
    this.marginHorizontalPt = AppConstants.pageMarginHorizontalPt,
    this.marginTopPt = AppConstants.pageMarginTopPt,
    this.marginBottomPt = AppConstants.pageMarginBottomPt,
    this.headerHeightPt = AppConstants.pageHeaderHeightPt,
    this.footerHeightPt = AppConstants.pageFooterHeightPt,
  });

  double get printableWidthPt => pageWidthPt - (marginHorizontalPt * 2);

  double get printableHeightPt =>
      pageHeightPt -
      marginTopPt -
      marginBottomPt -
      headerHeightPt -
      footerHeightPt;
}

/// A single rendered slice of a ContentBlock on a specific page.
/// Long paragraphs, lists, or tables may produce multiple PageSlices across consecutive pages.
class PageSlice {
  final String blockId;
  final String chapterId;
  final String? sectionId;
  final ContentBlockType type;
  final String text;
  final BlockFormatting formatting;
  final double measuredHeightPt;
  final double spacingAfterPt;
  final bool isContinuation;
  final List<String>? listItems;
  final int listStartIndex;
  final List<String>? tableHeaders;
  final List<List<String>>? tableRows;
  final String? imagePath;
  final String? imageCaption;
  final double? imageHeightPt;
  final String? linkedNuskhaId;

  const PageSlice({
    required this.blockId,
    required this.chapterId,
    this.sectionId,
    required this.type,
    required this.text,
    required this.formatting,
    required this.measuredHeightPt,
    this.spacingAfterPt = 10.0,
    this.isContinuation = false,
    this.listItems,
    this.listStartIndex = 1,
    this.tableHeaders,
    this.tableRows,
    this.imagePath,
    this.imageCaption,
    this.imageHeightPt,
    this.linkedNuskhaId,
  });

  double get totalHeightPt => measuredHeightPt + spacingAfterPt;
}

/// One numbered book page produced by PaginationEngine.
class DocumentPage {
  final int pageNumber; // 1-based body page number
  final String? chapterId;
  final String? chapterTitle;
  final String? sectionId;
  final String? sectionTitle;
  final List<PageSlice> slices;
  final double usedHeightPt;

  const DocumentPage({
    required this.pageNumber,
    this.chapterId,
    this.chapterTitle,
    this.sectionId,
    this.sectionTitle,
    required this.slices,
    required this.usedHeightPt,
  });

  String get previewText {
    final buf = StringBuffer();
    for (final s in slices) {
      if (s.text.trim().isNotEmpty) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(s.text.trim());
      } else if (s.listItems != null && s.listItems!.isNotEmpty) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(s.listItems!.join(' • '));
      } else if (s.type == ContentBlockType.image) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write('[Image: ${s.imageCaption ?? 'Figure'}]');
      } else if (s.type == ContentBlockType.table) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write('[Table: ${s.tableHeaders?.join(', ') ?? ''}]');
      }
      if (buf.length > 140) break;
    }
    final str = buf.toString();
    return str.length > 140 ? '${str.substring(0, 140)}…' : str;
  }
}

/// Entry in the automatically generated Table of Contents.
class TableOfContentsEntry {
  final String id;
  final String title;
  final String? urduTitle;
  final int level; // 1 = chapter, 2 = section
  final int pageNumber;
  final String chapterId;
  final String? sectionId;
  final String numberingLabel; // e.g., "Chapter 1" or "1.2"

  const TableOfContentsEntry({
    required this.id,
    required this.title,
    this.urduTitle,
    required this.level,
    required this.pageNumber,
    required this.chapterId,
    this.sectionId,
    required this.numberingLabel,
  });

  String get displayTitle =>
      (urduTitle != null && urduTitle!.trim().isNotEmpty)
          ? '$title — $urduTitle'
          : title;
}

/// Complete paginated representation of a Book, shared by Reader, TOC, Page Manager, Search, and PDF Exporter.
class PaginatedDocument {
  final BookModel book;
  final PageGeometry geometry;
  final List<DocumentPage> pages;
  final List<TableOfContentsEntry> tableOfContents;
  final Map<String, int> blockPageMap; // blockId -> first pageNumber (1-based)
  final Map<String, int> chapterPageMap; // chapterId -> first pageNumber
  final Map<String, int> sectionPageMap; // sectionId -> first pageNumber

  const PaginatedDocument({
    required this.book,
    required this.geometry,
    required this.pages,
    required this.tableOfContents,
    required this.blockPageMap,
    required this.chapterPageMap,
    required this.sectionPageMap,
  });

  int get totalPages => pages.length;

  int? pageForBlock(String blockId) => blockPageMap[blockId];
  int? pageForChapter(String chapterId) => chapterPageMap[chapterId];
  int? pageForSection(String sectionId) => sectionPageMap[sectionId];

  DocumentPage? getPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > pages.length) return null;
    return pages[pageNumber - 1];
  }
}
