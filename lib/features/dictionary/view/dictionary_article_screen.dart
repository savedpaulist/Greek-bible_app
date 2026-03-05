// lib/features/dictionary/view/dictionary_article_screen.dart
//
// Full dictionary article screen with widget caching for performance.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/tab_drag_mixin.dart';
import '../widgets/html_article_cache.dart';

class DictionaryArticleScreen extends StatefulWidget {
  const DictionaryArticleScreen({super.key, required this.entry});

  final DictionaryEntry entry;

  @override
  State<DictionaryArticleScreen> createState() =>
      _DictionaryArticleScreenState();
}

class _DictionaryArticleScreenState extends State<DictionaryArticleScreen>
    with AutomaticKeepAliveClientMixin, TabDragMixin {
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  void _scrollBy(double factor) {
    if (!_scroll.hasClients) return;
    final target =
        (_scroll.offset + _scroll.position.viewportDimension * factor)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final s = context.read<AppState>();
    if (s.isScrollDownKey(e.logicalKey)) {
      _scrollBy(0.92);
      return KeyEventResult.handled;
    }
    if (s.isScrollUpKey(e.logicalKey)) {
      _scrollBy(-0.92);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final entry = widget.entry;

    return Focus(
      autofocus: false,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            entry.term,
            style: const TextStyle(fontFamily: 'Gentium'),
          ),
        ),
        body: wrapWithTabDrag(
          context: context,
          onSwipeRight: () => goToTab(context, 1),
          onSwipeLeft: () => goToTab(context, 2),
          child: Selector<AppState, double>(
            selector: (_, s) => s.dictionaryFontSize,
            builder: (context, fontSize, _) {
              final cached = HtmlArticleCache().getOrBuild(
                articleKey: entry.term,
                html: entry.definitionHtml,
                fontSize: fontSize,
                fontFamily: 'Gentium',
              );
              return SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                child: cached,
              );
            },
          ),
        ),
      ),
    );
  }
}
