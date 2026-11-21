import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/typography/bilingual_text_helper.dart';
import '../../models/book/book_model.dart';
import '../../models/content_block/content_block_model.dart';
import '../document_layout/document_layout_model.dart';
import '../fonts/font_service.dart';

class PdfExportOptions {
  final bool includeFrontCover;
  final bool includeTitlePage;
  final bool includeAuthorPage;
  final bool includeTableOfContents;
  final bool includeBackCover;
  final bool showRunningHeaders;
  final bool showPageNumbers;

  const PdfExportOptions({
    this.includeFrontCover = true,
    this.includeTitlePage = true,
    this.includeAuthorPage = true,
    this.includeTableOfContents = true,
    this.includeBackCover = true,
    this.showRunningHeaders = true,
    this.showPageNumbers = true,
  });
}

class PdfExportResult {
  final Uint8List bytes;
  final int totalPdfPages;
  final int frontMatterPageCount;
  final int bodyPageCount;

  const PdfExportResult({
    required this.bytes,
    required this.totalPdfPages,
    required this.frontMatterPageCount,
    required this.bodyPageCount,
  });
}

/// Genuine programmatic PDF publisher that shares [PaginatedDocument] with the Reader
/// so every body chapter, section, and page number aligns 1:1.
class PdfExportService {
  final FontService _fontService;

  PdfExportService(this._fontService);

  static const PdfColor _forest = PdfColor.fromInt(0xFF174C3C);
  static const PdfColor _deepGreen = PdfColor.fromInt(0xFF103B30);
  static const PdfColor _sage = PdfColor.fromInt(0xFF78947B);
  static const PdfColor _ivory = PdfColor.fromInt(0xFFF8F6EF);
  static const PdfColor _paper = PdfColor.fromInt(0xFFFFFDF8);
  static const PdfColor _ink = PdfColor.fromInt(0xFF172B27);
  static const PdfColor _muted = PdfColor.fromInt(0xFF69766F);
  static const PdfColor _border = PdfColor.fromInt(0xFFE8E7DE);
  static const PdfColor _gold = PdfColor.fromInt(0xFFB59A61);

