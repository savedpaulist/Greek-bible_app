// lib/core/themes.dart
//
// ВСЕ ТЕМЫ И ПАЛИТРЫ ПРИЛОЖЕНИЯ.
// Файл вынесен отдельно для ручной настройки.
//
// CustomThemeColors — пользовательские цвета, которые можно
// менять через Настройки → Цвета. Хранятся в SharedPreferences
// отдельно для каждой темы (light / dark / eink).

import 'dart:convert';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Пользовательские цвета (по ролям)
// ─────────────────────────────────────────────────────────────────────────────

/// Все цветовые роли, которые может менять пользователь.
class CustomThemeColors {
  /// Основной акцент (AppBar, кнопки, ссылки)
  final Color primary;

  /// Фон экрана
  final Color background;

  /// Цвет текста
  final Color text;

  /// Второстепенный текст (морфология, даты)
  final Color textSecondary;

  /// Фон AppBar
  final Color appBar;

  /// Цвет текста AppBar
  final Color appBarText;

  /// Фон подложки попапа / карточки
  final Color cardBackground;

  /// Фон заголовка попапа
  final Color popupHeader;

  /// Цвет текста заголовка попапа
  final Color popupHeaderText;

  /// Цвет номера стиха
  final Color verseNumber;

  /// Цвет иконок-индикаторов (комментарии, параллели)
  final Color indicator;

  /// Цвет точки комментария к слову
  final Color wordCommentDot;

  /// Ссылки в HTML
  final Color link;

  /// Разделители (Divider)
  final Color divider;

  /// Критический текст (тусклый)
  final Color criticalText;

  /// Фон подсветки искомого слова (мигание)
  final Color highlightBlink;

  /// Фон слова с комментарием
  final Color wordCommentBg;

  /// Ошибки
  final Color error;

  const CustomThemeColors({
    required this.primary,
    required this.background,
    required this.text,
    required this.textSecondary,
    required this.appBar,
    required this.appBarText,
    required this.cardBackground,
    required this.popupHeader,
    required this.popupHeaderText,
    required this.verseNumber,
    required this.indicator,
    required this.wordCommentDot,
    required this.link,
    required this.divider,
    required this.criticalText,
    required this.highlightBlink,
    required this.wordCommentBg,
    required this.error,
  });

  /// Все роли в определённом порядке для UI.
  static const roleLabels = <String, String>{
    'primary':         'Основной акцент',
    'background':      'Фон',
    'text':            'Текст',
    'textSecondary':   'Второстепенный текст',
    'appBar':          'Фон AppBar',
    'appBarText':      'Текст AppBar',
    'cardBackground':  'Фон карточки / попапа',
    'popupHeader':     'Фон заголовка попапа',
    'popupHeaderText': 'Текст заголовка попапа',
    'verseNumber':     'Номер стиха',
    'indicator':       'Иконки-индикаторы',
    'wordCommentDot':  'Точка комментария слова',
    'link':            'Ссылки',
    'divider':         'Разделители',
    'criticalText':    'Критический текст',
    'highlightBlink':  'Подсветка слова',
    'wordCommentBg':   'Фон слова с комментарием',
    'error':           'Ошибки',
  };

  Color getByRole(String role) {
    switch (role) {
      case 'primary':         return primary;
      case 'background':      return background;
      case 'text':            return text;
      case 'textSecondary':   return textSecondary;
      case 'appBar':          return appBar;
      case 'appBarText':      return appBarText;
      case 'cardBackground':  return cardBackground;
      case 'popupHeader':     return popupHeader;
      case 'popupHeaderText': return popupHeaderText;
      case 'verseNumber':     return verseNumber;
      case 'indicator':       return indicator;
      case 'wordCommentDot':  return wordCommentDot;
      case 'link':            return link;
      case 'divider':         return divider;
      case 'criticalText':    return criticalText;
      case 'highlightBlink':  return highlightBlink;
      case 'wordCommentBg':   return wordCommentBg;
      case 'error':           return error;
      default: return primary;
    }
  }

