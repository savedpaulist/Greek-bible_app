// lib/app_state.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/models.dart';
import 'db/db_service.dart';
import 'prefs/prefs_service.dart';
import 'l10n/app_strings.dart';
import 'themes.dart';
import 'themes/palette_registry.dart';

class AppState extends ChangeNotifier {
  final DBService db;
  final PrefsService prefs;

  AppState({required this.db, required this.prefs});

  // ── Данные ────────────────────────────────────────────────────────────────
  List<BookModel> books = [];
  List<VerseModel> _verses = [];
  List<VerseModel> get verses => _verses;

  List<int> _allChapters = [];
  List<int> get allChapters => _allChapters;

  // ── Tab Management (for build freezing) ──────────────────────────────────
  int activeTab = 1; // 0: Notes, 1: Bible, 2: Dictionary

  void setActiveTab(int index) {
    if (activeTab == index) return;
    activeTab = index;
    notifyListeners();
  }

  // ── Текущая позиция ───────────────────────────────────────────────────────
  int currentBook = 1;
  int currentChapter = 1;
  int currentVerse = 1;

  // Сигнал для HomeScreen: когда меняется — нужен скролл к currentChapter:currentVerse
  int navVersion = 0;

  // ── История навигации ────────────────────────────────────────────────────
  final List<ReadingPosition> _history = [];
  int _historyIndex = -1;
  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward =>
      _historyIndex >= 0 && _historyIndex < _history.length - 1;

  // ── Highlight (мигание слова после перехода по ссылке) ───────────────────
  HighlightTarget? highlightTarget;

  // ── Lightweight position label (only AppBar listens, no full rebuild) ────
  final positionLabel = ValueNotifier<String>('');

  void _updatePositionLabel() {
    final bookName = books
            .where((b) => b.bookNumber == currentBook)
            .firstOrNull
            ?.shortName ??
        '?';
    positionLabel.value = '$bookName $currentChapter:$currentVerse';
  }

  // ── Настройки ─────────────────────────────────────────────────────────────
  double fontSize = 20.0;
  double popupFontSize = 15.0;
  double dictionaryFontSize = 18.0;
  double fullPopupFontSize = 17.0;
  double searchFontSize = 16.0;
  double versePreviewFontSize = 16.0;
  String fontFamily = 'Gentium';
  bool animationsEnabled = true;
  int scrollDownKeyId = 0;
  int scrollUpKeyId = 0;
  String themeMode = 'light'; // resolved: 'light', 'dark', 'eink'
  late CustomThemeColors customColors;
  Map<BibleSegment, Color> segmentColors = {};
  String paletteName = 'gruvbox';
  String brightnessMode = 'light'; // 'light','dark','system','schedule'
  int scheduleStart = 480; // 08:00
  int scheduleEnd = 1200; // 20:00
  late ThemePalette _palette;
  double criticalTextFontSize = 14.0;
  bool showCriticalText = true;
  double appBarFontSize = 20.0;
  bool textSelectionEnabled = false;
  double lineHeight = 1.55;
  double noteFontSize = 16.0;
  String noteFontFamily = 'Gentium';
  double noteLineHeight = 1.6;
  // Removed typewriterMode
  int? noteFontColor;
  bool showVerseNumbers = true;
  double noteTitleSize = 22.0;
  double noteH1Size = 26.0;
  double noteH2Size = 22.0;
  double noteH3Size = 20.0;
  double noteH4Size = 18.0;
  double noteExplorerFontSize = 14.0;
  // B2: масштаб интерфейса (90%–200%, по умолчанию 100%)
  double uiScale = 1.0;
  String language = 'ru';
  late AppStrings strings;

  // ── История поиска ────────────────────────────────────────────────────────
  List<String> searchHistory = [];
  int searchHistoryLimit = 20;

  // ── Флаги загрузки ────────────────────────────────────────────────────────
  bool isLoadingBooks = true;
  bool isLoadingText = false;
  bool isIndexing = false;
  final indexProgress = ValueNotifier<double>(0.0);
  String? error;

