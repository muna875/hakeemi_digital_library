import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utilities/date_formatter.dart';
import '../../models/book/book_model.dart';
import '../../shared/widgets/book_cover_widget.dart';
import '../../shared/widgets/editorial_card.dart';

class BookDetailsScreen extends StatelessWidget {
  final String bookId;

  const BookDetailsScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final book = state.getBook(bookId);
    if (book == null) {
      return const Scaffold(body: Center(child: Text('Book not found.')));
    }

    final chapters = state.chaptersForBook(bookId);
    final sections = state.sectionsForBook(bookId);
    final blocks = state.blocksForBook(bookId);
    final doc = state.paginatedForBook(bookId);
    final pageCount = doc?.totalPages ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          IconButton(
            tooltip: 'Edit Book Metadata',
            icon: const Icon(Icons.edit_note_outlined),
            onPressed: () => _showEditMetadataDialog(context, state, book),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          EditorialCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCoverWidget(book: book, width: 105, height: 150),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOLUME 0${book.slotOrder}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.mutedGold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (book.authorName.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'By ${book.authorName}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryForestGreen,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        book.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last modified: ${DateFormatter.formatDateTime(book.updatedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _StatBox(label: 'Chapters', value: '${chapters.length}'),
              const SizedBox(width: AppSpacing.xs),
              _StatBox(label: 'Sections', value: '${sections.length}'),
              const SizedBox(width: AppSpacing.xs),
              _StatBox(label: 'Pages', value: '$pageCount'),
              const SizedBox(width: AppSpacing.xs),
              _StatBox(label: 'Blocks', value: '${blocks.length}'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.reader,
                      arguments: ReaderArgs(
                        bookId: bookId,
                        initialPage: book.lastOpenedPage,
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('Read Book'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.editor,
                      arguments: EditorArgs(bookId: bookId),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Write / Edit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Book Workspace', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _ActionTile(
            icon: Icons.format_list_numbered,
            title: 'Table of Contents',
            subtitle: 'Auto-calculated chapter & section page numbers',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.tableOfContents,
              arguments: bookId,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ActionTile(
            icon: Icons.library_books_outlined,
            title: 'Chapter & Section Manager',
            subtitle: 'Add, rename, reorder, and structure chapters',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.chapterManager,
              arguments: bookId,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ActionTile(
            icon: Icons.grid_view_outlined,
            title: 'Page Manager',
            subtitle: 'Inspect auto-paginated thumbnails, breaks & blocks',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.pageManager,
              arguments: bookId,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ActionTile(
            icon: Icons.palette_outlined,
            title: 'Cover Designer',
            subtitle: 'Choose templates, upload cover art & edit publication info',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.coverDesigner,
              arguments: bookId,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ActionTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF Preview & Export',
            subtitle: 'Publish print-ready bilingual book PDF with TOC & cover',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.pdfExport,
              arguments: bookId,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ActionTile(
            icon: Icons.search,
            title: 'Search Within This Book',
            subtitle: 'Full-text Urdu & English search across all chapters',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.search,
              arguments: bookId,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditMetadataDialog(
    BuildContext context,
    AppState state,
    BookModel book,
  ) async {
    final titleCtrl = TextEditingController(text: book.title);
    final subCtrl = TextEditingController(text: book.subtitle);
    final authorCtrl = TextEditingController(text: book.authorName);
    final descCtrl = TextEditingController(text: book.description);
    final pubCtrl = TextEditingController(text: book.publicationInfo);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Book Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Book Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: subCtrl,
                decoration: const InputDecoration(labelText: 'Subtitle'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: authorCtrl,
                decoration: const InputDecoration(labelText: 'Author / Hakeem Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pubCtrl,
                decoration:
                    const InputDecoration(labelText: 'Publication Info'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && titleCtrl.text.trim().isNotEmpty) {
      await state.updateBook(
        book.copyWith(
          title: titleCtrl.text.trim(),
          subtitle: subCtrl.text.trim(),
          authorName: authorCtrl.text.trim(),
          description: descCtrl.text.trim(),
          publicationInfo: pubCtrl.text.trim(),
        ),
      );
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: EditorialCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'NotoSerif',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryForestGreen,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sageTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryForestGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.secondaryText),
        ],
      ),
    );
  }
}
