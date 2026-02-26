// lib/features/home/view/verse_widgets.dart
//
// Verse rendering widgets: VerseBlock, BlinkWrapper, WordTile.
// Extracted from home_screen.dart for maintainability.

import 'package:flutter/material.dart';

import '../../../core/bible_utils.dart';
import '../../../core/models/models.dart';
import '../../../core/themes.dart';
import '../../../word_popup.dart';

// ─────────────────────────────────────────────────────────────────────────────
// File-level active word overlay — delegates to shared showWordOverlayPopup()
// ─────────────────────────────────────────────────────────────────────────────
void dismissActiveWordOverlay() => dismissWordOverlay();

// ─────────────────────────────────────────────────────────────────────────────
// Verse block
// ─────────────────────────────────────────────────────────────────────────────
class VerseBlock extends StatelessWidget {
  final VerseModel   verse;
  final double       fontSize;
  final double       criticalTextFontSize;
  final bool         showCriticalText;
  final dynamic      db;
  final HighlightTarget? highlight;
  final Future<void> Function(int, int, int, {String? strongs}) onBibleLink;
  final VoidCallback onClearHighlight;
  final VoidCallback? onLongPress;
  final int          commentCount;
  final int          parallelCount;
  final int          tagCount;
  final List<WordMarkup> markups;
  final Map<String, WordComment> wordComments;
  final String       themeMode;
  final VoidCallback? onWordCommentChanged;
  final String       fontFamily;
  final CustomThemeColors customColors;
  final double       popupFontSize;
  final bool         animationsEnabled;
  final bool         textSelectionEnabled;
  final double       lineHeight;

