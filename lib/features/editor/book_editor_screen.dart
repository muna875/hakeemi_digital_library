import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/typography/bilingual_text_helper.dart';
import '../../models/chapter/chapter_model.dart';
import '../../models/content_block/content_block_model.dart';
import '../../models/section/section_model.dart';
import '../../shared/widgets/editorial_card.dart';
import '../../shared/widgets/empty_state_widget.dart';

class _EditorSnapshot {
  final String text;
  final BlockFormatting formatting;
  final ContentBlockType type;

  const _EditorSnapshot(this.text, this.formatting, this.type);
}

class BookEditorScreen extends StatefulWidget {
  final String bookId;
  final String? initialChapterId;

  const BookEditorScreen({
    super.key,
    required this.bookId,
    this.initialChapterId,
  });

  @override
  State<BookEditorScreen> createState() => _BookEditorScreenState();
}

class _BookEditorScreenState extends State<BookEditorScreen> {
  String? _selectedChapterId;
  String? _selectedSectionId;
  String? _editingBlockId;
  bool _showFormattingBar = true;
  bool _isSaving = false;

  final TextEditingController _textController = TextEditingController();
  BlockFormatting _activeFormatting = const BlockFormatting();
  ContentBlockType _activeType = ContentBlockType.paragraph;

  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _selectedChapterId = widget.initialChapterId;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _pushUndoSnapshot() {
    _undoStack.add(
      _EditorSnapshot(_textController.text, _activeFormatting, _activeType),
    );
    if (_undoStack.length > 40) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(
      _EditorSnapshot(_textController.text, _activeFormatting, _activeType),
    );
    final prev = _undoStack.removeLast();
    setState(() {
      _textController.text = prev.text;
      _activeFormatting = prev.formatting;
      _activeType = prev.type;
    });
    _scheduleAutoSave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(
      _EditorSnapshot(_textController.text, _activeFormatting, _activeType),
    );
    final next = _redoStack.removeLast();
    setState(() {
      _textController.text = next.text;
      _activeFormatting = next.formatting;
      _activeType = next.type;
    });
    _scheduleAutoSave();
  }

  void _selectBlockForEditing(ContentBlockModel block) {
    _autoSaveTimer?.cancel();
    _undoStack.clear();
    _redoStack.clear();
    setState(() {
      _editingBlockId = block.id;
      _activeType = block.type;
      _activeFormatting = block.formatting;
      _textController.text = block.textContent;
      _selectedSectionId = block.sectionId;
    });
  }

