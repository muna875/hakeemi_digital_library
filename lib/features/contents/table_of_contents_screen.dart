import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/typography/bilingual_text_helper.dart';
import '../../shared/widgets/editorial_card.dart';
import '../../shared/widgets/empty_state_widget.dart';

class TableOfContentsScreen extends StatelessWidget {
  final String bookId;

  const TableOfContentsScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final book = state.getBook(bookId);
    final doc = state.paginatedForBook(bookId);
    final entries = doc?.tableOfContents ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Contents • ${book?.title ?? ''}'),
      ),
      body: entries.isEmpty
          ? EmptyStateWidget(
              icon: Icons.format_list_numbered,
              title: 'No Chapters or Sections Yet',
              subtitle:
                  'Add chapters and sections in the editor or Chapter Manager. Page numbers are computed automatically.',
              actionLabel: 'Manage Chapters',
              onAction: () => Navigator.pushNamed(
                context,
                AppRoutes.chapterManager,
                arguments: bookId,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isChapter = entry.level == 1;
                return Padding(
                  padding: EdgeInsets.only(left: isChapter ? 0 : 18),
                  child: EditorialCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.reader,
                          arguments: ReaderArgs(
                            bookId: bookId,
                            initialPage: entry.pageNumber,
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isChapter
                                ? AppColors.primaryForestGreen
                                : AppColors.sageTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.numberingLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isChapter
                                  ? AppColors.paperWhite
                                  : AppColors.primaryForestGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Directionality(
                            textDirection: BilingualTextHelper.resolveDirection(
                              entry.displayTitle,
                            ),
                            child: Text(
                              entry.displayTitle,
                              style: BilingualTextHelper.buildTextStyle(
                                text: entry.displayTitle,
                                fontSize: isChapter ? 15 : 13.5,
                                color: AppColors.mainText,
                                isHeading: isChapter,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'p. ${entry.pageNumber}',
                          style: const TextStyle(
                            fontFamily: 'NotoSerif',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.primaryForestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
