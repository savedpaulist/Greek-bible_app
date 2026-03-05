// lib/prefs_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import "../models/models.dart";
import 'dart:convert';

class PrefsService {
    static const _kRecentTagIds = 'recent_tag_ids';

    List<String> get recentTagIds {
        final raw = _p.getString(_kRecentTagIds);
        if (raw == null) return [];
        return List<String>.from(json.decode(raw) as List);
    }

    Future<void> setRecentTagIds(List<String> ids) =>
            _p.setString(_kRecentTagIds, json.encode(ids));
  static const _kFontSize = 'font_size';
  static const _kPopupFontSize = 'popup_font_size';
  static const _kDictFontSize = 'dict_font_size';
  static const _kFullPopupFontSize = 'full_popup_font_size';
  static const _kSearchFontSize = 'search_font_size';
  static const _kBook = 'book_number';
  static const _kChapter = 'chapter';
  static const _kVerse = 'verse';
  static const _kIndexBuilt = 'fts_index_built';
  static const _kScrollDown = 'hotkey_scroll_down';
  static const _kScrollUp = 'hotkey_scroll_up';
  static const _kAnimations = 'animations_enabled';
  static const _kFontFamily = 'font_family';
  static const _kThemeMode = 'theme_mode'; // 'light','dark','eink' (legacy)
  static const _kPalette = 'theme_palette'; // 'gruvbox','tokyo_night','monokai_pro','dracula','eink'
  static const _kBrightness = 'theme_brightness'; // 'light','dark','system','schedule'
  static const _kScheduleStart = 'theme_schedule_start'; // minutes from midnight
  static const _kScheduleEnd = 'theme_schedule_end';
  static const _kVersePreviewFont = 'verse_preview_font_size';
  static const _kSearchHistory = 'search_history';
  static const _kSearchHistoryLimit = 'search_history_limit';
  static const _kCriticalTextFont = 'critical_text_font_size';
  static const _kAppBarFontSize = 'appbar_font_size';
  static const _kShowCriticalText = 'show_critical_text';
  static const _kDbStoragePath = 'db_storage_path';
  static const _kIndexVersion = 'fts_index_version';
  static const _kAssetsExtracted = 'assets_extracted';
  static const _kTextSelection = 'text_selection_enabled';
  static const _kLineHeight = 'line_height';
  static const _kNoteFontSize = 'note_font_size';
  static const _kNoteFontFamily = 'note_font_family';
  static const _kNoteLineHeight = 'note_line_height';
  static const _kShowVerseNumbers = 'show_verse_numbers';
  static const _kNoteTitleSize = 'note_title_size';
  static const _kNoteH1Size = 'note_h1_size';
  static const _kNoteH2Size = 'note_h2_size';
  static const _kNoteH3Size = 'note_h3_size';
  static const _kNoteH4Size = 'note_h4_size';
  static const _kNoteExplorerFontSize = 'note_explorer_font_size';
  static const _kLanguage = 'app_language'; // 'ru' | 'en'

  late SharedPreferences _p;
  Future<void> init() async => _p = await SharedPreferences.getInstance();

  double get fontSize => _p.getDouble(_kFontSize) ?? 20.0;
  Future<void> setFontSize(double v) => _p.setDouble(_kFontSize, v);

  double get popupFontSize => _p.getDouble(_kPopupFontSize) ?? 15.0;
  Future<void> setPopupFontSize(double v) => _p.setDouble(_kPopupFontSize, v);

  double get dictionaryFontSize => _p.getDouble(_kDictFontSize) ?? 18.0;
  Future<void> setDictionaryFontSize(double v) =>
      _p.setDouble(_kDictFontSize, v);

  double get fullPopupFontSize => _p.getDouble(_kFullPopupFontSize) ?? 17.0;
  Future<void> setFullPopupFontSize(double v) =>
      _p.setDouble(_kFullPopupFontSize, v);

  double get searchFontSize => _p.getDouble(_kSearchFontSize) ?? 16.0;
  Future<void> setSearchFontSize(double v) => _p.setDouble(_kSearchFontSize, v);

  String get fontFamily => _p.getString(_kFontFamily) ?? 'Gentium';
  Future<void> setFontFamily(String v) => _p.setString(_kFontFamily, v);

  bool get animationsEnabled => _p.getBool(_kAnimations) ?? true;
  Future<void> setAnimationsEnabled(bool v) => _p.setBool(_kAnimations, v);

