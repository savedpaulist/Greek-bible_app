// lib/core/themes/palette_registry.dart
//
// Registry of colour palettes. Each palette provides light + dark variants
// of CustomThemeColors plus matching highlight/underline arrays.

import 'package:flutter/material.dart';
import '../themes.dart';

/// Metadata for a single palette.
class ThemePalette {
  final String id;
  final String label;
  final Color accent;
  final CustomThemeColors light;
  final CustomThemeColors dark;
  final List<Color> lightHighlights;
  final List<Color> lightUnderlines;
  final List<Color> darkHighlights;
  final List<Color> darkUnderlines;
  final Map<BibleSegment, Color> lightSegmentColors;
  final Map<BibleSegment, Color> darkSegmentColors;

  const ThemePalette({
    required this.id,
    required this.label,
    required this.accent,
    required this.light,
    required this.dark,
    required this.lightHighlights,
    required this.lightUnderlines,
    required this.darkHighlights,
    required this.darkUnderlines,
    required this.lightSegmentColors,
    required this.darkSegmentColors,
  });

  CustomThemeColors colorsFor(String brightness) =>
      brightness == 'dark' ? dark : light;

  List<Color> highlightsFor(String brightness) =>
      brightness == 'dark' ? darkHighlights : lightHighlights;

  List<Color> underlinesFor(String brightness) =>
      brightness == 'dark' ? darkUnderlines : lightUnderlines;

  Map<BibleSegment, Color> segmentColorsFor(String brightness) =>
      brightness == 'dark' ? darkSegmentColors : lightSegmentColors;
}

// ─────────────────────────────────────────────────────────────────────────────
// GruvBox (existing default)
// ─────────────────────────────────────────────────────────────────────────────

const _gruvbox = ThemePalette(
  id: 'gruvbox',
  label: 'GruvBox',
  accent: Color(0xFF4A7A8A),
  light: defaultLightColors,
  dark: defaultDarkColors,
  lightHighlights: lightHighlightColors,
  lightUnderlines: lightUnderlineColors,
  darkHighlights: darkHighlightColors,
  darkUnderlines: darkUnderlineColors,
  lightSegmentColors: _gruvboxLightSegments,
  darkSegmentColors: _gruvboxDarkSegments,
);

const _gruvboxLightSegments = <BibleSegment, Color>{
  BibleSegment.pentateuch: Color(0xFFB5D8B5),
  BibleSegment.historical: Color(0xFFB5CCE0),
  BibleSegment.poetic: Color(0xFFE8D5A0),
  BibleSegment.majorProphets: Color(0xFFDAAFAF),
  BibleSegment.minorProphets: Color(0xFFC5B5D8),
  BibleSegment.gospelsActs: Color(0xFFA8D5DC),
  BibleSegment.paulEpistles: Color(0xFFCAD8A8),
  BibleSegment.generalEpistles: Color(0xFFDCC8A8),
};

const _gruvboxDarkSegments = <BibleSegment, Color>{
  BibleSegment.pentateuch: Color(0xFF5B8C5A),
  BibleSegment.historical: Color(0xFF6B8DAD),
  BibleSegment.poetic: Color(0xFFC49B4A),
  BibleSegment.majorProphets: Color(0xFFA05050),
  BibleSegment.minorProphets: Color(0xFF8B6BAD),
  BibleSegment.gospelsActs: Color(0xFF4A90A0),
  BibleSegment.paulEpistles: Color(0xFF7A8B5A),
  BibleSegment.generalEpistles: Color(0xFF9A7A5A),
};

// ─────────────────────────────────────────────────────────────────────────────
// Tokyo Night
// ─────────────────────────────────────────────────────────────────────────────

