// lib/features/dictionary/widgets/html_article_cache.dart
//
// LRU widget cache for flutter_html articles.
// Stores pre-built Widget trees keyed by (articleKey, fontSize).
// Max 50 entries; oldest evicted when full.

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class HtmlArticleCache {
  HtmlArticleCache._();
  static final _instance = HtmlArticleCache._();
  factory HtmlArticleCache() => _instance;

  static const _maxEntries = 50;
  final _cache = <String, Widget>{};
  final _accessOrder = <String>[];

  String _key(String articleKey, double fontSize) =>
      '$articleKey@$fontSize';

  Widget getOrBuild({
    required String articleKey,
    required String html,
    required double fontSize,
    required String fontFamily,
  }) {
    final k = _key(articleKey, fontSize);

    if (_cache.containsKey(k)) {
      // Move to end (most recently used)
      _accessOrder.remove(k);
      _accessOrder.add(k);
      return _cache[k]!;
    }

    final widget = RepaintBoundary(
      child: Html(
        data: html,
        style: {
          'body': Style(
            fontSize: FontSize(fontSize),
            fontFamily: fontFamily,
            lineHeight: LineHeight(1.7),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'a': Style(
            color: Colors.blue,
            textDecoration: TextDecoration.underline,
          ),
        },
      ),
    );

    // Evict oldest if at capacity
    if (_cache.length >= _maxEntries) {
      final oldest = _accessOrder.removeAt(0);
      _cache.remove(oldest);
    }

    _cache[k] = widget;
    _accessOrder.add(k);
    return widget;
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }
}
