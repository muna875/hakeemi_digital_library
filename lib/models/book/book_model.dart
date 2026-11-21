enum CoverTemplate {
  botanicalForest,
  botanicalSage,
  academicGold,
  minimalistIvory,
  customImage,
}

extension CoverTemplateX on CoverTemplate {
  String get key => name;

  String get displayName {
    switch (this) {
      case CoverTemplate.botanicalForest:
        return 'Botanical Forest';
      case CoverTemplate.botanicalSage:
        return 'Botanical Sage';
      case CoverTemplate.academicGold:
        return 'Academic Reference';
      case CoverTemplate.minimalistIvory:
        return 'Minimalist Ivory & Green';
      case CoverTemplate.customImage:
        return 'Custom Cover Image';
    }
  }

  static CoverTemplate fromKey(String? key) {
    for (final v in CoverTemplate.values) {
      if (v.name == key) return v;
    }
    return CoverTemplate.botanicalForest;
  }
}

class BookModel {
  final String id;
  final int slotOrder; // Strictly 1..4
  final String title;
  final String subtitle;
  final String authorName;
  final String description;
  final String publicationInfo;
  final CoverTemplate coverTemplate;
  final String coverAccentHex;
  final String? customCoverImagePath;
  final int lastOpenedPage;
  final String? lastOpenedChapterId;
  final int cachedPageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookModel({
    required this.id,
    required this.slotOrder,
    required this.title,
    required this.subtitle,
    required this.authorName,
    required this.description,
    required this.publicationInfo,
    required this.coverTemplate,
    required this.coverAccentHex,
    this.customCoverImagePath,
    this.lastOpenedPage = 1,
    this.lastOpenedChapterId,
    this.cachedPageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  double get readingProgress {
    if (cachedPageCount <= 0) return 0.0;
    return (lastOpenedPage / cachedPageCount).clamp(0.0, 1.0);
  }

  BookModel copyWith({
    String? title,
    String? subtitle,
    String? authorName,
    String? description,
    String? publicationInfo,
    CoverTemplate? coverTemplate,
    String? coverAccentHex,
    String? customCoverImagePath,
    bool clearCustomCover = false,
    int? lastOpenedPage,
    String? lastOpenedChapterId,
    int? cachedPageCount,
    DateTime? updatedAt,
  }) {
    return BookModel(
      id: id,
      slotOrder: slotOrder,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      authorName: authorName ?? this.authorName,
      description: description ?? this.description,
      publicationInfo: publicationInfo ?? this.publicationInfo,
      coverTemplate: coverTemplate ?? this.coverTemplate,
      coverAccentHex: coverAccentHex ?? this.coverAccentHex,
      customCoverImagePath: clearCustomCover
          ? null
          : (customCoverImagePath ?? this.customCoverImagePath),
      lastOpenedPage: lastOpenedPage ?? this.lastOpenedPage,
      lastOpenedChapterId: lastOpenedChapterId ?? this.lastOpenedChapterId,
      cachedPageCount: cachedPageCount ?? this.cachedPageCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'slot_order': slotOrder,
        'title': title,
        'subtitle': subtitle,
        'author_name': authorName,
        'description': description,
        'publication_info': publicationInfo,
        'cover_template': coverTemplate.key,
        'cover_accent_hex': coverAccentHex,
        'custom_cover_image_path': customCoverImagePath,
        'last_opened_page': lastOpenedPage,
        'last_opened_chapter_id': lastOpenedChapterId,
        'cached_page_count': cachedPageCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory BookModel.fromMap(Map<String, dynamic> map) {
    return BookModel(
      id: map['id'] as String,
      slotOrder: (map['slot_order'] as num).toInt(),
      title: (map['title'] as String?) ?? '',
      subtitle: (map['subtitle'] as String?) ?? '',
      authorName: (map['author_name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      publicationInfo: (map['publication_info'] as String?) ?? '',
      coverTemplate: CoverTemplateX.fromKey(map['cover_template'] as String?),
      coverAccentHex: (map['cover_accent_hex'] as String?) ?? '#174C3C',
      customCoverImagePath: map['custom_cover_image_path'] as String?,
      lastOpenedPage: (map['last_opened_page'] as num?)?.toInt() ?? 1,
      lastOpenedChapterId: map['last_opened_chapter_id'] as String?,
      cachedPageCount: (map['cached_page_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
