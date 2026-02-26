// lib/features/notes/view/note_editor_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/app_state.dart';
import '../../../core/models/models.dart';
import '../../../ui/main_shell.dart';
import '../../../word_popup.dart';
import '../../home/view/book_chapter_dialog.dart';
import '../data/note_model.dart';
import '../provider/notes_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Per-tab state container
// ─────────────────────────────────────────────────────────────────────────────
class _TabData {
  NoteModel note;
  final TextEditingController titleCtrl;
  final _LinkHighlightController contentCtrl;
  bool preview;

  _TabData({required this.note, required String title, required String content})
      : titleCtrl = TextEditingController(text: title),
        contentCtrl = _LinkHighlightController(text: content),
        preview = content.trim().isNotEmpty;

  void dispose() {
    titleCtrl.dispose();
    contentCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NoteEditorScreen — Write / Preview markdown editor with tabs
// ─────────────────────────────────────────────────────────────────────────────

class NoteEditorScreen extends StatefulWidget {
  final NoteModel note;
  const NoteEditorScreen({super.key, required this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  // ── Tab management ──────────────────────────────────────────────────────
  final List<_TabData> _tabs = [];
  int _activeTabIdx = 0;

  _TabData get _currentTab => _tabs[_activeTabIdx];

  // Convenience accessors (delegate to current tab)
  TextEditingController get _titleCtrl => _currentTab.titleCtrl;
  _LinkHighlightController get _contentCtrl => _currentTab.contentCtrl;
  bool get _preview => _currentTab.preview;
  set _preview(bool v) => _currentTab.preview = v;

  Timer? _saveTimer;
  late NotesProvider _provider;
  String? _activeLinkTarget;
  final _contentFocus = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _addTab(widget.note);
    _activeTabIdx = 0;
    // Listen to current tab's controllers
    _attachListeners();
  }

  /// Create a _TabData from a NoteModel and add it to the tabs list.
  _TabData _addTab(NoteModel note) {
    String title = note.title;
    if (title.isEmpty && note.content.isNotEmpty) {
      final firstLine = note.content.split('\n').first.trim();
      if (firstLine.startsWith('# ')) {
        title = firstLine.substring(2).trim();
      }
    }
    final tab = _TabData(note: note, title: title, content: note.content);
    _tabs.add(tab);
    return tab;
  }

  void _attachListeners() {
    _contentCtrl.addListener(_scheduleSave);
    _contentCtrl.addListener(_checkCursorLink);
    _titleCtrl.addListener(_scheduleSave);
  }

  void _detachListeners() {
    _contentCtrl.removeListener(_scheduleSave);
    _contentCtrl.removeListener(_checkCursorLink);
    _titleCtrl.removeListener(_scheduleSave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<NotesProvider>();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    if (!mounted) return;
    final provider = context.read<NotesProvider>();
    final tab = _currentTab;
    final updated = tab.note.copyWith(
      title: tab.titleCtrl.text.trim(),
      content: tab.contentCtrl.text,
      updatedAt: DateTime.now(),
    );
    tab.note = updated;
    await provider.updateNote(updated);
    await provider.updateNoteLinks(updated);
  }

  /// Save a specific tab (used when closing or switching).
  Future<void> _saveTab(_TabData tab) async {
    final updated = tab.note.copyWith(
      title: tab.titleCtrl.text.trim(),
      content: tab.contentCtrl.text,
      updatedAt: DateTime.now(),
    );
    tab.note = updated;
    await _provider.updateNote(updated);
    await _provider.updateNoteLinks(updated);
  }

  // ── Bible reference navigation ────────────────────────────────────────────

  /// Resolve a Bible reference string like "Μτ 5:3" or "Α Κορ 1:2".
  /// Iterates all known book shortNames (longest first) to match any script
  /// (Greek, Cyrillic, Latin) and handles multi-word names with spaces.
  ({int book, int chapter, int verse})? _parseBibleRef(String text) {
    final state = context.read<AppState>();
    final books = state.books;
    if (books.isEmpty) return null;

    final trimmed = text.trim();

    // Sort by shortName length descending ("Α Κορ" matched before "Α")
    final sorted = List<BookModel>.from(books)
      ..sort((a, b) => b.shortName.length.compareTo(a.shortName.length));

    // Case-sensitive first, then case-insensitive fallback
    for (final caseSensitive in [true, false]) {
      for (final book in sorted) {
        final sn = caseSensitive ? book.shortName : book.shortName.toLowerCase();
        final src = caseSensitive ? trimmed : trimmed.toLowerCase();
        if (!src.startsWith(sn)) continue;
        final rest = trimmed.substring(sn.length).trimLeft();
        final m = RegExp(r'^(\d+):(\d+)').firstMatch(rest);
        if (m == null) continue;
        final ch = int.tryParse(m.group(1)!);
        final v = int.tryParse(m.group(2)!);
        if (ch == null || v == null) continue;
        return (book: book.bookNumber, chapter: ch, verse: v);
      }
    }
    return null;
  }

  void _navigateToBibleRef(String text) {
    final ref = _parseBibleRef(text);
    if (ref == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось распознать ссылку: $text')),
      );
      return;
    }

    final state = context.read<AppState>();
    final db = state.db;
    final vpFs = state.versePreviewFontSize;

    // Show verse preview popup instead of navigating away
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VersePreviewSheet(
        book: ref.book,
        chapter: ref.chapter,
        verse: ref.verse,
        db: db,
        fontSize: vpFs,
        onNavigate: () {
          // Allow full navigation if user explicitly taps "Перейти"
          Navigator.of(context).pop(); // close sheet
          state.navigateToVerse(ref.book, ref.chapter, ref.verse);
          final shell = context.findAncestorStateOfType<MainShellState>();
          if (shell != null) {
            shell.goToPage(1);
          }
        },
      ),
    );
  }

  /// Track cursor position to detect [[...]] links
  void _checkCursorLink() {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      if (_activeLinkTarget != null) setState(() => _activeLinkTarget = null);
      return;
    }
    final pos = sel.baseOffset;
    if (pos < 0 || pos > text.length) {
      if (_activeLinkTarget != null) setState(() => _activeLinkTarget = null);
      return;
    }

    String? found;
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    for (final match in pattern.allMatches(text)) {
      if (pos >= match.start && pos <= match.end) {
        found = match.group(1);
        break;
      }
    }

    if (found != _activeLinkTarget) {
      setState(() => _activeLinkTarget = found);
    }
  }

  /// Follow a detected link (Bible ref or note)
  void _followLink(String linkText) {
    if (RegExp(r'\d+:\d+').hasMatch(linkText)) {
      _navigateToBibleRef(linkText);
    } else {
      _openLinkedNote(linkText);
    }
  }

  void _openLinkedNote(String noteTitle) {
    final provider = context.read<NotesProvider>();
    final target = provider.notes
        .where((n) => n.title.toLowerCase() == noteTitle.toLowerCase())
        .firstOrNull;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заметка «$noteTitle» не найдена')),
      );
      return;
    }
    // Open in a new tab instead of replacing the screen
    _openNoteInTab(target);
  }

  // ── Insert helpers ────────────────────────────────────────────────────────

  void _insertBibleRef() {
    showDialog(
      context: context,
      builder: (_) => BookChapterPicker(
        onSelect: (book, chapter, verse) {
          final state = context.read<AppState>();
          final name = state.books
              .where((b) => b.bookNumber == book)
              .firstOrNull?.shortName ?? '$book';
          _insertTextAtCursor('[[$name $chapter:$verse]]');
        },
      ),
    );
  }

  void _insertBibleQuote() {
    showDialog(
      context: context,
      builder: (_) => BookChapterPicker(
        onSelect: (book, chapter, verse) {
          final state = context.read<AppState>();
          final name = state.books
              .where((b) => b.bookNumber == book)
              .firstOrNull?.shortName ?? '$book';
          _insertTextAtCursor('{{$name $chapter:$verse}}');
        },
      ),
    );
  }

  void _insertNoteLink() async {
    final provider = context.read<NotesProvider>();
    final notes = provider.notes.where((n) => n.id != _currentTab.note.id).toList();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет других заметок для ссылки')),
      );
      return;
    }
    final selected = await showModalBottomSheet<NoteModel>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Ссылка на заметку',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
          ),
          for (final n in notes)
            ListTile(
              title: Text(n.title.isEmpty ? 'Без названия' : n.title),
              subtitle: Text(
                '${n.updatedAt.day}.${n.updatedAt.month}.${n.updatedAt.year}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.secondary),
              ),
              onTap: () => Navigator.pop(ctx, n),
            ),
        ],
      ),
    );
    if (selected != null && mounted) {
      _insertTextAtCursor('[[${selected.title}]]');
    }
  }

  void _insertTextAtCursor(String insertion) {
    final sel = _contentCtrl.selection;
    final text = _contentCtrl.text;
    final pos = sel.isValid ? sel.baseOffset : text.length;
    final before = text.substring(0, pos.clamp(0, text.length));
    final after = text.substring(pos.clamp(0, text.length));
    _contentCtrl.text = before + insertion + after;
    _contentCtrl.selection =
        TextSelection.collapsed(offset: pos + insertion.length);
    _contentFocus.requestFocus();
  }

  // ── Markdown toolbar actions ──────────────────────────────────────────────

  void _wrapSelection(String prefix, String suffix) {
    final sel = _contentCtrl.selection;
    final text = _contentCtrl.text;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      final pos = sel.baseOffset;
      _contentCtrl.text = text.substring(0, pos) +
          prefix + suffix + text.substring(pos);
      _contentCtrl.selection =
          TextSelection.collapsed(offset: pos + prefix.length);
    } else {
      final selected = text.substring(sel.start, sel.end);
      _contentCtrl.text = text.substring(0, sel.start) +
          prefix + selected + suffix + text.substring(sel.end);
      _contentCtrl.selection = TextSelection(
        baseOffset: sel.start + prefix.length,
        extentOffset: sel.start + prefix.length + selected.length,
      );
    }
    _contentFocus.requestFocus();
  }

  void _prefixLine(String prefix) {
    final sel = _contentCtrl.selection;
    final text = _contentCtrl.text;
    if (!sel.isValid) return;

    final pos = sel.baseOffset;
    int lineStart = text.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
    lineStart = lineStart < 0 ? 0 : lineStart + 1;

    _contentCtrl.text =
        text.substring(0, lineStart) + prefix + text.substring(lineStart);
    _contentCtrl.selection =
        TextSelection.collapsed(offset: pos + prefix.length);
    _contentFocus.requestFocus();
  }

  // ── Auto-list on Enter (org-style: + prefix, auto-numbered) ──────────────

  /// Called from a RawKeyboardListener wrapping the content field.
  /// Returns true if the key was handled.
  void _handleNewLine() {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    if (!sel.isValid || !sel.isCollapsed) return;
    final pos = sel.baseOffset;

    // Find the line that was just before the newly-inserted newline
    // The newline was already inserted by the text field at `pos - 1`
    final nlPos = pos - 1;
    if (nlPos < 0 || nlPos >= text.length || text[nlPos] != '\n') return;

    // Find start of previous line
    int prevLineStart = text.lastIndexOf('\n', nlPos > 0 ? nlPos - 1 : 0);
    prevLineStart = prevLineStart < 0 ? 0 : prevLineStart + 1;
    final prevLine = text.substring(prevLineStart, nlPos);

    // Match list patterns
    String? insertion;

    // Numbered list: "1. ", "2. ", etc.
    final numMatch = RegExp(r'^(\s*)(\d+)\.\s').firstMatch(prevLine);
    if (numMatch != null) {
      final indent = numMatch.group(1)!;
      final prevLineContent = prevLine.substring(numMatch.end);
      if (prevLineContent.trim().isEmpty) {
        // Empty list item → remove the prefix and the newline
        _contentCtrl.text = text.substring(0, prevLineStart) + text.substring(pos);
        _contentCtrl.selection = TextSelection.collapsed(offset: prevLineStart);
        return;
      }
      final nextNum = int.parse(numMatch.group(2)!) + 1;
      insertion = '$indent$nextNum. ';
    }

    // Plus-prefix list: "+ " (org-style, auto-converted to numbers on preview)
    final plusMatch = RegExp(r'^(\s*)\+\s').firstMatch(prevLine);
    if (plusMatch != null && insertion == null) {
      final indent = plusMatch.group(1)!;
      final prevLineContent = prevLine.substring(plusMatch.end);
      if (prevLineContent.trim().isEmpty) {
        _contentCtrl.text = text.substring(0, prevLineStart) + text.substring(pos);
        _contentCtrl.selection = TextSelection.collapsed(offset: prevLineStart);
        return;
      }
      insertion = '$indent+ ';
    }

    // Bullet list: "- " 
    final bulletMatch = RegExp(r'^(\s*)-\s').firstMatch(prevLine);
    if (bulletMatch != null && insertion == null) {
      final indent = bulletMatch.group(1)!;
      final prevLineContent = prevLine.substring(bulletMatch.end);
      if (prevLineContent.trim().isEmpty) {
        _contentCtrl.text = text.substring(0, prevLineStart) + text.substring(pos);
        _contentCtrl.selection = TextSelection.collapsed(offset: prevLineStart);
        return;
      }
      insertion = '$indent- ';
    }

    // Checkbox: "- [ ] " or "- [x] "
    final cbMatch = RegExp(r'^(\s*)-\s\[[\sx]\]\s').firstMatch(prevLine);
    if (cbMatch != null && insertion == null) {
      final indent = cbMatch.group(1)!;
      final prevLineContent = prevLine.substring(cbMatch.end);
      if (prevLineContent.trim().isEmpty) {
        _contentCtrl.text = text.substring(0, prevLineStart) + text.substring(pos);
        _contentCtrl.selection = TextSelection.collapsed(offset: prevLineStart);
        return;
      }
      insertion = '$indent- [ ] ';
    }

    if (insertion != null) {
      _contentCtrl.text =
          text.substring(0, pos) + insertion + text.substring(pos);
      _contentCtrl.selection =
          TextSelection.collapsed(offset: pos + insertion.length);
    }
  }

  // ── Export .md ────────────────────────────────────────────────────────────

  Future<void> _exportMarkdown() async {
    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : 'note';
    final safeName = title.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
    final content = _contentCtrl.text;
    final fullContent = title.isNotEmpty ? '# $title\n\n$content' : content;

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$safeName.md');
      await file.writeAsString(fullContent);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '$title.md',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    }
  }

  // ── Notes font settings dialog ────────────────────────────────────────────

  void _showNoteFontSettings() {
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _NoteFontSettingsSheet(appState: appState),
    );
  }

  // ── Enter edit mode (task 9/10: cursor placement) ─────────────────────────

  void _enterEditMode() {
    setState(() => _preview = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final text = _contentCtrl.text;
      if (text.isNotEmpty) {
        _contentCtrl.selection = TextSelection.collapsed(offset: text.length);
      }
      _contentFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _detachListeners();
    // Save and dispose all tabs
    for (final tab in _tabs) {
      final updated = tab.note.copyWith(
        title: tab.titleCtrl.text.trim(),
        content: tab.contentCtrl.text,
        updatedAt: DateTime.now(),
      );
      _provider.updateNote(updated);
      _provider.updateNoteLinks(updated);
      tab.dispose();
    }
    _contentFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Tab switching ────────────────────────────────────────────────────────

  void _switchToTab(int index) {
    if (index == _activeTabIdx || index < 0 || index >= _tabs.length) return;
    _detachListeners();
    _saveTab(_currentTab); // save current
    _activeLinkTarget = null;
    _contentFocus.unfocus();
    setState(() {
      _activeTabIdx = index;
    });
    _attachListeners();
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) {
      // Last tab — go back
      Navigator.of(context).pop();
      return;
    }
    _detachListeners();
    _saveTab(_tabs[index]);
    _tabs[index].dispose();
    _tabs.removeAt(index);
    if (_activeTabIdx >= _tabs.length) {
      _activeTabIdx = _tabs.length - 1;
    } else if (_activeTabIdx > index) {
      _activeTabIdx--;
    } else if (_activeTabIdx == index) {
      _activeTabIdx = _activeTabIdx.clamp(0, _tabs.length - 1);
    }
    _attachListeners();
    setState(() {});
  }

  void _openNoteInTab(NoteModel note) {
    // Check if already open
    final existing = _tabs.indexWhere((t) => t.note.id == note.id);
    if (existing >= 0) {
      _switchToTab(existing);
      return;
    }
    _detachListeners();
    _saveTab(_currentTab);
    _addTab(note);
    _activeTabIdx = _tabs.length - 1;
    _attachListeners();
    setState(() {});
  }

  /// Create a brand-new note (with optional template) and open it in a new tab.
  Future<void> _createNoteInTab() async {
    final templates = _provider.templates;

    // If there are multiple templates, let the user pick one.
    if (templates.length > 1) {
      final tpl = await showModalBottomSheet<NoteTemplate?>(
        context: context,
        showDragHandle: true,
        builder: (sheetCtx) => ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Выберите шаблон',
                  style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold)),
            ),
            for (final t in templates)
              ListTile(
                title: Text(t.name),
                leading: const Icon(Icons.description_outlined),
                onTap: () => Navigator.pop(sheetCtx, t),
              ),
          ],
        ),
      );
      if (tpl == null || !mounted) return;
      final note = await _provider.createNote(templateId: tpl.id);
      if (!mounted) return;
      _openNoteInTab(note);
      setState(() => _preview = false);
      return;
    }

    // No templates (or just one default) — create a plain note.
    final note = await _provider.createNote();
    if (!mounted) return;
    _openNoteInTab(note);
    setState(() => _preview = false);
  }

  /// Show a picker to open an existing note in a new tab.
  void _showTabPicker() {
    final allNotes = _provider.notes;
    final openIds = _tabs.map((t) => t.note.id).toSet();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Открыть заметку',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
          ),
          // ── Create new note ──
          ListTile(
            leading: Icon(Icons.add_circle_outline,
                color: Theme.of(ctx).colorScheme.primary),
            title: Text('Создать',
                style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
            onTap: () {
              Navigator.pop(ctx);
              _createNoteInTab();
            },
          ),
          const Divider(height: 1),
          // ── Existing notes ──
          for (final n in allNotes)
            ListTile(
              title: Text(n.title.isEmpty ? 'Без названия' : n.title),
              leading: Icon(
                openIds.contains(n.id)
                    ? Icons.check_circle
                    : Icons.description_outlined,
                color: openIds.contains(n.id)
                    ? Theme.of(ctx).colorScheme.primary
                    : null,
              ),
              subtitle: openIds.contains(n.id)
                  ? const Text('Уже открыта', style: TextStyle(fontSize: 12))
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _openNoteInTab(n);
              },
            ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appState = context.watch<AppState>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (MediaQuery.of(context).viewInsets.bottom > 0) {
          FocusScope.of(context).unfocus();
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_preview ? 'Предпросмотр' : 'Редактор'),
          actions: [
            if (!_preview) ...[
              IconButton(
                icon: const Icon(Icons.menu_book, size: 20),
                tooltip: 'Вставить ссылку на стих',
                onPressed: _insertBibleRef,
              ),
              IconButton(
                icon: const Icon(Icons.link, size: 20),
                tooltip: 'Ссылка на заметку',
                onPressed: _insertNoteLink,
              ),
            ],
            // Font settings in top bar
            IconButton(
              icon: const Icon(Icons.text_format, size: 22),
              tooltip: 'Настройки шрифта',
              onPressed: _showNoteFontSettings,
            ),
            // Export .md
            IconButton(
              icon: const Icon(Icons.share, size: 20),
              tooltip: 'Экспорт .md',
              onPressed: _exportMarkdown,
            ),
            // Edit / Preview toggle
            IconButton(
              icon: Icon(
                _preview ? Icons.edit_note : Icons.check,
                size: 22,
              ),
              tooltip: _preview ? 'Редактировать' : 'Готово',
              onPressed: () {
                if (_preview) {
                  _enterEditMode();
                  return;
                }
                FocusScope.of(context).unfocus();
                setState(() => _preview = true);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Tab bar ───────────────────────────────
            _buildTabBar(cs),
            // ── Editor / Preview ──────────────────────
            Expanded(
              child: _preview
                  ? _buildPreview(cs, appState)
                  : _buildEditor(cs, appState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _tabs.length + 1, // +1 for the "+" button
        itemBuilder: (_, i) {
          // Last item = "+" button
          if (i == _tabs.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: IconButton(
                icon: const Icon(Icons.add, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
                tooltip: 'Открыть заметку',
                onPressed: _showTabPicker,
              ),
            );
          }
          final tab = _tabs[i];
          final active = i == _activeTabIdx;
          final title = tab.titleCtrl.text.trim().isEmpty
              ? 'Без названия'
              : tab.titleCtrl.text.trim();
          return GestureDetector(
            onTap: () => _switchToTab(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              padding: const EdgeInsets.only(left: 10, right: 2),
              decoration: BoxDecoration(
                color: active
                    ? cs.surface
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: active
                    ? Border.all(color: cs.primary.withValues(alpha: 0.4))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      padding: EdgeInsets.zero,
                      onPressed: () => _closeTab(i),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Editor mode ───────────────────────────────────────────────────────────

  Widget _buildEditor(ColorScheme cs, AppState appState) {
    final noteFont = appState.noteFontFamily;
    final noteFontDisplay = AppState.availableFonts[noteFont] ?? noteFont;
    final noteFontSize = appState.noteFontSize;
    final noteLineH = appState.noteLineHeight;

    return Column(
      children: [
        // Link action bar
        if (_activeLinkTarget != null) _buildLinkBar(cs),
        // Markdown formatting toolbar
        _MarkdownToolbar(
          cs: cs,
          onBold: () => _wrapSelection('**', '**'),
          onItalic: () => _wrapSelection('*', '*'),
          onStrikethrough: () => _wrapSelection('~~', '~~'),
          onCode: () => _wrapSelection('`', '`'),
          onH1: () => _prefixLine('# '),
          onH2: () => _prefixLine('## '),
          onH3: () => _prefixLine('### '),
          onBulletList: () => _prefixLine('- '),
          onNumberedList: () => _prefixLine('1. '),
          onCheckbox: () => _prefixLine('- [ ] '),
          onBlockquote: () => _prefixLine('> '),
          onHorizontalRule: () => _insertTextAtCursor('\n---\n'),
          onBibleRef: _insertBibleRef,
          onBibleQuote: _insertBibleQuote,
          onNoteLink: _insertNoteLink,
        ),
        const Divider(height: 1),
        // Title field (task 1: gray hint when empty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _titleCtrl,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: noteFontDisplay,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Название заметки',
              hintStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            maxLines: 1,
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        // Content field with auto-list support
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _AutoListTextField(
              controller: _contentCtrl,
              focusNode: _contentFocus,
              scrollController: _scrollController,
              onNewLine: _handleNewLine,
              typewriterMode: appState.typewriterMode,
              style: TextStyle(
                fontSize: noteFontSize,
                fontFamily: noteFontDisplay,
                height: noteLineH,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Содержание (Markdown)…',
                hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkBar(ColorScheme cs) {
    final isBible = RegExp(r'\d+:\d+').hasMatch(_activeLinkTarget!);
    return Material(
      elevation: 1,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(isBible ? Icons.menu_book : Icons.link,
                size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _activeLinkTarget!,
                style: TextStyle(fontSize: 13, color: cs.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Перейти'),
              onPressed: () => _followLink(_activeLinkTarget!),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview mode ──────────────────────────────────────────────────────────

  /// Resolve all {{BookName ch:v}} quote placeholders to actual verse text.
  Future<String> _resolveVerseQuotes(String text) async {
    final quotePattern = RegExp(r'\{\{([^}]+)\}\}');
    final matches = quotePattern.allMatches(text).toList();
    if (matches.isEmpty) return text;

    final state = context.read<AppState>();
    final db = state.db;

    // Collect all refs
    final refs = <int, ({int book, int chapter, int verse, String label})>{};
    for (var i = 0; i < matches.length; i++) {
      final inner = matches[i].group(1)!.trim();
      final parsed = _parseBibleRef(inner);
      if (parsed != null) {
        final bookName = state.books
            .where((b) => b.bookNumber == parsed.book)
            .firstOrNull
            ?.shortName ?? '';
        refs[i] = (
          book: parsed.book,
          chapter: parsed.chapter,
          verse: parsed.verse,
          label: '$bookName ${parsed.chapter}:${parsed.verse}',
        );
      }
    }

    // Batch-fetch verse words
    final batchRefs = refs.values
        .map((r) => (book: r.book, chapter: r.chapter, verse: r.verse))
        .toList();
    final wordsMap = await db.getVerseWordsBatch(batchRefs);

    // Replace in reverse order to preserve indices
    String result = text;
    for (var i = matches.length - 1; i >= 0; i--) {
      final match = matches[i];
      final ref = refs[i];
      if (ref == null) continue;

      final key = '${ref.book}:${ref.chapter}:${ref.verse}';
      final words = wordsMap[key];
      final verseText = words != null
          ? words.map((w) => w.word).join(' ')
          : '(стих не найден)';

      // Render as blockquote with reference
      final replacement = '\n> *${ref.label}*\n> $verseText\n';
      result = result.substring(0, match.start) +
          replacement +
          result.substring(match.end);
    }
    return result;
  }

  Widget _buildPreview(ColorScheme cs, AppState appState) {
    final noteFont = AppState.availableFonts[appState.noteFontFamily] ?? appState.noteFontFamily;
    final nfs = appState.noteFontSize;
    final nlh = appState.noteLineHeight;

    return GestureDetector(
      // Task 6: tap in preview → switch to edit mode
      onTap: _enterEditMode,
      behavior: HitTestBehavior.translucent,
      child: FutureBuilder<String>(
        future: _resolveVerseQuotes(_contentCtrl.text),
        builder: (context, snapshot) {
          String processed = snapshot.data ?? _contentCtrl.text;

          // Convert + list items to numbered for display
          processed = _convertPlusListsToNumbered(processed);

          // Convert [[...]] to markdown links
          processed = processed.replaceAllMapped(
            RegExp(r'\[\[([^\]]+)\]\]'),
            (m) {
              final inner = m.group(1) ?? '';
              final encoded = Uri.encodeComponent(inner);
              if (RegExp(r'\d+:\d+').hasMatch(inner)) {
                return '[$inner](bible:$encoded)';
              }
              return '[$inner](note:$encoded)';
            },
          );

          final displayContent = _titleCtrl.text.isNotEmpty &&
                  !processed.trimLeft().startsWith('# ${_titleCtrl.text}')
              ? '# ${_titleCtrl.text}\n\n$processed'
              : processed;

          // Show creation date
          final created = _currentTab.note.createdAt;
          final dateStr = '${created.day}.${created.month.toString().padLeft(2, '0')}.${created.year} '
              '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
          final dateHeader = '*Создано: $dateStr*\n\n';

          return Markdown(
            data: dateHeader + displayContent,
            selectable: true,
            softLineBreak: true,
            padding: const EdgeInsets.all(16),
            styleSheet: MarkdownStyleSheet(
              h1: TextStyle(
                  fontSize: nfs + 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: noteFont,
                  color: cs.onSurface,
                  height: 1.3),
              h1Padding: const EdgeInsets.only(bottom: 8),
              h2: TextStyle(
                  fontSize: nfs + 7,
                  fontWeight: FontWeight.w600,
                  fontFamily: noteFont,
                  color: cs.onSurface,
                  height: 1.3),
              h2Padding: const EdgeInsets.only(bottom: 6, top: 16),
              h3: TextStyle(
                  fontSize: nfs + 3,
                  fontWeight: FontWeight.w600,
                  fontFamily: noteFont,
                  color: cs.onSurface,
                  height: 1.3),
              h3Padding: const EdgeInsets.only(bottom: 4, top: 12),
              p: TextStyle(fontSize: nfs, height: nlh, fontFamily: noteFont, color: cs.onSurface),
              pPadding: const EdgeInsets.only(bottom: 8),
              a: TextStyle(
                color: cs.primary,
                decoration: TextDecoration.underline,
                decorationColor: cs.primary.withValues(alpha: 0.4),
              ),
              code: TextStyle(
                fontSize: nfs - 1,
                fontFamily: 'monospace',
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.primary,
              ),
              codeblockDecoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              codeblockPadding: const EdgeInsets.all(12),
              blockquoteDecoration: BoxDecoration(
                border: Border(left: BorderSide(color: cs.primary, width: 3)),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              listBullet: TextStyle(color: cs.primary, fontSize: nfs),
              listIndent: 24,
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: cs.outlineVariant, width: 1),
                ),
              ),
              strong: TextStyle(fontWeight: FontWeight.w700, fontFamily: noteFont, color: cs.onSurface),
              em: TextStyle(fontStyle: FontStyle.italic, fontFamily: noteFont, color: cs.onSurface),
              del: TextStyle(
                decoration: TextDecoration.lineThrough,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              checkbox: TextStyle(color: cs.primary),
            ),
            onTapLink: (text, href, title) {
              if (href == null) return;
              if (href.startsWith('bible:')) {
                final decoded = Uri.decodeComponent(href.substring(6));
                _navigateToBibleRef(decoded);
              } else if (href.startsWith('note:')) {
                final decoded = Uri.decodeComponent(href.substring(5));
                _openLinkedNote(decoded);
              }
            },
          );
        },
      ),
    );
  }

  /// Convert org-style "+ item" lists to numbered "1. item" for preview
  String _convertPlusListsToNumbered(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    int counter = 0;
    String? currentIndent;

    for (final line in lines) {
      final m = RegExp(r'^(\s*)\+\s(.*)').firstMatch(line);
      if (m != null) {
        final indent = m.group(1)!;
        if (currentIndent == null || indent != currentIndent) {
          counter = 0;
          currentIndent = indent;
        }
        counter++;
        result.add('$indent$counter. ${m.group(2)}');
      } else {
        if (!RegExp(r'^\s*\+\s').hasMatch(line)) {
          counter = 0;
          currentIndent = null;
        }
        result.add(line);
      }
    }
    return result.join('\n');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Markdown formatting toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _MarkdownToolbar extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onStrikethrough;
  final VoidCallback onCode;
  final VoidCallback onH1;
  final VoidCallback onH2;
  final VoidCallback onH3;
  final VoidCallback onBulletList;
  final VoidCallback onNumberedList;
  final VoidCallback onCheckbox;
  final VoidCallback onBlockquote;
  final VoidCallback onHorizontalRule;
  final VoidCallback onBibleRef;
  final VoidCallback onBibleQuote;
  final VoidCallback onNoteLink;

  const _MarkdownToolbar({
    required this.cs,
    required this.onBold,
    required this.onItalic,
    required this.onStrikethrough,
    required this.onCode,
    required this.onH1,
    required this.onH2,
    required this.onH3,
    required this.onBulletList,
    required this.onNumberedList,
    required this.onCheckbox,
    required this.onBlockquote,
    required this.onHorizontalRule,
    required this.onBibleRef,
    required this.onBibleQuote,
    required this.onNoteLink,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            _btn(Icons.format_bold, 'Жирный', onBold),
            _btn(Icons.format_italic, 'Курсив', onItalic),
            _btn(Icons.strikethrough_s, 'Зачёркнутый', onStrikethrough),
            _btn(Icons.code, 'Код', onCode),
            _divider(),
            _headerBtn('H1', onH1),
            _headerBtn('H2', onH2),
            _headerBtn('H3', onH3),
            _divider(),
            _btn(Icons.format_list_bulleted, 'Маркированный', onBulletList),
            _btn(Icons.format_list_numbered, 'Нумерованный', onNumberedList),
            _btn(Icons.check_box_outlined, 'Чекбокс', onCheckbox),
            _btn(Icons.format_quote, 'Цитата', onBlockquote),
            _btn(Icons.horizontal_rule, 'Линия', onHorizontalRule),
            _divider(),
            _btn(Icons.menu_book, 'Ссылка на стих', onBibleRef),
            _btn(Icons.format_quote_rounded, 'Цитата стиха', onBibleQuote),
            _btn(Icons.link, 'Ссылка на заметку', onNoteLink),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20,
              color: cs.onSurface.withValues(alpha: 0.8)),
        ),
      ),
    );
  }

  Widget _headerBtn(String label, VoidCallback onTap) {
    return Tooltip(
      message: 'Заголовок $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outlineVariant,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TextEditingController that highlights [[...]] links
// ─────────────────────────────────────────────────────────────────────────────

class _LinkHighlightController extends TextEditingController {
  _LinkHighlightController({super.text});

  static final _linkPattern = RegExp(r'\[\[([^\]]+)\]\]|\{\{([^}]+)\}\}');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    if (t.isEmpty) return TextSpan(style: style, text: t);

    final linkColor = Theme.of(context).colorScheme.primary;
    final quoteColor = Theme.of(context).colorScheme.tertiary;
    final children = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _linkPattern.allMatches(t)) {
      if (match.start > lastEnd) {
        children
            .add(TextSpan(text: t.substring(lastEnd, match.start), style: style));
      }
      final isQuote = match.group(0)!.startsWith('{{');
      final color = isQuote ? quoteColor : linkColor;
      children.add(TextSpan(
        text: match.group(0),
        style: style?.copyWith(
          color: color,
          decoration: TextDecoration.underline,
          decorationColor: color.withValues(alpha: 0.5),
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < t.length) {
      children.add(TextSpan(text: t.substring(lastEnd), style: style));
    }

    if (children.isEmpty) return TextSpan(style: style, text: t);
    return TextSpan(children: children, style: style);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-list text field with optional typewriter scroll
// ─────────────────────────────────────────────────────────────────────────────

class _AutoListTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final VoidCallback onNewLine;
  final bool typewriterMode;
  final TextStyle style;
  final InputDecoration decoration;

  const _AutoListTextField({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.onNewLine,
    required this.typewriterMode,
    required this.style,
    required this.decoration,
  });

  @override
  State<_AutoListTextField> createState() => _AutoListTextFieldState();
}

class _AutoListTextFieldState extends State<_AutoListTextField> {
  int _prevLength = 0;
  int _prevNewlines = 0;

  @override
  void initState() {
    super.initState();
    _prevLength = widget.controller.text.length;
    _prevNewlines = '\n'.allMatches(widget.controller.text).length;
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final newlines = '\n'.allMatches(text).length;

    // Detect newline insertion (not deletion)
    if (text.length > _prevLength && newlines > _prevNewlines) {
      // Defer to after the text is committed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onNewLine();
        // Typewriter: keep cursor in center of visible area
        if (widget.typewriterMode) {
          _scrollToCursorCenter();
        }
      });
    }

    _prevLength = text.length;
    _prevNewlines = newlines;
  }

  void _scrollToCursorCenter() {
    final sc = widget.scrollController;
    if (!sc.hasClients) return;
    // Estimate cursor position from line count up to cursor
    final sel = widget.controller.selection;
    if (!sel.isValid) return;
    final textBeforeCursor = widget.controller.text.substring(0, sel.baseOffset);
    final lineCount = '\n'.allMatches(textBeforeCursor).length;
    final lineHeightEstimate = widget.style.fontSize! * (widget.style.height ?? 1.5);
    final cursorY = lineCount * lineHeightEstimate;
    final viewportHeight = sc.position.viewportDimension;
    final targetOffset = (cursorY - viewportHeight / 2).clamp(0.0, sc.position.maxScrollExtent);
    sc.animateTo(targetOffset, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollController: widget.scrollController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: widget.style,
      decoration: widget.decoration,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Note font settings bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _NoteFontSettingsSheet extends StatefulWidget {
  final AppState appState;
  const _NoteFontSettingsSheet({required this.appState});

  @override
  State<_NoteFontSettingsSheet> createState() => _NoteFontSettingsSheetState();
}

class _NoteFontSettingsSheetState extends State<_NoteFontSettingsSheet> {
  late double _fontSize;
  late double _lineHeight;
  late String _fontFamily;
  late bool _typewriter;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.appState.noteFontSize;
    _lineHeight = widget.appState.noteLineHeight;
    _fontFamily = widget.appState.noteFontFamily;
    _typewriter = widget.appState.typewriterMode;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Шрифт заметок',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 16),
            // Font family
            Text('Шрифт', style: TextStyle(fontSize: 13, color: cs.secondary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: AppState.availableFonts.entries.map((e) {
                final selected = _fontFamily == e.key;
                return ChoiceChip(
                  label: Text(e.value, style: TextStyle(fontFamily: e.value, fontSize: 13)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _fontFamily = e.key);
                    widget.appState.setNoteFontFamily(e.key);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Font size
            Row(
              children: [
                SizedBox(
                    width: 100,
                    child: Text('Размер: ${_fontSize.round()}',
                        style: TextStyle(fontSize: 13, color: cs.secondary))),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 10,
                    max: 32,
                    divisions: 22,
                    onChanged: (v) {
                      setState(() => _fontSize = v);
                      widget.appState.setNoteFontSize(v);
                    },
                  ),
                ),
              ],
            ),
            // Line height
            Row(
              children: [
                SizedBox(
                    width: 100,
                    child: Text('Межстрочный: ${_lineHeight.toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 13, color: cs.secondary))),
                Expanded(
                  child: Slider(
                    value: _lineHeight,
                    min: 1.0,
                    max: 2.5,
                    divisions: 15,
                    onChanged: (v) {
                      setState(() => _lineHeight = v);
                      widget.appState.setNoteLineHeight(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Typewriter mode toggle
            SwitchListTile(
              title: const Text('Режим печатной машинки',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text('Активная строка по центру',
                  style: TextStyle(fontSize: 12, color: cs.secondary)),
              value: _typewriter,
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                setState(() => _typewriter = v);
                widget.appState.setTypewriterMode(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}