  void _scheduleAutoSave() {
    if (_editingBlockId == null) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 650), _saveActiveBlock);
  }

  Future<void> _saveActiveBlock() async {
    final blockId = _editingBlockId;
    if (blockId == null || !mounted) return;
    final state = context.read<AppState>();
    final blocks = state.blocksForBook(widget.bookId);
    final existing = blocks.where((b) => b.id == blockId).firstOrNull;
    if (existing == null) return;

    setState(() => _isSaving = true);
    String? meta = existing.metadataJson;
    if (_activeType == ContentBlockType.bulletList ||
        _activeType == ContentBlockType.numberedList) {
      final items = _textController.text
          .split('
')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      meta = jsonEncode({'items': items});
    }

    await state.updateBlock(
      existing.copyWith(
        type: _activeType,
        textContent: _textController.text,
        metadataJson: meta,
        formatting: _activeFormatting,
        sectionId: _selectedSectionId,
        clearSectionId: _selectedSectionId == null,
      ),
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final book = state.getBook(widget.bookId);
    if (book == null) {
      return const Scaffold(body: Center(child: Text('Book not found.')));
    }

    final chapters = state.chaptersForBook(widget.bookId);
    if (chapters.isNotEmpty &&
        (_selectedChapterId == null ||
            !chapters.any((c) => c.id == _selectedChapterId))) {
      _selectedChapterId = chapters.first.id;
    }

    final activeChapter = chapters
        .where((c) => c.id == _selectedChapterId)
        .cast<ChapterModel?>()
        .firstOrNull;
    final chapterSections = activeChapter == null
        ? const <SectionModel>[]
        : state
            .sectionsForBook(widget.bookId)
            .where((s) => s.chapterId == activeChapter.id)
            .toList();
    final chapterBlocks = activeChapter == null
        ? const <ContentBlockModel>[]
        : state
            .blocksForBook(widget.bookId)
            .where((b) => b.chapterId == activeChapter.id)
            .toList();
    final doc = state.paginatedForBook(widget.bookId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Editor • ${book.title}', style: const TextStyle(fontSize: 16)),
            Text(
              _isSaving
                  ? 'Saving & recalculating pages…'
                  : 'Editing Mode • ${doc?.totalPages ?? 0} auto-paginated pages',
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
            tooltip: 'Undo',
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redoStack.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Live Printed-Page Preview',
            icon: const Icon(Icons.auto_stories_outlined),
            onPressed: () async {
              await _saveActiveBlock();
              if (!context.mounted) return;
              final jumpPage = activeChapter != null
                  ? (doc?.pageForChapter(activeChapter.id) ?? 1)
                  : 1;
              Navigator.pushNamed(
                context,
                AppRoutes.reader,
                arguments: ReaderArgs(
                  bookId: widget.bookId,
                  initialPage: jumpPage,
                ),
              );
            },
          ),
        ],
      ),
      body: chapters.isEmpty
          ? EmptyStateWidget(
              icon: Icons.edit_document,
              title: 'Create Your First Chapter',
              subtitle:
                  'Add a chapter to begin writing Urdu or English paragraphs, formulations, lists, images, and tables.',
              actionLabel: 'Add Chapter',
              onAction: () => _showAddChapterDialog(context, state),
            )
          : Column(
              children: [
                // Chapter & Section Selector Strip
                Container(
                  color: AppColors.paperWhite,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: activeChapter?.id,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Active Chapter',
                                isDense: true,
                              ),
                              items: chapters
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(
                                        c.displayTitle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                _saveActiveBlock();
                                setState(() {
                                  _selectedChapterId = val;
                                  _selectedSectionId = null;
                                  _editingBlockId = null;
                                  _textController.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Add Chapter',
                            onPressed: () =>
                                _showAddChapterDialog(context, state),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: chapterSections
                                      .any((s) => s.id == _selectedSectionId)
                                  ? _selectedSectionId
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Section (Optional)',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Chapter Introduction (No Section)'),
                                ),
                                ...chapterSections.map(
                                  (s) => DropdownMenuItem<String?>(
                                    value: s.id,
                                    child: Text(
                                      s.displayTitle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedSectionId = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Add Section',
                            onPressed: activeChapter == null
                                ? null
                                : () => _showAddSectionDialog(
                                      context,
                                      state,
                                      activeChapter.id,
                                    ),
                            icon: const Icon(Icons.playlist_add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Mobile-Friendly Expandable Formatting & Insert Toolbar
                Container(
                  color: AppColors.warmIvory,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ToolbarChip(
                              label: '+ Paragraph',
                              icon: Icons.notes,
                              onTap: () => _addNewBlock(
                                state,
                                activeChapter!.id,
                                ContentBlockType.paragraph,
                              ),
                            ),
                            _ToolbarChip(
                              label: 'H1',
                              selected:
                                  _activeType == ContentBlockType.chapterHeading,
                              onTap: () => _applyHeadingOrAdd(
                                state,
                                activeChapter!.id,
                                ContentBlockType.chapterHeading,
                              ),
                            ),
                            _ToolbarChip(
                              label: 'H2',
                              selected:
                                  _activeType == ContentBlockType.sectionHeading,
                              onTap: () => _applyHeadingOrAdd(
                                state,
                                activeChapter!.id,
                                ContentBlockType.sectionHeading,
                              ),
                            ),
                            _ToolbarChip(
                              label: 'H3',
                              selected:
                                  _activeType == ContentBlockType.subheading,
                              onTap: () => _applyHeadingOrAdd(
                                state,
                                activeChapter!.id,
                                ContentBlockType.subheading,
                              ),
                            ),
                            _ToolbarChip(
                              label: 'Bullets',
                              icon: Icons.format_list_bulleted,
                              onTap: () => _addNewBlock(
                                state,
                                activeChapter!.id,
                                ContentBlockType.bulletList,
                              ),
                            ),
                            _ToolbarChip(
                              label: 'Numbered',
                              icon: Icons.format_list_numbered,
                              onTap: () => _addNewBlock(
                                state,
                                activeChapter!.id,
                                ContentBlockType.numberedList,
                              ),
                            ),
                            _ToolbarChip(
                              label: 'Image',
                              icon: Icons.image_outlined,
                              onTap: () => _insertImageBlock(
                                context,
                                state,
                                activeChapter!.id,
                              ),
                            ),
                            _ToolbarChip(
                              label: 'Table',
                              icon: Icons.table_chart_outlined,
                              onTap: () => _showInsertTableDialog(
                                context,
                                state,
                                activeChapter!.id,
                              ),
                            ),
                            _ToolbarChip(
                              label: 'Note',
                              icon: Icons.sticky_note_2_outlined,
                              onTap: () => _addNewBlock(
                                state,
                                activeChapter!.id,
                                ContentBlockType.note,
                              ),
                            ),
                            _ToolbarChip(
                              label: 'Page Break',
                              icon: Icons.insert_page_break_outlined,
                              onTap: () => state.addBlock(
                                bookId: widget.bookId,
                                chapterId: activeChapter!.id,
                                sectionId: _selectedSectionId,
                                type: ContentBlockType.manualPageBreak,
                                textContent: '',
                              ),
                            ),
                            IconButton(
                              tooltip: _showFormattingBar
                                  ? 'Hide Formatting'
                                  : 'Show Formatting',
                              icon: Icon(
                                _showFormattingBar
                                    ? Icons.expand_less
                                    : Icons.tune,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _showFormattingBar = !_showFormattingBar,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showFormattingBar && _editingBlockId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FormatToggle(
                                  icon: Icons.format_bold,
                                  tooltip: 'Bold',
                                  active: _activeFormatting.bold,
                                  onTap: () {
                                    _pushUndoSnapshot();
                                    setState(() {
                                      _activeFormatting = _activeFormatting
                                          .copyWith(bold: !_activeFormatting.bold);
                                    });
                                    _scheduleAutoSave();
                                  },
                                ),
                                _FormatToggle(
                                  icon: Icons.format_italic,
                                  tooltip: 'Italic',
                                  active: _activeFormatting.italic,
                                  onTap: () {
                                    _pushUndoSnapshot();
                                    setState(() {
                                      _activeFormatting =
                                          _activeFormatting.copyWith(
                                        italic: !_activeFormatting.italic,
                                      );
                                    });
                                    _scheduleAutoSave();
                                  },
                                ),
                                _FormatToggle(
                                  icon: Icons.format_underlined,
                                  tooltip: 'Underline',
                                  active: _activeFormatting.underline,
                                  onTap: () {
                                    _pushUndoSnapshot();
                                    setState(() {
                                      _activeFormatting =
                                          _activeFormatting.copyWith(
                                        underline: !_activeFormatting.underline,
                                      );
                                    });
                                    _scheduleAutoSave();
                                  },
                                ),
                                const SizedBox(width: 6),
                                _FormatToggle(
                                  icon: Icons.text_decrease,
                                  tooltip: 'Decrease Font Size',
                                  active: false,
                                  onTap: () {
                                    _pushUndoSnapshot();
                                    setState(() {
                                      _activeFormatting =
                                          _activeFormatting.copyWith(
                                        fontSize: (_activeFormatting.fontSize - 1)
                                            .clamp(10.0, 26.0),
                                      );
                                    });
                                    _scheduleAutoSave();
                                  },
                                ),
                                Text(
                                  '${_activeFormatting.fontSize.round()}pt',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                _FormatToggle(
                                  icon: Icons.text_increase,
                                  tooltip: 'Increase Font Size',
                                  active: false,
                                  onTap: () {
                                    _pushUndoSnapshot();
                                    setState(() {
                                      _activeFormatting =
                                          _activeFormatting.copyWith(
                                        fontSize: (_activeFormatting.fontSize + 1)
                                            .clamp(10.0, 26.0),
                                      );
                                    });
                                    _scheduleAutoSave();
                                  },
                                ),
                                const SizedBox(width: 6),
                                _FormatToggle(
                                  icon: Icons.format_align_left,
                                  tooltip: 'Align Start',
                                  active:
                                      _activeFormatting.alignment == 'start',
                                  onTap: () => _setAlignment('start'),
                                ),
                                _FormatToggle(
                                  icon: Icons.format_align_center,
                                  tooltip: 'Align Center',
                                  active:
                                      _activeFormatting.alignment == 'center',
                                  onTap: () => _setAlignment('center'),
                                ),
                                _FormatToggle(
                                  icon: Icons.format_align_right,
                                  tooltip: 'Align End',
                                  active: _activeFormatting.alignment == 'end',
                                  onTap: () => _setAlignment('end'),
                                ),
                                _FormatToggle(
                                  icon: Icons.format_align_justify,
                                  tooltip: 'Justify',
                                  active:
                                      _activeFormatting.alignment == 'justify',
                                  onTap: () => _setAlignment('justify'),
                                ),
                                const SizedBox(width: 6),
                                _ToolbarChip(
                                  label:
                                      'Dir: ${_activeFormatting.direction.toUpperCase()}',
                                  selected:
                                      _activeFormatting.direction != 'auto',
                                  onTap: () {
                                    _pushUndoSnapshot();
                                    final next =
                                        switch (_activeFormatting.direction) {
                                      'auto' => 'rtl',
                                      'rtl' => 'ltr',
                                      _ => 'auto',
                                    };
                                    setState(() {
                                      _activeFormatting = _activeFormatting
                                          .copyWith(direction: next);
                                    });
                                    _scheduleAutoSave();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Active Block Editor Field
                if (_editingBlockId != null)
                  Container(
                    color: AppColors.paperWhite,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Editing: ${_activeType.label}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryForestGreen,
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await _saveActiveBlock();
                                setState(() => _editingBlockId = null);
                              },
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                        Directionality(
                          textDirection: BilingualTextHelper.resolveDirection(
                            _textController.text,
                            explicitDirection: _activeFormatting.direction,
                          ),
                          child: TextField(
                            controller: _textController,
                            maxLines: 6,
                            minLines: 3,
                            onChanged: (_) {
                              setState(() {});
                              _scheduleAutoSave();
                            },
                            style: BilingualTextHelper.buildTextStyle(
                              text: _textController.text,
                              fontSize: _activeFormatting.fontSize,
                              color: AppColors.mainText,
                              isHeading: _activeType.isHeading,
                              isBold: _activeFormatting.bold,
                              isItalic: _activeFormatting.italic,
                              isUnderline: _activeFormatting.underline,
                              explicitDirection: _activeFormatting.direction,
                            ),
                            decoration: InputDecoration(
                              hintText: _activeType ==
                                          ContentBlockType.bulletList ||
                                      _activeType ==
                                          ContentBlockType.numberedList
                                  ? 'Enter one list item per line (Urdu or English)…'
                                  : 'Write in Urdu (اردو) or English…',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Structured Content Blocks List (Reorderable)
                Expanded(
                  child: chapterBlocks.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.article_outlined,
                          title: 'Empty Chapter',
                          subtitle:
                              'Use the toolbar above to add paragraphs, headings, lists, images, tables, or manual page breaks.',
                          actionLabel: 'Add First Paragraph',
                          onAction: () => _addNewBlock(
                            state,
                            activeChapter!.id,
                            ContentBlockType.paragraph,
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: chapterBlocks.length,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final list = [...chapterBlocks];
                            final item = list.removeAt(oldIndex);
                            list.insert(newIndex, item);
                            state.reorderBlocks(
                              widget.bookId,
                              activeChapter!.id,
                              list,
                            );
                          },
                          itemBuilder: (_, index) {
                            final block = chapterBlocks[index];
                            final pageNum = doc?.pageForBlock(block.id);
                            final isSelected = block.id == _editingBlockId;
                            return Padding(
                              key: ValueKey(block.id),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: EditorialCard(
                                color: isSelected
                                    ? AppColors.sageTint
                                    : AppColors.paperWhite,
                                onTap: block.type ==
                                            ContentBlockType.manualPageBreak ||
                                        block.type == ContentBlockType.image ||
                                        block.type == ContentBlockType.table
                                    ? null
                                    : () => _selectBlockForEditing(block),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.drag_indicator,
                                      size: 20,
                                      color: AppColors.secondaryText,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.warmIvory,
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                  border: Border.all(
                                                    color: AppColors.border,
                                                  ),
                                                ),
                                                child: Text(
                                                  block.type.label,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors
                                                        .primaryForestGreen,
                                                  ),
                                                ),
                                              ),
                                              if (pageNum != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Page $pageNum',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.secondaryText,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Directionality(
                                            textDirection: BilingualTextHelper
                                                .resolveDirection(
                                              block.textContent,
                                              explicitDirection:
                                                  block.formatting.direction,
                                            ),
                                            child: Text(
                                              _blockPreview(block),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: BilingualTextHelper
                                                  .buildTextStyle(
                                                text: _blockPreview(block),
                                                fontSize: 13,
                                                color: AppColors.mainText,
                                                isHeading: block.type.isHeading,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Block',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppColors.dangerRed,
                                      ),
                                      onPressed: () async {
                                        if (_editingBlockId == block.id) {
                                          setState(() {
                                            _editingBlockId = null;
                                            _textController.clear();
                                          });
                                        }
                                        await state.deleteBlock(
                                          widget.bookId,
                                          block.id,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _blockPreview(ContentBlockModel block) {
    switch (block.type) {
      case ContentBlockType.manualPageBreak:
        return '──── Manual Page Break ────';
      case ContentBlockType.image:
        return 'Image: ${block.imageCaption ?? block.imagePath ?? 'Embedded figure'}';
      case ContentBlockType.table:
        final t = block.tableData;
        return 'Table (${t?.headers.length ?? 0} columns × ${t?.rows.length ?? 0} rows)';
      default:
        return block.textContent.trim().isEmpty
            ? '(Tap to write content)'
            : block.textContent;
    }
  }

  void _setAlignment(String align) {
    _pushUndoSnapshot();
    setState(() {
      _activeFormatting = _activeFormatting.copyWith(alignment: align);
    });
    _scheduleAutoSave();
  }

  Future<void> _applyHeadingOrAdd(
    AppState state,
    String chapterId,
    ContentBlockType headingType,
  ) async {
    if (_editingBlockId != null) {
      _pushUndoSnapshot();
      setState(() => _activeType = headingType);
      _scheduleAutoSave();
    } else {
      await _addNewBlock(state, chapterId, headingType);
    }
  }

  Future<void> _addNewBlock(
    AppState state,
    String chapterId,
    ContentBlockType type,
  ) async {
    await _saveActiveBlock();
    final created = await state.addBlock(
      bookId: widget.bookId,
      chapterId: chapterId,
      sectionId: _selectedSectionId,
      type: type,
      textContent: '',
      formatting: BlockFormatting(
        fontSize: state.settings.defaultFontSize,
        direction: state.settings.defaultDirection,
      ),
    );
    if (mounted) _selectBlockForEditing(created);
  }

  Future<void> _insertImageBlock(
    BuildContext context,
    AppState state,
    String chapterId,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !context.mounted) return;
    final storedPath = await state.imageStorage.persistImageFile(picked.path);
    final captionCtrl = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Image Caption'),
        content: TextField(
          controller: captionCtrl,
          decoration: const InputDecoration(
            labelText: 'Caption (Optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, captionCtrl.text.trim()),
            child: const Text('Insert'),
          ),
        ],
      ),
    );
    await state.addBlock(
      bookId: widget.bookId,
      chapterId: chapterId,
      sectionId: _selectedSectionId,
      type: ContentBlockType.image,
      textContent: caption ?? '',
      metadataJson: jsonEncode({
        'imagePath': storedPath,
        'caption': caption ?? '',
        'heightPt': 180.0,
      }),
    );
  }

  Future<void> _showInsertTableDialog(
    BuildContext context,
    AppState state,
    String chapterId,
  ) async {
    final headersCtrl = TextEditingController(text: 'Herb, Temperament, Notes');
    final rowsCtrl = TextEditingController(
      text: 'Item 1, Hot & Dry, Personal note
Item 2, Cold & Moist, Reference',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Table'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: headersCtrl,
                decoration: const InputDecoration(
                  labelText: 'Column Headers (comma-separated)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rowsCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Rows (one row per line, comma-separated)',
                ),
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
            child: const Text('Insert Table'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final headers = headersCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final rows = rowsCtrl.text
          .split('
')
          .map((line) => line.split(',').map((c) => c.trim()).toList())
          .where((r) => r.any((c) => c.isNotEmpty))
          .toList();
      await state.addBlock(
        bookId: widget.bookId,
        chapterId: chapterId,
        sectionId: _selectedSectionId,
        type: ContentBlockType.table,
        textContent: '${headers.join(' ')} ${rows.expand((r) => r).join(' ')}',
        metadataJson: jsonEncode({'headers': headers, 'rows': rows}),
      );
    }
  }

  Future<void> _showAddChapterDialog(
    BuildContext context,
    AppState state,
  ) async {
    final titleCtrl = TextEditingController();
    final urduCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Chapter'),
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
      final ch = await state.addChapter(
        bookId: widget.bookId,
        title: titleCtrl.text.trim(),
        urduTitle: urduCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _selectedChapterId = ch.id;
          _selectedSectionId = null;
        });
      }
    }
  }

  Future<void> _showAddSectionDialog(
    BuildContext context,
    AppState state,
    String chapterId,
  ) async {
    final titleCtrl = TextEditingController();
    final urduCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Section'),
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
      final sec = await state.addSection(
        bookId: widget.bookId,
        chapterId: chapterId,
        title: titleCtrl.text.trim(),
        urduTitle: urduCtrl.text.trim(),
      );
      if (mounted) setState(() => _selectedSectionId = sec.id);
    }
  }
}

class _ToolbarChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToolbarChip({
    required this.label,
    this.icon,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        avatar: icon != null
            ? Icon(
                icon,
                size: 16,
                color: selected
                    ? AppColors.paperWhite
                    : AppColors.primaryForestGreen,
              )
            : null,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.paperWhite : AppColors.mainText,
          ),
        ),
        backgroundColor:
            selected ? AppColors.primaryForestGreen : AppColors.paperWhite,
        side: const BorderSide(color: AppColors.border),
        onPressed: onTap,
      ),
    );
  }
}

class _FormatToggle extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _FormatToggle({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor:
            active ? AppColors.primaryForestGreen : AppColors.paperWhite,
        foregroundColor: active ? AppColors.paperWhite : AppColors.mainText,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(36, 36),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}
