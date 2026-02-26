// lib/features/dictionary/view/dictionary_article_screen.dart
//
// Полная статья словаря. Открывается как отдельный экран (не bottom sheet),
// чтобы работали горячие клавиши прокрутки (E-Ink / внешняя клавиатура).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/models/models.dart';

class DictionaryArticleScreen extends StatefulWidget {
  const DictionaryArticleScreen({super.key, required this.entry});

  final DictionaryEntry entry;

  @override
  State<DictionaryArticleScreen> createState() =>
      _DictionaryArticleScreenState();
}

class _DictionaryArticleScreenState extends State<DictionaryArticleScreen> {
  final _scroll = ScrollController();

  // ── Scroll helpers ─────────────────────────────────────────────────────────

  void _scrollBy(double factor) {
    if (!_scroll.hasClients) return;
    final s = context.read<AppState>();
    final target = (_scroll.offset + _scroll.position.viewportDimension * factor)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (s.animationsEnabled) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  // ── Keyboard ───────────────────────────────────────────────────────────────

  KeyEventResult _handleKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final s = context.read<AppState>();
    if (s.isScrollDownKey(e.logicalKey)) { _scrollBy(0.92);  return KeyEventResult.handled; }
    if (s.isScrollUpKey(e.logicalKey))   { _scrollBy(-0.92); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entry    = widget.entry;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            entry.term,
            style: const TextStyle(fontFamily: 'Gentium'),
          ),
        ),
        body: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Html(
            data: entry.definitionHtml,
            style: {
              'body': Style(
                fontSize:   FontSize(appState.dictionaryFontSize),
                fontFamily: 'Gentium',
                lineHeight: LineHeight(1.7),
                margin:     Margins.zero,
                padding:    HtmlPaddings.zero,
              ),
              'a': Style(
                color:          Colors.blue,
                textDecoration: TextDecoration.underline,
              ),
            },
          ),
        ),
      ),
    );
  }
}
