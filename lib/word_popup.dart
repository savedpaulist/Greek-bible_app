// lib/word_popup.dart
//
// Popup widgets for word details, verse previews, and dictionary entries.
// Uses the lightweight HTML parser (core/html_parser.dart) instead of
// flutter_html for dramatically better performance.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/bible_utils.dart';
import 'core/html_parser.dart';
import 'core/models/models.dart';
import 'core/app_state.dart';
import 'core/db/db_service.dart';
import 'core/themes.dart';
import 'features/dictionary/provider/dictionary_provider.dart';
import 'features/dictionary/view/dictionary_article_screen.dart';
import 'features/notes/provider/notes_provider.dart';

// Re-export for backward compatibility
export 'core/bible_utils.dart' show BibleLinkCallback;

// ─────────────────────────────────────────────────────────────────────────────
// Global word overlay singleton — one popup at a time, from anywhere
// ─────────────────────────────────────────────────────────────────────────────
OverlayEntry? _globalWordOverlay;

/// Dismiss the currently visible word popup overlay (if any).
void dismissWordOverlay() {
  _globalWordOverlay?.remove();
  _globalWordOverlay = null;
}

/// Show a [WordQuickView] overlay popup for [word] near the widget at [ctx].
///
/// This is the single entry-point used by [WordTile], [VerseWordRow], and any
/// other place that needs a word popup.  It manages a global singleton overlay
/// so only one popup is visible at a time.
void showWordOverlayPopup({
  required BuildContext ctx,
  required WordModel word,
  required dynamic db,
  required double fontSize,
  double? popupFontSize,
  BibleLinkCallback? onBibleLink,
  VoidCallback? onWordCommentChanged,
}) {
  dismissWordOverlay();

  final box = ctx.findRenderObject() as RenderBox;
  final offset = box.localToGlobal(Offset.zero);
  final sz = box.size;
  final sw = MediaQuery.of(ctx).size.width;
  final sh = MediaQuery.of(ctx).size.height;
  final popupWidth = (sw * 0.72).clamp(300.0, 540.0);
  final popupHeight = (sh * 0.50).clamp(180.0, 520.0);
  const gap = 4.0;

  final wordBottom = offset.dy + sz.height;
  final spaceBelow = sh - wordBottom;
  final spaceAbove = offset.dy;

  // 30/70 split: open above unless word is in the top 30 %
  final double popupTop;
  if (spaceAbove < sh * 0.3 && spaceBelow >= popupHeight + gap + 8) {
    popupTop = wordBottom + gap;
  } else if (spaceAbove >= popupHeight + gap + 8) {
    popupTop = offset.dy - popupHeight - gap;
  } else if (spaceBelow >= popupHeight + gap + 8) {
    popupTop = wordBottom + gap;
  } else {
    popupTop = spaceBelow >= spaceAbove
        ? (wordBottom + gap).clamp(8.0, sh - popupHeight - 8)
        : (offset.dy - popupHeight - gap).clamp(8.0, sh - popupHeight - 8);
  }

  // Use the root overlay so the popup is above everything (including modals)
  final rootOverlay = Overlay.of(ctx, rootOverlay: true);

  final overlay = OverlayEntry(
      builder: (_) => FocusScope(
            autofocus: false,
            child: Stack(children: [
              // Tap-away dismiss layer
              Positioned.fill(
                  child: GestureDetector(
                onTap: dismissWordOverlay,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              )),
              // Popup
              Positioned(
                left: (offset.dx - popupWidth / 2 + sz.width / 2)
                    .clamp(8.0, sw - popupWidth - 8),
                top: popupTop,
                width: popupWidth,
                child: LimitedBox(
                  maxHeight: popupHeight,
                  child: WordQuickView(
                    word: word,
                    db: db,
                    fontSize: fontSize,
                    popupFontSize: popupFontSize,
                    onClose: dismissWordOverlay,
                    onBibleLink: onBibleLink != null
                        ? (b, ch, v) {
                            dismissWordOverlay();
                            onBibleLink(b, ch, v);
                          }
                        : null,
                    onWordCommentChanged: onWordCommentChanged,
                  ),
                ),
              ),
            ]),
          ));

  _globalWordOverlay = overlay;
  rootOverlay.insert(overlay);
}

// ─────────────────────────────────────────────────────────────────────────────
// WordUnderline — custom-painted underline with adjustable offset
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [child] and paints an underline below it at a configurable [offset].
///
/// Replaces [TextDecoration.underline] to give control over vertical position
/// and to properly render all [MarkupKind] styles including dash-dot.
class WordUnderline extends StatelessWidget {
  final Widget child;
  final MarkupKind kind;
  final Color color;
  final double thickness;