  CustomThemeColors withRole(String role, Color color) {
    return CustomThemeColors(
      primary:         role == 'primary'         ? color : primary,
      background:      role == 'background'      ? color : background,
      text:            role == 'text'             ? color : text,
      textSecondary:   role == 'textSecondary'    ? color : textSecondary,
      appBar:          role == 'appBar'           ? color : appBar,
      appBarText:      role == 'appBarText'       ? color : appBarText,
      cardBackground:  role == 'cardBackground'   ? color : cardBackground,
      popupHeader:     role == 'popupHeader'      ? color : popupHeader,
      popupHeaderText: role == 'popupHeaderText'  ? color : popupHeaderText,
      verseNumber:     role == 'verseNumber'      ? color : verseNumber,
      indicator:       role == 'indicator'        ? color : indicator,
      wordCommentDot:  role == 'wordCommentDot'   ? color : wordCommentDot,
      link:            role == 'link'             ? color : link,
      divider:         role == 'divider'          ? color : divider,
      criticalText:    role == 'criticalText'     ? color : criticalText,
      highlightBlink:  role == 'highlightBlink'   ? color : highlightBlink,
      wordCommentBg:   role == 'wordCommentBg'    ? color : wordCommentBg,
      error:           role == 'error'            ? color : error,
    );
  }

  Map<String, int> toMap() => {
    'primary':         primary.toARGB32(),
    'background':      background.toARGB32(),
    'text':            text.toARGB32(),
    'textSecondary':   textSecondary.toARGB32(),
    'appBar':          appBar.toARGB32(),
    'appBarText':      appBarText.toARGB32(),
    'cardBackground':  cardBackground.toARGB32(),
    'popupHeader':     popupHeader.toARGB32(),
    'popupHeaderText': popupHeaderText.toARGB32(),
    'verseNumber':     verseNumber.toARGB32(),
    'indicator':       indicator.toARGB32(),
    'wordCommentDot':  wordCommentDot.toARGB32(),
    'link':            link.toARGB32(),
    'divider':         divider.toARGB32(),
    'criticalText':    criticalText.toARGB32(),
    'highlightBlink':  highlightBlink.toARGB32(),
    'wordCommentBg':   wordCommentBg.toARGB32(),
    'error':           error.toARGB32(),
  };

  String toJson() => json.encode(toMap());

  factory CustomThemeColors.fromMap(Map<String, dynamic> m, CustomThemeColors fallback) {
    Color c(String key, Color fb) =>
        m.containsKey(key) ? Color(m[key] as int) : fb;
    return CustomThemeColors(
      primary:         c('primary',         fallback.primary),
      background:      c('background',      fallback.background),
      text:            c('text',            fallback.text),
      textSecondary:   c('textSecondary',   fallback.textSecondary),
      appBar:          c('appBar',          fallback.appBar),
      appBarText:      c('appBarText',      fallback.appBarText),
      cardBackground:  c('cardBackground',  fallback.cardBackground),
      popupHeader:     c('popupHeader',     fallback.popupHeader),
      popupHeaderText: c('popupHeaderText', fallback.popupHeaderText),
      verseNumber:     c('verseNumber',     fallback.verseNumber),
      indicator:       c('indicator',       fallback.indicator),
      wordCommentDot:  c('wordCommentDot',  fallback.wordCommentDot),
      link:            c('link',            fallback.link),
      divider:         c('divider',         fallback.divider),
      criticalText:    c('criticalText',    fallback.criticalText),
      highlightBlink:  c('highlightBlink',  fallback.highlightBlink),
      wordCommentBg:   c('wordCommentBg',   fallback.wordCommentBg),
      error:           c('error',           fallback.error),
    );
  }

