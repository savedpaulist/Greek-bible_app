// lib/features/notes/widgets/format_toolbar.dart
//
// Markdown formatting toolbar for the note editor.

import 'package:flutter/material.dart';

class MarkdownToolbar extends StatelessWidget {
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

  const MarkdownToolbar({
    super.key,
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
            // Headings dropdown
            PopupMenuButton<int>(
              tooltip: 'Heading',
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('H',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        )),
                    Icon(Icons.arrow_drop_down,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.6)),
                  ],
                ),
              ),
              onSelected: (v) {
                switch (v) {
                  case 1: onH1(); break;
                  case 2: onH2(); break;
                  case 3: onH3(); break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('H1')),
                PopupMenuItem(value: 2, child: Text('H2')),
                PopupMenuItem(value: 3, child: Text('H3')),
              ],
            ),
            _btn(Icons.format_bold, 'Bold', onBold),
            _btn(Icons.format_italic, 'Italic', onItalic),
            _btn(Icons.strikethrough_s, 'Strikethrough', onStrikethrough),
            _btn(Icons.code, 'Code', onCode),
            _divider(),
            _btn(Icons.check_box_outlined, 'Checkbox', onCheckbox),
            _btn(Icons.format_quote, 'Blockquote', onBlockquote),
            _btn(Icons.horizontal_rule, 'Horizontal rule', onHorizontalRule),
            _divider(),
            _btn(Icons.menu_book, 'Bible ref', onBibleRef),
            _btn(Icons.format_quote_rounded, 'Bible quote', onBibleQuote),
            _btn(Icons.link, 'Note link', onNoteLink),
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

  Widget _divider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outlineVariant,
    );
  }
}