  /// Extra pixels below the text reserved for the underline.
  final double offset;

  const WordUnderline({
    super.key,
    required this.child,
    required this.kind,
    required this.color,
    this.thickness = 1.5,
    this.offset = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _WordUnderlinePainter(
        kind: kind,
        color: color,
        thickness: thickness,
        offset: offset,
      ),
      child: child,
    );
  }
}

class _WordUnderlinePainter extends CustomPainter {
  final MarkupKind kind;
  final Color color;
  final double thickness;
  final double offset;

  _WordUnderlinePainter({
    required this.kind,
    required this.color,
    required this.thickness,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    // Draw at the bottom of the child area (inside the bottom-padding zone)
    final y = size.height - offset / 2;
    final w = size.width;

    switch (kind) {
      case MarkupKind.underlineSingle:
        canvas.drawLine(Offset(0, y), Offset(w, y), paint);
        break;
      case MarkupKind.underlineDouble:
        canvas.drawLine(Offset(0, y - 2.5), Offset(w, y - 2.5), paint);
        canvas.drawLine(Offset(0, y + 2), Offset(w, y + 2), paint);
        break;
      case MarkupKind.underlineWavy:
        final path = Path()..moveTo(0, y);
        const amp = 1.8, wl = 6.0;
        for (double x = 0; x < w; x += wl) {
          path.quadraticBezierTo(x + wl / 4, y - amp, x + wl / 2, y);
          path.quadraticBezierTo(x + wl * 3 / 4, y + amp, x + wl, y);
        }
        canvas.drawPath(path, paint);
        break;
      case MarkupKind.underlineDashed:
        _drawDashes(canvas, paint, y, w, dashLen: 8, gapLen: 5);
        break;
      case MarkupKind.underlineDotted:
        final dotPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        for (double x = 1; x < w; x += 5.0) {
          canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
        }
        break;
      case MarkupKind.underlineDashDot:
        // Pattern: _._._. — alternating dash and dot with even spacing
        final dotPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        double x = 0;
        while (x < w) {
          // dash
          final dashEnd = (x + 6).clamp(0.0, w);
          canvas.drawLine(Offset(x, y), Offset(dashEnd, y), paint);
          x += 6 + 3; // dash + gap
          if (x >= w) break;
          // dot
          canvas.drawCircle(Offset(x + 0.5, y), 0.9, dotPaint);
          x += 1.5 + 3; // dot width + gap
        }
        break;
      case MarkupKind.background:
        break; // no underline
    }
  }

  void _drawDashes(Canvas canvas, Paint paint, double y, double w,
      {required double dashLen, required double gapLen}) {
    double x = 0;
    while (x < w) {
      canvas.drawLine(
          Offset(x, y), Offset((x + dashLen).clamp(0, w), y), paint);
      x += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _WordUnderlinePainter old) =>
      kind != old.kind ||
      color != old.color ||
      thickness != old.thickness ||
      offset != old.offset;
}

// ─────────────────────────────────────────────────────────────────────────────
// Strong's definition HTML cleanup
// ─────────────────────────────────────────────────────────────────────────────

/// Cleans up Strong's dictionary HTML:
/// 1. Merges float:left word div + float:right {part of speech} div into one line.
/// 2. Removes the extra <br/> between the header and definition body.
/// 3. Removes consecutive empty paragraphs / line breaks and leading/trailing whitespace.
// Note: RegExp-based HTML cleanup removed. We now pass raw HTML
// through the project's HTML parser dependency and let it handle
// presentation/cleanup. The previous `cleanStrongsHtml` function was
// removed to avoid fragile RegExp manipulations.

// ─────────────────────────────────────────────────────────────────────────────
// Shared popup header
// ─────────────────────────────────────────────────────────────────────────────

class PopupHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? strongs;
  final bool loading;
  final double fontSize;
  final VoidCallback? onExpand;
  final VoidCallback? onClose;

  const PopupHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.strongs,
    this.loading = false,
    required this.fontSize,
    this.onExpand,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: fontSize - 3,
                    fontStyle: FontStyle.italic,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (strongs != null) ...[
                const Spacer(),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'G$strongs',
                    style: TextStyle(
                      fontSize: fontSize - 4,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onExpand != null) ...[
          GestureDetector(
            onTap: onExpand,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.open_in_full,
                  size: 18, color: cs.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 4),
        ],
        if (onClose != null)
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close, size: 18, color: cs.onPrimaryContainer),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WordQuickView — compact popup over a word in the text
// ─────────────────────────────────────────────────────────────────────────────

class WordQuickView extends StatefulWidget {
  final WordModel word;
  final DBService db;
  final double fontSize;
  final double? popupFontSize;
  final VoidCallback onClose;
  final BibleLinkCallback? onBibleLink;
  final VoidCallback? onWordCommentChanged;

  const WordQuickView({
    super.key,
    required this.word,
    required this.db,
    required this.fontSize,
    required this.onClose,
    this.popupFontSize,
    this.onBibleLink,
    this.onWordCommentChanged,
  });

  @override
  State<WordQuickView> createState() => _WordQuickViewState();
}

class _WordQuickViewState extends State<WordQuickView> {
  WordDetail? _detail;
  bool _loading = true;
  WordComment? _wordComment;
  WordMarkup? _wordHighlight; // word-level background markup
  WordMarkup? _wordUnderline; // word-level underline markup
  bool _editingComment = false;
  final _commentCtrl = TextEditingController();
  Timer? _commentSaveTimer;

  // Cached references — safe to use in dispose()
  late final NotesProvider _notes;
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _notes = context.read<NotesProvider>();
    _appState = context.read<AppState>();
    _load();
    _commentCtrl.addListener(_scheduleCommentSave);
  }

  @override
  void dispose() {
    _commentSaveTimer?.cancel();
    // Save immediately on close if editing
    if (_editingComment) _saveComment();
    _commentCtrl.removeListener(_scheduleCommentSave);
    _commentCtrl.dispose();
    super.dispose();
  }

  void _scheduleCommentSave() {
    if (!_editingComment) return;
    _commentSaveTimer?.cancel();
    _commentSaveTimer = Timer(const Duration(milliseconds: 800), _saveComment);
  }

  Future<void> _load() async {
    final d = await widget.db.getWordDetail(widget.word, language: _appState.language);
    // Debug: print raw HTML from dictionary for inspection
    // ignore: avoid_print
    //print('RAW definitionHtml for "${widget.word.word}" (${widget.word.strongs}):\n${d.definitionHtml}\n---END---');
    WordComment? wc;
    WordMarkup? wh;
    WordMarkup? wu;
    if (mounted) {
      wc = await _notes.getWordComment(
        _appState.currentBook,
        widget.word.chapter,
        widget.word.verse,
        widget.word.wordNumber,
      );
      // Load word-level markups
      final markups = await _notes.getMarkupsForChapter(
        _appState.currentBook,
        widget.word.chapter,
      );
      final wordMarkups = markups.where(
        (m) =>
            m.verse == widget.word.verse &&
            m.wordNumber == widget.word.wordNumber,
      );
      wh =
          wordMarkups.where((m) => m.kind == MarkupKind.background).firstOrNull;
      wu =
          wordMarkups.where((m) => m.kind != MarkupKind.background).firstOrNull;
    }
    if (!mounted) return;
    setState(() {
      _detail = d;
      _wordComment = wc;
      _wordHighlight = wh;
      _wordUnderline = wu;
      if (wc != null) _commentCtrl.text = wc.text;
      _loading = false;
    });
  }

  Future<void> _saveComment({bool closeEditing = false}) async {
    final text = _commentCtrl.text.trim();
    if (!mounted) {
      // Called from dispose — fire-and-forget using cached refs
      if (text.isNotEmpty) {
        if (_wordComment != null) {
          await _notes.deleteWordComment(_wordComment!.id);
        }
        await _notes.addWordComment(
          _appState.currentBook,
          widget.word.chapter,
          widget.word.verse,
          widget.word.wordNumber,
          text,
        );
        widget.onWordCommentChanged?.call();
      }
      return;
    }
    if (text.isEmpty) {
      if (_wordComment != null) {
        await _notes.deleteWordComment(_wordComment!.id);
        if (!mounted) return;
        setState(() {
          _wordComment = null;
          if (closeEditing) _editingComment = false;
        });
        widget.onWordCommentChanged?.call();
      }
      return;
    }
    if (_wordComment != null) {
      await _notes.deleteWordComment(_wordComment!.id);
    }
    final wc = await _notes.addWordComment(
      _appState.currentBook,
      widget.word.chapter,
      widget.word.verse,
      widget.word.wordNumber,
      text,
    );
    if (!mounted) return;
    setState(() {
      _wordComment = wc;
      if (closeEditing) _editingComment = false;
    });
    widget.onWordCommentChanged?.call();
  }

  void _openFullScreen() {
    if (_detail == null || !mounted) return;
    final detail = _detail!;
    final word = widget.word;
    final onBibleLink = widget.onBibleLink;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => WordFullView(
        word: word,
        detail: detail,
        fontSize: widget.fontSize,
        db: widget.db,
        onBibleLink: onBibleLink,
      ),
    );
    widget.onClose();
  }

