// lib/core/models/models.dart

class BookModel {
  final int bookNumber;
  final String shortName;
  const BookModel({required this.bookNumber, required this.shortName});
  factory BookModel.fromMap(Map<String, dynamic> map) => BookModel(
        bookNumber: map['book_number'] as int,
        shortName: map['short_name'] as String? ?? '',
      );
}

class WordModel {
  final int chapter;
  final int verse;
  final int wordNumber;
  final String word;
  final String? strongs;
  final String? morphology;

  const WordModel({
    required this.chapter,
    required this.verse,
    required this.wordNumber,
    required this.word,
    this.strongs,
    this.morphology,
  });

  factory WordModel.fromMap(Map<String, dynamic> map) => WordModel(
        chapter:    map['chapter']     as int,
        verse:      map['verse']       as int,
        wordNumber: map['word_number'] as int,
        word:       map['word']        as String? ?? '',
        strongs:    map['strongs']     as String?,
        morphology: map['morphology']  as String?,
      );
}

class VerseModel {
  final int chapter;
  final int verse;
  final List<WordModel> words;
  const VerseModel({required this.chapter, required this.verse, required this.words});
}

class WordDetail {
  final String  morphologyText;
  final String? morphologyHtml;  // Linkified version of morphologyText
  final String  definitionHtml;
  /// Словарная форма (лемма) из колонки lexeme таблицы dictionary.
  /// Может быть null, если слово не найдено в словаре.
  final String? lexeme;
  /// Варианты словарной формы для перехода в другие словари.
  final List<String> lookupTerms;

  const WordDetail({
    required this.morphologyText,
    required this.definitionHtml,
    this.morphologyHtml,
    this.lexeme,
    this.lookupTerms = const [],
  });
}

class ReadingPosition {
  final int bookNumber;
  final int chapter;
  final int verse;
  const ReadingPosition({required this.bookNumber, required this.chapter, required this.verse});
}

class SearchResult {
  final int bookNumber;
  final String bookShortName;
  final int chapter;
  final int verse;
  final String word;
  final String? strongs;
  final String? morphology;

  const SearchResult({
    required this.bookNumber,
    required this.bookShortName,
    required this.chapter,
    required this.verse,
    required this.word,
    this.strongs,
    this.morphology,
  });
}

/// Used by morphology picker
class MorphEntry {
  final String indication;
  final String meaning;
  const MorphEntry({required this.indication, required this.meaning});
  @override
  String toString() => '$indication — $meaning';
}

/// Carries info about which word to highlight/blink after navigation
class HighlightTarget {
  final int chapter;
  final int verse;
  final String? strongs; // if null, highlight whole verse
  const HighlightTarget({required this.chapter, required this.verse, this.strongs});
}

// ── Search term (multi-word) ──────────────────────────────────────────────────
enum SearchTermType { word, strongs }

class SearchTerm {
  final SearchTermType type;
  final String value;
  const SearchTerm({required this.type, required this.value});
}

// ── Dictionary models ─────────────────────────────────────────────────────────

/// Represents a dictionary available in the app (e.g. Strong's, Liddell-Scott).
class DictionaryMeta {
  final String id;        // unique key, e.g. 'strongs_greek'
  final String title;
  final String? description;

  const DictionaryMeta({
    required this.id,
    required this.title,
    this.description,
  });
}

/// A single entry inside a dictionary.
class DictionaryEntry {
  final String term;          // the key / lemma shown as title
  final String definitionHtml; // HTML body (may contain markup from DB)

  const DictionaryEntry({
    required this.term,
    required this.definitionHtml,
  });

  factory DictionaryEntry.fromMap(Map<String, dynamic> map) => DictionaryEntry(
        term:           map['topic']      as String? ?? '',
        definitionHtml: map['definition'] as String? ?? '',
      );
}

/// Попадание при поиске по всем словарям.
class DictionaryLookupHit {
  final String dictionaryId;
  final String dictionaryTitle;
  final DictionaryEntry entry;

  const DictionaryLookupHit({
    required this.dictionaryId,
    required this.dictionaryTitle,
    required this.entry,
  });
}

// ── Verse context features ────────────────────────────────────────────────────

