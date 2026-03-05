// lib/features/notes/widgets/markdown_highlight_controller.dart
//
// TextEditingController that renders inline markdown formatting
// (headers, bold, italic, strikethrough, code, links, blockquotes).

import 'package:flutter/material.dart';

class MarkdownHighlightController extends TextEditingController {
  MarkdownHighlightController({super.text});

  // Inline markdown patterns
  static final _boldPattern = RegExp(r'\*\*(.+?)\*\*');
  static final _italicPattern = RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)');
  static final _strikePattern = RegExp(r'~~(.+?)~~');
  static final _codePattern = RegExp(r'`([^`]+)`');
  static final _linkBracketPattern = RegExp(r'\[\[([^\]]+)\]\]|\{\{([^}]+)\}\}');
  static final _headerPattern = RegExp(r'^(#{1,3}) (.+)$', multiLine: true);
  static final _blockquotePattern = RegExp(r'^> (.+)$', multiLine: true);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    if (t.isEmpty) return TextSpan(style: style, text: t);

    final cs = Theme.of(context).colorScheme;
    final baseFontSize = style?.fontSize ?? 16.0;

    // Build a list of styled ranges
    final spans = <_StyledRange>[];

    // Headers (line-level)
    for (final m in _headerPattern.allMatches(t)) {
      final level = m.group(1)!.length;
      final sizeAdd = level == 1 ? 10.0 : level == 2 ? 6.0 : 2.0;
      spans.add(_StyledRange(m.start, m.end, style?.copyWith(
        fontSize: baseFontSize + sizeAdd,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      )));
    }

    // Bold
    for (final m in _boldPattern.allMatches(t)) {
      spans.add(_StyledRange(m.start, m.end, style?.copyWith(
        fontWeight: FontWeight.w700,
      )));
    }

    // Italic
    for (final m in _italicPattern.allMatches(t)) {
      spans.add(_StyledRange(m.start, m.end, style?.copyWith(
        fontStyle: FontStyle.italic,
      )));
    }

    // Strikethrough
    for (final m in _strikePattern.allMatches(t)) {
      spans.add(_StyledRange(m.start, m.end, style?.copyWith(
        decoration: TextDecoration.lineThrough,
        color: cs.onSurface.withValues(alpha: 0.5),
      )));
    }

    // Inline code
    for (final m in _codePattern.allMatches(t)) {
      spans.add(_StyledRange(m.start, m.end, style?.copyWith(
        fontFamily: 'monospace',
        fontSize: baseFontSize - 1,
        color: cs.primary,
        backgroundColor: cs.surfaceContainerHighest,
      )));
    }

    // [[links]] and {{quotes}}
    for (final m in _linkBracketPattern.allMatches(t)) {
      final isQuote = m.group(0)!.startsWith('{{');
      final color = isQuote ? cs.tertiary : cs.primary;
      spans.add(_StyledRange(m.start, m.end, style?.copyWith(
        color: color,
        decoration: TextDecoration.underline,
        decorationColor: color.withValues(alpha: 0.5),
      )));
    }

    // Blockquotes
    for (final m in _blockquotePattern.allMatches(t)) {
      spans.add(_StyledRange(m.start, m.end, style?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
      )));
    }

    if (spans.isEmpty) return TextSpan(style: style, text: t);

    // Sort by start position, remove overlaps (first match wins)
    spans.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_StyledRange>[];
    for (final s in spans) {
      if (merged.isEmpty || s.start >= merged.last.end) {
        merged.add(s);
      }
    }

    // Build TextSpan children
    final children = <InlineSpan>[];
    int pos = 0;
    for (final r in merged) {
      if (r.start > pos) {
        children.add(TextSpan(text: t.substring(pos, r.start), style: style));
      }
      children.add(TextSpan(text: t.substring(r.start, r.end), style: r.style));
      pos = r.end;
    }
    if (pos < t.length) {
      children.add(TextSpan(text: t.substring(pos), style: style));
    }

    return TextSpan(children: children, style: style);
  }
}

class _StyledRange {
  final int start;
  final int end;
  final TextStyle? style;
  _StyledRange(this.start, this.end, this.style);
}