  Future<void> _setWordHighlight(Color color) async {
    if (!mounted) return;
    // Remove existing highlight
    if (_wordHighlight != null) {
      await _notes.deleteMarkup(_wordHighlight!.id);
    }
    final m = WordMarkup(
      id: '${_appState.currentBook}_${widget.word.chapter}_${widget.word.verse}_${widget.word.wordNumber}_bg',
      bookNumber: _appState.currentBook,
      chapter: widget.word.chapter,
      verse: widget.word.verse,
      wordNumber: widget.word.wordNumber,
      kind: MarkupKind.background,
      colorIndex: 0,
      colorValue: color.toARGB32(),
    );
    await _notes.addMarkup(m);
    if (!mounted) return;
    setState(() => _wordHighlight = m);
    widget.onWordCommentChanged?.call();
  }

  Future<void> _removeWordHighlight() async {
    if (!mounted || _wordHighlight == null) return;
    await _notes.deleteMarkup(_wordHighlight!.id);
    if (!mounted) return;
    setState(() => _wordHighlight = null);
    widget.onWordCommentChanged?.call();
  }

  // Preset word highlight colours (semi-transparent for readability)
  static const _presetHighlightColors = <Color>[
    Color(0x40FFEB3B), // yellow
    Color(0x4066BB6A), // green
    Color(0x4042A5F5), // blue
    Color(0x40EF5350), // red
  ];