const _tokyoNight = ThemePalette(
  id: 'tokyo_night',
  label: 'Tokyo Night',
  accent: Color(0xFF7AA2F7),
  light: CustomThemeColors(
    primary: Color(0xFF3D59A1),
    background: Color(0xFFD5D6DB),
    text: Color(0xFF343B58),
    textSecondary: Color(0xFF6A6F87),
    appBar: Color(0xFF3D59A1),
    appBarText: Color(0xFFD5D6DB),
    cardBackground: Color(0xFFCACBD0),
    popupHeader: Color(0xFFC0C1C6),
    popupHeaderText: Color(0xFF343B58),
    verseNumber: Color(0xFF8B90A5),
    indicator: Color(0xFF8B90A5),
    wordCommentDot: Color(0xFFFF9E64),
    link: Color(0xFF3D59A1),
    divider: Color(0xFFB0B1B6),
    criticalText: Color(0xFF9A9EB2),
    highlightBlink: Color(0x507AA2F7),
    wordCommentBg: Color(0x20FF9E64),
    error: Color(0xFFF7768E),
  ),
  dark: CustomThemeColors(
    primary: Color(0xFF7AA2F7),
    background: Color(0xFF1A1B26),
    text: Color(0xFFC0CAF5),
    textSecondary: Color(0xFF565F89),
    appBar: Color(0xFF24283B),
    appBarText: Color(0xFFC0CAF5),
    cardBackground: Color(0xFF24283B),
    popupHeader: Color(0xFF414868),
    popupHeaderText: Color(0xFFC0CAF5),
    verseNumber: Color(0xFF565F89),
    indicator: Color(0xFF565F89),
    wordCommentDot: Color(0xFFFF9E64),
    link: Color(0xFF7AA2F7),
    divider: Color(0xFF3B4261),
    criticalText: Color(0xFF444B6A),
    highlightBlink: Color(0x507AA2F7),
    wordCommentBg: Color(0x20FF9E64),
    error: Color(0xFFF7768E),
  ),
  lightHighlights: [
    Color(0x307AA2F7),
    Color(0x309ECE6A),
    Color(0x30FF9E64),
    Color(0x30E0AF68),
    Color(0x30F7768E),
  ],
  lightUnderlines: [
    Color(0xFF3D59A1),
    Color(0xFF587539),
    Color(0xFFB86430),
    Color(0xFFA88430),
    Color(0xFFB04050),
  ],
  darkHighlights: [
    Color(0x307AA2F7),
    Color(0x309ECE6A),
    Color(0x30FF9E64),
    Color(0x30E0AF68),
    Color(0x30F7768E),
  ],
  darkUnderlines: [
    Color(0xFF7AA2F7),
    Color(0xFF9ECE6A),
    Color(0xFFFF9E64),
    Color(0xFFE0AF68),
    Color(0xFFF7768E),
  ],
  lightSegmentColors: {
    BibleSegment.pentateuch: Color(0xFFB5CCB5),
    BibleSegment.historical: Color(0xFFB5C5E0),
    BibleSegment.poetic: Color(0xFFE0D5A8),
    BibleSegment.majorProphets: Color(0xFFD8B0B0),
    BibleSegment.minorProphets: Color(0xFFC0B5D8),
    BibleSegment.gospelsActs: Color(0xFFA8C8DC),
    BibleSegment.paulEpistles: Color(0xFFC5D0A8),
    BibleSegment.generalEpistles: Color(0xFFD8C5A8),
  },
  darkSegmentColors: {
    BibleSegment.pentateuch: Color(0xFF4A7A4A),
    BibleSegment.historical: Color(0xFF4A6A9A),
    BibleSegment.poetic: Color(0xFFB09040),
    BibleSegment.majorProphets: Color(0xFF904848),
    BibleSegment.minorProphets: Color(0xFF7A5A9A),
    BibleSegment.gospelsActs: Color(0xFF3A7A8A),
    BibleSegment.paulEpistles: Color(0xFF6A7A4A),
    BibleSegment.generalEpistles: Color(0xFF8A6A4A),
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Monokai Pro
// ─────────────────────────────────────────────────────────────────────────────

const _monokaiPro = ThemePalette(
  id: 'monokai_pro',
  label: 'Monokai Pro',
  accent: Color(0xFFA9DC76),
  light: CustomThemeColors(
    primary: Color(0xFF6A8A50),
    background: Color(0xFFFDFDF8),
    text: Color(0xFF2D2A2E),
    textSecondary: Color(0xFF727072),
    appBar: Color(0xFF6A8A50),
    appBarText: Color(0xFFFDFDF8),
    cardBackground: Color(0xFFF2F2ED),
    popupHeader: Color(0xFFE8E8E3),
    popupHeaderText: Color(0xFF2D2A2E),
    verseNumber: Color(0xFF939293),
    indicator: Color(0xFF939293),
    wordCommentDot: Color(0xFFFC9867),
    link: Color(0xFF6A8A50),
    divider: Color(0xFFD0D0CB),
    criticalText: Color(0xFFA0A0A0),
    highlightBlink: Color(0x50A9DC76),
    wordCommentBg: Color(0x20FC9867),
    error: Color(0xFFFF6188),
  ),
  dark: CustomThemeColors(
    primary: Color(0xFFA9DC76),
    background: Color(0xFF2D2A2E),
    text: Color(0xFFFCFCFA),
    textSecondary: Color(0xFF939293),
    appBar: Color(0xFF403E41),
    appBarText: Color(0xFFFCFCFA),
    cardBackground: Color(0xFF403E41),
    popupHeader: Color(0xFF5B595C),
    popupHeaderText: Color(0xFFFCFCFA),
    verseNumber: Color(0xFF727072),
    indicator: Color(0xFF727072),
    wordCommentDot: Color(0xFFFC9867),
    link: Color(0xFFA9DC76),
    divider: Color(0xFF5B595C),
    criticalText: Color(0xFF5B595C),
    highlightBlink: Color(0x50A9DC76),
    wordCommentBg: Color(0x20FC9867),
    error: Color(0xFFFF6188),
  ),
  lightHighlights: [
    Color(0x30A9DC76),
    Color(0x3078DCE8),
    Color(0x30FC9867),
    Color(0x30FFD866),
    Color(0x30FF6188),
  ],
  lightUnderlines: [
    Color(0xFF6A8A50),
    Color(0xFF4A8A98),
    Color(0xFFB06840),
    Color(0xFFB09840),
    Color(0xFFB04060),
  ],
  darkHighlights: [
    Color(0x30A9DC76),
    Color(0x3078DCE8),
    Color(0x30FC9867),
    Color(0x30FFD866),
    Color(0x30FF6188),
  ],
  darkUnderlines: [
    Color(0xFFA9DC76),
    Color(0xFF78DCE8),
    Color(0xFFFC9867),
    Color(0xFFFFD866),
    Color(0xFFFF6188),
  ],
  lightSegmentColors: {
    BibleSegment.pentateuch: Color(0xFFC5E0B5),
    BibleSegment.historical: Color(0xFFB5D8E0),
    BibleSegment.poetic: Color(0xFFE8DCA0),
    BibleSegment.majorProphets: Color(0xFFE0B0B0),
    BibleSegment.minorProphets: Color(0xFFD0B5D8),
    BibleSegment.gospelsActs: Color(0xFFA8D8D8),
    BibleSegment.paulEpistles: Color(0xFFD0D8A8),
    BibleSegment.generalEpistles: Color(0xFFD8CCA8),
  },
  darkSegmentColors: {
    BibleSegment.pentateuch: Color(0xFF5A8A4A),
    BibleSegment.historical: Color(0xFF4A7A8A),
    BibleSegment.poetic: Color(0xFFB09838),
    BibleSegment.majorProphets: Color(0xFF8A4848),
    BibleSegment.minorProphets: Color(0xFF7A5A8A),
    BibleSegment.gospelsActs: Color(0xFF3A8A7A),
    BibleSegment.paulEpistles: Color(0xFF6A8A3A),
    BibleSegment.generalEpistles: Color(0xFF8A6A3A),
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Dracula
// ─────────────────────────────────────────────────────────────────────────────

const _dracula = ThemePalette(
  id: 'dracula',
  label: 'Dracula',
  accent: Color(0xFFBD93F9),
  light: CustomThemeColors(
    primary: Color(0xFF7C5CB8),
    background: Color(0xFFF8F8F2),
    text: Color(0xFF282A36),
    textSecondary: Color(0xFF6272A4),
    appBar: Color(0xFF7C5CB8),
    appBarText: Color(0xFFF8F8F2),
    cardBackground: Color(0xFFEDEDE8),
    popupHeader: Color(0xFFE2E2DD),
    popupHeaderText: Color(0xFF282A36),
    verseNumber: Color(0xFF8A8A85),
    indicator: Color(0xFF8A8A85),
    wordCommentDot: Color(0xFFFFB86C),
    link: Color(0xFF7C5CB8),
    divider: Color(0xFFCCCCC7),
    criticalText: Color(0xFFA0A09B),
    highlightBlink: Color(0x50BD93F9),
    wordCommentBg: Color(0x20FFB86C),
    error: Color(0xFFFF5555),
  ),
  dark: CustomThemeColors(
    primary: Color(0xFFBD93F9),
    background: Color(0xFF282A36),
    text: Color(0xFFF8F8F2),
    textSecondary: Color(0xFF6272A4),
    appBar: Color(0xFF44475A),
    appBarText: Color(0xFFF8F8F2),
    cardBackground: Color(0xFF44475A),
    popupHeader: Color(0xFF6272A4),
    popupHeaderText: Color(0xFFF8F8F2),
    verseNumber: Color(0xFF6272A4),
    indicator: Color(0xFF6272A4),
    wordCommentDot: Color(0xFFFFB86C),
    link: Color(0xFFBD93F9),
    divider: Color(0xFF6272A4),
    criticalText: Color(0xFF44475A),
    highlightBlink: Color(0x50BD93F9),
    wordCommentBg: Color(0x20FFB86C),
    error: Color(0xFFFF5555),
  ),
  lightHighlights: [
    Color(0x30BD93F9),
    Color(0x3050FA7B),
    Color(0x30FFB86C),
    Color(0x30F1FA8C),
    Color(0x30FF5555),
  ],
  lightUnderlines: [
    Color(0xFF7C5CB8),
    Color(0xFF309A4A),
    Color(0xFFB08040),
    Color(0xFFA0A030),
    Color(0xFFB03030),
  ],
  darkHighlights: [
    Color(0x30BD93F9),
    Color(0x3050FA7B),
    Color(0x30FFB86C),
    Color(0x30F1FA8C),
    Color(0x30FF5555),
  ],
  darkUnderlines: [
    Color(0xFFBD93F9),
    Color(0xFF50FA7B),
    Color(0xFFFFB86C),
    Color(0xFFF1FA8C),
    Color(0xFFFF5555),
  ],
  lightSegmentColors: {
    BibleSegment.pentateuch: Color(0xFFC5D8C5),
    BibleSegment.historical: Color(0xFFC0C8E0),
    BibleSegment.poetic: Color(0xFFE8E0A8),
    BibleSegment.majorProphets: Color(0xFFE0B8B8),
    BibleSegment.minorProphets: Color(0xFFD0C0E0),
    BibleSegment.gospelsActs: Color(0xFFB0D8D8),
    BibleSegment.paulEpistles: Color(0xFFD0D8B0),
    BibleSegment.generalEpistles: Color(0xFFD8CDB0),
  },
  darkSegmentColors: {
    BibleSegment.pentateuch: Color(0xFF408A40),
    BibleSegment.historical: Color(0xFF4A609A),
    BibleSegment.poetic: Color(0xFFA09030),
    BibleSegment.majorProphets: Color(0xFF8A4040),
    BibleSegment.minorProphets: Color(0xFF7050A0),
    BibleSegment.gospelsActs: Color(0xFF308080),
    BibleSegment.paulEpistles: Color(0xFF608A30),
    BibleSegment.generalEpistles: Color(0xFF8A6030),
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// E-Ink (special, no light/dark — always the same)
// ─────────────────────────────────────────────────────────────────────────────

const _eink = ThemePalette(
  id: 'eink',
  label: 'E-Ink',
  accent: Color(0xFF000000),
  light: defaultEinkColors,
  dark: defaultEinkColors,
  lightHighlights: einkHighlightColors,
  lightUnderlines: einkUnderlineColors,
  darkHighlights: einkHighlightColors,
  darkUnderlines: einkUnderlineColors,
  lightSegmentColors: _einkSegments,
  darkSegmentColors: _einkSegments,
);

const _einkSegments = <BibleSegment, Color>{
  BibleSegment.pentateuch: Color(0xFFCCCCCC),
  BibleSegment.historical: Color(0xFFCCCCCC),
  BibleSegment.poetic: Color(0xFFCCCCCC),
  BibleSegment.majorProphets: Color(0xFFCCCCCC),
  BibleSegment.minorProphets: Color(0xFFCCCCCC),
  BibleSegment.gospelsActs: Color(0xFFCCCCCC),
  BibleSegment.paulEpistles: Color(0xFFCCCCCC),
  BibleSegment.generalEpistles: Color(0xFFCCCCCC),
};

// ─────────────────────────────────────────────────────────────────────────────
// Registry
// ─────────────────────────────────────────────────────────────────────────────

/// All available palettes (order = display order in settings).
const allPalettes = <ThemePalette>[
  _gruvbox,
  _tokyoNight,
  _monokaiPro,
  _dracula,
  _eink,
];

/// Quick lookup by id.
ThemePalette paletteById(String id) =>
    allPalettes.firstWhere((p) => p.id == id, orElse: () => _gruvbox);

/// Brightness options.
const brightnessOptions = <String, String>{
  'light': 'Светлая',
  'dark': 'Тёмная',
  'system': 'Системная',
  'schedule': 'Расписание',
};