  const VerseBlock({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.criticalTextFontSize,
    required this.showCriticalText,
    required this.db,
    required this.highlight,
    required this.onBibleLink,
    required this.onClearHighlight,
    required this.fontFamily,
    required this.customColors,
    required this.popupFontSize,
    this.animationsEnabled = true,
    this.textSelectionEnabled = false,
    this.lineHeight = 1.55,
    this.onLongPress,
    this.commentCount = 0,
    this.parallelCount = 0,
    this.tagCount = 0,
    this.markups = const [],
    this.wordComments = const {},
    this.themeMode = 'light',
    this.onWordCommentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    // Verse background color from markup (kind == background, wordNumber == null)
    Color? verseBg;
    final bgMarkup = markups.where(
        (m) => m.kind == MarkupKind.background && m.wordNumber == null).firstOrNull;
    if (bgMarkup != null) {
      if (bgMarkup.colorValue != null) {
        verseBg = Color(bgMarkup.colorValue!);
      } else {
        final colors = highlightColorsForTheme(themeMode);
        if (bgMarkup.colorIndex < colors.length) {
          verseBg = colors[bgMarkup.colorIndex].withValues(alpha: 0.18);
        }
      }
    }

    // Номер стиха
    widgets.add(const Padding(
      padding: EdgeInsets.only(right: 3),
      child: Text(
        '', // verse number будет добавлен ниже
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ));

    // Build a map of word-level markups for quick lookup
    final wordMarkupMap = <int, WordMarkup>{};
    for (final m in markups) {
      if (m.wordNumber != null) wordMarkupMap[m.wordNumber!] = m;
    }

    // Track whether we are inside a critical text block
    bool inCritical = false;
    // Track whether we're inside a brace-delimited block for hiding
    bool inBraceBlock = false;

    for (int i = 0; i < verse.words.length; i++) {
      final w           = verse.words[i];
      final wt          = w.word.trim();

      // Detect critical text markers
      if (wt.startsWith('n>')) { inCritical = true; }

      final isCritical = inCritical || isCriticalTag(wt);

      if (wt == '/n>') { inCritical = false; }

      // Track brace blocks for hiding when critical text is off
      if (wt == '{') inBraceBlock = true;
      if (wt == '}') {
        if (!showCriticalText) {
          inBraceBlock = false;
          continue; // skip the closing brace too
        }
      }

      // If critical text is hidden, skip all critical words and brace content
      if (!showCriticalText && (isCritical || inBraceBlock)) continue;

      final wp = isPunct(w.word);
      final nextIsPunct =
          (i + 1 < verse.words.length) && isPunct(verse.words[i + 1].word);

      final shouldBlink = highlight != null &&
          highlight!.chapter == verse.chapter &&
          highlight!.verse   == verse.verse &&
          (highlight!.strongs == null || highlight!.strongs == w.strongs);

      // Check for word-level markup (use actual wordNumber, not loop index)
      final wMarkup = wordMarkupMap[w.wordNumber];
      // Check for word-level comment
      final hasWordComment = wordComments.containsKey('${verse.verse}:${w.wordNumber}');

      Widget tile = WordTile(
        word:            w,
        fontSize:        isCritical ? criticalTextFontSize : fontSize,
        isCriticalText:  isCritical,
        db:              db,
        isPunct:         wp,
        noTrailingSpace: nextIsPunct,
        onBibleLink:     onBibleLink,
        markup:          wMarkup,
        hasWordComment:  hasWordComment,
        themeMode:       themeMode,
        onWordCommentChanged: onWordCommentChanged,
        fontFamily:      fontFamily,
        customColors:    customColors,
        popupFontSize:   popupFontSize,
        lineHeight:      lineHeight,
      );

      if (shouldBlink && animationsEnabled) {
        tile = BlinkWrapper(
          blinkColor: customColors.highlightBlink,
          onDone: onClearHighlight,
          child: tile,
        );
      } else if (shouldBlink && !animationsEnabled) {
        // No blink — just briefly highlight then clear
        tile = Container(
          color: customColors.highlightBlink,
          child: tile,
        );
        // Schedule clear on next frame
        WidgetsBinding.instance.addPostFrameCallback((_) => onClearHighlight());
      }

      widgets.add(tile);
    }

    // ── Merge punctuation widgets with preceding word ────────────────────────
    // Prevents a lone "." or "," from wrapping onto a new line.
    final merged = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      if (i > 0 && i < verse.words.length) {
        // Find the original word for this widget index
        // (skip hidden words — count only those that produced a widget)
      }
      merged.add(widgets[i]);
    }
    // Scan merged list and combine punct with the word before it.
    final finalWidgets = <Widget>[];
    int wi = 0;
    // Build a parallel list of whether each widget is punct
    // We track which original word each widget came from.
    // Since hidden words are skipped, build a bool list from the widgets
    // that were actually added:
    // Reconstruct isPunct flags for the visible words.
    final punctFlags = <bool>[];
    {
      bool inCriticalLocal = false;
      bool inBraceLocal = false;
      for (int i = 0; i < verse.words.length; i++) {
        final wt = verse.words[i].word.trim();
        if (wt.startsWith('n>')) inCriticalLocal = true;
        final isCritLocal = inCriticalLocal || isCriticalTag(wt);
        if (wt == '/n>') inCriticalLocal = false;
        if (wt == '{') inBraceLocal = true;
        if (wt == '}') {
          if (!showCriticalText) { inBraceLocal = false; continue; }
        }
        if (!showCriticalText && (isCritLocal || inBraceLocal)) continue;
        punctFlags.add(isPunct(verse.words[i].word));
      }
    }
    // Now merge: if punctFlags[wi] is true and wi > 0, wrap with previous.
    wi = 0;
    for (int i = 0; i < widgets.length && wi < punctFlags.length; i++, wi++) {
      if (wi < punctFlags.length && punctFlags[wi] && finalWidgets.isNotEmpty) {
        // Merge with previous
        final prev = finalWidgets.removeLast();
        finalWidgets.add(Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [prev, widgets[i]],
        ));
      } else {
        finalWidgets.add(widgets[i]);
      }
    }
    // Add any remaining indicator widgets (comment count, parallel count)
    for (int i = punctFlags.length; i < widgets.length; i++) {
      finalWidgets.add(widgets[i]);
    }

    // ── Indicator icons at end of verse ──────────────────────────────────────
    if (commentCount > 0) {
      finalWidgets.add(Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.comment_outlined, size: fontSize * 0.55, color: customColors.indicator),
            SizedBox(width: 1),
            Text('$commentCount',
                style: TextStyle(fontSize: fontSize * 0.5, color: customColors.indicator)),
          ],
        ),
      ));
    }
    if (parallelCount > 0) {
      finalWidgets.add(Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_arrows, size: fontSize * 0.55, color: customColors.indicator),
            SizedBox(width: 1),
            Text('$parallelCount',
                style: TextStyle(fontSize: fontSize * 0.5, color: customColors.indicator)),
          ],
        ),
      ));
    }
    if (tagCount > 0) {
      finalWidgets.add(Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sell, size: fontSize * 0.5, color: customColors.indicator),
            SizedBox(width: 1),
            Text('$tagCount',
                style: TextStyle(fontSize: fontSize * 0.5, color: customColors.indicator)),
          ],
        ),
      ));
    }

    return RepaintBoundary(
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.only(bottom: 2),
          decoration: verseBg != null
              ? BoxDecoration(
                  color: verseBg,
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: textSelectionEnabled
              ? SelectionArea(
                  child: Wrap(crossAxisAlignment: WrapCrossAlignment.end, children: finalWidgets),
                )
              : Wrap(crossAxisAlignment: WrapCrossAlignment.end, children: finalWidgets),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blink wrapper — lightweight StatefulWidget, only used for 1-2 words per nav
// ─────────────────────────────────────────────────────────────────────────────
class BlinkWrapper extends StatefulWidget {
  final Widget child;
  final Color blinkColor;
  final VoidCallback onDone;

  const BlinkWrapper({
    super.key,
    required this.child,
    required this.blinkColor,
    required this.onDone,
  });

  @override
  State<BlinkWrapper> createState() => _BlinkWrapperState();
}

class _BlinkWrapperState extends State<BlinkWrapper> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _on = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _on = false);
        widget.onDone();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _on ? widget.blinkColor : null,
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Word tile (StatelessWidget — no per-word state/controllers)
// ─────────────────────────────────────────────────────────────────────────────
class WordTile extends StatelessWidget {
  final WordModel  word;
  final double     fontSize;
  final bool       isCriticalText;
  final dynamic    db;
  final bool       isPunct;
  final bool       noTrailingSpace;
  final Future<void> Function(int, int, int, {String? strongs}) onBibleLink;
  final WordMarkup?  markup;
  final bool         hasWordComment;
  final String       themeMode;
  final VoidCallback? onWordCommentChanged;
  final String       fontFamily;
  final CustomThemeColors customColors;
  final double       popupFontSize;
  final double       lineHeight;

  const WordTile({
    super.key,
    required this.word,
    required this.fontSize,
    required this.isCriticalText,
    required this.db,
    required this.isPunct,
    required this.noTrailingSpace,
    required this.onBibleLink,
    required this.fontFamily,
    required this.customColors,
    required this.popupFontSize,
    this.lineHeight = 1.55,
    this.markup,
    this.hasWordComment = false,
    this.themeMode = 'light',
    this.onWordCommentChanged,
  });

  void _showPopup(BuildContext ctx) {
    showWordOverlayPopup(
      ctx: ctx,
      word: word,
      db: db,
      fontSize: fontSize,
      popupFontSize: popupFontSize,
      onBibleLink: (b, ch, v) => onBibleLink(b, ch, v),
      onWordCommentChanged: onWordCommentChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wt = word.word.trim();

    // ── Critical text label: stacked display ────────────────────────────────
    if (isCriticalText && wt.startsWith('n>')) {
      final label = wt.substring(2);
      final critDimColor = Theme.of(context)
          .colorScheme.onSurface.withValues(alpha: 0.35);

      if (label.contains('/')) {
        final parts = label.split('/');
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in parts)
                Text(p,
                    style: TextStyle(
                      fontSize: fontSize * 0.65,
                      color: critDimColor,
                      height: 1.1,
                    )),
            ],
          ),
        );
      } else {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(label,
              style: TextStyle(
                fontSize: fontSize * 0.7,
                color: critDimColor,
              )),
        );
      }
    }

    // ── Braces: normal size, dimmed ─────────────────────────────────────────
    if (isCriticalText && (wt == '{' || wt == '}')) {
      final critDimColor = Theme.of(context)
          .colorScheme.onSurface.withValues(alpha: 0.35);
      return Text(wt,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            color: critDimColor,
          ));
    }

    // /n> and variant: — skip display entirely
    if (wt == '/n>' || wt == 'variant:') {
      return const SizedBox.shrink();
    }

    final displayText = isPunct
        ? '${word.word} '
        : (noTrailingSpace ? word.word : '${word.word} ');

    final isCrit = isCriticalText;
    final critColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);

    // ── Underline markup info ────────────────────────────────────────────────
    final bool hasUnderline = markup != null && markup!.kind != MarkupKind.background;
    Color? ulColor;
    if (hasUnderline) {
      ulColor = markup!.colorValue != null
          ? Color(markup!.colorValue!)
          : underlineColorsForTheme(themeMode)[
              markup!.colorIndex.clamp(0, underlineColorsForTheme(themeMode).length - 1)];
    }

    // ── Word background: user highlight > comment bg ────────────────────────
    Color? wordBg;
    if (!isCrit) {
      if (markup != null && markup!.kind == MarkupKind.background && markup!.colorValue != null) {
        wordBg = Color(markup!.colorValue!);
      } else if (hasWordComment) {
        wordBg = customColors.wordCommentBg;
      }
    }

    Widget textWidget = Text(displayText,
        style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            height: lineHeight,
            fontStyle: isCrit ? FontStyle.italic : null,
            color: isCrit ? critColor : null,
            backgroundColor: wordBg,
        ));

    // Wrap with custom underline (painted below text with offset)
    if (hasUnderline) {
      textWidget = WordUnderline(
        kind: markup!.kind,
        color: ulColor!,
        child: textWidget,
      );
    }

    // Word comment dot indicator
    Widget wordWidget = textWidget;
    if (hasWordComment && !isCrit) {
      wordWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          textWidget,
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: customColors.wordCommentDot,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }

    // Critical text tags are not tappable
    final isCritTag = isCriticalTag(word.word.trim());

    return RepaintBoundary(
      child: GestureDetector(
        onTap: isCritTag ? null : () => _showPopup(context),
        child: isPunct
            ? Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Transform.translate(offset: const Offset(0, 1), child: wordWidget),
              )
            : wordWidget,
      ),
    );
  }
}
