// lib/features/home/view/book_chapter_dialog.dart
//
// Unified Book + Chapter + Verse picker dialog (3 steps).
// Used by both the main navigation and the parallel-verse picker.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/themes.dart';

const double kBookGridFontSize = 24.0;

// ─────────────────────────────────────────────────────────────────────────────
// Reusable 3-step picker: book → chapter → verse.
//
// [onSelect] is called with (book, chapter, verse) when the user completes
// all three steps.  Pass [highlightCurrent] = true to mark the currently
// active book / chapter / verse from AppState.
// ─────────────────────────────────────────────────────────────────────────────
class BookChapterPicker extends StatefulWidget {
  const BookChapterPicker({
    super.key,
    required this.onSelect,
    this.highlightCurrent = false,
    this.maxHeightFraction = 0.82,
  });

  /// Called when all three steps are complete.
  final void Function(int book, int chapter, int verse) onSelect;

  /// Whether to visually highlight the currently open book/chapter/verse.
  final bool highlightCurrent;

  /// Maximum height of the dialog as a fraction of the screen height.
  final double maxHeightFraction;

  @override
  State<BookChapterPicker> createState() => _BookChapterPickerState();
}

enum _Step { book, chapter, verse }

class _BookChapterPickerState extends State<BookChapterPicker> {
  _Step _step          = _Step.book;
  int   _pickedBook    = -1;
  int   _pickedChapter = 1;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hl = widget.highlightCurrent;

    const titles = {
      _Step.book:    'Выберите книгу',
      _Step.chapter: 'Выберите главу',
      _Step.verse:   'Выберите стих',
    };

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height *
                widget.maxHeightFraction),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(children: [
                if (_step != _Step.book)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      _step = _step == _Step.verse ? _Step.chapter : _Step.book;
                    }),
                  ),
                Expanded(
                    child: Text(titles[_step]!,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold))),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            const Divider(height: 1),

            Flexible(
              child: switch (_step) {
                // ── Шаг 1: выбор книги ───────────────────────────────────
                _Step.book => _PickerGrid(
                    childAspectRatio: 1.5,
                    items: state.books
                        .map((b) {
                          final seg = segmentForBook(b.bookNumber);
                          return GridItem(
                            label: b.shortName,
                            selected:
                                hl && b.bookNumber == state.currentBook,
                            color: state.segmentColors[seg],
                          );
                        })
                        .toList(),
                    onTap: (idx) {
                      _pickedBook = state.books[idx].bookNumber;
                      setState(() => _step = _Step.chapter);
                    },
                  ),

                // ── Шаг 2: выбор главы ───────────────────────────────────
                _Step.chapter => FutureBuilder<int>(
                    future: state.db.getChapterCount(_pickedBook),
                    builder: (_, snap) {
                      final count = snap.data ?? 0;
                      if (count == 0) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final bookColor = state.segmentColors[segmentForBook(_pickedBook)];
                      return _PickerGrid(
                        childAspectRatio: 1.2,
                        items: List.generate(count, (i) {
                          final ch = i + 1;
                          return GridItem(
                            label: '$ch',
                            selected: hl &&
                                _pickedBook == state.currentBook &&
                                ch == state.currentChapter,
                            color: bookColor,
                          );
                        }),
                        onTap: (idx) {
                          _pickedChapter = idx + 1;
                          setState(() => _step = _Step.verse);
                        },
                      );
                    },
                  ),

                // ── Шаг 3: выбор стиха ──────────────────────────────────
                _Step.verse => FutureBuilder<int>(
                    future:
                        state.db.getVerseCount(_pickedBook, _pickedChapter),
                    builder: (_, snap) {
                      final count = snap.data ?? 0;
                      if (count == 0) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final bookColor = state.segmentColors[segmentForBook(_pickedBook)];
                      return _PickerGrid(
                        childAspectRatio: 1.2,
                        items: List.generate(count, (i) {
                          final v = i + 1;
                          return GridItem(
                            label: '$v',
                            selected: hl &&
                                _pickedBook == state.currentBook &&
                                _pickedChapter == state.currentChapter &&
                                v == state.currentVerse,
                            color: bookColor,
                          );
                        }),
                        onTap: (idx) {
                          Navigator.pop(context);
                          widget.onSelect(
                              _pickedBook, _pickedChapter, idx + 1);
                        },
                      );
                    },
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience wrapper: BookChapterDialog for main navigation
// ─────────────────────────────────────────────────────────────────────────────
class BookChapterDialog extends StatelessWidget {
  const BookChapterDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BookChapterPicker(
      highlightCurrent: true,
      onSelect: (book, chapter, verse) {
        context.read<AppState>().navigateToVerse(book, chapter, verse);
      },
    );
  }
}

// ── Универсальная сетка ───────────────────────────────────────────────────────
class GridItem {
  final String label;
  final bool   selected;
  final Color? color;
  const GridItem({required this.label, this.selected = false, this.color});
}

class _PickerGrid extends StatelessWidget {
  final List<GridItem>     items;
  final void Function(int) onTap;
  final double childAspectRatio;
  const _PickerGrid({
    required this.items,
    required this.onTap,
    this.childAspectRatio = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (_, idx) {
        final item = items[idx];
        final bgColor = item.selected
            ? Theme.of(context).colorScheme.primary
            : (item.color ?? Theme.of(context).colorScheme.surfaceContainerHighest);
        return InkWell(
          onTap: () => onTap(idx),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: kBookGridFontSize,
                color: item.selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}