  /// Default: Ιω 3:16 (John 3:16), book_number 500 in this DB.
  ReadingPosition get position => ReadingPosition(
        bookNumber: _p.getInt(_kBook) ?? 500,
        chapter: _p.getInt(_kChapter) ?? 3,
        verse: _p.getInt(_kVerse) ?? 16,
      );
  void savePosition(int book, int ch, int verse) {
    _p.setInt(_kBook, book);
    _p.setInt(_kChapter, ch);
    _p.setInt(_kVerse, verse);
  }

  bool get isIndexBuilt => _p.getBool(_kIndexBuilt) ?? false;
  Future<void> setIndexBuilt(bool value) => _p.setBool(_kIndexBuilt, value);
  Future<void> clearIndexBuilt() => _p.setBool(_kIndexBuilt, false);

  int get indexVersion => _p.getInt(_kIndexVersion) ?? 0;
  Future<void> setIndexVersion(int v) => _p.setInt(_kIndexVersion, v);

  int get scrollDownKeyId => _p.getInt(_kScrollDown) ?? 0;
  int get scrollUpKeyId => _p.getInt(_kScrollUp) ?? 0;
  Future<void> setScrollDownKeyId(int id) => _p.setInt(_kScrollDown, id);
  Future<void> setScrollUpKeyId(int id) => _p.setInt(_kScrollUp, id);

  // ── Theme mode (legacy, still used for eink detection) ─────────────────
  String get themeMode => _p.getString(_kThemeMode) ?? 'light';
  Future<void> setThemeMode(String v) => _p.setString(_kThemeMode, v);

  // ── Palette + Brightness ──────────────────────────────────────────────
  String get palette => _p.getString(_kPalette) ?? 'gruvbox';
  Future<void> setPalette(String v) => _p.setString(_kPalette, v);

  String get brightness => _p.getString(_kBrightness) ?? 'light';
  Future<void> setBrightness(String v) => _p.setString(_kBrightness, v);

  /// Schedule: minutes from midnight (e.g. 480 = 08:00, 1200 = 20:00).
  int get scheduleStart => _p.getInt(_kScheduleStart) ?? 480;
  Future<void> setScheduleStart(int v) => _p.setInt(_kScheduleStart, v);

  int get scheduleEnd => _p.getInt(_kScheduleEnd) ?? 1200;
  Future<void> setScheduleEnd(int v) => _p.setInt(_kScheduleEnd, v);

  // ── Language ──────────────────────────────────────────────────────────────
  String get language => _p.getString(_kLanguage) ?? 'ru';
  Future<void> setLanguage(String v) => _p.setString(_kLanguage, v);

  // ── Verse preview font size ─────────────────────────────────────────────
  double get versePreviewFontSize => _p.getDouble(_kVersePreviewFont) ?? 16.0;
  Future<void> setVersePreviewFontSize(double v) =>
      _p.setDouble(_kVersePreviewFont, v);

  // ── Search history ──────────────────────────────────────────────────────
  List<String> get searchHistory {
    final raw = _p.getString(_kSearchHistory);
    if (raw == null) return [];
    return List<String>.from(json.decode(raw) as List);
  }

  Future<void> setSearchHistory(List<String> v) =>
      _p.setString(_kSearchHistory, json.encode(v));

  int get searchHistoryLimit => _p.getInt(_kSearchHistoryLimit) ?? 20;
  Future<void> setSearchHistoryLimit(int v) =>
      _p.setInt(_kSearchHistoryLimit, v);

  // ── Critical text font size ─────────────────────────────────────────────
  double get criticalTextFontSize => _p.getDouble(_kCriticalTextFont) ?? 14.0;
  Future<void> setCriticalTextFontSize(double v) =>
      _p.setDouble(_kCriticalTextFont, v);

  bool get showCriticalText => _p.getBool(_kShowCriticalText) ?? true;
  Future<void> setShowCriticalText(bool v) => _p.setBool(_kShowCriticalText, v);

  // ── AppBar font size ────────────────────────────────────────────────────
  double get appBarFontSize => _p.getDouble(_kAppBarFontSize) ?? 20.0;
  Future<void> setAppBarFontSize(double v) => _p.setDouble(_kAppBarFontSize, v);

