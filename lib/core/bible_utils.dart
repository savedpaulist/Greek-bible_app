// lib/core/bible_utils.dart
//
// Shared utilities used across popups, article screens, and home screen.
// Eliminates code duplication of BibleRef parsing, punctuation checks,
// HTML truncation, and dictionary lookup navigation.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import '../features/dictionary/provider/dictionary_provider.dart';

// ─── Punctuation check (cached RegExp) ───────────────────────────────────────
final _punctRe = RegExp(r'^[.,;·!?:»«—–\-\u037E\u0387\u00B7]+$');

/// Whether [w] consists entirely of punctuation characters.
bool isPunct(String w) => _punctRe.hasMatch(w.trim());

/// Check whether a word is a critical text marker/tag.
bool isCriticalTag(String w) {
  final t = w.trim();
  return t.startsWith('n>') || t == '/n>' || t == 'variant:' || t == '{' || t == '}';
}

// ─── Bible reference parsing ─────────────────────────────────────────────────

/// Parsed Bible reference: book number, chapter, verse.
class BibleRef {
  final int book, chapter, verse;
  const BibleRef(this.book, this.chapter, this.verse);
}

/// Parse a link href like "B:540 4:1" → BibleRef(book=540, chapter=4, verse=1).
/// Returns null if the format doesn't match.
BibleRef? parseBibleHref(String href) {
  if (!href.startsWith('B:')) return null;
  final body = href.substring(2).trim();
  final spaceIdx = body.indexOf(' ');
  if (spaceIdx < 0) return null;
  final rest = body.substring(spaceIdx + 1);
  final colonIdx = rest.indexOf(':');
  if (colonIdx < 0) return null;
  final book = int.tryParse(body.substring(0, spaceIdx));
  final chapter = int.tryParse(rest.substring(0, colonIdx));
  // Handle "4:1-5" by only taking the verse part before any dash
  final versePart = rest.substring(colonIdx + 1);
  final dashIdx = versePart.indexOf('-');
  final verseStr = dashIdx >= 0 ? versePart.substring(0, dashIdx) : versePart;
  final verse = int.tryParse(verseStr);
  if (book == null || chapter == null || verse == null) return null;
  return BibleRef(book, chapter, verse);
}

// ─── HTML truncation ─────────────────────────────────────────────────────────

/// Truncate HTML at the "Ссылки" heading (if present), then optionally
/// at [maxChars].  Used for compact popup previews.
String truncateHtmlForPreview(String html, [int? maxChars]) {
  // Pre-compiled pattern for "Ссылки" section
  final idx = _referencesRe.firstMatch(html)?.start ?? -1;
  var result = idx >= 0 ? html.substring(0, idx) : html;
  if (maxChars != null && result.length > maxChars) {
    result = result.substring(0, maxChars);
    final lastTagEnd = result.lastIndexOf('>');
    if (lastTagEnd > maxChars * 0.5) {
      result = result.substring(0, lastTagEnd + 1);
    }
    result += '…';
  }
  return result;
}

final _referencesRe = RegExp(r'Ссылки', caseSensitive: false);

// ─── Dictionary lookup navigation ───────────────────────────────────────────

/// Common callback types.
typedef BibleLinkCallback = void Function(int book, int chapter, int verse);

/// Show a disambiguation bottom sheet when a dictionary term matches multiple
/// entries across dictionaries.  If only one hit, directly opens the entry.
///
/// Returns the selected [DictionaryLookupHit] or null if canceled.
Future<DictionaryLookupHit?> showDictionaryHitsSheet(
  BuildContext context,
  List<DictionaryLookupHit> hits,
) async {
  if (hits.isEmpty) return null;
  if (hits.length == 1) return hits.first;

  return showModalBottomSheet<DictionaryLookupHit>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => ListView.separated(
      shrinkWrap: true,
      itemCount: hits.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final hit = hits[i];
        return ListTile(
          title: Text(hit.entry.term),
          subtitle: Text(hit.dictionaryTitle),
          onTap: () => Navigator.of(ctx).pop(hit),
        );
      },
    ),
  );
}

/// Looks up [term] across all dictionaries.
///
/// * Shows a "not found" snackbar when [showSnackbarOnMiss] is true and no
///   hits are found.
/// * When multiple hits exist, shows a disambiguation sheet.
/// * Returns the selected [DictionaryLookupHit] or `null` if nothing was
///   found / user cancelled.
Future<DictionaryLookupHit?> lookupDictionaryTerm(
  BuildContext context,
  String term, {
  bool showSnackbarOnMiss = true,
}) async {
  final provider = context.read<DictionaryProvider>();
  final hits = await provider.lookupAcrossDictionaries(term);
  if (!context.mounted) return null;

  if (hits.isEmpty) {
    if (showSnackbarOnMiss) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не найдено в словарях: $term')),
      );
    }
    return null;
  }

  if (hits.length == 1) return hits.first;

  return showDictionaryHitsSheet(context, hits);
}
