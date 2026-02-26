// lib/db_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import "../models/models.dart";

// ── Greek diacritics normalizer ───────────────────────────────────────────────
/// Strips all Greek diacritics (accents, breathings, iota subscript) and
/// lowercases.  Works with both NFC (precomposed) and NFD (decomposed) input.
String normalizeGreek(String s) {
  final buf = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_dMap[ch] ?? ch);
  }
  // Strip any remaining Unicode combining marks (handles NFD input).
  return buf.toString().toLowerCase().replaceAll(
      RegExp('[\u0300-\u036f\u1dc0-\u1dff\u20d0-\u20ff\ufe20-\ufe2f]'),
      '');
}

final Map<String, String> _dMap = () {
  final m = <String, String>{};
  void add(List<String> chars, String base) { for (final c in chars) {
    m[c] = base;
  } }
  add(['ά','ά','ἀ','ἁ','ἂ','ἃ','ἄ','ἅ','ἆ','ἇ','ᾀ','ᾁ','ᾂ','ᾃ','ᾄ','ᾅ','ᾆ','ᾇ',
       'ᾰ','ᾱ','ᾲ','ᾳ','ᾴ','ᾶ','ᾷ','Ά','Ά','Ἀ','Ἁ','Ἂ','Ἃ','Ἄ','Ἅ','Ἆ','Ἇ',
       'ᾈ','ᾉ','ᾊ','ᾋ','ᾌ','ᾍ','ᾎ','ᾏ','Ᾰ','Ᾱ','Ὰ','Ά','ᾼ','α','Α'], 'α');
  add(['έ','έ','ἐ','ἑ','ἒ','ἓ','ἔ','ἕ','Έ','Έ','Ἐ','Ἑ','Ἒ','Ἓ','Ἔ','Ἕ','Ὲ','Έ','ε','Ε'], 'ε');
  add(['ή','ή','ἠ','ἡ','ἢ','ἣ','ἤ','ἥ','ἦ','ἧ','ᾐ','ᾑ','ᾒ','ᾓ','ᾔ','ᾕ','ᾖ','ᾗ',
       'ῂ','ῃ','ῄ','ῆ','ῇ','Ή','Ή','Ἠ','Ἡ','Ἢ','Ἣ','Ἤ','Ἥ','Ἦ','Ἧ','ᾘ','ᾙ',
       'ᾚ','ᾛ','ᾜ','ᾝ','ᾞ','ᾟ','Ὴ','Ή','ῌ','η','Η'], 'η');
  add(['ί','ί','ἰ','ἱ','ἲ','ἳ','ἴ','ἵ','ἶ','ἷ','ῐ','ῑ','ῒ','ΐ','ῖ','ῗ',
       'Ί','Ί','Ἰ','Ἱ','Ἲ','Ἳ','Ἴ','Ἵ','Ἶ','Ἷ','Ῐ','Ῑ','Ὶ','Ί','ι','Ι'], 'ι');
  add(['ό','ό','ὀ','ὁ','ὂ','ὃ','ὄ','ὅ','Ό','Ό','Ὀ','Ὁ','Ὂ','Ὃ','Ὄ','Ὅ','Ὸ','Ό','ο','Ο'], 'ο');
  add(['ύ','ύ','ὐ','ὑ','ὒ','ὓ','ὔ','ὕ','ὖ','ὗ','ῠ','ῡ','ῢ','ΰ','ῦ','ῧ',
       'Ύ','Ύ','Ὑ','Ὓ','Ὕ','Ὗ','Ῠ','Ῡ','Ὺ','Ύ','υ','Υ'], 'υ');
  add(['ώ','ώ','ὠ','ὡ','ὢ','ὣ','ὤ','ὥ','ὦ','ὧ','ᾠ','ᾡ','ᾢ','ᾣ','ᾤ','ᾥ','ᾦ','ᾧ',
       'ῲ','ῳ','ῴ','ῶ','ῷ','Ώ','Ώ','Ὠ','Ὡ','Ὢ','Ὣ','Ὤ','Ὥ','Ὦ','Ὧ','ᾨ','ᾩ',
       'ᾪ','ᾫ','ᾬ','ᾭ','ᾮ','ᾯ','Ὼ','Ώ','ῼ','ω','Ω'], 'ω');
  add(['ῤ','ῥ','Ῥ','ρ','Ρ'], 'ρ');
  add(['β','Β'], 'β'); add(['γ','Γ'], 'γ'); add(['δ','Δ'], 'δ');
  add(['ζ','Ζ'], 'ζ'); add(['θ','Θ'], 'θ'); add(['κ','Κ'], 'κ');
  add(['λ','Λ'], 'λ'); add(['μ','Μ'], 'μ'); add(['ν','Ν'], 'ν');
  add(['ξ','Ξ'], 'ξ'); add(['π','Π'], 'π'); add(['σ','ς','Σ'], 'σ');
  add(['τ','Τ'], 'τ'); add(['φ','Φ'], 'φ'); add(['χ','Χ'], 'χ');
  add(['ψ','Ψ'], 'ψ');
  return m;
}();

