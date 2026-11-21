import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/typography/bilingual_text_helper.dart';
import '../../models/content_block/content_block_model.dart';
import '../../services/document_layout/document_layout_model.dart';
import '../../shared/widgets/empty_state_widget.dart';

class BookReaderScreen extends StatefulWidget {
  final String bookId;
  final int initialPage;

  const BookReaderScreen({
    super.key,
    required this.bookId,
    this.initialPage = 1,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  late int _currentPage;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage < 1 ? 1 : widget.initialPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      setState(() => _zoom = state.settings.readerZoom);
    });
  }

  void _goToPage(int page, PaginatedDocument doc) {
    if (doc.totalPages == 0) return;
    final clamped = page.clamp(1, doc.totalPages);
    setState(() => _currentPage = clamped);
    final docPage = doc.getPage(clamped);
    context.read<AppState>().recordReadingProgress(
          bookId: widget.bookId,
          pageNumber: clamped,
          chapterId: docPage?.chapterId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final book = state.getBook(widget.bookId);
    final doc = state.paginatedForBook(widget.bookId);
    final bookmarks = state.bookmarksForBook(widget.bookId);

    if (book == null || doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (doc.totalPages == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(book.title)),
        body: EmptyStateWidget(
          icon: Icons.auto_stories_outlined,
          title: 'This Book Has No Pages Yet',
          subtitle:
              'Start writing chapters and content in the editor. Pages and Table of Contents will be organized automatically.',
          actionLabel: 'Open Book Editor',
          onAction: () => Navigator.pushNamed(
            context,
            AppRoutes.editor,
            arguments: EditorArgs(bookId: widget.bookId),
          ),
        ),
      );
    }

    final safePage = _currentPage.clamp(1, doc.totalPages);
    final page = doc.getPage(safePage)!;
    final isBookmarked = bookmarks.any((b) => b.pageNumber == safePage);

    return Scaffold(
      backgroundColor: const Color(0xFFEDEAE0),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.title, style: const TextStyle(fontSize: 16)),
            Text(
              'Page $safePage of ${doc.totalPages} • ${page.chapterTitle ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark Page',
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? AppColors.mutedGold : AppColors.mainText,
            ),
            onPressed: () => state.toggleBookmark(
              bookId: widget.bookId,
              pageNumber: safePage,
              chapterTitle: page.chapterTitle,
            ),
          ),
          IconButton(
            tooltip: 'Table of Contents',
            icon: const Icon(Icons.format_list_numbered),
            onPressed: () async {
              final selectedPage = await Navigator.pushNamed<int>(
                context,
                AppRoutes.tableOfContents,
                arguments: widget.bookId,
              );
              if (selectedPage != null && mounted) {
                _goToPage(selectedPage, doc);
              }
            },
          ),
          IconButton(
            tooltip: 'Search in Book',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.search,
              arguments: widget.bookId,
            ),
          ),
          IconButton(
            tooltip: 'Edit Book',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.editor,
              arguments: EditorArgs(
                bookId: widget.bookId,
                initialChapterId: page.chapterId,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Zoom & Chapter Quick Strip
          Container(
            color: AppColors.warmIvory,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showJumpToPageDialog(context, doc),
                  icon: const Icon(Icons.pin_outlined, size: 16),
                  label: Text('Go to Page ($safePage/${doc.totalPages})'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Zoom Out',
                  icon: const Icon(Icons.zoom_out, size: 20),
                  onPressed: () =>
                      setState(() => _zoom = (_zoom - 0.1).clamp(0.75, 1.6)),
                ),
                Text(
                  '${(_zoom * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  tooltip: 'Zoom In',
                  icon: const Icon(Icons.zoom_in, size: 20),
                  onPressed: () =>
                      setState(() => _zoom = (_zoom + 0.1).clamp(0.75, 1.6)),
                ),
              ],
            ),
          ),
          // Printed Book Page Canvas
          Expanded(
            child: InteractiveViewer(
              minScale: 0.75,
              maxScale: 2.2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: Transform.scale(
                    scale: _zoom,
                    alignment: Alignment.topCenter,
                    child: _PrintedBookPageCard(
                      bookTitle: book.title,
                      page: page,
                      showHeader: state.settings.showRunningHeaders,
                      showPageNumber: state.settings.showPageNumbers,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bottom Navigation Controls (Prev / Slider / Next)
          Container(
            decoration: const BoxDecoration(
              color: AppColors.paperWhite,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous Page',
                    onPressed:
                        safePage > 1 ? () => _goToPage(safePage - 1, doc) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: doc.totalPages > 1
                        ? Slider(
                            value: safePage.toDouble(),
                            min: 1,
                            max: doc.totalPages.toDouble(),
                            divisions: doc.totalPages - 1,
                            activeColor: AppColors.primaryForestGreen,
                            onChanged: (v) => _goToPage(v.round(), doc),
                          )
                        : const Center(
                            child: Text(
                              'Page 1 of 1',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                  ),
                  IconButton(
                    tooltip: 'Next Page',
                    onPressed: safePage < doc.totalPages
                        ? () => _goToPage(safePage + 1, doc)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showJumpToPageDialog(
    BuildContext context,
    PaginatedDocument doc,
  ) async {
    final ctrl = TextEditingController(text: '$_currentPage');
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Page number (1 – ${doc.totalPages})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, n);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (target != null && mounted) {
      _goToPage(target, doc);
    }
  }
}

class _PrintedBookPageCard extends StatelessWidget {
  final String bookTitle;
  final DocumentPage page;
  final bool showHeader;
  final bool showPageNumber;

  const _PrintedBookPageCard({
    required this.bookTitle,
    required this.page,
    required this.showHeader,
    required this.showPageNumber,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620, minHeight: 740),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        decoration: BoxDecoration(
          color: AppColors.paperWhite,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHeader) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          bookTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'NotoSerif',
                            fontStyle: FontStyle.italic,
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          page.chapterTitle ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: BilingualTextHelper.resolveDirection(
                            page.chapterTitle ?? '',
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),
                ],
                for (final slice in page.slices) _SliceRenderer(slice: slice),
              ],
            ),
            if (showPageNumber) ...[
              const SizedBox(height: 20),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${page.pageNumber}',
                  style: const TextStyle(
                    fontFamily: 'NotoSerif',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SliceRenderer extends StatelessWidget {
  final PageSlice slice;

  const _SliceRenderer({required this.slice});

  @override
  Widget build(BuildContext context) {
    if (slice.type == ContentBlockType.image) {
      return Padding(
        padding: EdgeInsets.only(bottom: slice.spacingAfterPt),
        child: Column(
          children: [
            if (slice.imagePath != null && File(slice.imagePath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(slice.imagePath!),
                  height: slice.imageHeightPt ?? 180,
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.warmIvory,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: AppColors.secondaryText,
                ),
              ),
            if (slice.imageCaption != null && slice.imageCaption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  slice.imageCaption!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'NotoSerif',
                    fontStyle: FontStyle.italic,
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
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
      return Padding(
        padding: EdgeInsets.only(bottom: slice.spacingAfterPt),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: AppColors.border),
            children: [
              if (headers.isNotEmpty)
                TableRow(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryForestGreen,
                  ),
                  children: headers
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            h,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.paperWhite,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              for (final row in rows)
                TableRow(
                  children: row
                      .map(
                        (cell) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            cell,
                            textDirection:
                                BilingualTextHelper.resolveDirection(cell),
                            style: BilingualTextHelper.buildTextStyle(
                              text: cell,
                              fontSize: 12,
                              color: AppColors.mainText,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      );
    }

    if (slice.type == ContentBlockType.bulletList ||
        slice.type == ContentBlockType.numberedList) {
      final items = slice.listItems ?? const [];
      return Padding(
        padding: EdgeInsets.only(bottom: slice.spacingAfterPt),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Directionality(
                  textDirection: BilingualTextHelper.resolveDirection(
                    items[i],
                    explicitDirection: slice.formatting.direction,
                  ),
                  child: Text(
                    slice.type == ContentBlockType.numberedList
                        ? '${slice.listStartIndex + i}. ${items[i]}'
                        : '• ${items[i]}',
                    style: BilingualTextHelper.buildTextStyle(
                      text: items[i],
                      fontSize: slice.formatting.fontSize,
                      color: AppColors.mainText,
                      isBold: slice.formatting.bold,
                      isItalic: slice.formatting.italic,
                      isUnderline: slice.formatting.underline,
                      explicitDirection: slice.formatting.direction,
                    ),
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
      final dir = BilingualTextHelper.resolveDirection(
        slice.text,
        explicitDirection: slice.formatting.direction,
      );
      return Container(
        margin: EdgeInsets.only(bottom: slice.spacingAfterPt),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isNuskha ? AppColors.sageTint : AppColors.goldTint,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isNuskha
                  ? AppColors.primaryForestGreen
                  : AppColors.mutedGold,
              width: 3.5,
            ),
          ),
        ),
        child: Directionality(
          textDirection: dir,
          child: Text(
            slice.text,
            style: BilingualTextHelper.buildTextStyle(
              text: slice.text,
              fontSize: slice.formatting.fontSize,
              color: AppColors.mainText,
              explicitDirection: slice.formatting.direction,
            ),
          ),
        ),
      );
    }

    final dir = BilingualTextHelper.resolveDirection(
      slice.text,
      explicitDirection: slice.formatting.direction,
    );
    final align = switch (slice.formatting.alignment) {
      'center' => TextAlign.center,
      'end' => TextAlign.end,
      'justify' => TextAlign.justify,
      _ => TextAlign.start,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: slice.spacingAfterPt),
      child: Directionality(
        textDirection: dir,
        child: Text(
          slice.text,
          textAlign: align,
          style: BilingualTextHelper.buildTextStyle(
            text: slice.text,
            fontSize: slice.formatting.fontSize,
            color: slice.type == ContentBlockType.chapterHeading
                ? AppColors.primaryForestGreen
                : AppColors.mainText,
            isHeading: slice.type.isHeading,
            isBold: slice.formatting.bold,
            isItalic: slice.formatting.italic,
            isUnderline: slice.formatting.underline,
            explicitDirection: slice.formatting.direction,
          ),
        ),
      ),
    );
  }
}
