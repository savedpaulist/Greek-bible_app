// lib/features/notes/provider/notes_provider.dart

import 'package:flutter/foundation.dart';
import '../data/notes_db.dart';
import '../data/note_model.dart';
import '../../../core/models/models.dart';
import '../../../core/prefs/prefs_service.dart';

class NotesProvider extends ChangeNotifier {
    // A2: recentTagIds support
    List<String> _recentTagIds = [];
    List<String> get recentTagIds => List.unmodifiable(_recentTagIds);
    PrefsService? _prefs;

    void setPrefs(PrefsService prefs) {
      _prefs = prefs;
    }

    /// Отметить тег как «только что использованный».
    /// Перемещает tagId в начало списка, обрезает до 5.
    Future<void> markTagUsed(String tagId) async {
      _recentTagIds.removeWhere((id) => id == tagId);
      _recentTagIds.insert(0, tagId);
      if (_recentTagIds.length > 5) {
        _recentTagIds = _recentTagIds.sublist(0, 5);
      }
      await _prefs?.setRecentTagIds(_recentTagIds);
      notifyListeners();
    }
  // noteId -> List<NoteTag> (for fast sync access)
  final Map<String, List<NoteTag>> _noteTagsCache = {};

    /// Возвращает список тегов для заметки из кэша (синхронно).
    /// Возвращает список тегов для заметки из кэша (синхронно).
    List<NoteTag> tagsForNote(String noteId) {
      return _noteTagsCache[noteId] ?? const [];
    }

    /// Пересчитать кэш noteId→tags (вызывать после загрузки и при изменениях)
    Future<void> rebuildNoteTagsCache() async {
      final map = await _db.getAllNoteTagsMap();
      _noteTagsCache
        ..clear()
        ..addAll(map);
      notifyListeners();
    }
  final NotesDB _db;
  NotesProvider(this._db);

  List<NoteModel> _notes = [];
  List<NoteModel> get notes => _notes;

  List<NoteTemplate> _templates = [];
  List<NoteTemplate> get templates => _templates;

  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> get folders => _folders;

  List<NoteTag> _tags = [];
  List<NoteTag> get tags => _tags;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _loading = false;
  bool get loading => _loading;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _notes = await _db.getAllNotes();
    _templates = await _db.getTemplates();
    _folders = await _db.getAllFolders();
    _tags = await _db.getAllTags();
    await rebuildNoteTagsCache();
    _recentTagIds = _prefs?.recentTagIds ?? [];
    _loading = false;
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<NoteModel> createNote({String? templateId, String? folderId}) async {
    final note =
        await _db.createNote(templateId: templateId, folderId: folderId);
    _notes.insert(0, note);
    notifyListeners();
    return note;
  }

  /// Create a note with explicit title/content (for tag auto-notes).
  Future<NoteModel> createNoteWithContent({
    required String title,
    String content = '',
    String? folderId,
  }) async {
    final note = await _db.createNoteWithContent(
      title: title,
      content: content,
      folderId: folderId,
    );
    _notes.insert(0, note);
    notifyListeners();
    return note;
  }

  /// Ensure a folder named [name] exists, returning its id.
  Future<String> ensureFolder(String name) async {
    final existing = _folders.where(
        (f) => (f['name'] as String?)?.toLowerCase() == name.toLowerCase());
    if (existing.isNotEmpty) return existing.first['id'] as String;
    final id = await createFolder(name);
    return id;
  }

  /// Find an existing note by exact title (case-insensitive).
  NoteModel? findNoteByTitle(String title) {
    return _notes
        .where((n) => n.title.toLowerCase() == title.toLowerCase())
        .firstOrNull;
  }