  // ── Инициализация ─────────────────────────────────────────────────────────
  Future<void> initialize() async {
    fontSize = prefs.fontSize;
    popupFontSize = prefs.popupFontSize;
    dictionaryFontSize = prefs.dictionaryFontSize;
    fullPopupFontSize = prefs.fullPopupFontSize;
    searchFontSize = prefs.searchFontSize;
    versePreviewFontSize = prefs.versePreviewFontSize;
    fontFamily = prefs.fontFamily;
    animationsEnabled = prefs.animationsEnabled;
    scrollDownKeyId = prefs.scrollDownKeyId;
    scrollUpKeyId = prefs.scrollUpKeyId;
    language = prefs.language;
    strings = AppStrings.of(language);
    paletteName = prefs.palette;
    brightnessMode = prefs.brightness;
    scheduleStart = prefs.scheduleStart;
    scheduleEnd = prefs.scheduleEnd;
    _palette = paletteById(paletteName);
    themeMode = _resolvedBrightness();
    _loadCustomColors();
    criticalTextFontSize = prefs.criticalTextFontSize;
    showCriticalText = prefs.showCriticalText;
    appBarFontSize = prefs.appBarFontSize;
    textSelectionEnabled = prefs.textSelectionEnabled;
    lineHeight = prefs.lineHeight;
    noteFontSize = prefs.noteFontSize;
    noteFontFamily = prefs.noteFontFamily;
    noteLineHeight = prefs.noteLineHeight;
    // Removed typewriterMode
    noteFontColor = prefs.noteFontColor;
    showVerseNumbers = prefs.showVerseNumbers;
    noteTitleSize = prefs.noteTitleSize;
    noteH1Size = prefs.noteH1Size;
    noteH2Size = prefs.noteH2Size;
    noteH3Size = prefs.noteH3Size;
    noteH4Size = prefs.noteH4Size;
    noteExplorerFontSize = prefs.noteExplorerFontSize;
    uiScale = prefs.uiScale;
    searchHistory = prefs.searchHistory;
    searchHistoryLimit = prefs.searchHistoryLimit;

    final pos = prefs.position;
    currentBook = pos.bookNumber;
    currentChapter = pos.chapter;
    currentVerse = pos.verse;

    // On first Android launch, DB may not be fully fsynced yet after extraction.
    // Retry up to 3 times with a short delay.
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await loadBooks();
        await loadBook(currentBook);
        break;
      } catch (e) {
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 200));
          try { await db.reopenBible(); } catch (_) {}
        } else {
          error = e.toString();
        }
      }
    }
    _pushHistory(currentBook, currentChapter, currentVerse);

    // Rebuild index if never built, version outdated, or file missing on disk.
    // Current version: 6.
    final needsIndex = !prefs.isIndexBuilt ||
        prefs.indexVersion < 6 ||
        !await db.indexFileExists() ||
        await db.needsReindex();
    if (needsIndex) _buildIndex();
  }

  // ── Список книг ───────────────────────────────────────────────────────────
  Future<void> loadBooks() async {
    isLoadingBooks = true;
    notifyListeners();
    try {
      books = await db.getBooks();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingBooks = false;
      notifyListeners();
    }
  }

  // ── Загрузка книги ─────────────────────────────────────────────────────────
  // Стратегия: загружаем всю книгу целиком за один запрос.
  // После загрузки скролл работает без единого rebuild / подгрузки.
  Future<void> _loadFullBook(int bookNumber) async {
    // 1) Список глав (лёгкий SELECT DISTINCT — <5 мс)
    _allChapters = await db.getBookChapters(bookNumber);
    if (currentBook != bookNumber) return;

    // 2) Все слова книги за один запрос
    final allWords = await db.getWords(bookNumber);
    if (currentBook != bookNumber) return;
    _verses = db.groupIntoVerses(allWords);
  }

  /// Загрузка книги (начальная загрузка приложения).
  Future<void> loadBook(int bookNumber, {bool silent = false}) async {
    isLoadingText = true;
    error = null;
    currentBook = bookNumber;
    notifyListeners();
    try {
      await _loadFullBook(bookNumber);

      // Если текущая глава/стих отсутствуют в книге — сброс
      final chapters = allChapters;
      if (chapters.isNotEmpty && !chapters.contains(currentChapter)) {
        currentChapter = chapters.first;
        currentVerse = 1;
      }

      if (!silent) navVersion++;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingText = false;
      _updatePositionLabel();
      notifyListeners();
    }
  }

  // ── Выбор главы и стиха из пикера ─────────────────────────────────────────
  void selectChapterAndVerse(int chapter, int verse) {
    currentChapter = chapter;
    currentVerse = verse;
    highlightTarget = null;
    navVersion++;
    _pushHistory(currentBook, chapter, verse);
    _savePosition();
    _updatePositionLabel();
    notifyListeners();
  }

  // ── Переход по ссылке (поиск, словарь, пикер) ──────────────────────────────
  Future<void> navigateToVerse(
    int bookNumber,
    int chapter,
    int verse, {
    String? highlightStrongs,
  }) async {
    if (highlightStrongs != null) {
      highlightTarget = HighlightTarget(
        chapter: chapter,
        verse: verse,
        strongs: highlightStrongs,
      );
    }

    currentChapter = chapter;
    currentVerse = verse;

    if (bookNumber != currentBook) {
      isLoadingText = true;
      error = null;
      currentBook = bookNumber;
      notifyListeners();
      try {
        await _loadFullBook(bookNumber);
      } catch (e) {
        error = e.toString();
      } finally {
        isLoadingText = false;
      }
    }

    navVersion++;
    _pushHistory(bookNumber, chapter, verse);
    _savePosition();
    _updatePositionLabel();
    notifyListeners();
  }

  Future<void> goBack() async {
    if (!canGoBack) return;
    _historyIndex--;
    final pos = _history[_historyIndex];
    await _applyHistoryPosition(pos);
  }

  Future<void> goForward() async {
    if (!canGoForward) return;
    _historyIndex++;
    final pos = _history[_historyIndex];
    await _applyHistoryPosition(pos);
  }

  Future<void> _applyHistoryPosition(ReadingPosition pos) async {
    highlightTarget = null;
    currentChapter = pos.chapter;
    currentVerse = pos.verse;

    if (pos.bookNumber != currentBook) {
      isLoadingText = true;
      currentBook = pos.bookNumber;
      notifyListeners();
      try {
        await _loadFullBook(pos.bookNumber);
      } catch (e) {
        error = e.toString();
      } finally {
        isLoadingText = false;
      }
    }

    currentBook = pos.bookNumber;
    navVersion++;
    _savePosition();
    _updatePositionLabel();
    notifyListeners();
  }

  void _pushHistory(int book, int chapter, int verse) {
    final next =
        ReadingPosition(bookNumber: book, chapter: chapter, verse: verse);
    if (_historyIndex >= 0) {
      final cur = _history[_historyIndex];
      if (cur.bookNumber == next.bookNumber &&
          cur.chapter == next.chapter &&
          cur.verse == next.verse) {
        return;
      }
    }

    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(next);
    _historyIndex = _history.length - 1;
  }

  void clearHighlight() {
    highlightTarget = null;
    notifyListeners();
  }

  // ── Трекинг видимого стиха (из scroll listener) ───────────────────────────
  // НЕ вызывает notifyListeners() — обновление позиции при скролле не должно
  // перестраивать всё дерево виджетов. Для AppBar используется positionLabel.
  void updateVisibleVerse(int chapter, int verse) {
    if (chapter == currentChapter && verse == currentVerse) return;
    currentChapter = chapter;
    currentVerse = verse;
    _savePosition();
    _updatePositionLabel();
  }

  void _savePosition() {
    prefs.savePosition(currentBook, currentChapter, currentVerse);
  }

  // ── Настройки ─────────────────────────────────────────────────────────────

  /// Generic helper for double setters: clamp, persist, notify.
  void _setDouble(double value, double min, double max,
      void Function(double) assign, void Function(double) persist) {
    final clamped = value.clamp(min, max);
    assign(clamped);
    persist(clamped);
    notifyListeners();
  }

  void setFontSize(double size) =>
      _setDouble(size, 10, 40, (v) => fontSize = v, prefs.setFontSize);

  void setPopupFontSize(double size) => _setDouble(
      size, 10, 28, (v) => popupFontSize = v, prefs.setPopupFontSize);

  void setDictionaryFontSize(double size) => _setDouble(
      size, 10, 40, (v) => dictionaryFontSize = v, prefs.setDictionaryFontSize);

  void setFullPopupFontSize(double size) => _setDouble(
      size, 10, 40, (v) => fullPopupFontSize = v, prefs.setFullPopupFontSize);

  void setSearchFontSize(double size) => _setDouble(
      size, 10, 40, (v) => searchFontSize = v, prefs.setSearchFontSize);

  void setVersePreviewFontSize(double size) => _setDouble(size, 10, 40,
      (v) => versePreviewFontSize = v, prefs.setVersePreviewFontSize);

  void setCriticalTextFontSize(double size) => _setDouble(size, 8, 36,
      (v) => criticalTextFontSize = v, prefs.setCriticalTextFontSize);

  void setShowCriticalText(bool v) {
    showCriticalText = v;
    prefs.setShowCriticalText(v);
    notifyListeners();
  }

  void setShowVerseNumbers(bool v) {
    showVerseNumbers = v;
    prefs.setShowVerseNumbers(v);
    notifyListeners();
  }

  void setAppBarFontSize(double size) => _setDouble(
      size, 12, 30, (v) => appBarFontSize = v, prefs.setAppBarFontSize);

  void setTextSelectionEnabled(bool v) {
    textSelectionEnabled = v;
    prefs.setTextSelectionEnabled(v);
    notifyListeners();
  }

  void setLineHeight(double v) {
    lineHeight = v.clamp(1.0, 2.5);
    prefs.setLineHeight(lineHeight);
    notifyListeners();
  }

  void setNoteFontSize(double v) {
    noteFontSize = v.clamp(10.0, 32.0);
    prefs.setNoteFontSize(noteFontSize);
    notifyListeners();
  }

  void setNoteFontFamily(String family) {
    if (!availableFonts.containsKey(family)) return;
    noteFontFamily = family;
    prefs.setNoteFontFamily(family);
    notifyListeners();
  }

  void setNoteLineHeight(double v) {
    noteLineHeight = v.clamp(1.0, 2.5);
    prefs.setNoteLineHeight(noteLineHeight);
    notifyListeners();
  }

  // Removed setTypewriterMode
  /// System font logic for platform adaptivity
  static String getSystemFontFamily(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.iOS:
        return '.SF Pro Text';
      case TargetPlatform.android:
        return 'Roboto';
      case TargetPlatform.macOS:
        return '.SF NS Text';
      case TargetPlatform.windows:
        return 'Segoe UI';
      case TargetPlatform.linux:
        return 'Ubuntu';
      case TargetPlatform.fuchsia:
        return 'Roboto';
      // default unreachable
    }
  }

  void setNoteFontColor(int? color) {
    noteFontColor = color;
    if (color == null) {
      prefs.removeNoteFontColor();
    } else {
      prefs.setNoteFontColor(color);
    }
    notifyListeners();
  }

  void setNoteTitleSize(double v) =>
      _setDouble(v, 14, 48, (v) => noteTitleSize = v, prefs.setNoteTitleSize);

  void setNoteH1Size(double v) =>
      _setDouble(v, 14, 60, (v) => noteH1Size = v, prefs.setNoteH1Size);

  void setNoteH2Size(double v) =>
      _setDouble(v, 14, 54, (v) => noteH2Size = v, prefs.setNoteH2Size);

  void setNoteH3Size(double v) =>
      _setDouble(v, 14, 48, (v) => noteH3Size = v, prefs.setNoteH3Size);

  void setNoteH4Size(double v) =>
      _setDouble(v, 14, 42, (v) => noteH4Size = v, prefs.setNoteH4Size);

  void setNoteExplorerFontSize(double v) => _setDouble(v, 10, 32,
      (v) => noteExplorerFontSize = v, prefs.setNoteExplorerFontSize);

  // B2: масштаб UI
  void setUiScale(double v) {
    uiScale = v.clamp(0.9, 2.0);
    prefs.setUiScale(uiScale);
    notifyListeners();
  }

  /// Available font families (registered in pubspec.yaml)
  static const availableFonts = <String, String>{
    'Gentium': 'Gentium Plus',
    'CharisSIL': 'Charis SIL',
    'PTSerif': 'PT Serif',
    'SourceSerif4': 'Source Serif 4',
    'EBGaramond': 'EB Garamond',
    'DroidSerif': 'Droid Serif',
  };

  void setFontFamily(String family) {
    if (!availableFonts.containsKey(family)) return;
    fontFamily = family;
    prefs.setFontFamily(family);
    notifyListeners();
  }

  void setAnimations(bool enabled) {
    animationsEnabled = enabled;
    prefs.setAnimationsEnabled(enabled);
    notifyListeners();
  }

  void setScrollDownKey(int id) {
    scrollDownKeyId = id;
    prefs.setScrollDownKeyId(id);
    notifyListeners();
  }

  void setScrollUpKey(int id) {
    scrollUpKeyId = id;
    prefs.setScrollUpKeyId(id);
    notifyListeners();
  }

  // ── Language ────────────────────────────────────────────────────────────────
  void setLanguage(String lang) {
    if (lang != 'ru' && lang != 'en') return;
    language = lang;
    strings = AppStrings.of(lang);
    prefs.setLanguage(lang);
    notifyListeners();
  }

  // ── Theme ──────────────────────────────────────────────────────────────────

  /// Resolve actual brightness from brightnessMode setting.
  String _resolvedBrightness() {
    if (paletteName == 'eink') return 'eink';
    switch (brightnessMode) {
      case 'dark':
        return 'dark';
      case 'system':
        final platformBrightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return platformBrightness == Brightness.dark ? 'dark' : 'light';
      case 'schedule':
        final now = TimeOfDay.now();
        final nowMinutes = now.hour * 60 + now.minute;
        if (scheduleStart <= scheduleEnd) {
          // e.g. 08:00–20:00 → light during this window
          return (nowMinutes >= scheduleStart && nowMinutes < scheduleEnd)
              ? 'light'
              : 'dark';
        } else {
          // e.g. 20:00–08:00 → dark during this window
          return (nowMinutes >= scheduleEnd && nowMinutes < scheduleStart)
              ? 'light'
              : 'dark';
        }
      default:
        return 'light';
    }
  }

  /// Legacy setter — kept for backward compat with settings that set light/dark/eink directly.
  void setThemeMode(String mode) {
    if (!const ['light', 'dark', 'eink'].contains(mode)) return;
    if (mode == 'eink') {
      setPalette('eink');
      return;
    }
    brightnessMode = mode;
    prefs.setBrightness(mode);
    themeMode = _resolvedBrightness();
    prefs.setThemeMode(themeMode);
    _loadCustomColors();
    notifyListeners();
  }

  void setPalette(String id) {
    paletteName = id;
    _palette = paletteById(id);
    prefs.setPalette(id);
    themeMode = _resolvedBrightness();
    prefs.setThemeMode(themeMode);
    _loadCustomColors();
    notifyListeners();
  }

  void setBrightness(String mode) {
    brightnessMode = mode;
    prefs.setBrightness(mode);
    themeMode = _resolvedBrightness();
    prefs.setThemeMode(themeMode);
    _loadCustomColors();
    notifyListeners();
  }

  void setSchedule(int startMinutes, int endMinutes) {
    scheduleStart = startMinutes;
    scheduleEnd = endMinutes;
    prefs.setScheduleStart(startMinutes);
    prefs.setScheduleEnd(endMinutes);
    if (brightnessMode == 'schedule') {
      themeMode = _resolvedBrightness();
      prefs.setThemeMode(themeMode);
      _loadCustomColors();
      notifyListeners();
    }
  }

  /// Recheck brightness (called on system brightness change or schedule timer).
  void recheckBrightness() {
    final resolved = _resolvedBrightness();
    if (resolved != themeMode) {
      themeMode = resolved;
      prefs.setThemeMode(themeMode);
      _loadCustomColors();
      notifyListeners();
    }
  }

  /// Load custom colours for current themeMode (merging over palette defaults).
  void _loadCustomColors() {
    final defaults = _palette.colorsFor(themeMode);
    final jsonStr = prefs.customThemeColorsJson(themeMode);
    if (jsonStr != null) {
      customColors = CustomThemeColors.fromJson(jsonStr, defaults);
    } else {
      customColors = defaults;
    }
    _loadSegmentColors();
  }

  void _loadSegmentColors() {
    final defaults = _palette.segmentColorsFor(themeMode);
    final jsonStr = prefs.getString('segmentColors_$themeMode');
    if (jsonStr != null) {
      try {
        final m = json.decode(jsonStr) as Map<String, dynamic>;
        segmentColors = {
          for (final s in BibleSegment.values)
            s: m.containsKey(s.name) ? Color(m[s.name] as int) : defaults[s]!,
        };
      } catch (_) {
        segmentColors = defaults;
      }
    } else {
      segmentColors = defaults;
    }
  }

  void setSegmentColor(BibleSegment seg, Color color) {
    segmentColors[seg] = color;
    final m = {
      for (final s in BibleSegment.values) s.name: segmentColors[s]!.toARGB32()
    };
    prefs.setString('segmentColors_$themeMode', json.encode(m));
    notifyListeners();
  }

  void resetSegmentColors() {
    segmentColors = defaultSegmentColors(themeMode);
    prefs.remove('segmentColors_$themeMode');
    notifyListeners();
  }

  /// Set a single colour role and persist.
  void setThemeColor(String role, Color color) {
    customColors = customColors.withRole(role, color);
    prefs.setCustomThemeColorsJson(themeMode, customColors.toJson());
    notifyListeners();
  }

  /// Reset all custom colours for the current theme to defaults.
  void resetThemeColors() {
    customColors = defaultColorsForTheme(themeMode);
    prefs.removeCustomThemeColors(themeMode);
    notifyListeners();
  }

  /// Single source of truth for the app theme.
  ThemeData get currentTheme => buildTheme(
        themeMode,
        customColors,
        fontFamily,
        disableAnimations: !animationsEnabled,
      );

  // ── Search history ─────────────────────────────────────────────────────────
  void addSearchQuery(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    searchHistory.remove(q);
    searchHistory.insert(0, q);
    if (searchHistory.length > searchHistoryLimit) {
      searchHistory = searchHistory.sublist(0, searchHistoryLimit);
    }
    prefs.setSearchHistory(searchHistory);
    notifyListeners();
  }

  void removeSearchQuery(String query) {
    searchHistory.remove(query);
    prefs.setSearchHistory(searchHistory);
    notifyListeners();
  }

  void clearSearchHistory() {
    searchHistory.clear();
    prefs.setSearchHistory(searchHistory);
    notifyListeners();
  }

  void setSearchHistoryLimit(int limit) {
    searchHistoryLimit = limit.clamp(5, 100);
    prefs.setSearchHistoryLimit(searchHistoryLimit);
    if (searchHistory.length > searchHistoryLimit) {
      searchHistory = searchHistory.sublist(0, searchHistoryLimit);
      prefs.setSearchHistory(searchHistory);
    }
    notifyListeners();
  }

  bool isScrollDownKey(LogicalKeyboardKey k) =>
      scrollDownKeyId != 0 && k.keyId == scrollDownKeyId;
  bool isScrollUpKey(LogicalKeyboardKey k) =>
      scrollUpKeyId != 0 && k.keyId == scrollUpKeyId;

  // Заглушки — windowManager больше не используется
  void expandWindowBackward() {}
  void expandWindowForward() {}

  // ── Поисковый индекс ─────────────────────────────────────────────────────
  String? indexError;

  Future<void> _buildIndex() async {
    isIndexing = true;
    indexProgress.value = 0;
    indexError = null;
    notifyListeners();
    try {
      await db.buildIndex(onProgress: (p) {
        indexProgress.value = p;
      });
      await prefs.setIndexBuilt(true);
      await prefs.setIndexVersion(6);
      indexError = null;
    } catch (e, st) {
      debugPrint('Index error: $e\n$st');
      indexError = e.toString();
      // Mark as not built so it retries on next launch.
      await prefs.clearIndexBuilt();
    } finally {
      isIndexing = false;
      notifyListeners();
    }
  }

  Future<void> rebuildIndex() async {
    isIndexing = true;
    indexProgress.value = 0;
    indexError = null;
    notifyListeners();
    await prefs.clearIndexBuilt();
    // Close and delete the old index so we start completely fresh.
    await db.deleteIndex();
    await _buildIndex();
  }
}
