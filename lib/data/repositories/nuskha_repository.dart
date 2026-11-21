import 'package:uuid/uuid.dart';

import '../../core/constants/default_books.dart';
import '../../core/typography/bilingual_text_helper.dart';
import '../../models/nuskha/nuskha_model.dart';
import '../database/app_database.dart';

class NuskhaRepository {
  final AppDatabase _appDb;
  final Uuid _uuid = const Uuid();

  NuskhaRepository(this._appDb);

  Future<List<NuskhaModel>> getAllNuskhas() async {
    final db = await _appDb.database;
    final rows = await db.query('nuskhas', orderBy: 'updated_at DESC');
    final result = <NuskhaModel>[];
    for (final row in rows) {
      final ingRows = await db.query(
        'nuskha_ingredients',
        where: 'nuskha_id = ?',
        whereArgs: [row['id']],
        orderBy: 'sort_order ASC',
      );
      result.add(
        NuskhaModel.fromMap(
          row,
          ingredients: ingRows.map(NuskhaIngredient.fromMap).toList(),
        ),
      );
    }
    return result;
  }

  Future<NuskhaModel?> getNuskhaById(String id) async {
    final db = await _appDb.database;
    final rows = await db.query('nuskhas', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final ingRows = await db.query(
      'nuskha_ingredients',
      where: 'nuskha_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order ASC',
    );
    return NuskhaModel.fromMap(
      rows.first,
      ingredients: ingRows.map(NuskhaIngredient.fromMap).toList(),
    );
  }

  /// Saves or updates a Nuskha record verbatim without altering user-entered quantities.
  Future<NuskhaModel> saveNuskha(NuskhaModel input) async {
    final db = await _appDb.database;
    final now = DateTime.now();
    final id = input.id.isEmpty ? _uuid.v4() : input.id;
    final savedIngredients = <NuskhaIngredient>[];
    for (int i = 0; i < input.ingredients.length; i++) {
      final ing = input.ingredients[i];
      savedIngredients.add(
        NuskhaIngredient(
          id: ing.id.isEmpty ? _uuid.v4() : ing.id,
          nuskhaId: id,
          name: ing.name,
          quantity: ing.quantity,
          sortOrder: i,
        ),
      );
    }

    final saved = NuskhaModel(
      id: id,
      name: input.name,
      category: input.category,
      urduName: input.urduName,
      englishName: input.englishName,
      ingredients: savedIngredients,
      preparationMethod: input.preparationMethod,
      usageInstructions: input.usageInstructions,
      personalObservations: input.personalObservations,
      sourceReference: input.sourceReference,
      additionalNotes: input.additionalNotes,
      isPersonalNote: input.isPersonalNote,
      linkedBookId: input.linkedBookId,
      createdAt: input.id.isEmpty ? now : input.createdAt,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      final exists = await txn.query(
        'nuskhas',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (exists.isEmpty) {
        await txn.insert('nuskhas', saved.toMap());
      } else {
        await txn.update(
          'nuskhas',
          saved.toMap(),
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      await txn.delete(
        'nuskha_ingredients',
        where: 'nuskha_id = ?',
        whereArgs: [id],
      );
      for (final ing in savedIngredients) {
        await txn.insert('nuskha_ingredients', ing.toMap());
      }

      await txn.delete(
        'search_index',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['nuskha', id],
      );
      final raw = saved.toStructuredText();
      await txn.insert('search_index', {
        'entity_type': 'nuskha',
        'entity_id': id,
        'book_id': saved.linkedBookId ?? DefaultBooks.book1Id,
        'chapter_id': '',
        'section_id': '',
        'title': '${saved.name} ${saved.urduName}'.trim(),
        'body_raw': raw,
        'body_normalized': BilingualTextHelper.normalizeForSearch(raw),
      });
    });

    return saved;
  }

  Future<void> deleteNuskha(String id) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete(
        'search_index',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['nuskha', id],
      );
      await txn.delete('nuskhas', where: 'id = ?', whereArgs: [id]);
    });
  }
}
