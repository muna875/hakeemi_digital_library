import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/typography/bilingual_text_helper.dart';
import '../../models/content_block/content_block_model.dart';
import '../../shared/widgets/editorial_card.dart';
import '../../shared/widgets/empty_state_widget.dart';

class PageManagerScreen extends StatelessWidget {
  final String bookId;

  const PageManagerScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final book = state.getBook(bookId);
    final doc = state.paginatedForBook(bookId);
    final pages = doc?.pages ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Pages (${pages.length}) • ${book?.title ?? ''}'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.chapterManager,
              arguments: bookId,
            ),
            icon: const Icon(Icons.reorder, size: 18),
            label: const Text('Reorder Chapters'),
          ),
        ],
      ),
      body: pages.isEmpty
          ? EmptyStateWidget(
              icon: Icons.grid_view_outlined,
              title: 'No Paginated Pages Yet',
              subtitle:
                  'Pages are generated dynamically from your chapters and content blocks.',
              actionLabel: 'Open Editor',
              onAction: () => Navigator.pushNamed(
                context,
                AppRoutes.editor,
                arguments: EditorArgs(bookId: bookId),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.sageTint,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                  child: const Text(
                    'Pages are dynamically derived from document structure. Tap a page to read, or use the menu to edit blocks or insert a manual page break.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryForestGreen,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      return EditorialCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.reader,
                          arguments: ReaderArgs(
                            bookId: bookId,
                            initialPage: page.pageNumber,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryForestGreen,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'Page ${page.pageNumber}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.paperWhite,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.more_horiz, size: 18),
                                  onSelected: (action) async {
                                    if (action == 'edit' &&
                                        page.chapterId != null) {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.editor,
                                        arguments: EditorArgs(
                                          bookId: bookId,
                                          initialChapterId: page.chapterId,
                                        ),
                                      );
                                    } else if (action == 'break' &&
                                        page.chapterId != null) {
                                      await state.addBlock(
                                        bookId: bookId,
                                        chapterId: page.chapterId!,
                                        sectionId: page.sectionId,
                                        type: ContentBlockType.manualPageBreak,
                                        textContent: '',
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit Chapter Content'),
                                    ),
                                    PopupMenuItem(
                                      value: 'break',
                                      child: Text('Insert Manual Page Break'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (page.chapterTitle != null)
                              Text(
                                page.chapterTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryForestGreen,
                                ),
                              ),
                            if (page.sectionTitle != null)
                              Text(
                                page.sectionTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            const SizedBox(height: 6),
                            const Divider(),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Directionality(
                                textDirection:
                                    BilingualTextHelper.resolveDirection(
                                  page.previewText,
                                ),
                                child: Text(
                                  page.previewText,
                                  maxLines: 8,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    height: 1.45,
                                    color: AppColors.mainText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
