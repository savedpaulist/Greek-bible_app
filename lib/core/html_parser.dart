// lib/core/html_parser.dart
//
// Thin wrapper around flutter_html that provides a unified [buildHtmlWidget]
// API used across popups and dictionary screens.  flutter_html fully supports
// CSS styles, nested divs, floats, <font color>, <sup>, <sub>, etc.

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'bible_utils.dart';

/// Callback invoked when a link is tapped.  [href] is the raw `href` attribute.
typedef HtmlLinkTapCallback = void Function(String href);

/// Callback invoked when a word (any non-whitespace token that is NOT already
/// inside an `<a>` tag) is tapped.  [word] is the trimmed text.
typedef HtmlWordTapCallback = void Function(String word);

// ─── Public API ──────────────────────────────────────────────────────────────

/// Render [html] via flutter_html.
///
/// * [baseFontSize] – the root font size.
/// * [fontFamily] – optional font family override.
/// * [linkColor] – color for `<a>` links.
/// * [onLinkTap] – called when any `<a href>` is tapped.
/// * [onWordTap] – reserved; word taps are handled at the screen level
///   via hit-testing on [RenderParagraph].
/// * [maxLength] – if > 0, truncate the raw HTML before parsing.
/// * [shrinkWrap] – passed to [Html.shrinkWrap].
Widget buildHtmlWidget({
  required String html,
  required double baseFontSize,
  String? fontFamily,
  Color? linkColor,
  HtmlLinkTapCallback? onLinkTap,
  HtmlWordTapCallback? onWordTap,
  int maxLength = 0,
  bool shrinkWrap = true,
}) {
  var source = html;
  if (maxLength > 0 && source.length > maxLength) {
    source = truncateHtmlForPreview(source, maxLength);
  }

  final effectiveLinkColor = linkColor ?? Colors.blue;

  return Html(
    data: source,
    shrinkWrap: shrinkWrap,
    onLinkTap: onLinkTap != null
        ? (url, attributes, element) {
            if (url != null && url.isNotEmpty) onLinkTap(url);
          }
        : null,
    style: {
      'body': Style(
        fontSize: FontSize(baseFontSize),
        fontFamily: fontFamily,
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
      ),
      'p': Style(
        margin: Margins.only(top: 4, bottom: 4),
      ),
      'a': Style(
        color: effectiveLinkColor,
        textDecoration: TextDecoration.none,
      ),
      'el': Style(fontStyle: FontStyle.italic),
      'elt': Style(fontStyle: FontStyle.italic),
      // Numeric 1-5 color codes handled below via <font> tag extension
    },
    extensions: [
      // Handle custom <el> / <elT> tags (italic Greek)
      TagExtension(
        tagsToExtend: {'el', 'elt'},
        builder: (extensionContext) {
          return Text.rich(
            TextSpan(
              text: extensionContext.element?.text ?? '',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: baseFontSize,
                fontFamily: fontFamily,
              ),
            ),
          );
        },
      ),
    ],
  );
}