  // Underline style definitions
  static const _underlineKinds = <MarkupKind>[
    MarkupKind.underlineSingle,
    MarkupKind.underlineDouble,
    MarkupKind.underlineDashed,
    MarkupKind.underlineWavy,
    MarkupKind.underlineDotted,
    MarkupKind.underlineDashDot,
  ];

  static const _underlineLabels = <MarkupKind, String>{
    MarkupKind.underlineSingle: '──',
    MarkupKind.underlineDouble: '══',
    MarkupKind.underlineDashed: '╌╌',
    MarkupKind.underlineWavy: '∿∿',
    MarkupKind.underlineDotted: '····',
    MarkupKind.underlineDashDot: '╌·╌',
  };

  // Preset underline colours
  static const _presetUnderlineColors = <Color>[
    Color(0xFFE53935), // red
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFFFF8F00), // amber
    Color(0xFF8E24AA), // purple
  ];

  Future<void> _setWordUnderline(MarkupKind kind, Color color) async {
    if (!mounted) return;
    if (_wordUnderline != null) {
      await _notes.deleteMarkup(_wordUnderline!.id);
    }
    final m = WordMarkup(
      id: '${_appState.currentBook}_${widget.word.chapter}_${widget.word.verse}_${widget.word.wordNumber}_ul',
      bookNumber: _appState.currentBook,
      chapter: widget.word.chapter,
      verse: widget.word.verse,
      wordNumber: widget.word.wordNumber,
      kind: kind,
      colorIndex: 0,
      colorValue: color.toARGB32(),
    );
    await _notes.addMarkup(m);
    if (!mounted) return;
    setState(() => _wordUnderline = m);
    widget.onWordCommentChanged?.call();
  }

  Future<void> _removeWordUnderline() async {
    if (!mounted || _wordUnderline == null) return;
    await _notes.deleteMarkup(_wordUnderline!.id);
    if (!mounted) return;
    setState(() => _wordUnderline = null);
    widget.onWordCommentChanged?.call();
  }

  Widget _buildUnderlineRow(ColorScheme cs) {
    final activeKind = _wordUnderline?.kind;
    final activeColor = _wordUnderline?.colorValue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: underline style buttons
          Row(
            children: [
              for (int i = 0; i < _underlineKinds.length; i++) ...[
                _underlineStyleBtn(
                  kind: _underlineKinds[i],
                  label: _underlineLabels[_underlineKinds[i]]!,
                  selected: activeKind == _underlineKinds[i],
                  cs: cs,
                  onTap: () {
                    final kind = _underlineKinds[i];
                    if (activeKind == kind) {
                      _removeWordUnderline();
                    } else {
                      final color = activeColor != null
                          ? Color(activeColor)
                          : _presetUnderlineColors.first;
                      _setWordUnderline(kind, color);
                    }
                  },
                ),
                if (i < _underlineKinds.length - 1) const SizedBox(width: 4),
              ],
              const Spacer(),
              if (_wordUnderline != null)
                GestureDetector(
                  onTap: _removeWordUnderline,
                  child: Icon(Icons.format_color_reset,
                      size: 18, color: cs.onSurfaceVariant),
                ),
            ],
          ),
          // Row 2: underline color dots (shown when an underline is active)
          if (_wordUnderline != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                for (final color in _presetUnderlineColors) ...[
                  _highlightDot(
                    color: color,
                    selected: activeColor == color.toARGB32(),
                    onTap: () => _setWordUnderline(_wordUnderline!.kind, color),
                  ),
                  const SizedBox(width: 6),
                ],
                // Custom underline color picker
                _highlightDot(
                  color: activeColor != null &&
                          !_presetUnderlineColors
                              .any((c) => c.toARGB32() == activeColor)
                      ? Color(activeColor)
                      : null,
                  icon: Icons.palette,
                  selected: activeColor != null &&
                      !_presetUnderlineColors
                          .any((c) => c.toARGB32() == activeColor),
                  onTap: () => _openUnderlineColorPicker(cs),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _underlineStyleBtn({
    required MarkupKind kind,
    required String label,
    required bool selected,
    required ColorScheme cs,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
          color: selected ? cs.primary.withValues(alpha: 0.1) : null,
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: cs.onSurface,
            )),
      ),
    );
  }

  Future<void> _openUnderlineColorPicker(ColorScheme cs) async {
    final result = await showDialog<Color>(
      context: context,
      builder: (_) => _WordColorPickerDialog(
        initial: _wordUnderline?.colorValue != null
            ? Color(_wordUnderline!.colorValue!)
            : _presetUnderlineColors.first,
        title: 'Цвет подчёркивания',
      ),
    );
    if (result != null && mounted && _wordUnderline != null) {
      _setWordUnderline(_wordUnderline!.kind, result);
    }
  }

  Widget _buildHighlightRow(ColorScheme cs) {
    final currentArgb = _wordHighlight?.colorValue;
    final isCustom = currentArgb != null &&
        !_presetHighlightColors.any((c) => c.toARGB32() == currentArgb);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Presets
          for (final color in _presetHighlightColors) ...[
            _highlightDot(
              color: color,
              selected: currentArgb == color.toARGB32(),
              onTap: () => currentArgb == color.toARGB32()
                  ? _removeWordHighlight()
                  : _setWordHighlight(color),
            ),
            const SizedBox(width: 6),
          ],
          // Custom color picker
          _highlightDot(
            color: isCustom ? Color(currentArgb) : null,
            icon: Icons.palette,
            selected: isCustom,
            onTap: () => _openWordColorPicker(cs),
          ),
          const Spacer(),
          // Eraser — remove highlight
          if (_wordHighlight != null)
            GestureDetector(
              onTap: _removeWordHighlight,
              child: Icon(Icons.format_color_reset,
                  size: 18, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _highlightDot({
    Color? color,
    IconData? icon,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: icon != null
            ? Icon(icon,
                size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)
            : null,
      ),
    );
  }

  Future<void> _openWordColorPicker(ColorScheme cs) async {
    final result = await showDialog<Color>(
      context: context,
      builder: (_) => _WordColorPickerDialog(
        initial: _wordHighlight?.colorValue != null
            ? Color(_wordHighlight!.colorValue!)
            : const Color(0x40FFEB3B),
      ),
    );
    if (result != null && mounted) {
      _setWordHighlight(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.popupFontSize ?? widget.fontSize;
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      color: cs.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupHeader(
              title: _loading
                  ? widget.word.word
                  : (_detail?.lexeme ?? widget.word.word),
              subtitle: (!_loading &&
                      _detail?.lexeme != null &&
                      _detail!.lexeme != widget.word.word)
                  ? widget.word.word
                  : null,
              strongs: widget.word.strongs,
              loading: _loading,
              fontSize: fontSize,
              onExpand: _openFullScreen,
              onClose: widget.onClose,
            ),
            // ── Word highlight color row ──
            if (!_loading) _buildHighlightRow(cs),
            // ── Word underline style row ──
            if (!_loading) _buildUnderlineRow(cs),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: GestureDetector(
                    onTap: _openFullScreen,
                    behavior: HitTestBehavior.translucent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_detail!.morphologyText.isNotEmpty) ...[
                          Text(
                            _detail!.morphologyText,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: fontSize - 2,
                              color: cs.secondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        buildHtmlWidget(
                          html: truncateHtmlForPreview(_detail!.definitionHtml, 2000),
                          baseFontSize: fontSize - 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_loading) ...[
              Divider(height: 1, color: cs.outlineVariant),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: _CommentFooter(
                  comment: _wordComment,
                  editing: _editingComment,
                  controller: _commentCtrl,
                  fontSize: fontSize,
                  onEdit: () => setState(() => _editingComment = true),
                  onSave: _saveComment,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comment footer — shared between WordQuickView (could be reused)
// ─────────────────────────────────────────────────────────────────────────────

class _CommentFooter extends StatelessWidget {
  final WordComment? comment;
  final bool editing;
  final TextEditingController controller;
  final double fontSize;
  final VoidCallback onEdit;
  final VoidCallback onSave;

  const _CommentFooter({
    required this.comment,
    required this.editing,
    required this.controller,
    required this.fontSize,
    required this.onEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (editing) {
      return TextField(
        controller: controller,
        autofocus: true,
        maxLength: 200,
        maxLines: 2,
        style: TextStyle(fontSize: fontSize - 1),
        decoration: InputDecoration(
          hintText: 'Комментарий (до 200 символов)',
          hintStyle: TextStyle(fontSize: fontSize - 2),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: const OutlineInputBorder(),
        ),
      );
    }

    if (comment != null) {
      return InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(Icons.comment, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                comment!.text,
                style: TextStyle(
                  fontSize: fontSize - 2,
                  fontStyle: FontStyle.italic,
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.edit, size: 14, color: cs.onSurfaceVariant),
          ]),
        ),
      );
    }

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(Icons.add_comment_outlined,
              size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Комментарий',
              style:
                  TextStyle(fontSize: fontSize - 1, color: cs.onSurfaceVariant),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact color picker dialog for word highlights
// ─────────────────────────────────────────────────────────────────────────────

class _WordColorPickerDialog extends StatefulWidget {
  final Color initial;
  final String title;

  const _WordColorPickerDialog({
    required this.initial,
    this.title = 'Цвет выделения',
  });

  @override
  State<_WordColorPickerDialog> createState() => _WordColorPickerDialogState();
}

class _WordColorPickerDialogState extends State<_WordColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _lightness;
  late double _alpha;

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(widget.initial);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;
    _alpha = hsl.alpha.clamp(0.1, 1.0);
  }

  Color get _currentColor =>
      HSLColor.fromAHSL(_alpha, _hue, _saturation, _lightness).toColor();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outline),
              ),
            ),
            const SizedBox(height: 12),
            // Hue
            _colorSliderRow(
                'Тон', _hue / 360, (v) => setState(() => _hue = v * 360)),
            // Saturation
            _colorSliderRow(
                'Насыщ.', _saturation, (v) => setState(() => _saturation = v)),
            // Lightness
            _colorSliderRow(
                'Яркость', _lightness, (v) => setState(() => _lightness = v)),
            // Alpha
            _colorSliderRow(
                'Прозрач.', _alpha, (v) => setState(() => _alpha = v)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _currentColor),
          child: const Text('Применить'),
        ),
      ],
    );
  }

  Widget _colorSliderRow(
      String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WordFullView — full article bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class WordFullView extends StatefulWidget {
  final WordModel word;
  final WordDetail detail;
  final double fontSize;
  final DBService db;
  final BibleLinkCallback? onBibleLink;

  const WordFullView({
    super.key,
    required this.word,
    required this.detail,
    required this.fontSize,
    required this.db,
    this.onBibleLink,
  });

  @override
  State<WordFullView> createState() => _WordFullViewState();
}

class _WordFullViewState extends State<WordFullView> {
  List<DictionaryLookupHit> _dictHits = [];
  bool _dictLoading = true;
  final Set<String> _expandedDicts = {};

  @override
  void initState() {
    super.initState();
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    try {
      final provider = context.read<DictionaryProvider>();
      final seen = <String>{};
      final unique = <DictionaryLookupHit>[];
      for (final term in widget.detail.lookupTerms) {
        final hits = await provider.lookupAcrossDictionaries(term);
        for (final h in hits) {
          final key = '${h.dictionaryTitle}|${h.entry.term}';
          if (seen.add(key)) unique.add(h);
        }
      }
      if (mounted)
        setState(() {
          _dictHits = unique;
          _dictLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _dictLoading = false);
    }
  }

  Future<void> _lookupInDictionaries(String term) async {
    final hit = await lookupDictionaryTerm(context, term);
    if (hit != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DictionaryArticleScreen(
            entry: hit.entry,
          ),
        ),
      );
    }
  }

  void _handleLink(String href) {
    if (!href.startsWith('B:')) return;
    final ref = parseBibleHref(href);
    if (ref == null) return;
    final vpFs = context.read<AppState>().versePreviewFontSize;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VersePreviewSheet(
        book: ref.book,
        chapter: ref.chapter,
        verse: ref.verse,
        db: widget.db,
        fontSize: vpFs,
        highlightStrongs: widget.word.strongs,
        onNavigate: widget.onBibleLink != null
            ? () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                widget.onBibleLink!(ref.book, ref.chapter, ref.verse);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final fs = appState.fullPopupFontSize;
    final font = appState.fontFamily;
    final headTitle = widget.detail.lexeme ?? widget.word.word;
    final showInText = widget.detail.lexeme != null &&
        widget.detail.lexeme != widget.word.word;
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      builder: (ctx, controller) => Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: cs.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headTitle,
                        style: TextStyle(
                            fontSize: fs + 2, fontWeight: FontWeight.bold)),
                    if (showInText)
                      Text('в тексте: ${widget.word.word}',
                          style: TextStyle(
                              fontSize: fs - 2,
                              fontStyle: FontStyle.italic,
                              color: cs.secondary)),
                  ],
                ),
              ),
              if (widget.word.strongs != null)
                Chip(
                  label: Text('G${widget.word.strongs}'),
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ]),
          ),
          // Morphology
          if (widget.detail.morphologyText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.detail.morphologyText,
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: fs - 2,
                        color: cs.secondary)),
              ),
            ),
          // Lookup chips
          if (widget.detail.lookupTerms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final term in widget.detail.lookupTerms)
                      ActionChip(
                        label: Text(term),
                        onPressed: () => _lookupInDictionaries(term),
                      ),
                  ],
                ),
              ),
            ),
          const Divider(),
          // Body
          Expanded(
            child: SelectionArea(
              child: SingleChildScrollView(
                controller: controller,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHtmlWidget(
                      html: widget.detail.definitionHtml,
                      baseFontSize: fs,
                      fontFamily: font,
                      linkColor: appState.customColors.link,
                      onLinkTap: _handleLink,
                    ),
                    if (_dictLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_dictHits.isNotEmpty) ...[
                      const Divider(height: 24, thickness: 1),
                      Text('Другие словари',
                          style: TextStyle(
                              fontSize: fs,
                              fontWeight: FontWeight.bold,
                              color: cs.primary)),
                      const SizedBox(height: 8),
                      ..._buildDictSections(fs, font, cs),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDictSections(double fs, String font, ColorScheme cs) {
    final byDict = <String, List<DictionaryLookupHit>>{};
    for (final hit in _dictHits) {
      byDict.putIfAbsent(hit.dictionaryTitle, () => []).add(hit);
    }

    final widgets = <Widget>[];
    for (final entry in byDict.entries) {
      final dictName = entry.key;
      final isExpanded = _expandedDicts.contains(dictName);

      widgets.add(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            child: InkWell(
              onTap: () => setState(() {
                isExpanded
                    ? _expandedDicts.remove(dictName)
                    : _expandedDicts.add(dictName);
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(children: [
                  Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                    '$dictName (${entry.value.length})',
                    style: TextStyle(
                        fontSize: fs - 1,
                        fontWeight: FontWeight.w600,
                        color: cs.primary),
                  )),
                ]),
              ),
            ),
          ),
          if (isExpanded)
            for (final hit in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: buildHtmlWidget(
                  html: truncateHtmlForPreview(hit.entry.definitionHtml),
                  baseFontSize: fs - 1,
                  fontFamily: font,
                  linkColor: context.read<AppState>().customColors.link,
                  onLinkTap: _handleLink,
                ),
              ),
        ],
      ));
    }
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VersePreviewSheet — shows a single verse from a bible link
// ─────────────────────────────────────────────────────────────────────────────

class VersePreviewSheet extends StatefulWidget {
  final int book;
  final int chapter;
  final int verse;
  final DBService db;
  final double fontSize;
  final String? highlightStrongs;
  final VoidCallback? onNavigate;

  const VersePreviewSheet({
    super.key,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.db,
    required this.fontSize,
    this.highlightStrongs,
    this.onNavigate,
  });

  @override
  State<VersePreviewSheet> createState() => _VersePreviewSheetState();
}

class _VersePreviewSheetState extends State<VersePreviewSheet> {
  VerseModel? _verseModel;
  bool _loading = true;
  String? _bookName;
  List<WordMarkup> _markups = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final notes = context.read<NotesProvider>();
    final words = await widget.db.getVerseWords(
      widget.book,
      widget.chapter,
      widget.verse,
    );
    final verses = widget.db.groupIntoVerses(words);
    final books = appState.books;
    // Load markups for the verse
    List<WordMarkup> markups = const [];
    if (mounted) {
      final chapterMarkups = await notes.getMarkupsForChapter(
        widget.book,
        widget.chapter,
      );
      markups = chapterMarkups.where((m) => m.verse == widget.verse).toList();
    }
    if (mounted) {
      setState(() {
        _verseModel = verses.isNotEmpty ? verses.first : null;
        _bookName = books
            .where((b) => b.bookNumber == widget.book)
            .firstOrNull
            ?.shortName;
        _markups = markups;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ref = '${_bookName ?? widget.book} ${widget.chapter}:${widget.verse}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
              child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(ref,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary)),
              const Spacer(),
              if (widget.onNavigate != null)
                TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Перейти'),
                  onPressed: widget.onNavigate,
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          const Divider(),
          // Body
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_verseModel == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Стих не найден', style: theme.textTheme.bodyMedium),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: VerseWordRow(
                  verse: _verseModel!,
                  db: widget.db,
                  fontSize: widget.fontSize,
                  highlightStrongs: widget.highlightStrongs,
                  markups: _markups,
                ),
              ),
            ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VerseWordRow — row of tappable words for a verse
// ─────────────────────────────────────────────────────────────────────────────

class VerseWordRow extends StatelessWidget {
  final VerseModel verse;
  final DBService db;
  final double fontSize;
  final String? highlightStrongs;
  final List<WordMarkup> markups;

  const VerseWordRow({
    super.key,
    required this.verse,
    required this.db,
    required this.fontSize,
    this.highlightStrongs,
    this.markups = const [],
  });

  @override
  Widget build(BuildContext context) {
    final words = verse.words;
    final hs = highlightStrongs;
    final cs = Theme.of(context).colorScheme;
    final appState = context.read<AppState>();
    final fontFamily = appState.fontFamily;
    final lineHeight = appState.lineHeight;
    final themeMode = appState.themeMode;
    final children = <Widget>[];

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final punct = isPunct(w.word);
      final nextPunct = i + 1 < words.length && isPunct(words[i + 1].word);
      final display = punct ? w.word : (nextPunct ? w.word : '${w.word} ');
      final highlighted = hs != null && w.strongs != null && w.strongs == hs;

      // Find markup for this word
      final bgMarkup = markups
          .where((m) =>
              m.wordNumber == w.wordNumber && m.kind == MarkupKind.background)
          .firstOrNull;
      final ulMarkup = markups
          .where((m) =>
              m.wordNumber == w.wordNumber && m.kind != MarkupKind.background)
          .firstOrNull;

      // Background from markup
      Color? wordBg;
      if (bgMarkup != null && bgMarkup.colorValue != null) {
        wordBg = Color(bgMarkup.colorValue!);
      } else if (highlighted) {
        wordBg = cs.primary.withValues(alpha: 0.15);
      }

      // Underline color
      Color? ulColor;
      if (ulMarkup != null) {
        ulColor = ulMarkup.colorValue != null
            ? Color(ulMarkup.colorValue!)
            : underlineColorsForTheme(themeMode)[ulMarkup.colorIndex
                .clamp(0, underlineColorsForTheme(themeMode).length - 1)];
      }

      Widget wordChild = Text(display,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            height: lineHeight,
            fontWeight: highlighted ? FontWeight.w900 : FontWeight.normal,
            backgroundColor: wordBg,
          ));

      if (ulMarkup != null) {
        wordChild = WordUnderline(
          kind: ulMarkup.kind,
          color: ulColor!,
          child: wordChild,
        );
      }

      children.add(Builder(
          builder: (ctx) => GestureDetector(
                onTap: punct
                    ? null
                    : () => showWordOverlayPopup(
                          ctx: ctx,
                          word: w,
                          db: db,
                          fontSize: fontSize,
                        ),
                child: wordChild,
              )));
    }

    return SelectionArea(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DictionaryWordPopup — compact popup for dictionary article screen
// ─────────────────────────────────────────────────────────────────────────────

class DictionaryWordPopup extends StatelessWidget {
  final DictionaryEntry entry;
  final double fontSize;
  final VoidCallback onClose;
  final VoidCallback onExpand;

  const DictionaryWordPopup({
    super.key,
    required this.entry,
    required this.fontSize,
    required this.onClose,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      color: cs.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupHeader(
              title: entry.term,
              fontSize: fontSize,
              onExpand: onExpand,
              onClose: onClose,
            ),
            Flexible(
              child: SelectionArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: buildHtmlWidget(
                    html: truncateHtmlForPreview(entry.definitionHtml, 500),
                    baseFontSize: fontSize - 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
