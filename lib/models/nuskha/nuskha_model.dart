class NuskhaIngredient {
  final String id;
  final String nuskhaId;
  final String name;
  final String quantity;
  final int sortOrder;

  const NuskhaIngredient({
    required this.id,
    required this.nuskhaId,
    required this.name,
    required this.quantity,
    required this.sortOrder,
  });

  NuskhaIngredient copyWith({
    String? name,
    String? quantity,
    int? sortOrder,
  }) {
    return NuskhaIngredient(
      id: id,
      nuskhaId: nuskhaId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nuskha_id': nuskhaId,
        'name': name,
        'quantity': quantity,
        'sort_order': sortOrder,
      };

  factory NuskhaIngredient.fromMap(Map<String, dynamic> map) {
    return NuskhaIngredient(
      id: map['id'] as String,
      nuskhaId: map['nuskha_id'] as String,
      name: (map['name'] as String?) ?? '',
      quantity: (map['quantity'] as String?) ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class NuskhaModel {
  final String id;
  final String name;
  final String category;
  final String urduName;
  final String englishName;
  final List<NuskhaIngredient> ingredients;
  final String preparationMethod;
  final String usageInstructions;
  final String personalObservations;
  final String sourceReference;
  final String additionalNotes;
  final bool isPersonalNote; // Distinguishes personal notes from classical reference
  final String? linkedBookId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NuskhaModel({
    required this.id,
    required this.name,
    required this.category,
    required this.urduName,
    required this.englishName,
    required this.ingredients,
    required this.preparationMethod,
    required this.usageInstructions,
    required this.personalObservations,
    required this.sourceReference,
    required this.additionalNotes,
    this.isPersonalNote = true,
    this.linkedBookId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Formats the formulation verbatim without altering entered quantities or dosages.
  String toStructuredText() {
    final buf = StringBuffer();
    buf.writeln(name);
    if (urduName.trim().isNotEmpty) buf.writeln('Urdu Name: $urduName');
    if (englishName.trim().isNotEmpty) buf.writeln('English Name: $englishName');
    if (category.trim().isNotEmpty) buf.writeln('Category: $category');
    buf.writeln(
      isPersonalNote
          ? 'Classification: Personal Practitioner Record (Not Clinically Verified)'
          : 'Classification: Traditional Text Reference',
    );
    if (ingredients.isNotEmpty) {
      buf.writeln('
Ingredients:');
      for (final ing in ingredients) {
        buf.writeln('• ${ing.name} — ${ing.quantity}');
      }
    }
    if (preparationMethod.trim().isNotEmpty) {
      buf.writeln('
Preparation Method:
$preparationMethod');
    }
    if (usageInstructions.trim().isNotEmpty) {
      buf.writeln('
Usage Instructions:
$usageInstructions');
    }
    if (personalObservations.trim().isNotEmpty) {
      buf.writeln('
Personal Observations:
$personalObservations');
    }
    if (sourceReference.trim().isNotEmpty) {
      buf.writeln('
Source / Reference:
$sourceReference');
    }
    if (additionalNotes.trim().isNotEmpty) {
      buf.writeln('
Additional Notes:
$additionalNotes');
    }
    return buf.toString().trim();
  }

  NuskhaModel copyWith({
    String? name,
    String? category,
    String? urduName,
    String? englishName,
    List<NuskhaIngredient>? ingredients,
    String? preparationMethod,
    String? usageInstructions,
    String? personalObservations,
    String? sourceReference,
    String? additionalNotes,
    bool? isPersonalNote,
    String? linkedBookId,
    DateTime? updatedAt,
  }) {
    return NuskhaModel(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      urduName: urduName ?? this.urduName,
      englishName: englishName ?? this.englishName,
      ingredients: ingredients ?? this.ingredients,
      preparationMethod: preparationMethod ?? this.preparationMethod,
      usageInstructions: usageInstructions ?? this.usageInstructions,
      personalObservations: personalObservations ?? this.personalObservations,
      sourceReference: sourceReference ?? this.sourceReference,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      isPersonalNote: isPersonalNote ?? this.isPersonalNote,
      linkedBookId: linkedBookId ?? this.linkedBookId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'urdu_name': urduName,
        'english_name': englishName,
        'preparation_method': preparationMethod,
        'usage_instructions': usageInstructions,
        'personal_observations': personalObservations,
        'source_reference': sourceReference,
        'additional_notes': additionalNotes,
        'is_personal_note': isPersonalNote ? 1 : 0,
        'linked_book_id': linkedBookId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory NuskhaModel.fromMap(
    Map<String, dynamic> map, {
    List<NuskhaIngredient> ingredients = const [],
  }) {
    return NuskhaModel(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      urduName: (map['urdu_name'] as String?) ?? '',
      englishName: (map['english_name'] as String?) ?? '',
      ingredients: ingredients,
      preparationMethod: (map['preparation_method'] as String?) ?? '',
      usageInstructions: (map['usage_instructions'] as String?) ?? '',
      personalObservations: (map['personal_observations'] as String?) ?? '',
      sourceReference: (map['source_reference'] as String?) ?? '',
      additionalNotes: (map['additional_notes'] as String?) ?? '',
      isPersonalNote: ((map['is_personal_note'] as num?)?.toInt() ?? 1) == 1,
      linkedBookId: map['linked_book_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