// ─────────────────────────────────────────────────────────────────────────────
class DBService {
  static const _bibleAsset  = 'assets/LXX_BYZ_WORDS_ONLY.SQLite3';

  // ── Словари ───────────────────────────────────────────────────────────────
  // Ключи совпадают с DictionaryMeta.id в DictionaryService
  static const Map<String, String> _dictAssets = {
    'strongs' : 'assets/СтрДв.dictionary.SQLite3',
    'tdnt'    : 'assets/TDNT.dictionary 2.SQLite3',
    'cbtel'   : 'assets/CBTEL.dictionary.SQLite3',
    'bdag3'   : 'assets/BDAG3.dictionary.SQLite3',
    'morph'   : 'assets/gr-en.dictionary.SQLite3',
    'dvor'    : 'assets/DvorFull.sqlite3',
    'lsj'     : 'assets/LSJ.dictionary.SQLite3',
    'cambridge': 'assets/Cambridge.sqlite3',
  };
  static const Map<String, String> _dictFiles = {
    'strongs' : 'dict_strongs.db',
    'tdnt'    : 'dict_tdnt.db',
    'cbtel'   : 'dict_cbtel.db',
    'bdag3'   : 'dict_bdag3.db',
    'morph'   : 'dict_morph_gr_en.db',
    'dvor'    : 'dict_dvor.db',
    'lsj'     : 'dict_lsj.db',
    'cambridge': 'dict_cambridge.db',
  };

  Database? _bibleDb;
  /// Основной словарь Стронга (для getWordDetail / getMorphologyText)
  Database? get _strongsDb => _dictDbs['strongs'];
  final Map<String, Database> _dictDbs = {};
  Database? _indexDb;
  // Removed in-memory _morphTopicNormIndex / _lsjTopicNormIndex — using SQL topic_norm column.

  /// Cached list of books (lazy, loaded on first getBooks() call).
  List<BookModel>? _books;

  /// Custom base directory for all databases (Android SD‑card support).
  /// When `null` the default `getDatabasesPath()` is used.
  String? _basePath;

  /// Все открытые словарные базы (для DictionaryService)
  Map<String, Database> get dictDbs => Map.unmodifiable(_dictDbs);

  /// Resolve the actual directory where DB files live.
  Future<String> _dbDir() async => _basePath ?? await getDatabasesPath();

  Future<void> init({String? basePath}) async {
    _basePath = basePath;
    // Make sure the directory exists (important for external storage)
    if (_basePath != null) {
      final dir = Directory(_basePath!);
      if (!dir.existsSync()) dir.createSync(recursive: true);
    }
    _bibleDb = await _openReadOnly(_bibleAsset, 'bible.db');
    for (final entry in _dictAssets.entries) {
      try {
        _dictDbs[entry.key] =
            await _openDictionaryDb(entry.value, _dictFiles[entry.key]!);
      } catch (e) {
        debugPrint('DBService: не удалось открыть словарь ${entry.key}: $e');
      }
    }
  }

  Future<Database> _openReadOnly(String asset, String filename) async {
    final path = join(await _dbDir(), filename);
    if (!File(path).existsSync()) {
      await _extractAssetToFile(asset, path);
    }
    return openDatabase(path, readOnly: true);
  }

  Future<Database> _openDictionaryDb(String asset, String filename) async {
    final path = join(await _dbDir(), filename);
    if (!File(path).existsSync()) {
      await _extractAssetToFile(asset, path);
    }
    final db = await openDatabase(path);
    // Ensure topic index exists (DvorFull, Cambridge etc. ship without one)
    await _ensureTopicIndex(db);
    return db;
  }

