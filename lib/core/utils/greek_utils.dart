// lib/core/utils/greek_utils.dart
//
// Greek diacritics normalizer extracted from db_service.dart.

/// Strips all Greek diacritics (accents, breathings, iota subscript) and
/// lowercases.  Works with both NFC (precomposed) and NFD (decomposed) input.
String normalizeGreek(String s) {
  final buf = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_dMap[ch] ?? ch);
  }
  return buf.toString().toLowerCase().replaceAll(
      RegExp('[\u0300-\u036f\u1dc0-\u1dff\u20d0-\u20ff\ufe20-\ufe2f]'), '');
}

/// Batch-normalize for use with `compute()` in isolates.
List<String> batchNormalizeGreek(List<String> words) {
  return words.map(normalizeGreek).toList();
}

final Map<String, String> _dMap = () {
  final m = <String, String>{};
  void add(List<String> chars, String base) {
    for (final c in chars) {
      m[c] = base;
    }
  }

  add([
    'ά', 'ά', 'ἀ', 'ἁ', 'ἂ', 'ἃ', 'ἄ', 'ἅ', 'ἆ', 'ἇ',
    'ᾀ', 'ᾁ', 'ᾂ', 'ᾃ', 'ᾄ', 'ᾅ', 'ᾆ', 'ᾇ',
    'ᾰ', 'ᾱ', 'ᾲ', 'ᾳ', 'ᾴ', 'ᾶ', 'ᾷ',
    'Ά', 'Ά', 'Ἀ', 'Ἁ', 'Ἂ', 'Ἃ', 'Ἄ', 'Ἅ', 'Ἆ', 'Ἇ',
    'ᾈ', 'ᾉ', 'ᾊ', 'ᾋ', 'ᾌ', 'ᾍ', 'ᾎ', 'ᾏ',
    'Ᾰ', 'Ᾱ', 'Ὰ', 'Ά', 'ᾼ',
    'α', 'Α',
    '\u1f70', '\u1f71',
  ], 'α');
  add([
    'έ', 'έ', 'ἐ', 'ἑ', 'ἒ', 'ἓ', 'ἔ', 'ἕ',
    'Έ', 'Έ', 'Ἐ', 'Ἑ', 'Ἒ', 'Ἓ', 'Ἔ', 'Ἕ',
    'Ὲ', 'Έ',
    'ε', 'Ε',
    '\u1f72', '\u1f73',
  ], 'ε');
  add([
    'ή', 'ή', 'ἠ', 'ἡ', 'ἢ', 'ἣ', 'ἤ', 'ἥ', 'ἦ', 'ἧ',
    'ᾐ', 'ᾑ', 'ᾒ', 'ᾓ', 'ᾔ', 'ᾕ', 'ᾖ', 'ᾗ',
    'ῂ', 'ῃ', 'ῄ', 'ῆ', 'ῇ',
    'Ή', 'Ή', 'Ἠ', 'Ἡ', 'Ἢ', 'Ἣ', 'Ἤ', 'Ἥ', 'Ἦ', 'Ἧ',
    'ᾘ', 'ᾙ', 'ᾚ', 'ᾛ', 'ᾜ', 'ᾝ', 'ᾞ', 'ᾟ',
    'Ὴ', 'Ή', 'ῌ',
    'η', 'Η',
    '\u1f74', '\u1f75',
  ], 'η');
  add([
    'ί', 'ί', 'ἰ', 'ἱ', 'ἲ', 'ἳ', 'ἴ', 'ἵ', 'ἶ', 'ἷ',
    'ῐ', 'ῑ', 'ῒ', 'ΐ', 'ῖ', 'ῗ',
    'Ί', 'Ί', 'Ἰ', 'Ἱ', 'Ἲ', 'Ἳ', 'Ἴ', 'Ἵ', 'Ἶ', 'Ἷ',
    'Ῐ', 'Ῑ', 'Ὶ', 'Ί',
    'ι', 'Ι',
    '\u1f76', '\u1f77',
  ], 'ι');
  add([
    'ό', 'ό', 'ὀ', 'ὁ', 'ὂ', 'ὃ', 'ὄ', 'ὅ',
    'Ό', 'Ό', 'Ὀ', 'Ὁ', 'Ὂ', 'Ὃ', 'Ὄ', 'Ὅ',
    'Ὸ', 'Ό',
    'ο', 'Ο',
    '\u1f78', '\u1f79',
  ], 'ο');
  add([
    'ύ', 'ύ', 'ὐ', 'ὑ', 'ὒ', 'ὓ', 'ὔ', 'ὕ', 'ὖ', 'ὗ',
    'ῠ', 'ῡ', 'ῢ', 'ΰ', 'ῦ', 'ῧ',
    'Ύ', 'Ύ', 'Ὑ', 'Ὓ', 'Ὕ', 'Ὗ',
    'Ῠ', 'Ῡ', 'Ὺ', 'Ύ',
    'υ', 'Υ',
    '\u1f7a', '\u1f7b',
  ], 'υ');
  add([
    'ώ', 'ώ', 'ὠ', 'ὡ', 'ὢ', 'ὣ', 'ὤ', 'ὥ', 'ὦ', 'ὧ',
    'ᾠ', 'ᾡ', 'ᾢ', 'ᾣ', 'ᾤ', 'ᾥ', 'ᾦ', 'ᾧ',
    'ῲ', 'ῳ', 'ῴ', 'ῶ', 'ῷ',
    'Ώ', 'Ώ', 'Ὠ', 'Ὡ', 'Ὢ', 'Ὣ', 'Ὤ', 'Ὥ', 'Ὦ', 'Ὧ',
    'ᾨ', 'ᾩ', 'ᾪ', 'ᾫ', 'ᾬ', 'ᾭ', 'ᾮ', 'ᾯ',
    'Ὼ', 'Ώ', 'ῼ',
    'ω', 'Ω',
    '\u1f7c', '\u1f7d',
  ], 'ω');
  add(['ῤ', 'ῥ', 'Ῥ', 'ρ', 'Ρ'], 'ρ');
  add(['β', 'Β'], 'β');
  add(['γ', 'Γ'], 'γ');
  add(['δ', 'Δ'], 'δ');
  add(['ζ', 'Ζ'], 'ζ');
  add(['θ', 'Θ'], 'θ');
  add(['κ', 'Κ'], 'κ');
  add(['λ', 'Λ'], 'λ');
  add(['μ', 'Μ'], 'μ');
  add(['ν', 'Ν'], 'ν');
  add(['ξ', 'Ξ'], 'ξ');
  add(['π', 'Π'], 'π');
  add(['σ', 'ς', 'Σ'], 'σ');
  add(['τ', 'Τ'], 'τ');
  add(['φ', 'Φ'], 'φ');
  add(['χ', 'Χ'], 'χ');
  add(['ψ', 'Ψ'], 'ψ');
  return m;
}();
