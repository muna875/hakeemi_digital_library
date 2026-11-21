import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/typography/bilingual_text_helper.dart';
import '../../models/book/book_model.dart';
import '../../models/chapter/chapter_model.dart';
import '../../models/content_block/content_block_model.dart';
import '../../models/section/section_model.dart';
import '../document_layout/document_layout_model.dart';

class MeasuredTextChunk {
  final String text;
  final double heightPt;

  const MeasuredTextChunk({required this.text, required this.heightPt});
}

/// Abstraction for text measurement so PaginationEngine uses real Flutter TextPainter
/// metrics on device/widget tests and a deterministic font-metric fallback in pure Dart tests.
abstract class TextMeasurer {
  double measureHeight({
    required String text,
    required double fontSize,
    required double maxWidth,
    required bool isHeading,
    required bool isBold,
    required bool isItalic,
    required String explicitDirection,
  });

  /// Splits [text] so the first chunk fits within [maxHeightPt] at [maxWidth].
  /// Returns (fittingChunk, remainingText). If nothing fits, fittingChunk.text is empty.
  (MeasuredTextChunk, String) splitToFitHeight({
    required String text,
    required double fontSize,
    required double maxWidth,
    required double maxHeightPt,
    required bool isHeading,
    required bool isBold,
    required bool isItalic,
    required String explicitDirection,
  });
}

/// Real Flutter TextPainter measurement using actual font metrics, shaping, and line breaks.
class FlutterTextPainterMeasurer implements TextMeasurer {
  const FlutterTextPainterMeasurer();

  TextPainter _buildPainter({
    required String text,
    required double fontSize,
    required double maxWidth,
    required bool isHeading,
    required bool isBold,
    required bool isItalic,
    required String explicitDirection,
  }) {
    final dir = BilingualTextHelper.resolveDirection(
      text,
      explicitDirection: explicitDirection,
    );
    final style = BilingualTextHelper.buildTextStyle(
      text: text,
      fontSize: fontSize,
      color: const Color(0xFF172B27),
      isHeading: isHeading,
      isBold: isBold,
      isItalic: isItalic,
      explicitDirection: explicitDirection,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: dir,
      textAlign: dir == TextDirection.rtl ? TextAlign.right : TextAlign.left,
    )..layout(maxWidth: maxWidth);
    return painter;
  }

  @override
  double measureHeight({
    required String text,
    required double fontSize,
    required double maxWidth,
    required bool isHeading,
    required bool isBold,
    required bool isItalic,
    required String explicitDirection,
  }) {
    if (text.isEmpty) return 0;
    final painter = _buildPainter(
      text: text,
      fontSize: fontSize,
      maxWidth: maxWidth,
      isHeading: isHeading,
      isBold: isBold,
      isItalic: isItalic,
      explicitDirection: explicitDirection,
    );
    final h = painter.height;
    painter.dispose();
    return h;
  }

  @override
  (MeasuredTextChunk, String) splitToFitHeight({
    required String text,
    required double fontSize,
    required double maxWidth,
    required double maxHeightPt,
    required bool isHeading,
    required bool isBold,
    required bool isItalic,
    required String explicitDirection,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || maxHeightPt <= 0) {
      return (const MeasuredTextChunk(text: '', heightPt: 0), trimmed);
    }

    final fullPainter = _buildPainter(
      text: trimmed,
      fontSize: fontSize,
      maxWidth: maxWidth,
      isHeading: isHeading,
      isBold: isBold,
      isItalic: isItalic,
      explicitDirection: explicitDirection,
    );

    if (fullPainter.height <= maxHeightPt) {
      final h = fullPainter.height;
      fullPainter.dispose();
      return (MeasuredTextChunk(text: trimmed, heightPt: h), '');
    }

    // Use real computed line metrics to determine how many complete lines fit.
    final lines = fullPainter.computeLineMetrics();
    double accHeight = 0;
    int fittingLines = 0;
    for (final line in lines) {
      if (accHeight + line.height <= maxHeightPt) {
        accHeight += line.height;
        fittingLines++;
      } else {
        break;
      }
    }

    if (fittingLines == 0) {
      fullPainter.dispose();
      return (const MeasuredTextChunk(text: '', heightPt: 0), trimmed);
    }

    // Find the exact character offset at the end of the last fitting line.
    final lastLine = lines[fittingLines - 1];
    final pos = fullPainter.getPositionForOffset(
      Offset(maxWidth, lastLine.baseline),
    );
    int splitIndex = pos.offset.clamp(1, trimmed.length);
    fullPainter.dispose();

    // Avoid cutting a word in half where a whitespace boundary exists.
    if (splitIndex < trimmed.length) {
      final lastSpace = trimmed.lastIndexOf(RegExp(r'\s'), splitIndex);
      if (lastSpace > 0) {
        splitIndex = lastSpace;
      }
    }

    final head = trimmed.substring(0, splitIndex).trimRight();
    final tail = trimmed.substring(splitIndex).trimLeft();
    final measuredHeadHeight = measureHeight(
      text: head,
      fontSize: fontSize,
      maxWidth: maxWidth,
      isHeading: isHeading,
      isBold: isBold,
      isItalic: isItalic,
      explicitDirection: explicitDirection,
    );
    return (MeasuredTextChunk(text: head, heightPt: measuredHeadHeight), tail);
  }
}

