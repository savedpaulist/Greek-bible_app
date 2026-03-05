// lib/features/notes/data/notes_db.dart

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'note_model.dart';
import '../../../core/models/models.dart';

const _uuid = Uuid();

/// Default templates shipped with the app
const _defaultTemplates = <NoteTemplate>[
  NoteTemplate(
    id: 'tpl_study',
    name: 'Изучение отрывка',
    content: '# Изучение\n\n'
        '## Отрывок\n`[[Книга Гл:Ст]]`\n\n'
        '## Контекст\n\n\n'
        '## Наблюдения\n- \n\n'
        '## Применение\n\n',
  ),
  NoteTemplate(
    id: 'tpl_word',
    name: 'Слово / Лемма',
    content: '# Слово: \n\n'
        '## Strong\'s\nG\n\n'
        '## Значение\n\n\n'
        '## Контексты\n- [[Книга Гл:Ст]]\n\n'
        '## Заметки\n\n',
  ),
  NoteTemplate(
    id: 'tpl_theme',
    name: 'Тематическая заметка',
    content: '# Тема: \n\n'
        '## Ключевые места\n- [[Книга Гл:Ст]]\n\n'
        '## Связи\n- [[заметка]]\n\n'
        '## Размышления\n\n',
  ),
  NoteTemplate(
    id: 'tpl_blank',
    name: 'Пустая',
    content: '# \n\n',
  ),
];

class NotesDB {
  Database? _db;

  Future<void> init({String? basePath}) async {
    final dir = basePath ?? await getDatabasesPath();
    final path = join(dir, 'notes.db');
    _db = await openDatabase(
      path,
      version: 7,
      onCreate: (db, _) async {
        await _createV1Tables(db);
        await _createV2Tables(db);
        await _createV3Tables(db);
        await _createV4Tables(db);
        await _createV5Tables(db);
        await _createV6Tables(db);
        await _createV7Tables(db);
        for (final t in _defaultTemplates) {
          await db.insert('templates', t.toMap());
        }
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _createV2Tables(db);
        if (oldV < 3) await _createV3Tables(db);
        if (oldV < 4) await _createV4Tables(db);
        if (oldV < 5) await _createV5Tables(db);
        if (oldV < 6) await _createV6Tables(db);
        if (oldV < 7) await _createV7Tables(db);
      },
    );
  }