/// Параллельный стих (перекрёстная ссылка)
class ParallelVerse {
  final String id;
  final int sourceBook;
  final int sourceChapter;
  final int sourceVerse;
  final int targetBook;
  final int targetChapter;
  final int targetVerse;

  const ParallelVerse({
    required this.id,
    required this.sourceBook,
    required this.sourceChapter,
    required this.sourceVerse,
    required this.targetBook,
    required this.targetChapter,
    required this.targetVerse,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'source_book': sourceBook,
    'source_chapter': sourceChapter,
    'source_verse': sourceVerse,
    'target_book': targetBook,
    'target_chapter': targetChapter,
    'target_verse': targetVerse,
  };

  factory ParallelVerse.fromMap(Map<String, dynamic> m) => ParallelVerse(
    id: m['id'] as String,
    sourceBook: m['source_book'] as int,
    sourceChapter: m['source_chapter'] as int,
    sourceVerse: m['source_verse'] as int,
    targetBook: m['target_book'] as int,
    targetChapter: m['target_chapter'] as int,
    targetVerse: m['target_verse'] as int,
  );
}

/// Комментарий к стиху
class VerseComment {
  final String id;
  final int bookNumber;
  final int chapter;
  final int verse;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VerseComment({
    required this.id,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  VerseComment copyWith({String? text, DateTime? updatedAt}) => VerseComment(
    id: id,
    bookNumber: bookNumber,
    chapter: chapter,
    verse: verse,
    text: text ?? this.text,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'book_number': bookNumber,
    'chapter': chapter,
    'verse': verse,
    'text': text,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory VerseComment.fromMap(Map<String, dynamic> m) => VerseComment(
    id: m['id'] as String,
    bookNumber: m['book_number'] as int,
    chapter: m['chapter'] as int,
    verse: m['verse'] as int,
    text: m['text'] as String? ?? '',
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Комментарий к отдельному слову (≤ 200 символов)
class WordComment {
  final String id;
  final int bookNumber;
  final int chapter;
  final int verse;
  final int wordNumber;
  final String text;
  final DateTime createdAt;

  const WordComment({
    required this.id,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.wordNumber,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'book_number': bookNumber,
    'chapter': chapter,
    'verse': verse,
    'word_number': wordNumber,
    'text': text,
    'created_at': createdAt.toIso8601String(),
  };

  factory WordComment.fromMap(Map<String, dynamic> m) => WordComment(
    id: m['id'] as String,
    bookNumber: m['book_number'] as int,
    chapter: m['chapter'] as int,
    verse: m['verse'] as int,
    wordNumber: m['word_number'] as int,
    text: m['text'] as String? ?? '',
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Подчёркивание / выделение фона слова или стиха
enum MarkupKind {
  underlineSingle,
  underlineDouble,
  underlineWavy,
  underlineDashed,
  underlineDotted,
  underlineDashDot,
  background,
}

class WordMarkup {
  final String id;
  final int bookNumber;
  final int chapter;
  final int verse;
  final int? wordNumber;   // null → весь стих (фон)
  final MarkupKind kind;
  final int colorIndex;    // index in the theme palette
  final int? colorValue;   // ARGB int — if set, overrides colorIndex

  const WordMarkup({
    required this.id,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    this.wordNumber,
    required this.kind,
    required this.colorIndex,
    this.colorValue,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'book_number': bookNumber,
    'chapter': chapter,
    'verse': verse,
    'word_number': wordNumber,
    'kind': kind.name,
    'color_index': colorIndex,
    'color_value': colorValue,
  };

  factory WordMarkup.fromMap(Map<String, dynamic> m) => WordMarkup(
    id: m['id'] as String,
    bookNumber: m['book_number'] as int,
    chapter: m['chapter'] as int,
    verse: m['verse'] as int,
    wordNumber: m['word_number'] as int?,
    kind: MarkupKind.values.firstWhere(
      (k) => k.name == (m['kind'] as String? ?? 'underlineSingle'),
      orElse: () => MarkupKind.underlineSingle,
    ),
    colorIndex: m['color_index'] as int? ?? 0,
    colorValue: m['color_value'] as int?,
  );
}
