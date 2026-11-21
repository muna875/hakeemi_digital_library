import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/typography/bilingual_text_helper.dart';
import '../../models/nuskha/nuskha_model.dart';
import '../../shared/widgets/editorial_card.dart';
import '../../shared/widgets/empty_state_widget.dart';

class NuskhaManagerScreen extends StatefulWidget {
  const NuskhaManagerScreen({super.key});

  @override
  State<NuskhaManagerScreen> createState() => _NuskhaManagerScreenState();
}

class _NuskhaManagerScreenState extends State<NuskhaManagerScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allNuskhas = state.nuskhas;
    final filtered = _filter.trim().isEmpty
        ? allNuskhas
        : allNuskhas.where((n) {
            final hay = BilingualTextHelper.normalizeForSearch(
              '${n.name} ${n.urduName} ${n.englishName} ${n.category} ${n.ingredients.map((i) => i.name).join(' ')}',
            );
            return hay.contains(BilingualTextHelper.normalizeForSearch(_filter));
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hakeemi Nuskha Manager'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryForestGreen,
        foregroundColor: AppColors.paperWhite,
        onPressed: () => _openNuskhaEditor(context, state),
        icon: const Icon(Icons.add),
        label: const Text('New Nuskha'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter by Nuskha name, Urdu name, or ingredient…',
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.medication_liquid_outlined,
                    title: allNuskhas.isEmpty
                        ? 'No Nuskhe Recorded Yet'
                        : 'No Matching Formulations',
                    subtitle: allNuskhas.isEmpty
                        ? 'Record your personal herbal formulations with exact ingredients, quantities, preparation methods, and observations.'
                        : 'Try another Urdu or English keyword.',
                    actionLabel: allNuskhas.isEmpty ? 'Add First Nuskha' : null,
                    onAction: allNuskhas.isEmpty
                        ? () => _openNuskhaEditor(context, state)
                        : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      96,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      return EditorialCard(
                        onTap: () =>
                            _openNuskhaEditor(context, state, existing: n),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      if (n.urduName.trim().isNotEmpty)
                                        Directionality(
                                          textDirection: TextDirection.rtl,
                                          child: Text(
                                            n.urduName,
                                            style: BilingualTextHelper
                                                .buildTextStyle(
                                              text: n.urduName,
                                              fontSize: 15,
                                              color:
                                                  AppColors.primaryForestGreen,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: n.isPersonalNote
                                        ? AppColors.goldTint
                                        : AppColors.sageTint,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    n.isPersonalNote
                                        ? 'Personal Note'
                                        : 'Classical Ref.',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: n.isPersonalNote
                                          ? AppColors.mainText
                                          : AppColors.primaryForestGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${n.category.isEmpty ? 'Uncategorized' : n.category} • ${n.ingredients.length} ingredients',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 34),
                                  ),
                                  onPressed: () =>
                                      _showInsertIntoBookDialog(context, state, n),
                                  icon: const Icon(
                                    Icons.menu_book_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Insert into Book'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _openNuskhaEditor(
                                    context,
                                    state,
                                    existing: n,
                                  ),
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('Edit'),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.dangerRed,
                                  ),
                                  onPressed: () =>
                                      _confirmDeleteNuskha(context, state, n),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  label: const Text('Delete'),
                                ),
                              ],
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

  Future<void> _openNuskhaEditor(
    BuildContext context,
    AppState state, {
    NuskhaModel? existing,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _NuskhaFormPage(existing: existing),
      ),
    );
  }

  Future<void> _confirmDeleteNuskha(
    BuildContext context,
    AppState state,
    NuskhaModel nuskha,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Nuskha Entry?'),
        content: Text(
          'Permanently delete "${nuskha.name}"? Existing book blocks already inserted will not be affected.',
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
      await state.deleteNuskha(nuskha.id);
    }
  }

  Future<void> _showInsertIntoBookDialog(
    BuildContext context,
    AppState state,
    NuskhaModel nuskha,
  ) async {
    String selectedBookId = state.books.first.id;
    String? selectedChapterId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final chapters = state.chaptersForBook(selectedBookId);
          if (chapters.isNotEmpty &&
              (selectedChapterId == null ||
                  !chapters.any((c) => c.id == selectedChapterId))) {
            selectedChapterId = chapters.first.id;
          }
          return AlertDialog(
            title: const Text('Insert Nuskha Into Book'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedBookId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Book'),
                  items: state.books
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.title),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() {
                        selectedBookId = v;
                        selectedChapterId = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (chapters.isEmpty)
                  const Text(
                    'This book has no chapters yet. A "Formulations" chapter will be created automatically.',
                    style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedChapterId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Select Chapter'),
                    items: chapters
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.displayTitle),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedChapterId = v),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  String targetChapterId = selectedChapterId ?? '';
                  if (targetChapterId.isEmpty) {
                    final created = await state.addChapter(
                      bookId: selectedBookId,
                      title: 'Formulations',
                      urduTitle: 'نسخہ جات',
                    );
                    targetChapterId = created.id;
                  }
                  await state.insertNuskhaIntoBook(
                    nuskha: nuskha,
                    bookId: selectedBookId,
                    chapterId: targetChapterId,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Nuskha inserted verbatim and book pagination updated.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Insert'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NuskhaFormPage extends StatefulWidget {
  final NuskhaModel? existing;

  const _NuskhaFormPage({this.existing});

  @override
  State<_NuskhaFormPage> createState() => _NuskhaFormPageState();
}

class _NuskhaFormPageState extends State<_NuskhaFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _urduCtrl;
  late final TextEditingController _englishCtrl;
  late final TextEditingController _prepCtrl;
  late final TextEditingController _usageCtrl;
  late final TextEditingController _obsCtrl;
  late final TextEditingController _sourceCtrl;
  late final TextEditingController _notesCtrl;
  late bool _isPersonalNote;

  final List<(TextEditingController, TextEditingController)> _ingredientRows =
      [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _categoryCtrl = TextEditingController(text: e?.category ?? '');
    _urduCtrl = TextEditingController(text: e?.urduName ?? '');
    _englishCtrl = TextEditingController(text: e?.englishName ?? '');
    _prepCtrl = TextEditingController(text: e?.preparationMethod ?? '');
    _usageCtrl = TextEditingController(text: e?.usageInstructions ?? '');
    _obsCtrl = TextEditingController(text: e?.personalObservations ?? '');
    _sourceCtrl = TextEditingController(text: e?.sourceReference ?? '');
    _notesCtrl = TextEditingController(text: e?.additionalNotes ?? '');
    _isPersonalNote = e?.isPersonalNote ?? true;

    if (e != null && e.ingredients.isNotEmpty) {
      for (final ing in e.ingredients) {
        _ingredientRows.add((
          TextEditingController(text: ing.name),
          TextEditingController(text: ing.quantity),
        ));
      }
    } else {
      _addIngredientRow();
    }
  }

  void _addIngredientRow() {
    setState(() {
      _ingredientRows.add((TextEditingController(), TextEditingController()));
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _urduCtrl.dispose();
    _englishCtrl.dispose();
    _prepCtrl.dispose();
    _usageCtrl.dispose();
    _obsCtrl.dispose();
    _sourceCtrl.dispose();
    _notesCtrl.dispose();
    for (final row in _ingredientRows) {
      row.$1.dispose();
      row.$2.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final now = DateTime.now();
    final ingredients = <NuskhaIngredient>[];
    for (int i = 0; i < _ingredientRows.length; i++) {
      final name = _ingredientRows[i].$1.text.trim();
      final qty = _ingredientRows[i].$2.text.trim();
      if (name.isEmpty && qty.isEmpty) continue;
      ingredients.add(
        NuskhaIngredient(
          id: '',
          nuskhaId: widget.existing?.id ?? '',
          name: name,
          quantity: qty,
          sortOrder: i,
        ),
      );
    }

    final model = NuskhaModel(
      id: widget.existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      urduName: _urduCtrl.text.trim(),
      englishName: _englishCtrl.text.trim(),
      ingredients: ingredients,
      preparationMethod: _prepCtrl.text.trim(),
      usageInstructions: _usageCtrl.text.trim(),
      personalObservations: _obsCtrl.text.trim(),
      sourceReference: _sourceCtrl.text.trim(),
      additionalNotes: _notesCtrl.text.trim(),
      isPersonalNote: _isPersonalNote,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );

    await state.saveNuskha(model);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Nuskha Entry' : 'Edit Nuskha'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.goldTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.mutedGold.withOpacity(0.5)),
              ),
              child: const Text(
                'All entered ingredients, quantities, and dosages are preserved verbatim and never automatically altered.',
                style: TextStyle(fontSize: 12, color: AppColors.mainText),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter Nuskha name' : null,
              decoration: const InputDecoration(labelText: 'Nuskha Name *'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Category (e.g., Safoof, Majoon, Joshanda)',
              ),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.rtl,
              child: TextFormField(
                controller: _urduCtrl,
                decoration: const InputDecoration(
                  labelText: 'Urdu Name — اردو نام',
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _englishCtrl,
              decoration: const InputDecoration(labelText: 'English Name'),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mark as Personal Practitioner Note'),
              subtitle: const Text(
                'Distinguishes personal observations from classical/verified texts',
              ),
              value: _isPersonalNote,
              onChanged: (v) => setState(() => _isPersonalNote = v),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ingredients & Quantities',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _addIngredientRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Ingredient'),
                ),
              ],
            ),
            for (int i = 0; i < _ingredientRows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ingredientRows[i].$1,
                        decoration: InputDecoration(
                          labelText: 'Ingredient ${i + 1}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _ingredientRows[i].$2,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.dangerRed,
                      ),
                      onPressed: _ingredientRows.length > 1
                          ? () => setState(() => _ingredientRows.removeAt(i))
                          : null,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _prepCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Preparation Method (ترکیب تیاری)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _usageCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Usage Instructions (ترکیب استعمال)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _obsCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Personal Observations'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _sourceCtrl,
              decoration: const InputDecoration(labelText: 'Source / Reference'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Additional Notes'),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save Formulation'),
            ),
          ],
        ),
      ),
    );
  }
}
