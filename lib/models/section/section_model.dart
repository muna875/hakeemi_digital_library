class SectionModel {
  final String id;
  final String bookId;
  final String chapterId;
  final String title;
  final String? urduTitle;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SectionModel({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.title,
    this.urduTitle,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayTitle =>
      (urduTitle != null && urduTitle!.trim().isNotEmpty)
          ? '$title — $urduTitle'
          : title;

  SectionModel copyWith({
    String? chapterId,
    String? title,
    String? urduTitle,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return SectionModel(
      id: id,
      bookId: bookId,
      chapterId: chapterId ?? this.chapterId,
      title: title ?? this.title,
      urduTitle: urduTitle ?? this.urduTitle,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'chapter_id': chapterId,
        'title': title,
        'urdu_title': urduTitle,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SectionModel.fromMap(Map<String, dynamic> map) {
    return SectionModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      chapterId: map['chapter_id'] as String,
      title: (map['title'] as String?) ?? '',
      urduTitle: map['urdu_title'] as String?,
      sortOrder: (map['sort_order'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