/// Deterministic font-metric measurer for pure-Dart unit testing without Flutter engine bindings.
class MetricFallbackMeasurer implements TextMeasurer {
  const MetricFallbackMeasurer();

  double _lineHeight(String text, double fontSize, bool isHeading, String dir) {
    final lh = BilingualTextHelper.resolveLineHeight(
      text,
      isHeading: isHeading,
      explicitDirection: dir,
    );
    return fontSize * lh;
  }

  int _charsPerLine(String text, double fontSize, double maxWidth) {
    final avgCharWidth =
        BilingualTextHelper.containsUrdu(text) ? fontSize * 0.48 : fontSize * 0.54;
    return math.max(12, (maxWidth / avgCharWidth).floor());
  }

  List<String> _wrapLines(String text, int charsPerLine) {
    final result = <String>[];
    for (final rawPara in text.split('
')) {
      if (rawPara.trim().isEmpty) {
        result.add('');
        continue;
      }
      final words = rawPara.split(RegExp(r'\s+'));
      var current = '';
      for (final word in words) {
        if (current.isEmpty) {
          current = word;
        } else if (current.length + 1 + word.length <= charsPerLine) {
          current = '$current $word';
        } else {
          result.add(current);
          current = word;
        }
      }
      if (current.isNotEmpty) result.add(current);
    }
    return result;
  }

  @override
  double measureHeight({
    required String text,
    required double fontSize,
    required double maxWidth,
    required bool isHeading,
    required bool isBold,
    required bool isItalic,
    required String explicitDirection,
  }) {
    if (text.trim().isEmpty) return 0;
    final cpl = _charsPerLine(text, fontSize, maxWidth);
    final lines = _wrapLines(text, cpl);
    return lines.length * _lineHeight(text, fontSize, isHeading, explicitDirection);
  }

  @override
  (MeasuredTextChunk, String) splitToFitHeight({
    required String text,
    required double fontSize,
    required double maxWidth,
    required double maxHeightPt,
    required bool isHeading,
    required bool isBold,
    required bool isItalic,
    required String explicitDirection,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || maxHeightPt <= 0) {
      return (const MeasuredTextChunk(text: '', heightPt: 0), trimmed);
    }
    final lh = _lineHeight(trimmed, fontSize, isHeading, explicitDirection);
    final maxLines = (maxHeightPt / lh).floor();
    if (maxLines <= 0) {
      return (const MeasuredTextChunk(text: '', heightPt: 0), trimmed);
    }

    final cpl = _charsPerLine(trimmed, fontSize, maxWidth);
    final lines = _wrapLines(trimmed, cpl);
    if (lines.length <= maxLines) {
      return (
        MeasuredTextChunk(text: trimmed, heightPt: lines.length * lh),
        '',
      );
    }

    final headLines = lines.sublist(0, maxLines);
    final tailLines = lines.sublist(maxLines);
    return (
      MeasuredTextChunk(
        text: headLines.join(' '),
        heightPt: headLines.length * lh,
      ),
      tailLines.join(' '),
    );
  }
}

/// Core Dynamic Book Layout & Pagination Engine.
/// Flows structured chapters, sections, and content blocks into A4-like pages
/// with keep-with-next heading protection, automatic reflow, and TOC generation.
class PaginationEngine {
  final TextMeasurer measurer;
  final PageGeometry geometry;