  /// Extracts an asset to [targetPath], trying compressed (.gz) first,
  /// then falling back to the uncompressed original.
  /// Uses streaming gzip decompression to keep memory usage low.
  /// Atomic write: .tmp → rename.
  Future<void> _extractAssetToFile(String asset, String targetPath) async {
    final tmpPath = '$targetPath.tmp';
    final tmpFile = File(tmpPath);
    if (tmpFile.existsSync()) tmpFile.deleteSync();

    Uint8List bytes;
    bool isCompressed = false;

    // Try compressed (.gz) asset first
    try {
      final data = await rootBundle.load('$asset.gz');
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      isCompressed = true;
    } catch (_) {
      // Fallback: load uncompressed original
      final data = await rootBundle.load(asset);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }

    if (isCompressed) {
      // Streaming gzip decompression — memory ≈ compressed size + buffer
      final output = File(tmpPath).openWrite();
      await Stream<List<int>>.value(bytes)
          .transform(gzip.decoder)
          .pipe(output);
    } else {
      await File(tmpPath).writeAsBytes(bytes, flush: true);
    }

    File(tmpPath).renameSync(targetPath);
  }

  /// Creates an index on dictionary.topic if none exists yet.
  /// Also creates a `topic_norm` column + index for normalized Greek lookups.
  Future<void> _ensureTopicIndex(Database db) async {
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='dictionary'",
      );
      if (tables.isEmpty) return;