  Future<PdfExportResult> buildBookPdf({
    required PaginatedDocument document,
    PdfExportOptions options = const PdfExportOptions(),
    String? localAssetsRoot,
  }) async {
    final fonts = await _fontService.loadPdfFonts(
      localAssetsRoot: localAssetsRoot,
    );
    final book = document.book;
    final geom = document.geometry;
    final pageFormat = PdfPageFormat(geom.pageWidthPt, geom.pageHeightPt);

    final pdf = pw.Document(
      title: book.title,
      author: book.authorName,
      creator: 'Hakeemi Digital Library',
    );

    int frontMatterPages = 0;

    // 1. Front Cover (Page 1 of exported PDF)
    if (options.includeFrontCover) {
      frontMatterPages++;
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => _buildCoverPage(book, fonts),
        ),
      );
    }

    // 2. Title Page
    if (options.includeTitlePage) {
      frontMatterPages++;
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(geom.marginHorizontalPt),
          build: (_) => _buildTitlePage(book, fonts),
        ),
      );
    }

    // 3. Optional Author / Publication Page
    if (options.includeAuthorPage) {
      frontMatterPages++;
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(geom.marginHorizontalPt),
          build: (_) => _buildAuthorPage(book, fonts),
        ),
      );
    }

    // 4. Automatically Generated Table of Contents (supports multiple TOC pages)
    if (options.includeTableOfContents && document.tableOfContents.isNotEmpty) {
      const entriesPerTocPage = 24;
      final totalTocPages =
          (document.tableOfContents.length / entriesPerTocPage).ceil();
      for (int pIdx = 0; pIdx < totalTocPages; pIdx++) {
        frontMatterPages++;
        final start = pIdx * entriesPerTocPage;
        final end = (start + entriesPerTocPage)
            .clamp(0, document.tableOfContents.length);
        final chunk = document.tableOfContents.sublist(start, end);
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.symmetric(
              horizontal: geom.marginHorizontalPt,
              vertical: geom.marginTopPt,
            ),
            build: (_) => _buildTocPage(
              entries: chunk,
              tocPageIndex: pIdx + 1,
              totalTocPages: totalTocPages,
              fonts: fonts,
            ),
          ),
        );
      }
    }

    // 5. Body Pages — Rendered 1:1 from shared PaginatedDocument.pages
    for (final docPage in document.pages) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.fromLTRB(
            geom.marginHorizontalPt,
            geom.marginTopPt,
            geom.marginHorizontalPt,
            geom.marginBottomPt,
          ),
          build: (_) => pw.Container(
            color: _paper,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (options.showRunningHeaders)
                  pw.Container(
                    height: geom.headerHeightPt,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: _border, width: 0.7),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          book.title,
                          style: pw.TextStyle(
                            font: fonts.serifItalic,
                            fontFallback: fonts.englishFallbacks,
                            fontSize: 9,
                            color: _muted,
                          ),
                        ),
                        pw.Text(
                          docPage.chapterTitle ?? '',
                          textDirection: _pdfDirection(
                            docPage.chapterTitle ?? '',
                          ),
                          style: pw.TextStyle(
                            font: BilingualTextHelper.containsUrdu(
                              docPage.chapterTitle ?? '',
                            )
                                ? fonts.naskhFallback
                                : fonts.sansRegular,
                            fontFallback: fonts.englishFallbacks,
                            fontSize: 9,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: docPage.slices
                        .map((slice) => _buildPdfSlice(slice, fonts))
                        .toList(),
                  ),
                ),
                if (options.showPageNumbers)
                  pw.Container(
                    height: geom.footerHeightPt,
                    alignment: pw.Alignment.center,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: _border, width: 0.7),
                      ),
                    ),
                    child: pw.Text(
                      '${docPage.pageNumber}',
                      style: pw.TextStyle(
                        font: fonts.serifRegular,
                        fontSize: 10,
                        color: _muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // 6. Optional Back Cover
    int backCoverCount = 0;
    if (options.includeBackCover) {
      backCoverCount = 1;
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => _buildBackCoverPage(book, fonts),
        ),
      );
    }

    final bytes = await pdf.save();
    return PdfExportResult(
      bytes: bytes,
      totalPdfPages: frontMatterPages + document.pages.length + backCoverCount,
      frontMatterPageCount: frontMatterPages,
      bodyPageCount: document.pages.length,
    );
  }

  Future<File> savePdfToDevice({
    required BookModel book,
    required Uint8List bytes,
    Directory? overrideDirectory,
  }) async {
    final baseDir = overrideDirectory ?? await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(baseDir.path, 'hakeemi_pdfs'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final safeName = book.title
        .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final fileName =
        '${safeName.isEmpty ? book.id : safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(p.join(exportsDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  pw.TextDirection _pdfDirection(
    String text, {
    String explicit = 'auto',
  }) {
    if (explicit == 'rtl') return pw.TextDirection.rtl;
    if (explicit == 'ltr') return pw.TextDirection.ltr;
    return BilingualTextHelper.containsUrdu(text)
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
  }

  pw.TextStyle _pdfTextStyle({
    required String text,
    required double fontSize,
    required PdfFontBundle fonts,
    bool isHeading = false,
    bool isBold = false,
    bool isItalic = false,
    PdfColor color = _ink,
    String explicitDirection = 'auto',
  }) {
    final isUrdu = explicitDirection == 'rtl' ||
        (explicitDirection == 'auto' && BilingualTextHelper.containsUrdu(text));
    if (isUrdu) {
      return pw.TextStyle(
        font: (isBold || isHeading) ? fonts.urduBold : fonts.urduRegular,
        fontFallback: fonts.urduFallbacks,
        fontSize: fontSize,
        lineSpacing: 5,
        color: color,
      );
    }
    final font = isHeading
        ? fonts.serifBold
        : isBold
            ? fonts.sansBold
            : isItalic
                ? fonts.serifItalic
                : fonts.sansRegular;
    return pw.TextStyle(
      font: font,
      fontFallback: fonts.englishFallbacks,
      fontSize: fontSize,
      lineSpacing: 3.5,
      color: color,
    );
  }

  pw.Widget _buildPdfSlice(PageSlice slice, PdfFontBundle fonts) {
    if (slice.type == ContentBlockType.image) {
      pw.Widget imgWidget;
      if (slice.imagePath != null && File(slice.imagePath!).existsSync()) {
        final img = pw.MemoryImage(File(slice.imagePath!).readAsBytesSync());
        imgWidget = pw.Image(
          img,
          height: slice.imageHeightPt ?? 160,
          fit: pw.BoxFit.contain,
        );
      } else {
        imgWidget = pw.Container(
          height: 80,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border),
            color: _ivory,
          ),
          child: pw.Text(
            slice.imageCaption ?? 'Image',
            style: pw.TextStyle(font: fonts.sansRegular, color: _muted),
          ),
        );
      }
      return pw.Padding(
        padding: pw.EdgeInsets.only(bottom: slice.spacingAfterPt),
        child: pw.Column(
          children: [
            imgWidget,
            if (slice.imageCaption != null && slice.imageCaption!.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  slice.imageCaption!,
                  style: pw.TextStyle(
                    font: fonts.serifItalic,
                    fontFallback: fonts.englishFallbacks,
                    fontSize: 9.5,
                    color: _muted,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (slice.type == ContentBlockType.table) {
      final headers = slice.tableHeaders ?? const [];
      final rows = slice.tableRows ?? const [];
      return pw.Padding(
        padding: pw.EdgeInsets.only(bottom: slice.spacingAfterPt),
        child: pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
            font: fonts.sansBold,
            fontFallback: fonts.englishFallbacks,
            fontSize: 10,
            color: _paper,
          ),
          headerDecoration: const pw.BoxDecoration(color: _forest),
          cellStyle: pw.TextStyle(
            font: fonts.sansRegular,
            fontFallback: fonts.englishFallbacks,
            fontSize: 9.5,
            color: _ink,
          ),
          border: pw.TableBorder.all(color: _border, width: 0.7),
          cellPadding: const pw.EdgeInsets.all(6),
        ),
      );
    }

    if (slice.type == ContentBlockType.bulletList ||
        slice.type == ContentBlockType.numberedList) {
      final items = slice.listItems ?? const [];
      return pw.Padding(
        padding: pw.EdgeInsets.only(bottom: slice.spacingAfterPt),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < items.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3, left: 10, right: 10),
                child: pw.Text(
                  slice.type == ContentBlockType.numberedList
                      ? '${slice.listStartIndex + i}. ${items[i]}'
                      : '• ${items[i]}',
                  textDirection: _pdfDirection(
                    items[i],
                    explicit: slice.formatting.direction,
                  ),
                  style: _pdfTextStyle(
                    text: items[i],
                    fontSize: slice.formatting.fontSize,
                    fonts: fonts,
                    isBold: slice.formatting.bold,
                    isItalic: slice.formatting.italic,
                    explicitDirection: slice.formatting.direction,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (slice.type == ContentBlockType.note ||
        slice.type == ContentBlockType.nuskhaEntry) {
      final isNuskha = slice.type == ContentBlockType.nuskhaEntry;
      return pw.Container(
        margin: pw.EdgeInsets.only(bottom: slice.spacingAfterPt),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _ivory,
          border: pw.Border(
            left: pw.BorderSide(color: isNuskha ? _forest : _gold, width: 3),
            top: const pw.BorderSide(color: _border, width: 0.6),
            right: const pw.BorderSide(color: _border, width: 0.6),
            bottom: const pw.BorderSide(color: _border, width: 0.6),
          ),
        ),
        child: pw.Text(
          slice.text,
          textDirection: _pdfDirection(
            slice.text,
            explicit: slice.formatting.direction,
          ),
          style: _pdfTextStyle(
            text: slice.text,
            fontSize: slice.formatting.fontSize,
            fonts: fonts,
            isBold: slice.formatting.bold,
            isItalic: slice.formatting.italic,
            explicitDirection: slice.formatting.direction,
          ),
        ),
      );
    }

    final dir = _pdfDirection(
      slice.text,
      explicit: slice.formatting.direction,
    );
    final align = switch (slice.formatting.alignment) {
      'center' => pw.TextAlign.center,
      'end' => dir == pw.TextDirection.rtl
          ? pw.TextAlign.left
          : pw.TextAlign.right,
      'justify' => pw.TextAlign.justify,
      _ => dir == pw.TextDirection.rtl ? pw.TextAlign.right : pw.TextAlign.left,
    };

    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: slice.spacingAfterPt),
      child: pw.Text(
        slice.text,
        textDirection: dir,
        textAlign: align,
        style: _pdfTextStyle(
          text: slice.text,
          fontSize: slice.formatting.fontSize,
          fonts: fonts,
          isHeading: slice.type.isHeading,
          isBold: slice.formatting.bold,
          isItalic: slice.formatting.italic,
          color: slice.type == ContentBlockType.chapterHeading ? _forest : _ink,
          explicitDirection: slice.formatting.direction,
        ),
      ),
    );
  }

  pw.Widget _buildCoverPage(BookModel book, PdfFontBundle fonts) {
    final isIvory = book.coverTemplate == CoverTemplate.minimalistIvory;
    final bgColor = switch (book.coverTemplate) {
      CoverTemplate.botanicalForest => _forest,
      CoverTemplate.botanicalSage => _deepGreen,
      CoverTemplate.academicGold => _deepGreen,
      CoverTemplate.minimalistIvory => _ivory,
      CoverTemplate.customImage => _forest,
    };
    final fgColor = isIvory ? _forest : _paper;
    final subColor = isIvory ? _muted : _ivory;

    return pw.Container(
      color: bgColor,
      padding: const pw.EdgeInsets.all(42),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _gold, width: 2),
        ),
        padding: const pw.EdgeInsets.all(36),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'VOLUME 0${book.slotOrder} • HAKEEMI DIGITAL LIBRARY',
              style: pw.TextStyle(
                font: fonts.sansBold,
                fontSize: 10,
                letterSpacing: 2.2,
                color: _gold,
              ),
            ),
            pw.Column(
              children: [
                if (book.coverTemplate == CoverTemplate.customImage &&
                    book.customCoverImagePath != null &&
                    File(book.customCoverImagePath!).existsSync())
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 24),
                    child: pw.Image(
                      pw.MemoryImage(
                        File(book.customCoverImagePath!).readAsBytesSync(),
                      ),
                      height: 210,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                pw.Text(
                  book.title,
                  textAlign: pw.TextAlign.center,
                  textDirection: _pdfDirection(book.title),
                  style: _pdfTextStyle(
                    text: book.title,
                    fontSize: 32,
                    fonts: fonts,
                    isHeading: true,
                    color: fgColor,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Container(width: 90, height: 1.5, color: _gold),
                pw.SizedBox(height: 14),
                pw.Text(
                  book.subtitle,
                  textAlign: pw.TextAlign.center,
                  textDirection: _pdfDirection(book.subtitle),
                  style: _pdfTextStyle(
                    text: book.subtitle,
                    fontSize: 15,
                    fonts: fonts,
                    isItalic: true,
                    color: subColor,
                  ),
                ),
              ],
            ),
            pw.Column(
              children: [
                if (book.authorName.trim().isNotEmpty)
                  pw.Text(
                    book.authorName,
                    style: pw.TextStyle(
                      font: fonts.serifBold,
                      fontFallback: fonts.englishFallbacks,
                      fontSize: 14,
                      color: fgColor,
                    ),
                  ),
                if (book.publicationInfo.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 6),
                    child: pw.Text(
                      book.publicationInfo,
                      style: pw.TextStyle(
                        font: fonts.sansRegular,
                        fontSize: 10,
                        color: subColor,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTitlePage(BookModel book, PdfFontBundle fonts) {
    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            book.title,
            textAlign: pw.TextAlign.center,
            style: _pdfTextStyle(
              text: book.title,
              fontSize: 28,
              fonts: fonts,
              isHeading: true,
              color: _forest,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            book.subtitle,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: fonts.serifItalic,
              fontFallback: fonts.englishFallbacks,
              fontSize: 14,
              color: _muted,
            ),
          ),
          pw.SizedBox(height: 36),
          pw.Container(width: 60, height: 1, color: _gold),
          pw.SizedBox(height: 36),
          if (book.authorName.trim().isNotEmpty)
            pw.Text(
              'Compiled by ${book.authorName}',
              style: pw.TextStyle(
                font: fonts.serifRegular,
                fontFallback: fonts.englishFallbacks,
                fontSize: 13,
                color: _ink,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildAuthorPage(BookModel book, PdfFontBundle fonts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(
          book.title,
          style: pw.TextStyle(
            font: fonts.serifBold,
            fontFallback: fonts.englishFallbacks,
            fontSize: 14,
            color: _forest,
          ),
        ),
        pw.SizedBox(height: 8),
        if (book.description.trim().isNotEmpty)
          pw.Text(
            book.description,
            style: pw.TextStyle(
              font: fonts.sansRegular,
              fontFallback: fonts.englishFallbacks,
              fontSize: 10.5,
              color: _ink,
            ),
          ),
        pw.SizedBox(height: 16),
        if (book.authorName.trim().isNotEmpty)
          pw.Text(
            'Author / Practitioner: ${book.authorName}',
            style: pw.TextStyle(
              font: fonts.sansRegular,
              fontSize: 10,
              color: _muted,
            ),
          ),
        pw.Text(
          book.publicationInfo.isEmpty
              ? 'Personal Offline Edition — Hakeemi Digital Library'
              : book.publicationInfo,
          style: pw.TextStyle(
            font: fonts.sansRegular,
            fontSize: 10,
            color: _muted,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTocPage({
    required List<TableOfContentsEntry> entries,
    required int tocPageIndex,
    required int totalTocPages,
    required PdfFontBundle fonts,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          totalTocPages > 1
              ? 'Table of Contents ($tocPageIndex of $totalTocPages)'
              : 'Table of Contents',
          style: pw.TextStyle(
            font: fonts.serifBold,
            fontSize: 20,
            color: _forest,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 1.5, color: _gold),
        pw.SizedBox(height: 18),
        for (final entry in entries)
          pw.Padding(
            padding: pw.EdgeInsets.only(
              left: entry.level == 1 ? 0 : 18,
              bottom: entry.level == 1 ? 10 : 6,
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '${entry.numberingLabel}: ${entry.displayTitle}',
                    textDirection: _pdfDirection(entry.displayTitle),
                    style: _pdfTextStyle(
                      text: entry.displayTitle,
                      fontSize: entry.level == 1 ? 11.5 : 10.5,
                      fonts: fonts,
                      isBold: entry.level == 1,
                      color: entry.level == 1 ? _ink : _muted,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Text(
                  '${entry.pageNumber}',
                  style: pw.TextStyle(
                    font: entry.level == 1 ? fonts.serifBold : fonts.serifRegular,
                    fontSize: 11,
                    color: _forest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildBackCoverPage(BookModel book, PdfFontBundle fonts) {
    return pw.Container(
      color: _deepGreen,
      padding: const pw.EdgeInsets.all(48),
      child: pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Container(width: 50, height: 1.5, color: _gold),
            pw.SizedBox(height: 20),
            pw.Text(
              book.title,
              style: pw.TextStyle(
                font: fonts.serifBold,
                fontFallback: fonts.englishFallbacks,
                fontSize: 18,
                color: _paper,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              book.description,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: fonts.sansRegular,
                fontFallback: fonts.englishFallbacks,
                fontSize: 11,
                color: _sage,
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Hakeemi Digital Library • Offline Archival Edition',
              style: pw.TextStyle(
                font: fonts.sansRegular,
                fontSize: 9,
                color: _gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
