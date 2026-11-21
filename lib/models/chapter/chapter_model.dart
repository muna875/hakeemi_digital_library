class ChapterModel {
  final String id;
  final String bookId;
  final String title;
  final String? urduTitle;
  final int sortOrder;
  final bool startsOnNewPage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChapterModel({
    required this.id,
    required this.bookId,
    required this.title,
    this.urduTitle,
    required this.sortOrder,
    this.startsOnNewPage = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayTitle =>
      (urduTitle != null && urduTitle!.trim().isNotEmpty)
          ? '$title — $urduTitle'
          : title;

  ChapterModel copyWith({
    String? title,
    String? urduTitle,
    int? sortOrder,
    bool? startsOnNewPage,
    DateTime? updatedAt,
  }) {
    return ChapterModel(
      id: id,
      bookId: bookId,
      title: title ?? this.title,
      urduTitle: urduTitle ?? this.urduTitle,
      sortOrder: sortOrder ?? this.sortOrder,
      startsOnNewPage: startsOnNewPage ?? this.startsOnNewPage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'title': title,
        'urdu_title': urduTitle,
        'sort_order': sortOrder,
        'starts_on_new_page': startsOnNewPage ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ChapterModel.fromMap(Map<String, dynamic> map) {
    return ChapterModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      title: (map['title'] as String?) ?? '',
      urduTitle: map['urdu_title'] as String?,
      sortOrder: (map['sort_order'] as num).toInt(),
      startsOnNewPage: ((map['starts_on_new_page'] as num?)?.toInt() ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