  static Future<void> _createV1Tables(Database db) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        template_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE note_links (
        source_id TEXT NOT NULL,
        target_id TEXT NOT NULL,
        PRIMARY KEY (source_id, target_id),
        FOREIGN KEY (source_id) REFERENCES notes(id) ON DELETE CASCADE,
        FOREIGN KEY (target_id) REFERENCES notes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  static Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS verse_comments (
        id TEXT PRIMARY KEY,
        book_number INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_vc_ref
      ON verse_comments(book_number, chapter, verse)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parallel_verses (
        id TEXT PRIMARY KEY,
        source_book INTEGER NOT NULL,
        source_chapter INTEGER NOT NULL,
        source_verse INTEGER NOT NULL,
        target_book INTEGER NOT NULL,
        target_chapter INTEGER NOT NULL,
        target_verse INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pv_src
      ON parallel_verses(source_book, source_chapter, source_verse)
    ''');
  }

  static Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_comments (
        id TEXT PRIMARY KEY,
        book_number INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        word_number INTEGER NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_wc_ref
      ON word_comments(book_number, chapter, verse, word_number)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_markup (
        id TEXT PRIMARY KEY,
        book_number INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        word_number INTEGER,
        kind TEXT NOT NULL DEFAULT 'underlineSingle',
        color_index INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_wm_ref
      ON word_markup(book_number, chapter, verse)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        parent_id TEXT
      )
    ''');
    // Add folder_id column to notes table if it doesn't exist
    try {
      await db.execute('ALTER TABLE notes ADD COLUMN folder_id TEXT');
    } catch (_) {
      // Column already exists — ignore
    }
  }

  /// V4 – bidirectional cross‑references table + migration from parallel_verses
  static Future<void> _createV4Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cross_refs (
        id TEXT PRIMARY KEY,
        book_a INTEGER NOT NULL,
        chapter_a INTEGER NOT NULL,
        verse_a INTEGER NOT NULL,
        book_b INTEGER NOT NULL,
        chapter_b INTEGER NOT NULL,
        verse_b INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cr_a
      ON cross_refs(book_a, chapter_a, verse_a)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cr_b
      ON cross_refs(book_b, chapter_b, verse_b)
    ''');
    // Migrate data from parallel_verses (if it exists)
    try {
      final rows = await db.query('parallel_verses');
      for (final r in rows) {
        await db.insert(
            'cross_refs',
            {
              'id': r['id'],
              'book_a': r['source_book'],
              'chapter_a': r['source_chapter'],
              'verse_a': r['source_verse'],
              'book_b': r['target_book'],
              'chapter_b': r['target_chapter'],
              'verse_b': r['target_verse'],
              'created_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await db.execute('DROP TABLE IF EXISTS parallel_verses');
    } catch (_) {
      // parallel_verses table may not exist on fresh install
    }
  }

  /// V5 – add color_value column to word_markup for custom ARGB colours
  static Future<void> _createV5Tables(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE word_markup ADD COLUMN color_value INTEGER',
      );
    } catch (_) {
      // Column already exists — ignore
    }
  }

  /// V6 – tags and verse_tags tables
  static Future<void> _createV6Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        color_value INTEGER NOT NULL DEFAULT 4280391411
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS verse_tags (
        id TEXT PRIMARY KEY,
        tag_id TEXT NOT NULL,
        book_number INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_vt_ref
      ON verse_tags(book_number, chapter, verse)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_vt_tag
      ON verse_tags(tag_id)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_tags (
        note_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (note_id, tag_id),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');
  }

  /// V7 – add color_value column to note_folders for folder colors
  static Future<void> _createV7Tables(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE note_folders ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4282735204',
      );
    } catch (_) {
      // Column already exists — ignore
    }
  }

  // ── Notes CRUD ────────────────────────────────────────────────────────────

  Future<List<NoteModel>> getAllNotes() async {
    final rows = await _db!.query('notes', orderBy: 'updated_at DESC');
    return rows.map(NoteModel.fromMap).toList();
  }

  Future<NoteModel?> getNote(String id) async {
    final rows = await _db!.query('notes', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : NoteModel.fromMap(rows.first);
  }

  Future<NoteModel> createNote({String? templateId, String? folderId}) async {
    String content = '';
    if (templateId != null) {
      final tpl = await getTemplate(templateId);
      if (tpl != null) content = tpl.content;
    }
    final now = DateTime.now();
    final note = NoteModel(
      id: _uuid.v4(),
      title: '',
      content: content,
      templateId: templateId,
      folderId: folderId,
      createdAt: now,
      updatedAt: now,
    );
    await _db!.insert('notes', note.toMap());
    return note;
  }

  /// Create a note with specific title and content (for tag auto-notes).
  Future<NoteModel> createNoteWithContent({
    required String title,
    String content = '',
    String? folderId,
  }) async {
    final now = DateTime.now();
    final note = NoteModel(
      id: _uuid.v4(),
      title: title,
      content: content,
      folderId: folderId,
      createdAt: now,
      updatedAt: now,
    );
    await _db!.insert('notes', note.toMap());
    return note;
  }

  Future<void> updateNote(NoteModel note) async {
    await _db!
        .update('notes', note.toMap(), where: 'id=?', whereArgs: [note.id]);
  }

  Future<void> deleteNote(String id) async {
    await _db!.delete('notes', where: 'id=?', whereArgs: [id]);
    await _db!.delete('note_links',
        where: 'source_id=? OR target_id=?', whereArgs: [id, id]);
  }

  Future<List<NoteModel>> searchNotes(String query) async {
    final q = '%$query%';
    final rows = await _db!.query('notes',
        where: 'title LIKE ? OR content LIKE ?',
        whereArgs: [q, q],
        orderBy: 'updated_at DESC');
    return rows.map(NoteModel.fromMap).toList();
  }

  // ── Note links ────────────────────────────────────────────────────────────

  Future<void> setNoteLinks(String sourceId, List<String> targetIds) async {
    await _db!
        .delete('note_links', where: 'source_id=?', whereArgs: [sourceId]);
    for (final tid in targetIds) {
      await _db!.insert(
          'note_links',
          {
            'source_id': sourceId,
            'target_id': tid,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<NoteModel>> getLinkedNotes(String noteId) async {
    final rows = await _db!.rawQuery('''
      SELECT n.* FROM notes n
      INNER JOIN note_links l ON (l.target_id = n.id AND l.source_id = ?)
         OR (l.source_id = n.id AND l.target_id = ?)
      ORDER BY n.updated_at DESC
    ''', [noteId, noteId]);
    return rows.map(NoteModel.fromMap).toList();
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  Future<List<NoteTemplate>> getTemplates() async {
    final rows = await _db!.query('templates', orderBy: 'name');
    return rows.map(NoteTemplate.fromMap).toList();
  }

  Future<NoteTemplate?> getTemplate(String id) async {
    final rows = await _db!.query('templates', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : NoteTemplate.fromMap(rows.first);
  }

  Future<void> saveTemplate(NoteTemplate t) async {
    await _db!.insert('templates', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTemplate(String id) async {
    await _db!.delete('templates', where: 'id=?', whereArgs: [id]);
  }

  // ── Verse Comments ────────────────────────────────────────────────────────

  Future<List<VerseComment>> getVerseComments(
      int bookNumber, int chapter, int verse) async {
    final rows = await _db!.query('verse_comments',
        where: 'book_number=? AND chapter=? AND verse=?',
        whereArgs: [bookNumber, chapter, verse],
        orderBy: 'created_at DESC');
    return rows.map(VerseComment.fromMap).toList();
  }

  Future<VerseComment> addVerseComment(
      int bookNumber, int chapter, int verse, String text) async {
    final now = DateTime.now();
    final c = VerseComment(
      id: _uuid.v4(),
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      text: text,
      createdAt: now,
      updatedAt: now,
    );
    await _db!.insert('verse_comments', c.toMap());
    return c;
  }

  Future<void> updateVerseComment(VerseComment c) async {
    await _db!
        .update('verse_comments', c.toMap(), where: 'id=?', whereArgs: [c.id]);
  }

  Future<void> deleteVerseComment(String id) async {
    await _db!.delete('verse_comments', where: 'id=?', whereArgs: [id]);
  }

  /// Returns set of verse keys ("book:ch:v") that have at least one comment.
  Future<Set<String>> getCommentedVerseKeys(int bookNumber, int chapter) async {
    final rows = await _db!.query('verse_comments',
        columns: ['verse'],
        where: 'book_number=? AND chapter=?',
        whereArgs: [bookNumber, chapter],
        distinct: true);
    return rows.map((r) => '$bookNumber:$chapter:${r['verse']}').toSet();
  }

  /// Returns verse → comment count for the chapter.
  Future<Map<int, int>> getCommentCountsForChapter(
      int bookNumber, int chapter) async {
    final rows = await _db!.rawQuery(
        'SELECT verse, COUNT(*) as cnt FROM verse_comments '
        'WHERE book_number=? AND chapter=? GROUP BY verse',
        [bookNumber, chapter]);
    return {for (final r in rows) r['verse'] as int: r['cnt'] as int};
  }

  // ── Parallel (Cross‑Ref) Verses ────────────────────────────────────────────

  /// Get all cross‑refs for a verse.  Returns [ParallelVerse] objects where
  /// source = the queried verse and target = the other side, so the UI
  /// doesn't need to know about bidirectionality.
  Future<List<ParallelVerse>> getParallelVerses(
      int bookNumber, int chapter, int verse) async {
    final rows = await _db!.rawQuery(
      'SELECT * FROM cross_refs '
      'WHERE (book_a=? AND chapter_a=? AND verse_a=?) '
      '   OR (book_b=? AND chapter_b=? AND verse_b=?) '
      'ORDER BY book_a, chapter_a, verse_a, book_b, chapter_b, verse_b',
      [bookNumber, chapter, verse, bookNumber, chapter, verse],
    );
    return rows.map((r) {
      final isA = r['book_a'] == bookNumber &&
          r['chapter_a'] == chapter &&
          r['verse_a'] == verse;
      return ParallelVerse(
        id: r['id'] as String,
        sourceBook: bookNumber,
        sourceChapter: chapter,
        sourceVerse: verse,
        targetBook: (isA ? r['book_b'] : r['book_a']) as int,
        targetChapter: (isA ? r['chapter_b'] : r['chapter_a']) as int,
        targetVerse: (isA ? r['verse_b'] : r['verse_a']) as int,
      );
    }).toList();
  }

  /// Add a bidirectional cross‑reference.
  Future<ParallelVerse> addParallelVerse({
    required int sourceBook,
    required int sourceChapter,
    required int sourceVerse,
    required int targetBook,
    required int targetChapter,
    required int targetVerse,
  }) async {
    // Check for duplicate in either direction
    final existing = await _db!.rawQuery(
      'SELECT id FROM cross_refs WHERE '
      '  (book_a=? AND chapter_a=? AND verse_a=? AND book_b=? AND chapter_b=? AND verse_b=?) '
      '  OR '
      '  (book_a=? AND chapter_a=? AND verse_a=? AND book_b=? AND chapter_b=? AND verse_b=?)',
      [
        sourceBook,
        sourceChapter,
        sourceVerse,
        targetBook,
        targetChapter,
        targetVerse,
        targetBook,
        targetChapter,
        targetVerse,
        sourceBook,
        sourceChapter,
        sourceVerse,
      ],
    );
    if (existing.isNotEmpty) {
      // Already exists — return existing
      final row = (await _db!.query('cross_refs',
              where: 'id=?', whereArgs: [existing.first['id']]))
          .first;
      return ParallelVerse(
        id: row['id'] as String,
        sourceBook: sourceBook,
        sourceChapter: sourceChapter,
        sourceVerse: sourceVerse,
        targetBook: targetBook,
        targetChapter: targetChapter,
        targetVerse: targetVerse,
      );
    }
    final id = _uuid.v4();
    await _db!.insert('cross_refs', {
      'id': id,
      'book_a': sourceBook,
      'chapter_a': sourceChapter,
      'verse_a': sourceVerse,
      'book_b': targetBook,
      'chapter_b': targetChapter,
      'verse_b': targetVerse,
      'created_at': DateTime.now().toIso8601String(),
    });
    return ParallelVerse(
      id: id,
      sourceBook: sourceBook,
      sourceChapter: sourceChapter,
      sourceVerse: sourceVerse,
      targetBook: targetBook,
      targetChapter: targetChapter,
      targetVerse: targetVerse,
    );
  }

  Future<void> deleteParallelVerse(String id) async {
    await _db!.delete('cross_refs', where: 'id=?', whereArgs: [id]);
  }

  /// Returns set of verse keys that have at least one cross‑ref.
  Future<Set<String>> getParallelVerseKeys(int bookNumber, int chapter) async {
    final rowsA = await _db!.rawQuery(
        'SELECT DISTINCT verse_a AS v FROM cross_refs '
        'WHERE book_a=? AND chapter_a=?',
        [bookNumber, chapter]);
    final rowsB = await _db!.rawQuery(
        'SELECT DISTINCT verse_b AS v FROM cross_refs '
        'WHERE book_b=? AND chapter_b=?',
        [bookNumber, chapter]);
    final set = <String>{};
    for (final r in rowsA) {
      set.add('$bookNumber:$chapter:${r['v']}');
    }
    for (final r in rowsB) {
      set.add('$bookNumber:$chapter:${r['v']}');
    }
    return set;
  }

  /// Returns verse → cross‑ref count for the chapter (both directions).
  Future<Map<int, int>> getParallelCountsForChapter(
      int bookNumber, int chapter) async {
    final rowsA = await _db!.rawQuery(
        'SELECT verse_a AS v, COUNT(*) AS cnt FROM cross_refs '
        'WHERE book_a=? AND chapter_a=? GROUP BY verse_a',
        [bookNumber, chapter]);
    final rowsB = await _db!.rawQuery(
        'SELECT verse_b AS v, COUNT(*) AS cnt FROM cross_refs '
        'WHERE book_b=? AND chapter_b=? GROUP BY verse_b',
        [bookNumber, chapter]);
    final counts = <int, int>{};
    for (final r in rowsA) {
      final v = r['v'] as int;
      counts[v] = (counts[v] ?? 0) + (r['cnt'] as int);
    }
    for (final r in rowsB) {
      final v = r['v'] as int;
      counts[v] = (counts[v] ?? 0) + (r['cnt'] as int);
    }
    return counts;
  }

  // ── V3: Word Comments ─────────────────────────────────────────────────────

  Future<WordComment?> getWordComment(
      int bookNumber, int chapter, int verse, int wordNumber) async {
    final rows = await _db!.query('word_comments',
        where: 'book_number=? AND chapter=? AND verse=? AND word_number=?',
        whereArgs: [bookNumber, chapter, verse, wordNumber],
        limit: 1);
    return rows.isEmpty ? null : WordComment.fromMap(rows.first);
  }

  Future<Map<String, WordComment>> getWordCommentsForChapter(
      int bookNumber, int chapter) async {
    final rows = await _db!.query('word_comments',
        where: 'book_number=? AND chapter=?',
        whereArgs: [bookNumber, chapter],
        orderBy: 'verse, word_number');
    final list = rows.map(WordComment.fromMap).toList();
    return {for (final c in list) '${c.verse}:${c.wordNumber}': c};
  }

  Future<WordComment> addWordComment(int bookNumber, int chapter, int verse,
      int wordNumber, String text) async {
    final c = WordComment(
      id: _uuid.v4(),
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      wordNumber: wordNumber,
      text: text.length > 200 ? text.substring(0, 200) : text,
      createdAt: DateTime.now(),
    );
    await _db!.insert('word_comments', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return c;
  }

  Future<void> deleteWordComment(String id) async {
    await _db!.delete('word_comments', where: 'id=?', whereArgs: [id]);
  }

  // ── V3: Word / Verse Markup (underline, bg color) ─────────────────────────

  Future<List<WordMarkup>> getMarkupsForChapter(
      int bookNumber, int chapter) async {
    final rows = await _db!.query('word_markup',
        where: 'book_number=? AND chapter=?', whereArgs: [bookNumber, chapter]);
    return rows.map(WordMarkup.fromMap).toList();
  }

  Future<WordMarkup> addMarkup(WordMarkup m) async {
    await _db!.insert('word_markup', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return m;
  }

  Future<void> deleteMarkup(String id) async {
    await _db!.delete('word_markup', where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteMarkupsForVerse(
      int bookNumber, int chapter, int verse) async {
    await _db!.delete('word_markup',
        where: 'book_number=? AND chapter=? AND verse=?',
        whereArgs: [bookNumber, chapter, verse]);
  }

  // ── V3: Note Folders ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllFolders() async {
    return await _db!.query('note_folders', orderBy: 'name');
  }

  Future<String> createFolder(String name) async {
    final id = _uuid.v4();
    await _db!
        .insert('note_folders', {'id': id, 'name': name, 'parent_id': null});
    return id;
  }

  Future<void> renameFolder(String id, String name) async {
    await _db!
        .update('note_folders', {'name': name}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteFolder(String id) async {
    // Move notes in this folder to root
    await _db!.update('notes', {'folder_id': null},
        where: 'folder_id=?', whereArgs: [id]);
    await _db!.delete('note_folders', where: 'id=?', whereArgs: [id]);
  }

  Future<void> updateFolderColor(String id, int colorValue) async {
    await _db!.update('note_folders', {'color_value': colorValue},
        where: 'id=?', whereArgs: [id]);
  }

  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    await _db!.update('notes', {'folder_id': folderId},
        where: 'id=?', whereArgs: [noteId]);
  }

  Future<List<NoteModel>> getNotesInFolder(String? folderId) async {
    final rows = folderId == null
        ? await _db!.query('notes',
            where: 'folder_id IS NULL', orderBy: 'updated_at DESC')
        : await _db!.query('notes',
            where: 'folder_id=?',
            whereArgs: [folderId],
            orderBy: 'updated_at DESC');
    return rows.map(NoteModel.fromMap).toList();
  }

  void dispose() {
    _db?.close();
  }

  // ── Tags CRUD ─────────────────────────────────────────────────────────────

  Future<List<NoteTag>> getAllTags() async {
    final rows = await _db!.query('tags', orderBy: 'name');
    return rows.map(NoteTag.fromMap).toList();
  }

  Future<NoteTag> createTag(String name, {int colorValue = 0xFF2196F3}) async {
    final id = _uuid.v4();
    final tag = NoteTag(id: id, name: name, colorValue: colorValue);
    await _db!.insert('tags', tag.toMap());
    return tag;
  }

  Future<void> updateTag(NoteTag tag) async {
    await _db!.update('tags', tag.toMap(), where: 'id=?', whereArgs: [tag.id]);
  }

  Future<void> deleteTag(String id) async {
    await _db!.delete('tags', where: 'id=?', whereArgs: [id]);
  }

  // ── Note Tags (many-to-many) ──────────────────────────────────────────────

  Future<List<NoteTag>> getTagsForNote(String noteId) async {
    final rows = await _db!.rawQuery('''
      SELECT t.* FROM tags t
      INNER JOIN note_tags nt ON nt.tag_id = t.id
      WHERE nt.note_id = ?
      ORDER BY t.name
    ''', [noteId]);
    return rows.map(NoteTag.fromMap).toList();
  }

  /// Bulk-fetch all note→tags associations in one SQL query.
  /// Used by NotesProvider to build the sync cache efficiently.
  Future<Map<String, List<NoteTag>>> getAllNoteTagsMap() async {
    final rows = await _db!.rawQuery('''
      SELECT nt.note_id, t.id, t.name, t.color_value
      FROM note_tags nt
      JOIN tags t ON t.id = nt.tag_id
    ''');

    final result = <String, List<NoteTag>>{};
    for (final row in rows) {
      final noteId = row['note_id'] as String;
      final tag = NoteTag(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        colorValue: row['color_value'] as int? ?? 0xFF2196F3,
      );
      result.putIfAbsent(noteId, () => []).add(tag);
    }
    return result;
  }

  Future<void> addTagToNote(String noteId, String tagId) async {
    await _db!.insert('note_tags', {'note_id': noteId, 'tag_id': tagId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeTagFromNote(String noteId, String tagId) async {
    await _db!.delete('note_tags',
        where: 'note_id=? AND tag_id=?', whereArgs: [noteId, tagId]);
  }

  // ── Verse Tags ────────────────────────────────────────────────────────────

  Future<List<VerseTag>> getVerseTagsForChapter(
      int bookNumber, int chapter) async {
    final rows = await _db!.query('verse_tags',
        where: 'book_number=? AND chapter=?', whereArgs: [bookNumber, chapter]);
    return rows.map(VerseTag.fromMap).toList();
  }

  Future<List<VerseTag>> getVerseTagsForVerse(
      int bookNumber, int chapter, int verse) async {
    final rows = await _db!.query('verse_tags',
        where: 'book_number=? AND chapter=? AND verse=?',
        whereArgs: [bookNumber, chapter, verse]);
    return rows.map(VerseTag.fromMap).toList();
  }

  Future<VerseTag> addVerseTag({
    required String tagId,
    required int bookNumber,
    required int chapter,
    required int verse,
  }) async {
    final id = _uuid.v4();
    final vt = VerseTag(
      id: id,
      tagId: tagId,
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      createdAt: DateTime.now(),
    );
    await _db!.insert('verse_tags', vt.toMap());
    return vt;
  }

  Future<void> deleteVerseTag(String id) async {
    await _db!.delete('verse_tags', where: 'id=?', whereArgs: [id]);
  }

  /// Get all verses tagged with a specific tag
  Future<List<VerseTag>> getVersesForTag(String tagId) async {
    final rows = await _db!.query('verse_tags',
        where: 'tag_id=?',
        whereArgs: [tagId],
        orderBy: 'book_number, chapter, verse');
    return rows.map(VerseTag.fromMap).toList();
  }

  /// Get tag IDs present in a chapter (for indicators)
  Future<Map<int, List<String>>> getVerseTagIdsForChapter(
      int bookNumber, int chapter) async {
    final rows = await _db!.query('verse_tags',
        where: 'book_number=? AND chapter=?', whereArgs: [bookNumber, chapter]);
    final map = <int, List<String>>{};
    for (final r in rows) {
      final v = r['verse'] as int;
      (map[v] ??= []).add(r['tag_id'] as String);
    }
    return map;
  }
}