  const PaginationEngine({
    this.measurer = const FlutterTextPainterMeasurer(),
    this.geometry = const PageGeometry(),
  });

  PaginatedDocument paginate({
    required BookModel book,
    required List<ChapterModel> chapters,
    required List<SectionModel> sections,
    required List<ContentBlockModel> blocks,
    double baseFontSize = 13.0,
  }) {
    final sortedChapters = [...chapters]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final sectionsByChapter = <String, List<SectionModel>>{};
    for (final s in sections) {
      sectionsByChapter.putIfAbsent(s.chapterId, () => []).add(s);
    }
    for (final list in sectionsByChapter.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final blocksByChapter = <String, List<ContentBlockModel>>{};
    for (final b in blocks) {
      blocksByChapter.putIfAbsent(b.chapterId, () => []).add(b);
    }
    for (final list in blocksByChapter.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final pages = <DocumentPage>[];
    final tocEntries = <TableOfContentsEntry>[];
    final blockPageMap = <String, int>{};
    final chapterPageMap = <String, int>{};
    final sectionPageMap = <String, int>{};

    final maxW = geometry.printableWidthPt;
    final maxH = geometry.printableHeightPt;

    // Active mutable page builder state
    var currentSlices = <PageSlice>[];
    var usedHeight = 0.0;
    String? currentChapterId;
    String? currentChapterTitle;
    String? currentSectionId;
    String? currentSectionTitle;

    int activePageNumber() => pages.length + 1;

    void flushPage() {
      if (currentSlices.isEmpty) return;
      pages.add(
        DocumentPage(
          pageNumber: pages.length + 1,
          chapterId: currentChapterId,
          chapterTitle: currentChapterTitle,
          sectionId: currentSectionId,
          sectionTitle: currentSectionTitle,
          slices: List.unmodifiable(currentSlices),
          usedHeightPt: usedHeight,
        ),
      );
      currentSlices = <PageSlice>[];
      usedHeight = 0.0;
    }

    void addSlice(PageSlice slice) {
      if (usedHeight + slice.totalHeightPt > maxH && currentSlices.isNotEmpty) {
        flushPage();
      }
      currentSlices.add(slice);
      usedHeight += slice.totalHeightPt;
      blockPageMap.putIfAbsent(slice.blockId, () => activePageNumber());
    }

    for (int chIdx = 0; chIdx < sortedChapters.length; chIdx++) {
      final chapter = sortedChapters[chIdx];
      final chapterNum = chIdx + 1;

      if (chapter.startsOnNewPage && currentSlices.isNotEmpty) {
        flushPage();
      }

      currentChapterId = chapter.id;
      currentChapterTitle = chapter.displayTitle;
      currentSectionId = null;
      currentSectionTitle = null;

      // Chapter Heading Slice (keep-with-next protection)
      final chTitleText = 'Chapter $chapterNum: ${chapter.displayTitle}';
      final chFontSize = baseFontSize + 7.0;
      final chHeight = measurer.measureHeight(
        text: chTitleText,
        fontSize: chFontSize,
        maxWidth: maxW,
        isHeading: true,
        isBold: true,
        isItalic: false,
        explicitDirection: 'auto',
      );
      const chSpacingAfter = 14.0;
      const minFollowingReserve = 42.0;

      if (usedHeight + chHeight + chSpacingAfter + minFollowingReserve > maxH &&
          currentSlices.isNotEmpty) {
        flushPage();
      }

      final chPageNum = activePageNumber();
      chapterPageMap[chapter.id] = chPageNum;
      tocEntries.add(
        TableOfContentsEntry(
          id: 'toc_ch_${chapter.id}',
          title: chapter.title,
          urduTitle: chapter.urduTitle,
          level: 1,
          pageNumber: chPageNum,
          chapterId: chapter.id,
          numberingLabel: 'Chapter $chapterNum',
        ),
      );

      addSlice(
        PageSlice(
          blockId: 'chapter_hdr_${chapter.id}',
          chapterId: chapter.id,
          type: ContentBlockType.chapterHeading,
          text: chTitleText,
          formatting: BlockFormatting(bold: true, fontSize: chFontSize),
          measuredHeightPt: chHeight,
          spacingAfterPt: chSpacingAfter,
        ),
      );

      final chSections = sectionsByChapter[chapter.id] ?? [];
      final chBlocks = blocksByChapter[chapter.id] ?? [];

      // Group blocks: unsectioned first, then in section order
      final orderedGroups = <(SectionModel?, List<ContentBlockModel>)>[];
      final unsectioned =
          chBlocks.where((b) => b.sectionId == null || b.sectionId!.isEmpty).toList();
      if (unsectioned.isNotEmpty) {
        orderedGroups.add((null, unsectioned));
      }
      for (final sec in chSections) {
        final secBlocks = chBlocks.where((b) => b.sectionId == sec.id).toList();
        orderedGroups.add((sec, secBlocks));
      }

      int secCounter = 0;
      for (final group in orderedGroups) {
        final section = group.$1;
        final groupBlocks = group.$2;

        if (section != null) {
          secCounter++;
          currentSectionId = section.id;
          currentSectionTitle = section.displayTitle;

          final secLabel = '$chapterNum.$secCounter ${section.displayTitle}';
          final secFontSize = baseFontSize + 3.5;
          final secHeight = measurer.measureHeight(
            text: secLabel,
            fontSize: secFontSize,
            maxWidth: maxW,
            isHeading: true,
            isBold: true,
            isItalic: false,
            explicitDirection: 'auto',
          );
          const secSpacingAfter = 10.0;

          if (usedHeight + secHeight + secSpacingAfter + minFollowingReserve >
                  maxH &&
              currentSlices.isNotEmpty) {
            flushPage();
          }

          final secPageNum = activePageNumber();
          sectionPageMap[section.id] = secPageNum;
          tocEntries.add(
            TableOfContentsEntry(
              id: 'toc_sec_${section.id}',
              title: section.title,
              urduTitle: section.urduTitle,
              level: 2,
              pageNumber: secPageNum,
              chapterId: chapter.id,
              sectionId: section.id,
              numberingLabel: '$chapterNum.$secCounter',
            ),
          );

          addSlice(
            PageSlice(
              blockId: 'section_hdr_${section.id}',
              chapterId: chapter.id,
              sectionId: section.id,
              type: ContentBlockType.sectionHeading,
              text: secLabel,
              formatting: BlockFormatting(bold: true, fontSize: secFontSize),
              measuredHeightPt: secHeight,
              spacingAfterPt: secSpacingAfter,
            ),
          );
        }

        for (final block in groupBlocks) {
          _flowBlock(
            block: block,
            baseFontSize: baseFontSize,
            maxW: maxW,
            maxH: maxH,
            getUsedHeight: () => usedHeight,
            hasCurrentSlices: () => currentSlices.isNotEmpty,
            flushPage: flushPage,
            addSlice: addSlice,
          );
        }
      }
    }

    flushPage();

    return PaginatedDocument(
      book: book,
      geometry: geometry,
      pages: List.unmodifiable(pages),
      tableOfContents: List.unmodifiable(tocEntries),
      blockPageMap: Map.unmodifiable(blockPageMap),
      chapterPageMap: Map.unmodifiable(chapterPageMap),
      sectionPageMap: Map.unmodifiable(sectionPageMap),
    );
  }

  void _flowBlock({
    required ContentBlockModel block,
    required double baseFontSize,
    required double maxW,
    required double maxH,
    required double Function() getUsedHeight,
    required bool Function() hasCurrentSlices,
    required void Function() flushPage,
    required void Function(PageSlice) addSlice,
  }) {
    if (block.type == ContentBlockType.manualPageBreak) {
      if (hasCurrentSlices()) {
        flushPage();
      }
      return;
    }

    if (block.type == ContentBlockType.image) {
      final imgH = block.imageHeightPt.clamp(80.0, maxH - 40.0);
      final captionH =
          (block.imageCaption != null && block.imageCaption!.isNotEmpty)
              ? 22.0
              : 0.0;
      final totalH = imgH + captionH;
      if (getUsedHeight() + totalH + 12.0 > maxH && hasCurrentSlices()) {
        flushPage();
      }
      addSlice(
        PageSlice(
          blockId: block.id,
          chapterId: block.chapterId,
          sectionId: block.sectionId,
          type: ContentBlockType.image,
          text: block.imageCaption ?? '',
          formatting: block.formatting,
          measuredHeightPt: totalH,
          spacingAfterPt: 12.0,
          imagePath: block.imagePath,
          imageCaption: block.imageCaption,
          imageHeightPt: imgH,
        ),
      );
      return;
    }

    if (block.type == ContentBlockType.table) {
      final table = block.tableData;
      if (table == null) return;
      const headerRowH = 30.0;
      const dataRowH = 28.0;
      final remainingRows = List<List<String>>.from(table.rows);

      if (remainingRows.isEmpty) {
        if (getUsedHeight() + headerRowH + 12.0 > maxH && hasCurrentSlices()) {
          flushPage();
        }
        addSlice(
          PageSlice(
            blockId: block.id,
            chapterId: block.chapterId,
            sectionId: block.sectionId,
            type: ContentBlockType.table,
            text: '',
            formatting: block.formatting,
            measuredHeightPt: headerRowH,
            spacingAfterPt: 12.0,
            tableHeaders: table.headers,
            tableRows: const [],
          ),
        );
        return;
      }

      var isCont = false;
      while (remainingRows.isNotEmpty) {
        var avail = maxH - getUsedHeight() - 12.0;
        if (avail < headerRowH + dataRowH && hasCurrentSlices()) {
          flushPage();
          avail = maxH - 12.0;
        }
        final rowsThatFit =
            math.max(1, ((avail - headerRowH) / dataRowH).floor());
        final takeCount = math.min(rowsThatFit, remainingRows.length);
        final chunkRows = remainingRows.sublist(0, takeCount);
        remainingRows.removeRange(0, takeCount);

        addSlice(
          PageSlice(
            blockId: block.id,
            chapterId: block.chapterId,
            sectionId: block.sectionId,
            type: ContentBlockType.table,
            text: '',
            formatting: block.formatting,
            measuredHeightPt: headerRowH + (chunkRows.length * dataRowH),
            spacingAfterPt: 12.0,
            isContinuation: isCont,
            tableHeaders: table.headers,
            tableRows: chunkRows,
          ),
        );
        isCont = true;
      }
      return;
    }

    if (block.type == ContentBlockType.bulletList ||
        block.type == ContentBlockType.numberedList) {
      final items = block.listItems;
      if (items.isEmpty) return;
      final fontSize = block.formatting.fontSize > 0
          ? block.formatting.fontSize
          : baseFontSize;

      var idx = 0;
      var isCont = false;
      while (idx < items.length) {
        final batch = <String>[];
        double batchHeight = 0;
        final startNum = idx + 1;

        while (idx < items.length) {
          final itemText = block.type == ContentBlockType.numberedList
              ? '${idx + 1}. ${items[idx]}'
              : '• ${items[idx]}';
          final itemH = measurer.measureHeight(
                text: itemText,
                fontSize: fontSize,
                maxWidth: maxW - 18.0,
                isHeading: false,
                isBold: block.formatting.bold,
                isItalic: block.formatting.italic,
                explicitDirection: block.formatting.direction,
              ) +
              4.0;

          if (getUsedHeight() + batchHeight + itemH + 10.0 <= maxH) {
            batch.add(items[idx]);
            batchHeight += itemH;
            idx++;
          } else {
            break;
          }
        }

        if (batch.isEmpty) {
          if (hasCurrentSlices()) {
            flushPage();
            continue;
          } else {
            // Single very long list item on fresh page
            final itemH = measurer.measureHeight(
              text: items[idx],
              fontSize: fontSize,
              maxWidth: maxW - 18.0,
              isHeading: false,
              isBold: block.formatting.bold,
              isItalic: block.formatting.italic,
              explicitDirection: block.formatting.direction,
            );
            batch.add(items[idx]);
            batchHeight = math.min(itemH, maxH - 12.0);
            idx++;
          }
        }

        addSlice(
          PageSlice(
            blockId: block.id,
            chapterId: block.chapterId,
            sectionId: block.sectionId,
            type: block.type,
            text: batch.join('
'),
            formatting: block.formatting,
            measuredHeightPt: batchHeight,
            spacingAfterPt: 10.0,
            isContinuation: isCont,
            listItems: batch,
            listStartIndex: startNum,
          ),
        );
        isCont = true;
      }
      return;
    }

    // Text-based blocks (headings, paragraphs, richText, nuskhaEntry, note)
    final rawText = block.textContent.trim();
    if (rawText.isEmpty) return;

    final isHeading = block.type.isHeading;
    final fontSize = switch (block.type) {
      ContentBlockType.chapterHeading => baseFontSize + 6.0,
      ContentBlockType.sectionHeading => baseFontSize + 3.5,
      ContentBlockType.subheading => baseFontSize + 1.5,
      _ => block.formatting.fontSize > 0
          ? block.formatting.fontSize
          : baseFontSize,
    };
    final effectiveWidth = (block.type == ContentBlockType.note ||
            block.type == ContentBlockType.nuskhaEntry)
        ? maxW - 24.0
        : maxW;
    final extraChrome = (block.type == ContentBlockType.note ||
            block.type == ContentBlockType.nuskhaEntry)
        ? 20.0
        : 0.0;
    final spacingAfter = isHeading ? 8.0 : 10.0;

    // Keep-with-next protection for headings
    if (isHeading) {
      final h = measurer.measureHeight(
        text: rawText,
        fontSize: fontSize,
        maxWidth: effectiveWidth,
        isHeading: true,
        isBold: true,
        isItalic: block.formatting.italic,
        explicitDirection: block.formatting.direction,
      );
      if (getUsedHeight() + h + spacingAfter + 38.0 > maxH &&
          hasCurrentSlices()) {
        flushPage();
      }
      addSlice(
        PageSlice(
          blockId: block.id,
          chapterId: block.chapterId,
          sectionId: block.sectionId,
          type: block.type,
          text: rawText,
          formatting: block.formatting.copyWith(fontSize: fontSize, bold: true),
          measuredHeightPt: h,
          spacingAfterPt: spacingAfter,
        ),
      );
      return;
    }

    // Flow long text across as many pages as needed without clipping
    var remaining = rawText;
    var isCont = false;
    var safetyIterations = 0;

    while (remaining.isNotEmpty && safetyIterations < 500) {
      safetyIterations++;
      var avail = maxH - getUsedHeight() - spacingAfter - extraChrome;
      if (avail < fontSize * 2.2 && hasCurrentSlices()) {
        flushPage();
        avail = maxH - spacingAfter - extraChrome;
      }

      final (chunk, tail) = measurer.splitToFitHeight(
        text: remaining,
        fontSize: fontSize,
        maxWidth: effectiveWidth,
        maxHeightPt: math.max(avail, fontSize * 2.5),
        isHeading: false,
        isBold: block.formatting.bold,
        isItalic: block.formatting.italic,
        explicitDirection: block.formatting.direction,
      );

      if (chunk.text.isEmpty) {
        if (hasCurrentSlices()) {
          flushPage();
          continue;
        }
        // Fallback: force progress on an empty page to guarantee termination
        addSlice(
          PageSlice(
            blockId: block.id,
            chapterId: block.chapterId,
            sectionId: block.sectionId,
            type: block.type,
            text: remaining,
            formatting: block.formatting.copyWith(fontSize: fontSize),
            measuredHeightPt: math.min(maxH - spacingAfter, fontSize * 4),
            spacingAfterPt: spacingAfter,
            isContinuation: isCont,
            linkedNuskhaId: block.linkedNuskhaId,
          ),
        );
        break;
      }

      addSlice(
        PageSlice(
          blockId: block.id,
          chapterId: block.chapterId,
          sectionId: block.sectionId,
          type: block.type,
          text: chunk.text,
          formatting: block.formatting.copyWith(fontSize: fontSize),
          measuredHeightPt: chunk.heightPt + extraChrome,
          spacingAfterPt: spacingAfter,
          isContinuation: isCont,
          linkedNuskhaId: block.linkedNuskhaId,
        ),
      );
      remaining = tail;
      isCont = true;
      if (remaining.isNotEmpty) {
        flushPage();
      }
    }
  }
}
