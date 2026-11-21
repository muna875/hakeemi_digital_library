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

class LibraryScreen extends StatelessWidget {
  final void Function(int tabIndex)? onSelectTab;

  const LibraryScreen({super.key, this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final books = state.books;
    final recentBook = state.mostRecentlyModifiedBook;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hakeemi Digital Library'),
            Text(
              'Personal Offline Manuscript Shelf',
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Global Search',
            icon: const Icon(Icons.search),
            onPressed: () => onSelectTab?.call(1),
          ),
          IconButton(
            tooltip: 'Create Backup',
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => onSelectTab?.call(3),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => onSelectTab?.call(4),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (recentBook != null) ...[
              _ContinueReadingCard(book: recentBook),
              const SizedBox(height: AppSpacing.lg),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Four Permanent Volumes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.sageTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '100% Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryForestGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 680;
                if (isWide) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.75,
                    ),
                    itemCount: books.length,
                    itemBuilder: (_, i) => _BookShelfCard(book: books[i]),
                  );
                }
                return Column(
                  children: [
                    for (final book in books) ...[
                      _BookShelfCard(book: book),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final BookModel book;

  const _ContinueReadingCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final doc = state.paginatedForBook(book.id);
    final totalPages = doc?.totalPages ?? 0;

    return EditorialCard(
      color: AppColors.primaryForestGreen,
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.reader,
          arguments: ReaderArgs(
            bookId: book.id,
            initialPage: book.lastOpenedPage,
          ),
        );
      },
      child: Row(
        children: [
          BookCoverWidget(book: book, width: 62, height: 88, compact: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONTINUE READING',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedGold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'NotoSerif',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.paperWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalPages == 0
                      ? 'Ready to start writing chapters'
                      : 'Page ${book.lastOpenedPage} of $totalPages • ${(book.readingProgress * 100).round()}% read',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warmIvory.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.mutedGold,
          ),
        ],
      ),
    );
  }
}

class _BookShelfCard extends StatelessWidget {
  final BookModel book;

  const _BookShelfCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final chapters = state.chaptersForBook(book.id);
    final doc = state.paginatedForBook(book.id);
    final pageCount = doc?.totalPages ?? 0;
    String? lastChapterTitle;
    if (book.lastOpenedChapterId != null) {
      for (final ch in chapters) {
        if (ch.id == book.lastOpenedChapterId) {
          lastChapterTitle = ch.title;
          break;
        }
      }
    }

    return EditorialCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.bookDetails,
          arguments: book.id,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCoverWidget(book: book, width: 86, height: 124, compact: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            book.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Book options',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: AppColors.secondaryText,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'read':
                            Navigator.pushNamed(
                              context,
                              AppRoutes.reader,
                              arguments: ReaderArgs(
                                bookId: book.id,
                                initialPage: book.lastOpenedPage,
                              ),
                            );
                          case 'edit':
                            Navigator.pushNamed(
                              context,
                              AppRoutes.editor,
                              arguments: EditorArgs(bookId: book.id),
                            );
                          case 'cover':
                            Navigator.pushNamed(
                              context,
                              AppRoutes.coverDesigner,
                              arguments: book.id,
                            );
                          case 'pdf':
                            Navigator.pushNamed(
                              context,
                              AppRoutes.pdfExport,
                              arguments: book.id,
                            );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'read', child: Text('Read Book')),
                        PopupMenuItem(value: 'edit', child: Text('Open Editor')),
                        PopupMenuItem(
                            value: 'cover', child: Text('Cover Designer')),
                        PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                      icon: Icons.menu_book_outlined,
                      label: '${chapters.length} ch.',
                    ),
                    _MetaChip(
                      icon: Icons.description_outlined,
                      label: '$pageCount pages',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: book.readingProgress,
                    minHeight: 5,
                    backgroundColor: AppColors.warmIvory,
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.primaryForestGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lastChapterTitle != null
                      ? 'Last: $lastChapterTitle'
                      : 'Updated ${DateFormatter.formatShort(book.updatedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.reader,
                            arguments: ReaderArgs(
                              bookId: book.id,
                              initialPage: book.lastOpenedPage,
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_stories_outlined, size: 16),
                        label: const Text('Read', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.editor,
                            arguments: EditorArgs(bookId: book.id),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label:
                            const Text('Write', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryForestGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mainText,
            ),
          ),
        ],
      ),
    );
  }
}
