import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../models/chapter/chapter_model.dart';
import '../../models/section/section_model.dart';
import '../../shared/widgets/editorial_card.dart';
import '../../shared/widgets/empty_state_widget.dart';

class ChapterManagerScreen extends StatelessWidget {
  final String bookId;

  const ChapterManagerScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final book = state.getBook(bookId);
    final chapters = state.chaptersForBook(bookId);
    final sections = state.sectionsForBook(bookId);
    final doc = state.paginatedForBook(bookId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chapters • ${book?.title ?? ''}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryForestGreen,
        foregroundColor: AppColors.paperWhite,
        onPressed: () => _showChapterDialog(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Add Chapter'),
      ),
      body: chapters.isEmpty
          ? EmptyStateWidget(
              icon: Icons.library_books_outlined,
              title: 'No Chapters Created Yet',
              subtitle:
                  'Organize your manuscript into structured chapters and subsections. Reordering chapters automatically updates all page numbers.',
              actionLabel: 'Create Chapter 1',
              onAction: () => _showChapterDialog(context, state),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                96,
              ),
              itemCount: chapters.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final list = [...chapters];
                final moved = list.removeAt(oldIndex);
                list.insert(newIndex, moved);
                state.reorderChapters(bookId, list);
              },
              itemBuilder: (context, index) {
                final ch = chapters[index];
                final chSections =
                    sections.where((s) => s.chapterId == ch.id).toList();
                final startPage = doc?.pageForChapter(ch.id);

                return Padding(
                  key: ValueKey(ch.id),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EditorialCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.drag_handle,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chapter ${index + 1}: ${ch.displayTitle}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${chSections.length} sections • ${startPage != null ? 'Starts on Page $startPage' : 'Not yet paginated'}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit Chapter',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showChapterDialog(
                                context,
                                state,
                                existing: ch,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete Chapter',
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.dangerRed,
                              ),
                              onPressed: () =>
                                  _confirmDeleteChapter(context, state, ch),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 34),
                              ),
                              onPressed: () =>
                                  _showSectionDialog(context, state, ch.id),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Section'),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 34),
                              ),
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.editor,
                                arguments: EditorArgs(
                                  bookId: bookId,
                                  initialChapterId: ch.id,
                                ),
                              ),
                              icon: const Icon(Icons.edit_note, size: 16),
                              label: const Text('Write'),
                            ),
                          ],
                        ),
                        if (chSections.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(),
                          for (int sIdx = 0; sIdx < chSections.length; sIdx++)
                            _SectionRow(
                              chapterIndex: index + 1,
                              sectionIndex: sIdx + 1,
                              section: chSections[sIdx],
                              pageNumber:
                                  doc?.pageForSection(chSections[sIdx].id),
                              onDelete: () => state.deleteSection(
                                bookId,
                                chSections[sIdx].id,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showChapterDialog(
    BuildContext context,
    AppState state, {
    ChapterModel? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final urduCtrl = TextEditingController(text: existing?.urduTitle ?? '');
    bool newPage = existing?.startsOnNewPage ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'Add Chapter' : 'Edit Chapter'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Chapter Title'),
              ),
              const SizedBox(height: 10),
              Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: urduCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Urdu Title (Optional) — اردو عنوان',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start chapter on a new page'),
                value: newPage,
                onChanged: (v) => setModalState(() => newPage = v),
              ),
            ],
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
      ),
    );

    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      if (existing == null) {
        await state.addChapter(
          bookId: bookId,
          title: titleCtrl.text.trim(),
          urduTitle: urduCtrl.text.trim(),
          startsOnNewPage: newPage,
        );
      } else {
        await state.updateChapter(
          existing.copyWith(
            title: titleCtrl.text.trim(),
            urduTitle: urduCtrl.text.trim(),
            startsOnNewPage: newPage,
          ),
        );
      }
    }
  }

  Future<void> _showSectionDialog(
    BuildContext context,
    AppState state,
    String chapterId,
  ) async {
    final titleCtrl = TextEditingController();
    final urduCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Section Title'),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: urduCtrl,
                decoration: const InputDecoration(
                  labelText: 'Urdu Title (Optional) — اردو عنوان',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      await state.addSection(
        bookId: bookId,
        chapterId: chapterId,
        title: titleCtrl.text.trim(),
        urduTitle: urduCtrl.text.trim(),
      );
    }
  }

  Future<void> _confirmDeleteChapter(
    BuildContext context,
    AppState state,
    ChapterModel ch,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chapter?'),
        content: Text(
          'Delete "${ch.displayTitle}" and all of its sections and content blocks? Pagination will recalculate automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.deleteChapter(bookId, ch.id);
    }
  }
}

class _SectionRow extends StatelessWidget {
  final int chapterIndex;
  final int sectionIndex;
  final SectionModel section;
  final int? pageNumber;
  final VoidCallback onDelete;

  const _SectionRow({
    required this.chapterIndex,
    required this.sectionIndex,
    required this.section,
    required this.pageNumber,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 12),
      title: Text('$chapterIndex.$sectionIndex ${section.displayTitle}'),
      subtitle: pageNumber != null ? Text('Page $pageNumber') : null,
      trailing: IconButton(
        icon: const Icon(
          Icons.close,
          size: 18,
          color: AppColors.dangerRed,
        ),
        onPressed: onDelete,
      ),
    );
  }
}
