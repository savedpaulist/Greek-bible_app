// lib/features/home/view/comment_sheets.dart
//
// Bottom sheets for parallel verses and comments,
// plus the AddParallelDialog picker.
// Extracted from home_screen.dart for maintainability.

import 'package:flutter/material.dart';

import '../../../core/db/db_service.dart';
import '../../../core/models/models.dart';
import 'book_chapter_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Parallel Verses bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class ParallelVersesSheet extends StatefulWidget {
  final List<ParallelVerse> parallels;
  final List<BookModel> books;
  final DBService db;
  final void Function(ParallelVerse) onNavigate;
  final void Function(String id) onDelete;

  const ParallelVersesSheet({
    super.key,
    required this.parallels,
    required this.books,
    required this.db,
    required this.onNavigate,
    required this.onDelete,
  });

  @override
  State<ParallelVersesSheet> createState() => _ParallelVersesSheetState();
}

class _ParallelVersesSheetState extends State<ParallelVersesSheet> {
  /// Index of the currently expanded verse (-1 = none).
  int _expandedIndex = -1;

  /// Cached verse text per index.
  final Map<int, String> _verseTexts = {};

  /// Loading state per index.
  final Set<int> _loading = {};

  String _bookName(int num) =>
      widget.books
          .where((b) => b.bookNumber == num)
          .firstOrNull
          ?.shortName ??
      '# $num';

  Future<void> _loadVerseText(int index) async {
    if (_verseTexts.containsKey(index)) return;
    setState(() => _loading.add(index));
    final p = widget.parallels[index];
    final words =
        await widget.db.getVerseWords(p.targetBook, p.targetChapter, p.targetVerse);
    final text = words.map((w) => w.word).join(' ');
    if (!mounted) return;
    setState(() {
      _verseTexts[index] = text;
      _loading.remove(index);
    });
  }

  void _onTap(int index) {
    final p = widget.parallels[index];
    if (_expandedIndex == index) {
      // Second tap — navigate
      widget.onNavigate(p);
    } else {
      // First tap — show verse text
      setState(() => _expandedIndex = index);
      _loadVerseText(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text('Параллельные стихи',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.parallels.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = widget.parallels[i];
                final isExpanded = _expandedIndex == i;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(
                        '${_bookName(p.targetBook)} ${p.targetChapter}:${p.targetVerse}',
                        style: TextStyle(color: cs.primary),
                      ),
                      subtitle: isExpanded
                          ? Text('Нажмите ещё раз для перехода',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.5)))
                          : null,
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: cs.error),
                        onPressed: () => widget.onDelete(p.id),
                      ),
                      onTap: () => _onTap(i),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _loading.contains(i)
                            ? const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child:
                                    SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : Text(
                                _verseTexts[i] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: cs.onSurface.withValues(alpha: 0.85),
                                ),
                              ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class CommentsSheet extends StatelessWidget {
  final List<VerseComment> comments;
  final VerseModel verse;
  final void Function(String id) onDelete;
  final void Function(VerseComment) onEdit;

  const CommentsSheet({
    super.key,
    required this.comments,
    required this.verse,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'Комментарии к ${verse.chapter}:${verse.verse}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: comments.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = comments[i];
                return ListTile(
                  title: Text(c.text),
                  subtitle: Text(
                    _formatDate(c.updatedAt),
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 18, color: cs.primary),
                        onPressed: () => onEdit(c),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: cs.error),
                        onPressed: () => onDelete(c.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Add parallel verse dialog  (reuses unified BookChapterPicker)
// ─────────────────────────────────────────────────────────────────────────────
class AddParallelDialog extends StatelessWidget {
  final VerseModel sourceVerse;
  final int sourceBook;
  final Future<void> Function(int book, int chapter, int verse) onAdd;

  const AddParallelDialog({
    super.key,
    required this.sourceVerse,
    required this.sourceBook,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return BookChapterPicker(
      maxHeightFraction: 0.7,
      onSelect: (book, chapter, verse) => onAdd(book, chapter, verse),
    );
  }
}