  factory CustomThemeColors.fromJson(String jsonStr, CustomThemeColors fallback) {
    try {
      final m = json.decode(jsonStr) as Map<String, dynamic>;
      return CustomThemeColors.fromMap(m, fallback);
    } catch (_) {
      return fallback;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Дефолтные палитры
// ─────────────────────────────────────────────────────────────────────────────

/// Светлая тема (GruvBox, пониженная насыщенность)
const defaultLightColors = CustomThemeColors(
  primary:         Color(0xFF4A7A8A),
  background:      Color(0xFFF5ECD7),
  text:            Color(0xFF3C3836),
  textSecondary:   Color(0xFF7C7065),
  appBar:          Color(0xFF4A7A8A),
  appBarText:      Color(0xFFF5ECD7),
  cardBackground:  Color(0xFFF0E6CC),
  popupHeader:     Color(0xFFE8DEC0),
  popupHeaderText: Color(0xFF3C3836),
  verseNumber:     Color(0xFF7C8B92),
  indicator:       Color(0xFF7C8B92),
  wordCommentDot:  Color(0xFFBF8040),
  link:            Color(0xFF4A7A8A),
  divider:         Color(0xFFCDC1A5),
  criticalText:    Color(0xFFA89B84),
  highlightBlink:  Color(0x504A7A8A),
  wordCommentBg:   Color(0x20BF8040),
  error:           Color(0xFFA84032),
);

/// Тёмная тема (GruvBox dark)
const defaultDarkColors = CustomThemeColors(
  primary:         Color(0xFF8EC07C),
  background:      Color(0xFF1D2021),
  text:            Color(0xFFEBDBB2),
  textSecondary:   Color(0xFFBDAE93),
  appBar:          Color(0xFF3C3836),
  appBarText:      Color(0xFFEBDBB2),
  cardBackground:  Color(0xFF282828),
  popupHeader:     Color(0xFF504945),
  popupHeaderText: Color(0xFFEBDBB2),
  verseNumber:     Color(0xFF928374),
  indicator:       Color(0xFF928374),
  wordCommentDot:  Color(0xFFFE8019),
  link:            Color(0xFF83A598),
  divider:         Color(0xFF504945),
  criticalText:    Color(0xFF7C6F64),
  highlightBlink:  Color(0x508EC07C),
  wordCommentBg:   Color(0x20FE8019),
  error:           Color(0xFFFB4934),
);

/// E-Ink тема
const defaultEinkColors = CustomThemeColors(
  primary:         Color(0xFF000000),
  background:      Color(0xFFFFFFFF),
  text:            Color(0xFF000000),
  textSecondary:   Color(0xFF555555),
  appBar:          Color(0xFF000000),
  appBarText:      Color(0xFFFFFFFF),
  cardBackground:  Color(0xFFF0F0F0),
  popupHeader:     Color(0xFFE0E0E0),
  popupHeaderText: Color(0xFF000000),
  verseNumber:     Color(0xFF777777),
  indicator:       Color(0xFF777777),
  wordCommentDot:  Color(0xFF555555),
  link:            Color(0xFF333333),
  divider:         Color(0xFFBBBBBB),
  criticalText:    Color(0xFF999999),
  highlightBlink:  Color(0x40000000),
  wordCommentBg:   Color(0x15555555),
  error:           Color(0xFF333333),
);

/// Возвращает дефолтную палитру для данного режима темы.
CustomThemeColors defaultColorsForTheme(String themeMode) {
  switch (themeMode) {
    case 'dark':  return defaultDarkColors;
    case 'eink':  return defaultEinkColors;
    default:      return defaultLightColors;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Highlight / Underline цвета (для маркировки стихов)
// ─────────────────────────────────────────────────────────────────────────────

const lightHighlightColors = <Color>[
  Color(0x304A7A8A),
  Color(0x30698B69),
  Color(0x30BF8040),
  Color(0x30A89030),
  Color(0x30A84032),
];

const lightUnderlineColors = <Color>[
  Color(0xFF4A7A8A),
  Color(0xFF698B69),
  Color(0xFFBF8040),
  Color(0xFFA89030),
  Color(0xFFA84032),
];

const darkHighlightColors = <Color>[
  Color(0x3083A598),
  Color(0x308EC07C),
  Color(0x30FE8019),
  Color(0x30FABD2F),
  Color(0x30FB4934),
];

const darkUnderlineColors = <Color>[
  Color(0xFF83A598),
  Color(0xFF8EC07C),
  Color(0xFFFE8019),
  Color(0xFFFABD2F),
  Color(0xFFFB4934),
];

const einkHighlightColors = <Color>[
  Color(0x30777777),
];

const einkUnderlineColors = <Color>[
  Color(0xFF555555),
];

List<Color> highlightColorsForTheme(String themeMode) {
  switch (themeMode) {
    case 'dark':  return darkHighlightColors;
    case 'eink':  return einkHighlightColors;
    default:      return lightHighlightColors;
  }
}

List<Color> underlineColorsForTheme(String themeMode) {
  switch (themeMode) {
    case 'dark':  return darkUnderlineColors;
    case 'eink':  return einkUnderlineColors;
    default:      return lightUnderlineColors;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ThemeData builders (используют CustomThemeColors)
// ─────────────────────────────────────────────────────────────────────────────

ThemeData buildThemeFromColors(CustomThemeColors c, String font, String mode, {bool disableAnimations = false}) {
  final isLight = mode != 'dark';
  final cs = isLight
      ? ColorScheme.light(
          primary:              c.primary,
          onPrimary:            c.appBarText,
          primaryContainer:     c.popupHeader,
          onPrimaryContainer:   c.popupHeaderText,
          secondary:            c.textSecondary,
          onSecondary:          c.background,
          secondaryContainer:   c.cardBackground,
          onSecondaryContainer: c.text,
          tertiary:             c.wordCommentDot,
          error:                c.error,
          surface:              c.background,
          onSurface:            c.text,
          surfaceContainerHighest: c.cardBackground,
          outline:              c.divider,
          outlineVariant:       c.divider,
        )
      : ColorScheme.dark(
          primary:              c.primary,
          onPrimary:            c.background,
          primaryContainer:     c.popupHeader,
          onPrimaryContainer:   c.popupHeaderText,
          secondary:            c.link,
          onSecondary:          c.background,
          secondaryContainer:   c.cardBackground,
          onSecondaryContainer: c.text,
          tertiary:             c.wordCommentDot,
          error:                c.error,
          surface:              c.background,
          onSurface:            c.text,
          surfaceContainerHighest: c.cardBackground,
          outline:              c.divider,
          outlineVariant:       c.divider,
        );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    fontFamily: font,
    scaffoldBackgroundColor: c.background,
    textTheme: TextTheme(
      bodyMedium:  TextStyle(fontFamily: font, color: c.text),
      bodyLarge:   TextStyle(fontFamily: font, color: c.text),
      titleMedium: TextStyle(fontFamily: font, color: c.text),
      titleLarge:  TextStyle(fontFamily: font, color: c.text),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.appBar,
      foregroundColor: c.appBarText,
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, color: c.appBarText),
      iconTheme: IconThemeData(color: c.appBarText),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.cardBackground,
      selectedColor: c.primary.withValues(alpha: 0.25),
      labelStyle: TextStyle(fontFamily: font, color: c.text),
    ),
    dividerColor: c.divider,
    iconTheme: IconThemeData(color: c.text),
    splashFactory: mode == 'eink' ? NoSplash.splashFactory : null,
    pageTransitionsTheme: disableAnimations
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _NoAnimPageTransitionsBuilder(),
              TargetPlatform.iOS: _NoAnimPageTransitionsBuilder(),
              TargetPlatform.macOS: _NoAnimPageTransitionsBuilder(),
              TargetPlatform.linux: _NoAnimPageTransitionsBuilder(),
              TargetPlatform.windows: _NoAnimPageTransitionsBuilder(),
            },
          )
        : null,
  );
}

/// Page transition builder that shows pages instantly (no animation).
class _NoAnimPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Convenience — build from theme mode string.
ThemeData buildLightTheme(String font, [CustomThemeColors? colors]) =>
    buildThemeFromColors(colors ?? defaultLightColors, font, 'light');

ThemeData buildDarkTheme(String font, [CustomThemeColors? colors]) =>
    buildThemeFromColors(colors ?? defaultDarkColors, font, 'dark');

ThemeData buildEinkTheme(String font, [CustomThemeColors? colors]) =>
    buildThemeFromColors(colors ?? defaultEinkColors, font, 'eink');

/// Single entry point for theme building.
ThemeData buildTheme(
  String mode,
  CustomThemeColors colors,
  String font, {
  bool disableAnimations = false,
}) {
  switch (mode) {
    case 'dark':
      return buildThemeFromColors(colors, font, 'dark',
          disableAnimations: disableAnimations);
    case 'eink':
      return buildThemeFromColors(colors, font, 'eink',
          disableAnimations: disableAnimations);
    default:
      return buildThemeFromColors(colors, font, 'light',
          disableAnimations: disableAnimations);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bible segment colors (for book picker grid)
// ─────────────────────────────────────────────────────────────────────────────

/// Bible segments enum.
enum BibleSegment {
  pentateuch,        // Πятикнижие      10-50
  historical,        // Исторические     60-190
  poetic,            // Поэтические      220-260
  majorProphets,     // Большие пророки  290-340
  minorProphets,     // Малые пророки    350-460
  gospelsActs,       // Евангелия+Деяния 470-510
  paulEpistles,      // Послания Павла   520-650
  generalEpistles,   // Соборные+Откр    660-730
}

/// Human-readable labels for each segment.
const segmentLabels = <BibleSegment, String>{
  BibleSegment.pentateuch:      'Пятикнижие',
  BibleSegment.historical:      'Исторические книги',
  BibleSegment.poetic:          'Поэтические книги',
  BibleSegment.majorProphets:   'Большие пророки',
  BibleSegment.minorProphets:   'Малые пророки',
  BibleSegment.gospelsActs:     'Евангелия и Деяния',
  BibleSegment.paulEpistles:    'Послания Павла',
  BibleSegment.generalEpistles: 'Соборные послания и Откровение',
};

/// Determine segment from book number.
BibleSegment segmentForBook(int bookNumber) {
  if (bookNumber >= 10 && bookNumber <= 50)   return BibleSegment.pentateuch;
  if (bookNumber >= 60 && bookNumber <= 190)  return BibleSegment.historical;
  if (bookNumber >= 220 && bookNumber <= 260) return BibleSegment.poetic;
  if (bookNumber >= 290 && bookNumber <= 340) return BibleSegment.majorProphets;
  if (bookNumber >= 350 && bookNumber <= 460) return BibleSegment.minorProphets;
  if (bookNumber >= 470 && bookNumber <= 510) return BibleSegment.gospelsActs;
  if (bookNumber >= 520 && bookNumber <= 650) return BibleSegment.paulEpistles;
  return BibleSegment.generalEpistles;
}

/// Default segment colors per theme.
Map<BibleSegment, Color> defaultSegmentColors(String themeMode) {
  if (themeMode == 'dark') {
    return {
      BibleSegment.pentateuch:      const Color(0xFF5B8C5A),
      BibleSegment.historical:      const Color(0xFF6B8DAD),
      BibleSegment.poetic:          const Color(0xFFC49B4A),
      BibleSegment.majorProphets:   const Color(0xFFA05050),
      BibleSegment.minorProphets:   const Color(0xFF8B6BAD),
      BibleSegment.gospelsActs:     const Color(0xFF4A90A0),
      BibleSegment.paulEpistles:    const Color(0xFF7A8B5A),
      BibleSegment.generalEpistles: const Color(0xFF9A7A5A),
    };
  }
  if (themeMode == 'eink') {
    return {
      for (final s in BibleSegment.values) s: const Color(0xFFCCCCCC),
    };
  }
  // light
  return {
    BibleSegment.pentateuch:      const Color(0xFFB5D8B5),
    BibleSegment.historical:      const Color(0xFFB5CCE0),
    BibleSegment.poetic:          const Color(0xFFE8D5A0),
    BibleSegment.majorProphets:   const Color(0xFFDAAFAF),
    BibleSegment.minorProphets:   const Color(0xFFC5B5D8),
    BibleSegment.gospelsActs:     const Color(0xFFA8D5DC),
    BibleSegment.paulEpistles:    const Color(0xFFCAD8A8),
    BibleSegment.generalEpistles: const Color(0xFFDCC8A8),
  };
}
