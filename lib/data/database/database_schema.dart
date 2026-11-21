class DatabaseSchema {
  DatabaseSchema._();

  static const List<String> createTableStatements = [
    '''
    CREATE TABLE books (
      id TEXT PRIMARY KEY,
      slot_order INTEGER NOT NULL UNIQUE CHECK(slot_order BETWEEN 1 AND 4),
      title TEXT NOT NULL,
      subtitle TEXT NOT NULL DEFAULT '',
      author_name TEXT NOT NULL DEFAULT '',
      description TEXT NOT NULL DEFAULT '',
      publication_info TEXT NOT NULL DEFAULT '',
      cover_template TEXT NOT NULL DEFAULT 'botanicalForest',
      cover_accent_hex TEXT NOT NULL DEFAULT '#174C3C',
      custom_cover_image_path TEXT,
      last_opened_page INTEGER NOT NULL DEFAULT 1,
      last_opened_chapter_id TEXT,
      cached_page_count INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE chapters (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      title TEXT NOT NULL,
      urdu_title TEXT,
      sort_order INTEGER NOT NULL,
      starts_on_new_page INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE INDEX idx_chapters_book_order ON chapters(book_id, sort_order)
    ''',
    '''
    CREATE TABLE sections (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      title TEXT NOT NULL,
      urdu_title TEXT,
      sort_order INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
      FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE INDEX idx_sections_chapter_order ON sections(chapter_id, sort_order)
    ''',
    '''
    CREATE TABLE content_blocks (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      section_id TEXT,
      block_type TEXT NOT NULL,
      text_content TEXT NOT NULL DEFAULT '',
      metadata_json TEXT,
      formatting_json TEXT,
      sort_order INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
      FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE,
      FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE SET NULL
    )
    ''',
    '''
    CREATE INDEX idx_blocks_book_chapter_order ON content_blocks(book_id, chapter_id, sort_order)
    ''',
    '''
    CREATE TABLE nuskhas (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT '',
      urdu_name TEXT NOT NULL DEFAULT '',
      english_name TEXT NOT NULL DEFAULT '',
      preparation_method TEXT NOT NULL DEFAULT '',
      usage_instructions TEXT NOT NULL DEFAULT '',
      personal_observations TEXT NOT NULL DEFAULT '',
      source_reference TEXT NOT NULL DEFAULT '',
      additional_notes TEXT NOT NULL DEFAULT '',
      is_personal_note INTEGER NOT NULL DEFAULT 1,
      linked_book_id TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE nuskha_ingredients (
      id TEXT PRIMARY KEY,
      nuskha_id TEXT NOT NULL,
      name TEXT NOT NULL,
      quantity TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL,
      FOREIGN KEY (nuskha_id) REFERENCES nuskhas(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE INDEX idx_ingredients_nuskha ON nuskha_ingredients(nuskha_id, sort_order)
    ''',
    '''
    CREATE TABLE bookmarks (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      page_number INTEGER NOT NULL,
      chapter_title TEXT,
      label TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    '''
    CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
      entity_type,
      entity_id,
      book_id,
      chapter_id,
      section_id,
      title,
      body_raw,
      body_normalized,
      tokenize='unicode61'
    )
    ''',
  ];
}
