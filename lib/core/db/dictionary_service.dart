// lib/core/db/dictionary_service.dart
//
// Читает данные из любого из четырёх словарных SQLite-файлов.
// Каждый словарь идентифицируется строковым id (совпадает с DictionaryMeta.id
// и ключами в DBService.dictDbs).
//
// Все четыре базы имеют таблицу: dictionary(topic TEXT, definition TEXT).

import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import 'db_service.dart' show normalizeGreek;

class DictionaryService {
  final Map<String, Database> _dbs;
  DictionaryService(this._dbs);

  static const _dictionaryTitles = <String, String>{
    'strongs': 'Словарь Стронга (СтрДв)',
    'bdag3': 'BDAG (3-е изд.)',
    'tdnt': 'TDNT',
    'cbtel': 'CBTEL',
    'morph': 'Морфологический греко-английский',
    'dvor': 'Словарь Дворецкого',
    'lsj': 'LSJ',
    'cambridge': 'Cambridge Dictionary',
  };

  // ── Список доступных словарей ─────────────────────────────────────────────
  List<DictionaryMeta> get availableDictionaries => [
        const DictionaryMeta(
          id: 'strongs',
          title: 'Словарь Стронга (СтрДв)',
          description: 'Лексикон греческих слов НЗ с леммой и транслитерацией.',
        ),
        const DictionaryMeta(
          id: 'bdag3',
          title: 'BDAG (3-е изд.)',
          description: 'Bauer–Danker–Arndt–Gingrich. Авторитетный '
              'греческо-английский лексикон НЗ.',
        ),
        const DictionaryMeta(
          id: 'tdnt',
          title: 'TDNT',
          description: 'Theological Dictionary of the New Testament '
              '(Kittel & Friedrich). Богословский анализ терминов.',
        ),
        const DictionaryMeta(
          id: 'cbtel',
          title: 'CBTEL',
          description: 'Cyclopædia of Biblical, Theological and Ecclesiastical '
              'Literature (McClintock & Strong).',
        ),
        const DictionaryMeta(
          id: 'morph',
          title: 'Морфологический греко-английский',
          description: 'Формы слов, словарная форма и базовые грамматические метки.',
        ),
        const DictionaryMeta(
          id: 'dvor',
          title: 'Словарь Дворецкого',
          description: 'Греческие словарные формы и определения (HTML).',
        ),
        const DictionaryMeta(
          id: 'lsj',
          title: 'LSJ',
          description: 'Liddell-Scott-Jones Greek-English Lexicon.',
        ),
        const DictionaryMeta(
          id: 'cambridge',
          title: 'Cambridge Dictionary',
          description: 'Английский словарь для lookup английских слов.',
        ),
      ].where((m) => _dbs.containsKey(m.id)).toList();

  // ── Страница записей ──────────────────────────────────────────────────────
  /// [searchInContent] — если false (по умолчанию), ищем только по topic.
  Future<List<DictionaryEntry>> fetchEntries({
    required String dictionaryId,
    String? query,
    bool searchInContent = false,
    int limit  = 50,
    int offset = 0,
  }) async {
    final db = _dbs[dictionaryId];
    if (db == null) return [];

    final List<Map<String, dynamic>> rows;
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      final sql = searchInContent
          ? 'SELECT topic, definition FROM dictionary '
            'WHERE topic LIKE ? OR definition LIKE ? '
            'ORDER BY topic LIMIT ? OFFSET ?'
          : 'SELECT topic, definition FROM dictionary '
            'WHERE topic LIKE ? '
            'ORDER BY topic LIMIT ? OFFSET ?';
      final args = searchInContent
          ? [q, q, limit, offset]
          : [q, limit, offset];
      rows = await db.rawQuery(sql, args);
    } else {
      rows = await db.rawQuery(
        'SELECT topic, definition FROM dictionary ORDER BY topic LIMIT ? OFFSET ?',
        [limit, offset],
      );
    }
    return rows.map(DictionaryEntry.fromMap).toList();
  }

  // ── Количество (для пагинации) ────────────────────────────────────────────
  Future<int> countEntries({
    required String dictionaryId,
    String? query,
    bool searchInContent = false,
  }) async {
    final db = _dbs[dictionaryId];
    if (db == null) return 0;

    final List<Map<String, dynamic>> rows;
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      final sql = searchInContent
          ? 'SELECT COUNT(*) AS cnt FROM dictionary '
            'WHERE topic LIKE ? OR definition LIKE ?'
          : 'SELECT COUNT(*) AS cnt FROM dictionary WHERE topic LIKE ?';
      rows = await db.rawQuery(sql, searchInContent ? [q, q] : [q]);
    } else {
      rows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM dictionary');
    }
    return (rows.first['cnt'] as int?) ?? 0;
  }

  // ── Поиск по Стронгу (только словарь strongs) ────────────────────────────
  Future<DictionaryEntry?> fetchByStrongs(String strongs) async {
    final db = _dbs['strongs'];
    if (db == null) return null;
    final clean = strongs.replaceAll(RegExp(r'^[A-Za-z]+'), '');
    final rows  = await db.rawQuery(
      'SELECT topic, definition FROM dictionary WHERE topic=? LIMIT 1',
      ['G$clean'],
    );
    if (rows.isEmpty) return null;
    return DictionaryEntry.fromMap(rows.first);
  }

  /// Pattern to detect English-only terms.
  static final _englishRe = RegExp(r"^[A-Za-z][A-Za-z\-']*$");

  Future<List<DictionaryLookupHit>> lookupAcrossDictionaries(
    String term, {
    int limitPerDictionary = 3,
  }) async {
    final q = term.trim();
    if (q.isEmpty) return const [];

    final isEnglish = _englishRe.hasMatch(q);
    final dictionaryIds = isEnglish
        ? <String>['cambridge']
        : <String>['dvor', 'lsj', 'bdag3', 'tdnt', 'cbtel', 'strongs'];

    final normQ = isEnglish ? q.toLowerCase() : normalizeGreek(q);

    final hits = <DictionaryLookupHit>[];
    for (final id in dictionaryIds) {
      final db = _dbs[id];
      if (db == null) continue;

      // 1) Exact match on topic
      var rows = await db.rawQuery(
        'SELECT topic, definition FROM dictionary WHERE topic = ? LIMIT ?',
        [q, limitPerDictionary],
      );

      // 2) Normalized match via topic_norm column (indexed, no RAM needed)
      if (rows.isEmpty && !isEnglish) {
        rows = await db.rawQuery(
          'SELECT topic, definition FROM dictionary WHERE topic_norm = ? LIMIT ?',
          [normQ, limitPerDictionary],
        );
      } else if (rows.isEmpty && isEnglish) {
        rows = await db.rawQuery(
          'SELECT topic, definition FROM dictionary WHERE topic LIKE ? LIMIT ?',
          ['%$q%', limitPerDictionary],
        );
      }

      final title = _dictionaryTitles[id] ?? id;
      for (final row in rows) {
        hits.add(DictionaryLookupHit(
          dictionaryId: id,
          dictionaryTitle: title,
          entry: DictionaryEntry.fromMap(row),
        ));
      }
    }

    return hits;
  }
}
