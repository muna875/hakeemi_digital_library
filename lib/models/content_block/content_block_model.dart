import 'dart:convert';

enum ContentBlockType {
  chapterHeading,
  sectionHeading,
  subheading,
  paragraph,
  richText,
  numberedList,
  bulletList,
  image,
  table,
  nuskhaEntry,
  note,
  manualPageBreak,
}

extension ContentBlockTypeX on ContentBlockType {
  String get key => name;

  String get label {
    switch (this) {
      case ContentBlockType.chapterHeading:
        return 'Heading 1 (Chapter)';
      case ContentBlockType.sectionHeading:
        return 'Heading 2 (Section)';
      case ContentBlockType.subheading:
        return 'Heading 3 (Subheading)';
      case ContentBlockType.paragraph:
        return 'Paragraph';
      case ContentBlockType.richText:
        return 'Rich Text';
      case ContentBlockType.numberedList:
        return 'Numbered List';
      case ContentBlockType.bulletList:
        return 'Bullet List';
      case ContentBlockType.image:
        return 'Image';
      case ContentBlockType.table:
        return 'Table';
      case ContentBlockType.nuskhaEntry:
        return 'Nuskha Entry';
      case ContentBlockType.note:
        return 'Personal Note';
      case ContentBlockType.manualPageBreak:
        return 'Manual Page Break';
    }
  }

  bool get isHeading =>
      this == ContentBlockType.chapterHeading ||
      this == ContentBlockType.sectionHeading ||
      this == ContentBlockType.subheading;

  static ContentBlockType fromKey(String? key) {
    for (final v in ContentBlockType.values) {
      if (v.name == key) return v;
    }
    return ContentBlockType.paragraph;
  }
}

class BlockFormatting {
  final bool bold;
  final bool italic;
  final bool underline;
  final double fontSize;
  final String alignment; // 'start', 'center', 'end', 'justify'
  final String direction; // 'auto', 'rtl', 'ltr'

  const BlockFormatting({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.fontSize = 13.0,
    this.alignment = 'start',
    this.direction = 'auto',
  });

  BlockFormatting copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    double? fontSize,
    String? alignment,
    String? direction,
  }) {
    return BlockFormatting(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      fontSize: fontSize ?? this.fontSize,
      alignment: alignment ?? this.alignment,
      direction: direction ?? this.direction,
    );
  }

  Map<String, dynamic> toJson() => {
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'fontSize': fontSize,
        'alignment': alignment,
        'direction': direction,
      };

  factory BlockFormatting.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BlockFormatting();
    return BlockFormatting(
      bold: (json['bold'] as bool?) ?? false,
      italic: (json['italic'] as bool?) ?? false,
      underline: (json['underline'] as bool?) ?? false,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 13.0,
      alignment: (json['alignment'] as String?) ?? 'start',
      direction: (json['direction'] as String?) ?? 'auto',
    );
  }
}

class TableBlockData {
  final List<String> headers;
  final List<List<String>> rows;

  const TableBlockData({required this.headers, required this.rows});

  Map<String, dynamic> toJson() => {'headers': headers, 'rows': rows};

  factory TableBlockData.fromJson(Map<String, dynamic> json) {
    final headers = (json['headers'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final rows = (json['rows'] as List<dynamic>? ?? [])
        .map((r) => (r as List<dynamic>).map((c) => c.toString()).toList())
        .toList();
    return TableBlockData(headers: headers, rows: rows);
  }
}

class ContentBlockModel {
  final String id;
  final String bookId;
  final String chapterId;
  final String? sectionId;
  final ContentBlockType type;
  final String textContent;
  final String? metadataJson; // Stores table rows, image path+caption, list items, or nuskhaId
  final BlockFormatting formatting;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContentBlockModel({
    required this.id,
    required this.bookId,
    required this.chapterId,
    this.sectionId,
    required this.type,
    required this.textContent,
    this.metadataJson,
    this.formatting = const BlockFormatting(),
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> get metadata {
    if (metadataJson == null || metadataJson!.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(metadataJson!);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  List<String> get listItems {
    final m = metadata;
    if (m['items'] is List) {
      return (m['items'] as List).map((e) => e.toString()).toList();
    }
    return textContent
        .split('
')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  TableBlockData? get tableData {
    if (type != ContentBlockType.table) return null;
    final m = metadata;
    if (m.containsKey('headers') || m.containsKey('rows')) {
      return TableBlockData.fromJson(m);
    }
    return const TableBlockData(headers: ['Column 1', 'Column 2'], rows: []);
  }

  String? get imagePath => metadata['imagePath'] as String?;
  String? get imageCaption => metadata['caption'] as String?;
  double get imageHeightPt =>
      (metadata['heightPt'] as num?)?.toDouble() ?? 180.0;
  String? get linkedNuskhaId => metadata['nuskhaId'] as String?;

  ContentBlockModel copyWith({
    String? chapterId,
    String? sectionId,
    bool clearSectionId = false,
    ContentBlockType? type,
    String? textContent,
    String? metadataJson,
    BlockFormatting? formatting,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return ContentBlockModel(
      id: id,
      bookId: bookId,
      chapterId: chapterId ?? this.chapterId,
      sectionId: clearSectionId ? null : (sectionId ?? this.sectionId),
      type: type ?? this.type,
      textContent: textContent ?? this.textContent,
      metadataJson: metadataJson ?? this.metadataJson,
      formatting: formatting ?? this.formatting,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'chapter_id': chapterId,
        'section_id': sectionId,
        'block_type': type.key,
        'text_content': textContent,
        'metadata_json': metadataJson,
        'formatting_json': jsonEncode(formatting.toJson()),
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ContentBlockModel.fromMap(Map<String, dynamic> map) {
    BlockFormatting fmt = const BlockFormatting();
    final fmtStr = map['formatting_json'] as String?;
    if (fmtStr != null && fmtStr.isNotEmpty) {
      try {
        fmt = BlockFormatting.fromJson(
          jsonDecode(fmtStr) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    return ContentBlockModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      chapterId: map['chapter_id'] as String,
      sectionId: map['section_id'] as String?,
      type: ContentBlockTypeX.fromKey(map['block_type'] as String?),
      textContent: (map['text_content'] as String?) ?? '',
      metadataJson: map['metadata_json'] as String?,
      formatting: fmt,
      sortOrder: (map['sort_order'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