  // ── Database storage path (Android SD‑card support) ────────────────────
  /// `null` means «not yet chosen» (first launch on Android).
  String? get dbStoragePath => _p.getString(_kDbStoragePath);
  Future<void> setDbStoragePath(String v) => _p.setString(_kDbStoragePath, v);
  bool get dbStoragePathSet => _p.containsKey(_kDbStoragePath);

  // ── Assets extraction state ─────────────────────────────────────────────
  bool get isAssetsExtracted => _p.getBool(_kAssetsExtracted) ?? false;
  Future<void> setAssetsExtracted(bool v) => _p.setBool(_kAssetsExtracted, v);

  // ── Text selection toggle ──────────────────────────────────────────────
  bool get textSelectionEnabled => _p.getBool(_kTextSelection) ?? false;
  Future<void> setTextSelectionEnabled(bool v) =>
      _p.setBool(_kTextSelection, v);
  // ── Line height ─────────────────────────────────────────────────────────
  double get lineHeight => _p.getDouble(_kLineHeight) ?? 1.55;
  Future<void> setLineHeight(double v) => _p.setDouble(_kLineHeight, v);
  // ── Note font settings ─────────────────────────────────────────────────
  double get noteFontSize => _p.getDouble(_kNoteFontSize) ?? 16.0;
  Future<void> setNoteFontSize(double v) => _p.setDouble(_kNoteFontSize, v);

  String get noteFontFamily => _p.getString(_kNoteFontFamily) ?? 'Gentium';
  Future<void> setNoteFontFamily(String v) => _p.setString(_kNoteFontFamily, v);

  double get noteLineHeight => _p.getDouble(_kNoteLineHeight) ?? 1.6;
  Future<void> setNoteLineHeight(double v) => _p.setDouble(_kNoteLineHeight, v);


  bool get showVerseNumbers => _p.getBool(_kShowVerseNumbers) ?? true;
  Future<void> setShowVerseNumbers(bool v) => _p.setBool(_kShowVerseNumbers, v);

  int? get noteFontColor => _p.getInt('note_font_color');
  Future<void> setNoteFontColor(int v) => _p.setInt('note_font_color', v);
  Future<void> removeNoteFontColor() => _p.remove('note_font_color');

  double get noteTitleSize => _p.getDouble(_kNoteTitleSize) ?? 22.0;
  Future<void> setNoteTitleSize(double v) => _p.setDouble(_kNoteTitleSize, v);

  double get noteH1Size => _p.getDouble(_kNoteH1Size) ?? 26.0;
  Future<void> setNoteH1Size(double v) => _p.setDouble(_kNoteH1Size, v);

  double get noteH2Size => _p.getDouble(_kNoteH2Size) ?? 22.0;
  Future<void> setNoteH2Size(double v) => _p.setDouble(_kNoteH2Size, v);

  double get noteH3Size => _p.getDouble(_kNoteH3Size) ?? 20.0;
  Future<void> setNoteH3Size(double v) => _p.setDouble(_kNoteH3Size, v);

  double get noteH4Size => _p.getDouble(_kNoteH4Size) ?? 18.0;
  Future<void> setNoteH4Size(double v) => _p.setDouble(_kNoteH4Size, v);

  double get noteExplorerFontSize =>
      _p.getDouble(_kNoteExplorerFontSize) ?? 14.0;
  Future<void> setNoteExplorerFontSize(double v) =>
      _p.setDouble(_kNoteExplorerFontSize, v);

  // ── UI Scale (B2) ──────────────────────────────────────────────────────────
  static const _kUiScale = 'ui_scale';
  double get uiScale => (_p.getDouble(_kUiScale) ?? 1.0).clamp(0.9, 2.0);
  Future<void> setUiScale(double v) =>
      _p.setDouble(_kUiScale, v.clamp(0.9, 2.0));

  // ── Custom theme colors (per theme mode) ───────────────────────────────
  /// Returns stored JSON for a given theme mode, or null if not customised.
  String? customThemeColorsJson(String themeMode) =>
      _p.getString('custom_colors_$themeMode');
  Future<void> setCustomThemeColorsJson(String themeMode, String jsonStr) =>
      _p.setString('custom_colors_$themeMode', jsonStr);
  Future<void> removeCustomThemeColors(String themeMode) =>
      _p.remove('custom_colors_$themeMode');

  // ── Generic key-value access ───────────────────────────────────────────
  String? getString(String key) => _p.getString(key);
  Future<void> setString(String key, String v) => _p.setString(key, v);
  Future<void> remove(String key) => _p.remove(key);
}
