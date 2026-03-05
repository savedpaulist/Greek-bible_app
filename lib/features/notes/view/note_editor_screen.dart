// lib/features/notes/view/note_editor_screen.dart

import 'dart:async';
import 'dart:ui';
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
import '../widgets/auto_list_text_field.dart';
import '../widgets/format_toolbar.dart';
import '../widgets/markdown_highlight_controller.dart';
import '../widgets/note_font_settings_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Per-tab state container
// ─────────────────────────────────────────────────────────────────────────────
class _TabData {
  NoteModel note;
  final TextEditingController titleCtrl;
  final MarkdownHighlightController contentCtrl;
  bool preview;

  _TabData({required this.note, required String title, required String content})
      : titleCtrl = TextEditingController(text: title),
        contentCtrl = MarkdownHighlightController(text: content),
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
  bool _contentVisible = false;
  // ── Tab management ──────────────────────────────────────────────────────
  final List<_TabData> _tabs = [];
  int _activeTabIdx = 0;

  _TabData get _currentTab => _tabs[_activeTabIdx];

  // Convenience accessors (delegate to current tab)
  TextEditingController get _titleCtrl => _currentTab.titleCtrl;
  MarkdownHighlightController get _contentCtrl => _currentTab.contentCtrl;
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
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _contentVisible = true);
    });
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
      builder: (ctx) => NoteFontSettingsSheet(appState: appState),
    );
  }

  // ── Enter edit mode (cursor placement by tap position) ──────────────────

  void _enterEditMode({Offset? tapPosition}) {
    setState(() => _preview = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (tapPosition != null) {
        final offset = _estimateCursorOffset(tapPosition);
        _contentCtrl.selection = TextSelection.collapsed(offset: offset);
      } else {
        final text = _contentCtrl.text;
        if (text.isNotEmpty) {
          _contentCtrl.selection = TextSelection.collapsed(offset: text.length);
        }
      }
      _contentFocus.requestFocus();
    });
  }

  /// Estimate the text offset from a tap position in the preview area.
  /// Uses line height and font size to approximate which line & character
  /// was tapped, then maps back to the raw markdown text offset.
  int _estimateCursorOffset(Offset localPosition) {
    final appState = context.read<AppState>();
    final fontSize = appState.noteFontSize;
    final lineHeight = appState.noteLineHeight;
    final lineH = fontSize * lineHeight;
    final text = _contentCtrl.text;
    if (text.isEmpty) return 0;

    // Account for padding (16 top in preview)
    final y = (localPosition.dy - 16).clamp(0.0, double.infinity);
    // Account for title header + date header (~2 extra lines)
    final headerLines = _titleCtrl.text.isNotEmpty ? 3 : 1;
    final tappedLine = ((y / lineH) - headerLines).clamp(0.0, double.infinity).floor();

    final lines = text.split('\n');
    // Find which line in the raw text
    int charOffset = 0;
    for (int i = 0; i < lines.length && i < tappedLine; i++) {
      charOffset += lines[i].length + 1; // +1 for '\n'
    }

    // Estimate horizontal position within the line
    final x = (localPosition.dx - 16).clamp(0.0, double.infinity);
    final charWidth = fontSize * 0.55; // approximate monospace-like width
    final charInLine = (x / charWidth).floor();

    if (tappedLine < lines.length) {
      charOffset += charInLine.clamp(0, lines[tappedLine].length);
    }

    return charOffset.clamp(0, text.length);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _detachListeners();
    _contentFocus.unfocus();
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
    FocusScope.of(context).unfocus();
    setState(() {
      _activeTabIdx = index;
    });
    _attachListeners();
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) {
      // Last tab — go back
      FocusScope.of(context).unfocus();
      _contentFocus.unfocus();
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
    _contentFocus.unfocus();
    FocusScope.of(context).unfocus();
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
      child: Stack(
        children: [
          // ── Основной контент с отступом под AppBar ──
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 56),
              _buildTabBar(cs),
              Expanded(
                child: _preview ? _buildPreview(cs, appState) : _buildEditor(cs, appState),
              ),
            ],
          ),
          // ── Размытая плавающая панель сверху ──────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: MediaQuery.of(context).padding.top + 56,
                  color: Theme.of(context).canvasColor.withValues(alpha: 0.85),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
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
                        IconButton(
                          icon: const Icon(Icons.text_format, size: 22),
                          tooltip: 'Настройки шрифта',
                          onPressed: _showNoteFontSettings,
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          tooltip: 'Экспорт .md',
                          onPressed: _exportMarkdown,
                        ),
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
                  ),
                ),
              ),
            ),
          ),
        ],
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: AnimatedOpacity(
        opacity: _contentVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeIn,
        child: Column(
          children: [
            if (_activeLinkTarget != null) _buildLinkBar(cs),
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
                decoration: InputDecoration.collapsed(
                  hintText: 'Название заметки',
                  hintStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                maxLines: 1,
              ),
            ),
            AnimatedOpacity(
              opacity: _contentVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  'Изменено: ' + _currentTab.note.updatedAt.toString(),
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AutoListTextField(
                  controller: _contentCtrl,
                  focusNode: _contentFocus,
                  scrollController: _scrollController,
                  onNewLine: _handleNewLine,
                  typewriterMode: true,
                  style: TextStyle(
                    fontSize: noteFontSize,
                    fontFamily: noteFontDisplay,
                    height: noteLineH,
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Содержание (Markdown)…',
                    hintStyle: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
            MarkdownToolbar(
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
          ],
        ),
      ),
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
      // Tap anywhere in preview → switch to edit mode at tap position
      onTapUp: (details) => _enterEditMode(tapPosition: details.localPosition),
      behavior: HitTestBehavior.opaque,
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
            selectable: false,
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


// Extracted classes are now in ../widgets/:
//   MarkdownHighlightController → markdown_highlight_controller.dart
//   AutoListTextField → auto_list_text_field.dart
//   MarkdownToolbar → format_toolbar.dart
//   NoteFontSettingsSheet → note_font_settings_sheet.dart