      // ── 1. Ensure topic index ──
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND tbl_name='dictionary' AND sql IS NOT NULL",
      );
      bool hasTopicIdx = false;
      for (final idx in indexes) {
        final name = idx['name'] as String? ?? '';
        if (name.contains('topic')) { hasTopicIdx = true; break; }
        final info = await db.rawQuery("PRAGMA index_info('$name')");
        for (final col in info) {
          if ((col['name'] as String?) == 'topic') { hasTopicIdx = true; break; }
        }
        if (hasTopicIdx) break;
      }
      if (!hasTopicIdx) {
        final autoIdx = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND tbl_name='dictionary' AND name LIKE 'sqlite_autoindex_%'",
        );
        if (autoIdx.isNotEmpty) hasTopicIdx = true;
      }
      if (!hasTopicIdx) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_dictionary_topic ON dictionary(topic)',
        );
      }

      // ── 2. Ensure topic_norm column + index for normalized Greek lookups ──
      final cols = await db.rawQuery("PRAGMA table_info('dictionary')");
      final hasNorm = cols.any((c) => c['name'] == 'topic_norm');
      if (!hasNorm) {
        await db.execute('ALTER TABLE dictionary ADD COLUMN topic_norm TEXT');
        // Populate in Dart (normalizeGreek is Dart-side only)
        final rows = await db.rawQuery('SELECT rowid, topic FROM dictionary');
        final batch = db.batch();
        for (final row in rows) {
          final topic = (row['topic'] as String? ?? '').trim();
          if (topic.isEmpty) continue;
          batch.rawUpdate(
            'UPDATE dictionary SET topic_norm = ? WHERE rowid = ?',
            [normalizeGreek(topic), row['rowid']],
          );
        }
        await batch.commit(noResult: true);
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_dictionary_topic_norm ON dictionary(topic_norm)',
        );
        debugPrint('DBService: built topic_norm column on ${db.path}');
      }
    } catch (e) {
      debugPrint('DBService: _ensureTopicIndex error: $e');
    }
  }

  // ── Books ──────────────────────────────────────────────────────────────────
  Future<List<BookModel>> getBooks() async {
    if (_books != null) return _books!;
    final rows = await _bibleDb!.rawQuery(
        'SELECT book_number, short_name FROM books ORDER BY book_number');
    _books = rows.map(BookModel.fromMap).toList();
    return _books!;
  }

  // ── All words of a book ────────────────────────────────────────────────────
  Future<List<WordModel>> getWords(int bookNumber) async {
    final rows = await _bibleDb!.rawQuery(
        'SELECT chapter, verse, word_number, word, strongs, morphology '
        'FROM words WHERE book_number=? ORDER BY chapter, verse, word_number',
        [bookNumber]);
    return rows.map(WordModel.fromMap).toList();
  }

  // ── Words for a range of chapters (inclusive) ─────────────────────────────
  Future<List<WordModel>> getChaptersRange(
      int bookNumber, int fromChapter, int toChapter) async {
    final rows = await _bibleDb!.rawQuery(
        'SELECT chapter, verse, word_number, word, strongs, morphology '
        'FROM words WHERE book_number=? AND chapter>=? AND chapter<=? '
        'ORDER BY chapter, verse, word_number',
        [bookNumber, fromChapter, toChapter]);
    return rows.map(WordModel.fromMap).toList();
  }

  // ── Chapter / verse counts ─────────────────────────────────────────────────
  /// Returns sorted list of all chapter numbers for the given book.
  Future<List<int>> getBookChapters(int bookNumber) async {
    final rows = await _bibleDb!.rawQuery(
        'SELECT DISTINCT chapter FROM words WHERE book_number=? ORDER BY chapter',
        [bookNumber]);
    return rows.map((r) => r['chapter'] as int).toList();
  }

  Future<int> getChapterCount(int bookNumber) async {
    final rows = await _bibleDb!.rawQuery(
        'SELECT MAX(chapter) AS cnt FROM words WHERE book_number=?',
        [bookNumber]);
    return (rows.first['cnt'] as int?) ?? 1;
  }

  Future<int> getVerseCount(int bookNumber, int chapter) async {
    final rows = await _bibleDb!.rawQuery(
        'SELECT MAX(verse) AS cnt FROM words WHERE book_number=? AND chapter=?',
        [bookNumber, chapter]);
    return (rows.first['cnt'] as int?) ?? 1;
  }

  // ── Words of one verse ─────────────────────────────────────────────────────
  Future<List<WordModel>> getVerseWords(int book, int ch, int v) async {
    final rows = await _bibleDb!.rawQuery(
        'SELECT chapter, verse, word_number, word, strongs, morphology '
        'FROM words WHERE book_number=? AND chapter=? AND verse=? ORDER BY word_number',
        [book, ch, v]);
    return rows.map(WordModel.fromMap).toList();
  }

  /// Batch-load words for multiple verses at once (single SQL query).
  /// Returns a map keyed by `book:chapter:verse` → `List<WordModel>`.
  Future<Map<String, List<WordModel>>> getVerseWordsBatch(
      List<({int book, int chapter, int verse})> refs) async {
    if (refs.isEmpty) return {};
    // Build WHERE clause: (book_number=? AND chapter=? AND verse=?) OR ...
    final clauses = <String>[];
    final args = <Object>[];
    for (final r in refs) {
      clauses.add('(book_number=? AND chapter=? AND verse=?)');
      args.addAll([r.book, r.chapter, r.verse]);
    }
    final rows = await _bibleDb!.rawQuery(
        'SELECT book_number, chapter, verse, word_number, word, strongs, morphology '
        'FROM words WHERE ${clauses.join(' OR ')} '
        'ORDER BY book_number, chapter, verse, word_number',
        args);
    final result = <String, List<WordModel>>{};
    for (final row in rows) {
      final key = '${row['book_number']}:${row['chapter']}:${row['verse']}';
      (result[key] ??= []).add(WordModel.fromMap(row));
    }
    return result;
  }

  // ── Group flat word list into VerseModel list ─────────────────────────────
  /// Words are expected to be pre-sorted by (chapter, verse) from the DB query.
  List<VerseModel> groupIntoVerses(List<WordModel> words) {
    final map = <String, VerseModel>{};
    for (final w in words) {
      final k = '${w.chapter}_${w.verse}';
      if (!map.containsKey(k)) {
        map[k] = VerseModel(chapter: w.chapter, verse: w.verse, words: []);
      }
      (map[k]!.words).add(w);
    }
    // Map preserves insertion order (LinkedHashMap), data is pre-sorted by DB.
    return map.values.toList();
  }

  // ── Strong's definition ────────────────────────────────────────────────────
  Future<String?> getStrongsDefinition(String strongs) async {
    final clean = strongs.replaceAll(RegExp(r'^[A-Za-z]+'), '');
    final rows  = await _strongsDb!.rawQuery(
        'SELECT definition FROM dictionary WHERE topic=? LIMIT 1', ['G$clean']);
    return rows.isEmpty ? null : rows.first['definition'] as String?;
  }

  // ── Morphology ─────────────────────────────────────────────────────────────
  Future<String> getMorphologyText(String morphology) async {
    final db      = _strongsDb!;
    final results = <String>[];

    Future<String?> lookup(String code) async {
      final rows = await db.rawQuery(
          'SELECT meaning FROM morphology_indications WHERE indication=? LIMIT 1',
          [code]);
      return rows.isEmpty ? null : rows.first['meaning'] as String?;
    }

    final full = await lookup(morphology);
    if (full != null) return full;

    final rawParts = morphology.split('-');
    int segIdx = 0;
    for (final seg in rawParts) {
      if (seg.isEmpty) continue;
      final ind = segIdx == 0 ? seg : '-$seg';
      segIdx++;

      final m = await lookup(ind);
      if (m != null && m.isNotEmpty) { results.add(m); continue; }

      if (seg.length > 1) {
        bool found = false;
        for (int len = 1; len < seg.length && !found; len++) {
          final sub = segIdx == 1 ? seg.substring(0, len) : '-${seg.substring(0, len)}';
          final sm  = await lookup(sub);
          if (sm != null && sm.isNotEmpty) { results.add(sm); found = true; }
        }
        if (!found && seg.length >= 2) {
          final suf = '-${seg.substring(seg.length - 2)}';
          final sm  = await lookup(suf);
          if (sm != null && sm.isNotEmpty) results.add(sm);
        }
      }
    }
    return results.isEmpty ? morphology : results.join(', ');
  }

  // ── Word detail ────────────────────────────────────────────────────────────
  Future<WordDetail> getWordDetail(WordModel word) async {
    final morph = (word.morphology?.isNotEmpty ?? false)
        ? await getMorphologyText(word.morphology!) : '';

    String  def    = '<p>Нет данных</p>';
    String? lexeme;
    final lookupTerms = <String>[];

    if (word.strongs?.isNotEmpty ?? false) {
      final clean = word.strongs!.replaceAll(RegExp(r'^[A-Za-z]+'), '');
      final rows  = await _strongsDb!.rawQuery(
          'SELECT definition, lexeme FROM dictionary WHERE topic=? LIMIT 1',
          ['G$clean']);
      if (rows.isNotEmpty) {
        def    = rows.first['definition'] as String? ?? def;
        lexeme = rows.first['lexeme']     as String?;
        if (lexeme != null && lexeme.isEmpty) lexeme = null;
        if (lexeme != null) {
          lookupTerms.add(lexeme);
        }
      }
    }

    final noStrongs = !(word.strongs?.trim().isNotEmpty ?? false);
    final noData = RegExp(r'нет\s+данных', caseSensitive: false).hasMatch(def);
    if (noStrongs || noData) {
      final morphRows = await _lookupMorphologyRows(word.word);
      if (morphRows.isNotEmpty) {
        def = morphRows.first['definition'] as String? ?? def;
        for (final row in morphRows) {
          final topic = (row['topic'] as String? ?? '').trim();
          if (topic.isNotEmpty) {
            lookupTerms.add(topic);
          }

          final html = row['definition'] as String? ?? '';
          final extracted = _extractMorphLemmas(html);
          if (extracted.isNotEmpty) {
            lookupTerms.addAll(extracted);
          }
        }
      }
    }

    if (lookupTerms.isEmpty && word.word.trim().isNotEmpty) {
      lookupTerms.add(word.word.trim());
    }

    // Linkify morphology text to make words clickable
    final morphologyHtml = morph.isEmpty ? null : _linkifyMorphologyText(morph);

    return WordDetail(
      morphologyText: morph,
      morphologyHtml: morphologyHtml,
      definitionHtml: def,
      lexeme: lexeme,
      lookupTerms: lookupTerms.toSet().toList(),
    );
  }

  // Convert morphology text (like "Present Tense, 3rd Person Singular") to HTML
  // with clickable words that search across dictionaries
  String _linkifyMorphologyText(String text) {
    // Match words (English or Greek)
    final wordPattern = RegExp(r'[A-Za-z][A-Za-z\-]*|[α-ωάέήίόύώΐΰ]+', unicode: true);
    return text.replaceAllMapped(wordPattern, (match) {
      final word = match.group(0) ?? '';
      if (word.isEmpty) return '';
      final encoded = Uri.encodeComponent(word);
      return '<a href="lookup:$encoded">$word</a>';
    });
  }

  Future<List<Map<String, dynamic>>> _lookupMorphologyRows(String sourceWord) async {
    final db = _dictDbs['morph'];
    if (db == null) return const [];
    final word = sourceWord.trim();
    if (word.isEmpty) return const [];

    final exact = await db.rawQuery(
      'SELECT topic, definition FROM dictionary WHERE topic = ? LIMIT 5',
      [word],
    );
    if (exact.isNotEmpty) return exact;

    // Use indexed topic_norm column instead of in-memory map
    final norm = normalizeGreek(word);
    return db.rawQuery(
      'SELECT topic, definition FROM dictionary WHERE topic_norm = ? LIMIT 10',
      [norm],
    );
  }

  List<String> _extractMorphLemmas(String html) {
    final out = <String>[];
    final boldFollow = RegExp(r'<b>[^<]+</b>\s*([^<\s]+)', caseSensitive: false);
    for (final match in boldFollow.allMatches(html)) {
      final lemma = (match.group(1) ?? '').trim();
      if (lemma.isNotEmpty) out.add(lemma);
    }
    return out.toSet().toList();
  }

  // ── Morphology picker ──────────────────────────────────────────────────────
  Future<List<MorphEntry>> getFirstLevelMorphCodes() async {
    final rows = await _strongsDb!.rawQuery(
        "SELECT indication, meaning FROM morphology_indications "
        "WHERE indication NOT LIKE '-%' ORDER BY indication");
    return rows.map((r) => MorphEntry(
        indication: r['indication'] as String,
        meaning: r['meaning'] as String? ?? '')).toList();
  }

  Future<List<MorphEntry>> getSecondLevelMorphCodes() async {
    final rows = await _strongsDb!.rawQuery(
        "SELECT indication, meaning FROM morphology_indications "
        "WHERE indication LIKE '-%' ORDER BY indication");
    return rows.map((r) => MorphEntry(
        indication: r['indication'] as String,
        meaning: r['meaning'] as String? ?? '')).toList();
  }

  // ── FTS index ──────────────────────────────────────────────────────────────

  /// Whether index is currently being built (prevents concurrent builds and
  /// lets search methods return early instead of querying a half-ready DB).
  bool _isBuilding = false;

  /// Check whether the search index file physically exists and is non-empty.
  /// Used by AppState to detect stale prefs (prefs say "built" but file is
  /// missing, e.g. after partial data clear).
  Future<bool> indexFileExists() async {
    final path = join(await _dbDir(), 'search_index.db');
    final f = File(path);
    return f.existsSync() && f.lengthSync() > 0;
  }

  /// Close and delete the current search index file so a fresh build starts
  /// from scratch.
  Future<void> deleteIndex() async {
    if (_indexDb != null) {
      try { await _indexDb!.close(); } catch (_) {}
      _indexDb = null;
    }
    final dir  = await _dbDir();
    final path = join(dir, 'search_index.db');
    final tmp  = join(dir, 'search_index.tmp.db');
    if (File(path).existsSync()) await File(path).delete();
    if (File(tmp).existsSync())  await File(tmp).delete();
  }

  Future<void> buildIndex({void Function(double)? onProgress}) async {
    if (_bibleDb == null) {
      throw StateError('buildIndex: _bibleDb is null — call init() first');
    }
    _isBuilding = true;
    Database? tmpDb;
    try {
      final dir  = await _dbDir();
      final path = join(dir, 'search_index.db');
      final tmp  = join(dir, 'search_index.tmp.db');

      debugPrint('buildIndex: dir=$dir');

      // Build into a temporary file so that _ensureIndex never opens a
      // half-built database.
      if (File(tmp).existsSync()) await File(tmp).delete();
      if (File(path).existsSync()) await File(path).delete();

      tmpDb = await openDatabase(tmp, version: 1, onCreate: (db, _) async {
        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS words_fts
          USING fts4(book_number, chapter, verse,
                     word, word_norm, strongs, morphology)''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS books_cache(
            book_number INTEGER PRIMARY KEY, short_name TEXT)''');
      });

      // ── PRAGMA optimizations (best-effort, non-fatal) ──
      for (final pragma in [
        'PRAGMA synchronous = OFF',
        'PRAGMA journal_mode = MEMORY',
        'PRAGMA cache_size = -50000',
      ]) {
        try { await tmpDb.execute(pragma); } catch (_) {}
      }

      // Cache book names
      final books = await getBooks();
      debugPrint('buildIndex: ${books.length} books');
      final bb = tmpDb.batch();
      for (final b in books) {
        bb.insert('books_cache',
            {'book_number': b.bookNumber, 'short_name': b.shortName});
      }
      await bb.commit(noResult: true);

      // Load all words once
      final words = await _bibleDb!.rawQuery(
          'SELECT book_number, chapter, verse, word, strongs, morphology FROM words');
      final total = words.length;
      debugPrint('buildIndex: $total words to index');

      if (total == 0) {
        await tmpDb.close();
        tmpDb = null;
        if (File(tmp).existsSync()) await File(tmp).delete();
        throw StateError(
            'buildIndex: words table is empty — bible database may be corrupted');
      }

      // Pre-normalize all words in a background isolate (CPU-intensive)
      final rawWords = words.map((w) => w['word'] as String? ?? '').toList();
      final normalizedWords = await compute(_batchNormalizeGreek, rawWords);

      // Insert in larger chunks (5000 instead of 2000) for fewer transactions
      const chunk = 5000;

      for (int start = 0; start < total; start += chunk) {
        final end   = (start + chunk).clamp(0, total);
        final batch = tmpDb.batch();
        for (int i = start; i < end; i++) {
          final w  = words[i];
          final ws = w['word'] as String? ?? '';
          batch.rawInsert(
              'INSERT INTO words_fts'
              '(book_number,chapter,verse,word,word_norm,strongs,morphology)'
              ' VALUES(?,?,?,?,?,?,?)',
              [w['book_number'], w['chapter'], w['verse'],
               ws, normalizedWords[i], w['strongs'], w['morphology']]);
        }
        await batch.commit(noResult: true);
        onProgress?.call(end / total);
      }

      // Optimize the FTS index for faster queries
      try {
        await tmpDb.execute("INSERT INTO words_fts(words_fts) VALUES('optimize')");
      } catch (_) {}

      // Verify the index has actual content
      final count = Sqflite.firstIntValue(
          await tmpDb.rawQuery('SELECT COUNT(*) FROM words_fts'));
      debugPrint('buildIndex: FTS has $count rows');

      await tmpDb.close();
      tmpDb = null;

      // Atomic swap: close old handle, replace file, reopen.
      if (_indexDb != null) {
        await _indexDb!.close();
        _indexDb = null;
      }
      if (File(path).existsSync()) await File(path).delete();
      await File(tmp).rename(path);

      final fileSize = File(path).lengthSync();
      debugPrint('buildIndex: index file = $fileSize bytes');

      _indexDb = await openDatabase(path, readOnly: true);
      debugPrint('buildIndex: ✓ done');
    } catch (e) {
      debugPrint('buildIndex error: $e');
      // Close tmpDb if it was opened but not yet closed
      try { await tmpDb?.close(); } catch (_) {}
      rethrow;
    } finally {
      _isBuilding = false;
    }
  }

  /// Top-level function for compute() — normalizes Greek words in a separate
  /// isolate to avoid blocking the UI thread.
  static List<String> _batchNormalizeGreek(List<String> words) {
    return words.map(normalizeGreek).toList();
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  Future<List<SearchResult>> searchByWord(String query) async {
    if (!await _ensureIndex()) return [];
    final norm = normalizeGreek(query.trim());
    if (norm.isEmpty) return [];
    return _likeFallback('word_norm', norm);
  }

  Future<List<SearchResult>> searchMultiTerm(List<SearchTerm> terms) async {
    if (!await _ensureIndex()) return [];
    if (terms.isEmpty) return [];

    // Step 1: For each term, find matching verse keys independently.
    Set<String>? intersection;
    for (final t in terms) {
      List<Map<String, dynamic>> rows;
      if (t.type == SearchTermType.strongs) {
        final clean = t.value.replaceAll(RegExp(r'^[GgА-Яа-я]+'), '');
        try {
          rows = await _indexDb!.rawQuery(
            'SELECT DISTINCT book_number, chapter, verse FROM words_fts WHERE strongs MATCH ?',
            [clean]);
        } catch (_) {
          rows = await _indexDb!.rawQuery(
            'SELECT DISTINCT book_number, chapter, verse FROM words_fts WHERE strongs = ?',
            [clean]);
        }
      } else {
        final norm = normalizeGreek(t.value);
        rows = await _indexDb!.rawQuery(
          'SELECT DISTINCT book_number, chapter, verse FROM words_fts WHERE word_norm LIKE ?',
          ['%$norm%']);
      }
      final keys = rows.map((r) => '${r['book_number']}:${r['chapter']}:${r['verse']}').toSet();
      intersection = intersection == null ? keys : intersection.intersection(keys);
      if (intersection.isEmpty) return []; // early exit
    }
    if (intersection == null || intersection.isEmpty) return [];

    // Step 2: Fetch full rows for the intersected verses (limit 300).
    final limited = intersection.take(300).toList();
    final placeholders = <String>[];
    final args = <dynamic>[];
    for (final key in limited) {
      final parts = key.split(':');
      placeholders.add('(book_number=? AND chapter=? AND verse=?)');
      args.addAll([int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])]);
    }
    final sql = '''
      SELECT book_number, chapter, verse, word, strongs, morphology
      FROM words_fts
      WHERE ${placeholders.join(' OR ')}
      LIMIT 300
    ''';

    try {
      final rows = await _indexDb!.rawQuery(sql, args);
      return _mapWithBookNames(rows);
    } catch (_) {
      return [];
    }
  }

  Future<List<SearchResult>> searchByStrongs(String s) async {
    if (!await _ensureIndex()) return [];
    final clean = s.trim().replaceAll(RegExp(r'^[GgА-Яа-я]+'), '');
    if (clean.isEmpty) return [];

    List<Map<String, dynamic>> rows = [];

    // Try FTS MATCH first (fast)
    try {
      rows = await _indexDb!.rawQuery(
        'SELECT book_number, chapter, verse, word, strongs, morphology '
        'FROM words_fts WHERE strongs MATCH ? LIMIT 300', [clean]);
    } catch (_) {}

    // Fallback: exact match via full scan (no JOIN – fast on FTS)
    if (rows.isEmpty) {
      try {
        rows = await _indexDb!.rawQuery(
          'SELECT book_number, chapter, verse, word, strongs, morphology '
          'FROM words_fts WHERE strongs = ? LIMIT 300', [clean]);
      } catch (_) {}
    }

    if (rows.isEmpty) return [];

    // Batch-lookup book short names
    return _mapWithBookNames(rows);
  }

  Future<List<SearchResult>> searchByMorphology(String morph) async {
    if (!await _ensureIndex()) return [];
    try {
      final rows = await _indexDb!.rawQuery(
        'SELECT book_number, chapter, verse, word, strongs, morphology '
        'FROM words_fts WHERE morphology MATCH ? LIMIT 300', [morph.trim()]);
      return _mapWithBookNames(rows);
    } catch (_) {
      return _likeFallback('morphology', morph.trim());
    }
  }

  Future<List<SearchResult>> _likeFallback(String col, String q) async {
    if (!await _ensureIndex()) return [];
    try {
      final rows = await _indexDb!.rawQuery(
        'SELECT book_number, chapter, verse, word, strongs, morphology '
        'FROM words_fts WHERE $col LIKE ? LIMIT 300', ['%$q%']);
      return _mapWithBookNames(rows);
    } catch (_) {
      return [];
    }
  }

  /// Maps FTS rows (without short_name) to SearchResult, batch-looking up book names.
  Future<List<SearchResult>> _mapWithBookNames(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final bookIds = rows.map((r) => r['book_number']).toSet().toList();
    final bookRows = await _indexDb!.rawQuery(
      'SELECT book_number, short_name FROM books_cache '
      'WHERE book_number IN (${bookIds.join(",")})');
    final bookNames = {for (final b in bookRows) b['book_number'] as int: b['short_name'] as String};
    return rows.map((r) {
      final bn = r['book_number'] as int;
      return SearchResult(
        bookNumber:    bn,
        bookShortName: bookNames[bn] ?? '',
        chapter:       r['chapter'] as int,
        verse:         r['verse'] as int,
        word:          r['word'] as String? ?? '',
        strongs:       r['strongs'] as String?,
        morphology:    r['morphology'] as String?,
      );
    }).toList();
  }

  /// Returns `true` when a usable search index is available.
  /// Returns `false` (without throwing) when the index is still building
  /// or the database file is missing / corrupt.
  Future<bool> _ensureIndex() async {
    if (_indexDb != null) return true;
    if (_isBuilding) return false;        // build in progress — don't open partial DB
    final path = join(await _dbDir(), 'search_index.db');
    if (!File(path).existsSync() || File(path).lengthSync() == 0) return false;
    try {
      _indexDb = await openDatabase(path, readOnly: true);
      // Verify the required table exists.
      final tables = await _indexDb!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='words_fts'");
      if (tables.isEmpty) {
        await _indexDb!.close();
        _indexDb = null;
        return false;
      }
      return true;
    } catch (_) {
      _indexDb = null;
      return false;
    }
  }

  void dispose() {
    _bibleDb?.close();
    for (final db in _dictDbs.values) { db.close(); }
    _indexDb?.close();
  }
}
