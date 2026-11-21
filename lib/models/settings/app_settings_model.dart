class BookmarkModel {
  final String id;
  final String bookId;
  final int pageNumber;
  final String? chapterTitle;
  final String label;
  final DateTime createdAt;

  const BookmarkModel({
    required this.id,
    required this.bookId,
    required this.pageNumber,
    this.chapterTitle,
    required this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'page_number': pageNumber,
        'chapter_title': chapterTitle,
        'label': label,
        'created_at': createdAt.toIso8601String(),
      };

  factory BookmarkModel.fromMap(Map<String, dynamic> map) {
    return BookmarkModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      pageNumber: (map['page_number'] as num).toInt(),
      chapterTitle: map['chapter_title'] as String?,
      label: (map['label'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class AppSettingsModel {
  final double defaultFontSize;
  final double readerZoom;
  final bool showRunningHeaders;
  final bool showPageNumbers;
  final bool includeBackCoverInPdf;
  final bool includeAuthorPageInPdf;
  final String defaultAuthorName;
  final String defaultDirection; // 'auto', 'rtl', 'ltr'

  const AppSettingsModel({
    this.defaultFontSize = 13.0,
    this.readerZoom = 1.0,
    this.showRunningHeaders = true,
    this.showPageNumbers = true,
    this.includeBackCoverInPdf = true,
    this.includeAuthorPageInPdf = true,
    this.defaultAuthorName = '',
    this.defaultDirection = 'auto',
  });

  AppSettingsModel copyWith({
    double? defaultFontSize,
    double? readerZoom,
    bool? showRunningHeaders,
    bool? showPageNumbers,
    bool? includeBackCoverInPdf,
    bool? includeAuthorPageInPdf,
    String? defaultAuthorName,
    String? defaultDirection,
  }) {
    return AppSettingsModel(
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      readerZoom: readerZoom ?? this.readerZoom,
      showRunningHeaders: showRunningHeaders ?? this.showRunningHeaders,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      includeBackCoverInPdf:
          includeBackCoverInPdf ?? this.includeBackCoverInPdf,
      includeAuthorPageInPdf:
          includeAuthorPageInPdf ?? this.includeAuthorPageInPdf,
      defaultAuthorName: defaultAuthorName ?? this.defaultAuthorName,
      defaultDirection: defaultDirection ?? this.defaultDirection,
    );
  }

  Map<String, String> toKeyValueMap() => {
        'default_font_size': defaultFontSize.toString(),
        'reader_zoom': readerZoom.toString(),
        'show_running_headers': showRunningHeaders ? '1' : '0',
        'show_page_numbers': showPageNumbers ? '1' : '0',
        'include_back_cover_in_pdf': includeBackCoverInPdf ? '1' : '0',
        'include_author_page_in_pdf': includeAuthorPageInPdf ? '1' : '0',
        'default_author_name': defaultAuthorName,
        'default_direction': defaultDirection,
      };

  factory AppSettingsModel.fromKeyValueMap(Map<String, String> map) {
    return AppSettingsModel(
      defaultFontSize: double.tryParse(map['default_font_size'] ?? '') ?? 13.0,
      readerZoom: double.tryParse(map['reader_zoom'] ?? '') ?? 1.0,
      showRunningHeaders: (map['show_running_headers'] ?? '1') == '1',
      showPageNumbers: (map['show_page_numbers'] ?? '1') == '1',
      includeBackCoverInPdf: (map['include_back_cover_in_pdf'] ?? '1') == '1',
      includeAuthorPageInPdf: (map['include_author_page_in_pdf'] ?? '1') == '1',
      defaultAuthorName: map['default_author_name'] ?? '',
      defaultDirection: map['default_direction'] ?? 'auto',
    );
  }
}