  Future<void> updateNote(NoteModel note) async {
    await _db.updateNote(note);
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      _notes[idx] = note;
      // Re-sort by updated_at
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    }
  }

  Future<void> deleteNote(String id) async {
    await _db.deleteNote(id);
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _notes = await _db.getAllNotes();
    } else {
      _notes = await _db.searchNotes(query);
    }
    notifyListeners();
  }

  // ── Links ─────────────────────────────────────────────────────────────────

  /// Найти все заметки, которые ссылаются на [noteId] через [[noteTitle]].
  List<NoteModel> getBacklinks(String noteId, String noteTitle) {
    if (noteTitle.isEmpty) return [];
    final titleLower = noteTitle.toLowerCase();
    return _notes.where((n) {
      if (n.id == noteId) return false;
      final contentLower = n.content.toLowerCase();
      return contentLower.contains('[[$titleLower]]') ||
          n.content.contains('[[$noteTitle]]');
    }).toList();
  }

  Future<List<NoteModel>> getLinkedNotes(String noteId) async {
    return _db.getLinkedNotes(noteId);
  }

  /// Parse [[note title]] links from markdown content and update link table
  Future<void> updateNoteLinks(NoteModel note) async {
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = pattern.allMatches(note.content);
    final targetIds = <String>[];
    for (final m in matches) {
      final title = m.group(1)?.trim() ?? '';
      if (title.isEmpty) continue;
      // Find note by title
      final target = _notes
          .where((n) =>
              n.id != note.id && n.title.toLowerCase() == title.toLowerCase())
          .firstOrNull;
      if (target != null) targetIds.add(target.id);
    }
    await _db.setNoteLinks(note.id, targetIds);
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  Future<void> saveTemplate(NoteTemplate t) async {
    await _db.saveTemplate(t);
    _templates = await _db.getTemplates();
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    await _db.deleteTemplate(id);
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ── Verse Comments ────────────────────────────────────────────────────────

  Future<List<VerseComment>> getVerseComments(
          int bookNumber, int chapter, int verse) =>
      _db.getVerseComments(bookNumber, chapter, verse);

  Future<VerseComment> addVerseComment(
          int bookNumber, int chapter, int verse, String text) =>
      _db.addVerseComment(bookNumber, chapter, verse, text);

  Future<void> updateVerseComment(VerseComment c) => _db.updateVerseComment(c);

  Future<void> deleteVerseComment(String id) => _db.deleteVerseComment(id);

  Future<Set<String>> getCommentedVerseKeys(int bookNumber, int chapter) =>
      _db.getCommentedVerseKeys(bookNumber, chapter);

  // ── Parallel Verses ───────────────────────────────────────────────────────

  Future<List<ParallelVerse>> getParallelVerses(
          int bookNumber, int chapter, int verse) =>
      _db.getParallelVerses(bookNumber, chapter, verse);

  Future<ParallelVerse> addParallelVerse({
    required int sourceBook,
    required int sourceChapter,
    required int sourceVerse,
    required int targetBook,
    required int targetChapter,
    required int targetVerse,
  }) =>
      _db.addParallelVerse(
        sourceBook: sourceBook,
        sourceChapter: sourceChapter,
        sourceVerse: sourceVerse,
        targetBook: targetBook,
        targetChapter: targetChapter,
        targetVerse: targetVerse,
      );

  Future<void> deleteParallelVerse(String id) => _db.deleteParallelVerse(id);

  Future<Set<String>> getParallelVerseKeys(int bookNumber, int chapter) =>
      _db.getParallelVerseKeys(bookNumber, chapter);

  Future<Map<int, int>> getCommentCountsForChapter(
          int bookNumber, int chapter) =>
      _db.getCommentCountsForChapter(bookNumber, chapter);

  Future<Map<int, int>> getParallelCountsForChapter(
          int bookNumber, int chapter) =>
      _db.getParallelCountsForChapter(bookNumber, chapter);

  // ── Word Comments ───────────────────────────────────────────────────────

  Future<WordComment?> getWordComment(
          int bookNumber, int chapter, int verse, int wordNumber) =>
      _db.getWordComment(bookNumber, chapter, verse, wordNumber);

  Future<Map<String, WordComment>> getWordCommentsForChapter(
          int bookNumber, int chapter) =>
      _db.getWordCommentsForChapter(bookNumber, chapter);

  Future<WordComment> addWordComment(int bookNumber, int chapter, int verse,
          int wordNumber, String text) =>
      _db.addWordComment(bookNumber, chapter, verse, wordNumber, text);

  Future<void> deleteWordComment(String id) => _db.deleteWordComment(id);

  // ── Word Markup ─────────────────────────────────────────────────────────

  Future<List<WordMarkup>> getMarkupsForChapter(int bookNumber, int chapter) =>
      _db.getMarkupsForChapter(bookNumber, chapter);

  Future<WordMarkup> addMarkup(WordMarkup m) => _db.addMarkup(m);

  Future<void> deleteMarkup(String id) => _db.deleteMarkup(id);

  Future<void> deleteMarkupsForVerse(int bookNumber, int chapter, int verse) =>
      _db.deleteMarkupsForVerse(bookNumber, chapter, verse);

  // ── Note Folders ────────────────────────────────────────────────────────

  Future<String> createFolder(String name) async {
    final id = await _db.createFolder(name);
    _folders = await _db.getAllFolders();
    notifyListeners();
    return id;
  }

  Future<void> renameFolder(String id, String newName) async {
    await _db.renameFolder(id, newName);
    _folders = await _db.getAllFolders();
    notifyListeners();
  }

  Future<void> deleteFolder(String id) async {
    await _db.deleteFolder(id);
    _folders = await _db.getAllFolders();
    _notes = await _db.getAllNotes();
    notifyListeners();
  }

  Future<void> updateFolderColor(String id, int colorValue) async {
    await _db.updateFolderColor(id, colorValue);
    _folders = await _db.getAllFolders();
    notifyListeners();
  }

  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    await _db.moveNoteToFolder(noteId, folderId);
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx >= 0) {
      _notes[idx] = _notes[idx].copyWith(folderId: folderId);
      notifyListeners();
    }
  }

  Future<List<NoteModel>> getNotesInFolder(String? folderId) =>
      _db.getNotesInFolder(folderId);

  // ── Tags ────────────────────────────────────────────────────────────────

  Future<NoteTag> createTag(String name, {int colorValue = 0xFF2196F3}) async {
    final tag = await _db.createTag(name, colorValue: colorValue);
    _tags.add(tag);
    // Создать заметку с таким же названием и первой строкой # НазваниеТега
    await createNoteWithContent(
      title: name,
      content: '# $name\n',
    );
    notifyListeners();
    return tag;
  }

  Future<void> updateTag(NoteTag tag) async {
    await _db.updateTag(tag);
    final idx = _tags.indexWhere((t) => t.id == tag.id);
    if (idx >= 0) _tags[idx] = tag;
    notifyListeners();
  }

  Future<void> deleteTag(String id) async {
    await _db.deleteTag(id);
    _tags.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ── Note Tags ─────────────────────────────────────────────────────────────

  Future<List<NoteTag>> getTagsForNote(String noteId) =>
      _db.getTagsForNote(noteId);

  Future<void> addTagToNote(String noteId, String tagId) async {
    await _db.addTagToNote(noteId, tagId);
    _noteTagsCache[noteId] = await _db.getTagsForNote(noteId);
    notifyListeners();
  }

  Future<void> removeTagFromNote(String noteId, String tagId) async {
    await _db.removeTagFromNote(noteId, tagId);
    _noteTagsCache[noteId] = await _db.getTagsForNote(noteId);
    notifyListeners();
  }

  // ── Verse Tags ────────────────────────────────────────────────────────────

  Future<List<VerseTag>> getVerseTagsForVerse(
          int bookNumber, int chapter, int verse) =>
      _db.getVerseTagsForVerse(bookNumber, chapter, verse);

  Future<VerseTag> addVerseTag({
    required String tagId,
    required int bookNumber,
    required int chapter,
    required int verse,
  }) =>
      _db.addVerseTag(
        tagId: tagId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
      );

  Future<void> deleteVerseTag(String id) => _db.deleteVerseTag(id);

  Future<List<VerseTag>> getVersesForTag(String tagId) =>
      _db.getVersesForTag(tagId);

  Future<Map<int, List<String>>> getVerseTagIdsForChapter(
          int bookNumber, int chapter) =>
      _db.getVerseTagIdsForChapter(bookNumber, chapter);
}
