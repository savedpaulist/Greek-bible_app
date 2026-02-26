// lib/home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
// ScrollDirection уже импортируется из material.dart
import '../../../core/app_state.dart';
import '../../../core/bible_utils.dart';
import '../../../core/keyboard_scroll_helpers.dart';
import '../../../core/models/models.dart';
import '../../search/view/search_screen.dart';
import '../../notes/provider/notes_provider.dart';
import '../../notes/data/note_model.dart';
import '../../settings/view/settings_screen.dart';
import 'book_chapter_dialog.dart';
import 'verse_widgets.dart';
import 'comment_sheets.dart';

// ─────────────────────────────────────────────────────────────────────────────

enum _ScrollDirection { forward, reverse }
typedef ScrollDirectionCallback = void Function(_ScrollDirection direction);

class HomeScreen extends StatefulWidget {
  final ScrollDirectionCallback? onScrollDirection;
  const HomeScreen({super.key, this.onScrollDirection});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  double _lastScrollOffset = 0;
  final ItemScrollController _itemScroll = ItemScrollController();
  final ItemPositionsListener _positionsListener = ItemPositionsListener.create();
  final FocusNode _focusNode = FocusNode();

  @override
  bool get wantKeepAlive => true;

  // Последний navVersion, по которому уже сделан скролл
  int _lastNavVersion = -1;

  // Следим за сменой книги, чтобы сбросить кэши
  int _lastBook = -1;
  Timer? _scrollDebounce;

  // ── Verse indicators: comment & parallel counts per chapter ──────────────
  // Key = "book:chapter", value = verse → count
  final Map<String, Map<int, int>> _commentCounts = {};
  final Map<String, Map<int, int>> _parallelCounts = {};
  // ── Verse tag counts per chapter (verse → number of tags) ─────────────────
  final Map<String, Map<int, int>> _verseTagCounts = {};
  // ── Word markups per chapter ──────────────────────────────────────────────
  final Map<String, List<WordMarkup>> _chapterMarkups = {};
  // ── Word comments per chapter ─────────────────────────────────────────────
  final Map<String, Map<String, WordComment>> _chapterWordComments = {};

  @override
  void initState() {
    super.initState();
    _positionsListener.itemPositions.addListener(_onPositionsChanged);
    // Запросить фокус в следующем кадре
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// Reclaim keyboard focus for hotkeys. Called when the user taps the
  /// Bible text area (not a popup or dialog).
  void _reclaimFocus() {
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  // ── Прыжок к стиху (по индексу — мгновенный, надёжный) ─────────────────
  void _jumpToVerse(int chapter, int verse) {
    if (!_itemScroll.isAttached) return;
    final verses = context.read<AppState>().verses;
    if (verses.isEmpty) return;
    final idx = verses.indexWhere((v) => v.chapter == chapter && v.verse == verse);
    if (idx < 0) return;
    _itemScroll.jumpTo(index: idx);
  }

  // ── Слушатель видимых позиций (заменяет _onScroll) ─────────────────────
  void _onPositionsChanged() {
    if (!mounted) return;

    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Первый видимый элемент = наименьший индекс
    int topIndex = positions.first.index;
    for (final p in positions) {
      if (p.index < topIndex) topIndex = p.index;
    }

    final state = context.read<AppState>();
    if (state.isLoadingText) return;
    final verses = state.verses;
    if (topIndex >= verses.length) return;

    final v = verses[topIndex];
    // Lightweight: updates label + saves position, NO notifyListeners
    state.updateVisibleVerse(v.chapter, v.verse);

    // Defer indicator loading until scroll settles (300ms)
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _loadIndicatorsIfNeeded(context.read<AppState>());
    });
  }

  // ── Page scroll ───────────────────────────────────────────────────────────
  void _pageDown() {
    if (!_itemScroll.isAttached) return;
    final positions = _positionsListener.itemPositions.value.toList();
    if (positions.isEmpty) return;
    int lastIdx = 0;
    for (final p in positions) {
      if (p.index > lastIdx) lastIdx = p.index;
    }
    final anim = context.read<AppState>().animationsEnabled;
    if (anim) {
      _itemScroll.scrollTo(
        index: lastIdx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _itemScroll.jumpTo(index: lastIdx);
    }
  }

  void _pageUp() {
    if (!_itemScroll.isAttached) return;
    final positions = _positionsListener.itemPositions.value.toList();
    if (positions.isEmpty) return;
    int firstIdx = positions.first.index;
    for (final p in positions) {
      if (p.index < firstIdx) firstIdx = p.index;
    }
    final count = positions.length;
    final targetIdx = (firstIdx - count + 1).clamp(0, double.maxFinite.toInt());
    final anim = context.read<AppState>().animationsEnabled;
    if (anim) {
      _itemScroll.scrollTo(
        index: targetIdx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _itemScroll.jumpTo(index: targetIdx);
    }
  }

  // ── AppBar actions ─────────────────────────────────────────────────────────
  void _showBookPicker() =>
      showDialog(context: context, builder: (_) => const BookChapterDialog());

  void _showSettings() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void _openSearch() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SearchScreen()));

  // ── Keyboard ──────────────────────────────────────────────────────────────
  KeyEventResult _handleKey(FocusNode _, KeyEvent e) =>
      handleScrollKeys(context, e, onPageDown: _pageDown, onPageUp: _pageUp);

  // ── Переход по ссылке из словаря ──────────────────────────────────────────
  Future<void> _onBibleLink(int book, int ch, int v, {String? strongs}) async {
    await context
        .read<AppState>()
        .navigateToVerse(book, ch, v, highlightStrongs: strongs);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = context.watch<AppState>();

    // Новый navVersion → прыжок к стиху + загрузка индикаторов
    if (state.navVersion != _lastNavVersion && !state.isLoadingText) {
      _lastNavVersion = state.navVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToVerse(state.currentChapter, state.currentVerse);
        if (mounted) _loadIndicatorsIfNeeded(context.read<AppState>());
      });
    }

    final bookName = state.isLoadingBooks
        ? '…'
        : (state.books
                .where((b) => b.bookNumber == state.currentBook)
                .firstOrNull
                ?.shortName ??
            '?');

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final offset = notification.metrics.pixels;
            if (widget.onScrollDirection != null) {
              if (offset > _lastScrollOffset + 8) {
                widget.onScrollDirection!(_ScrollDirection.reverse);
              } else if (offset < _lastScrollOffset - 8) {
                widget.onScrollDirection!(_ScrollDirection.forward);
              }
            }
            _lastScrollOffset = offset;
          }
          return false;
        },
        child: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ValueListenableBuilder<String>(
              valueListenable: context.read<AppState>().positionLabel,
              builder: (_, label, __) => TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: _showBookPicker,
                child: Text(
                  label.isEmpty ? '$bookName ${state.currentChapter}:${state.currentVerse}' : label,
                  style: TextStyle(
                      fontSize: state.appBarFontSize, color: state.customColors.appBarText),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
          leadingWidth: 170,
          title: const SizedBox.shrink(),
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 22),
                    tooltip: 'Назад',
                    padding: EdgeInsets.zero,
                    onPressed: state.canGoBack ? () => state.goBack() : null,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 22),
                    tooltip: 'Вперёд',
                    padding: EdgeInsets.zero,
                    onPressed: state.canGoForward ? () => state.goForward() : null,
                  ),
                ),
                IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
                IconButton(
                  icon: Icon(state.textSelectionEnabled
                      ? Icons.content_copy
                      : Icons.content_copy_outlined),
                  tooltip: state.textSelectionEnabled
                      ? 'Выделение текста (вкл)'
                      : 'Выделение текста (выкл)',
                  onPressed: () => state.setTextSelectionEnabled(
                      !state.textSelectionEnabled),
                ),
                IconButton(
                    icon: const Icon(Icons.settings), onPressed: _showSettings),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (state.isIndexing)
              LinearProgressIndicator(
                value: state.indexProgress == 0 ? null : state.indexProgress,
                minHeight: 2,
              ),
            Expanded(
              child: state.isLoadingText
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                      ? Center(child: Text('Ошибка: ${state.error}'))
                      : _buildText(state),
            ),
          ],
        ),
      )));
  }

  Widget _buildText(AppState state) {
    // При смене книги — очищаем кэши индикаторов
    if (state.currentBook != _lastBook) {
      _commentCounts.clear();
      _parallelCounts.clear();
      _verseTagCounts.clear();
      _chapterMarkups.clear();
      _chapterWordComments.clear();
      _lastBook = state.currentBook;
    }

    final verses = state.verses;
    final book = state.currentBook;

    return GestureDetector(
      onTap: _reclaimFocus,
      behavior: HitTestBehavior.translucent,
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScroll,
        itemPositionsListener: _positionsListener,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 60),
        itemCount: verses.length,
        itemBuilder: (ctx, idx) {
          final verse = verses[idx];
          final keyId = '${verse.chapter}:${verse.verse}';

          final showHeader =
              idx == 0 || verses[idx - 1].chapter != verse.chapter;

          final chKey = '$book:${verse.chapter}';
          final commentCount = _commentCounts[chKey]?[verse.verse] ?? 0;
          final parallelCount = _parallelCounts[chKey]?[verse.verse] ?? 0;
          final tagCount = _verseTagCounts[chKey]?[verse.verse] ?? 0;
          final markups = _chapterMarkups[chKey] ?? [];
          final wordComments = _chapterWordComments[chKey] ?? {};

          // Filter markups for this verse
          final verseMarkups = markups
              .where((m) => m.verse == verse.verse)
              .toList();

          return Column(
            key: ValueKey(keyId),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 4),
                  child: Text(
                    'Глава ${verse.chapter}',
                    style: TextStyle(
                      fontSize: state.fontSize + 2,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              VerseBlock(
                verse:            verse,
                fontSize:         state.fontSize,
                criticalTextFontSize: state.criticalTextFontSize,
                showCriticalText: state.showCriticalText,
                db:               state.db,
                highlight:        state.highlightTarget,
                onBibleLink:      _onBibleLink,
                onClearHighlight: state.clearHighlight,
                onLongPress: () => _showVerseMenu(verse),
                commentCount:     commentCount,
                parallelCount:    parallelCount,
                tagCount:         tagCount,
                markups:          verseMarkups,
                wordComments:     wordComments,
                themeMode:        state.themeMode,
                onWordCommentChanged: _reloadVisibleIndicators,
                fontFamily:       state.fontFamily,
                customColors:     state.customColors,
                popupFontSize:    state.popupFontSize,
                animationsEnabled: state.animationsEnabled,
                textSelectionEnabled: state.textSelectionEnabled,
                lineHeight: state.lineHeight,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Load comment/parallel counts & markups for visible chapters (±2 from current)
  void _loadIndicatorsIfNeeded(AppState state) {
    final book = state.currentBook;
    final curCh = state.currentChapter;
    // Only load indicators for chapters near the current one (±2)
    final visibleChapters = <int>{};
    for (int delta = -2; delta <= 2; delta++) {
      final ch = curCh + delta;
      if (state.allChapters.contains(ch)) visibleChapters.add(ch);
    }
    for (final ch in visibleChapters) {
      final chKey = '$book:$ch';
      if (_commentCounts.containsKey(chKey)) continue;
      // Load asynchronously and rebuild
      final notes = context.read<NotesProvider>();
      Future.wait([
        notes.getCommentCountsForChapter(book, ch),
        notes.getParallelCountsForChapter(book, ch),
        notes.getMarkupsForChapter(book, ch),
        notes.getWordCommentsForChapter(book, ch),
        notes.getVerseTagIdsForChapter(book, ch),
      ]).then((results) {
        if (!mounted) return;
        setState(() {
          _commentCounts[chKey] = results[0] as Map<int, int>;
          _parallelCounts[chKey] = results[1] as Map<int, int>;
          _chapterMarkups[chKey] = results[2] as List<WordMarkup>;
          _chapterWordComments[chKey] = results[3] as Map<String, WordComment>;
          final tagIds = results[4] as Map<int, List<String>>;
          _verseTagCounts[chKey] = tagIds.map((v, ids) => MapEntry(v, ids.length));
        });
      });
    }
  }

  /// Force reload indicators — clears cache for all loaded chapters
  void _reloadIndicators() {
    _commentCounts.clear();
    _chapterMarkups.clear();
    _chapterWordComments.clear();
    _parallelCounts.clear();
    _verseTagCounts.clear();
    setState(() {});
  }

  /// Soft reload indicators for visible chapters only (no cache clear → no flash).
  /// Used when a single word highlight changes so other words keep their colors.
  void _reloadVisibleIndicators() {
    final state = context.read<AppState>();
    final notes = context.read<NotesProvider>();
    final book = state.currentBook;
    final curCh = state.currentChapter;

    for (int delta = -2; delta <= 2; delta++) {
      final ch = curCh + delta;
      if (!state.allChapters.contains(ch)) continue;
      final chKey = '$book:$ch';
      Future.wait([
        notes.getCommentCountsForChapter(book, ch),
        notes.getParallelCountsForChapter(book, ch),
        notes.getMarkupsForChapter(book, ch),
        notes.getWordCommentsForChapter(book, ch),
        notes.getVerseTagIdsForChapter(book, ch),
      ]).then((results) {
        if (!mounted) return;
        setState(() {
          _commentCounts[chKey] = results[0] as Map<int, int>;
          _parallelCounts[chKey] = results[1] as Map<int, int>;
          _chapterMarkups[chKey] = results[2] as List<WordMarkup>;
          _chapterWordComments[chKey] = results[3] as Map<String, WordComment>;
          final tagIds = results[4] as Map<int, List<String>>;
          _verseTagCounts[chKey] = tagIds.map((v, ids) => MapEntry(v, ids.length));
        });
      });
    }
  }

  // ── Verse long-press context menu ──────────────────────────────────────────
  void _showVerseMenu(VerseModel verse) {
    HapticFeedback.mediumImpact();
    final anim = context.read<AppState>().animationsEnabled;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'verse-menu',
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.26),
      transitionDuration: anim ? const Duration(milliseconds: 180) : Duration.zero,
      transitionBuilder: (ctx, animation, _, child) {
        if (!anim) return child;
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (ctx, _, __) {
        final cs = Theme.of(ctx).colorScheme;
        final state = context.read<AppState>();
        final notes = context.read<NotesProvider>();
        final bookName = state.books
            .where((b) => b.bookNumber == state.currentBook)
            .firstOrNull
            ?.shortName ?? '';

        // Find existing verse-level background markup
        final chKey = '${state.currentBook}:${verse.chapter}';
        final chMarkups = _chapterMarkups[chKey] ?? [];
        final existingBg = chMarkups.where((m) =>
            m.kind == MarkupKind.background &&
            m.wordNumber == null &&
            m.verse == verse.verse).firstOrNull;
        final currentBgArgb = existingBg?.colorValue;

        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Material(
              color: cs.surfaceContainerHighest,
              elevation: 6,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Text(
                      '$bookName ${verse.chapter}:${verse.verse}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Verse background color row ──
                    _verseBgRow(
                      cs: cs,
                      currentArgb: currentBgArgb,
                      existingBg: existingBg,
                      verse: verse,
                      state: state,
                      notes: notes,
                      dialogCtx: ctx,
                    ),
                    const SizedBox(height: 6),
                    // Tags row (task 14/15)
                    _verseTagsRow(
                      cs: cs,
                      verse: verse,
                      state: state,
                      notes: notes,
                      dialogCtx: ctx,
                    ),
                    const SizedBox(height: 6),
                    // Action buttons row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _menuBtn(ctx, Icons.copy, 'Копировать', () {
                            Navigator.pop(ctx);
                            _copyVerse(verse);
                          }),
                          _menuBtn(ctx, Icons.compare_arrows,
                              'Параллельные\nстихи', () {
                            Navigator.pop(ctx);
                            _showParallelVerses(verse);
                          }),
                          _menuBtn(ctx, Icons.add_link,
                              'Добавить\nпараллельный', () {
                            Navigator.pop(ctx);
                            _addParallelVerse(verse);
                          }),
                          _menuBtn(ctx, Icons.edit_note,
                              'Комментировать', () {
                            Navigator.pop(ctx);
                            _addComment(verse);
                          }),
                          _menuBtn(ctx, Icons.comment,
                              'Комментарии', () {
                            Navigator.pop(ctx);
                            _showComments(verse);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Very subtle verse background presets (alpha ~0.10)
  static const _verseBgPresets = <Color>[
    Color(0x1AFFEB3B), // yellow
    Color(0x1A66BB6A), // green
    Color(0x1A42A5F5), // blue
    Color(0x1AEF5350), // red
  ];

  Widget _verseBgRow({
    required ColorScheme cs,
    required int? currentArgb,
    required WordMarkup? existingBg,
    required VerseModel verse,
    required AppState state,
    required NotesProvider notes,
    required BuildContext dialogCtx,
  }) {
    final isCustom = currentArgb != null &&
        !_verseBgPresets.any((c) => c.toARGB32() == currentArgb);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final color in _verseBgPresets) ...[
          _verseBgDot(
            cs: cs,
            color: color,
            selected: currentArgb == color.toARGB32(),
            onTap: () async {
              Navigator.pop(dialogCtx);
              if (currentArgb == color.toARGB32()) {
                // Remove
                if (existingBg != null) await notes.deleteMarkup(existingBg.id);
              } else {
                // Set
                if (existingBg != null) await notes.deleteMarkup(existingBg.id);
                await notes.addMarkup(WordMarkup(
                  id: '${state.currentBook}_${verse.chapter}_${verse.verse}_versebg',
                  bookNumber: state.currentBook,
                  chapter: verse.chapter,
                  verse: verse.verse,
                  wordNumber: null, // verse-level
                  kind: MarkupKind.background,
                  colorIndex: 0,
                  colorValue: color.toARGB32(),
                ));
              }
              _reloadIndicators();
            },
          ),
          const SizedBox(width: 8),
        ],
        // Custom color picker
        _verseBgDot(
          cs: cs,
          color: isCustom ? Color(currentArgb) : null,
          selected: isCustom,
          icon: Icons.palette,
          onTap: () async {
            Navigator.pop(dialogCtx);
            final picked = await _showVerseBgColorPicker(
              context,
              currentArgb != null ? Color(currentArgb) : const Color(0x1AFFEB3B),
            );
            if (picked != null) {
              if (existingBg != null) await notes.deleteMarkup(existingBg.id);
              await notes.addMarkup(WordMarkup(
                id: '${state.currentBook}_${verse.chapter}_${verse.verse}_versebg',
                bookNumber: state.currentBook,
                chapter: verse.chapter,
                verse: verse.verse,
                wordNumber: null,
                kind: MarkupKind.background,
                colorIndex: 0,
                colorValue: picked.toARGB32(),
              ));
              _reloadIndicators();
            }
          },
        ),
        const SizedBox(width: 8),
        // Eraser
        if (existingBg != null)
          GestureDetector(
            onTap: () async {
              Navigator.pop(dialogCtx);
              await notes.deleteMarkup(existingBg.id);
              _reloadIndicators();
            },
            child: Icon(Icons.format_color_reset,
                size: 18, color: cs.onSurfaceVariant),
          ),
      ],
    );
  }

  Future<Color?> _showVerseBgColorPicker(
      BuildContext context, Color initial) {
    return showDialog<Color>(
      context: context,
      builder: (_) => _VerseBgColorPickerDialog(initial: initial),
    );
  }

  Widget _verseBgDot({
    required ColorScheme cs,
    Color? color,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: icon != null
            ? Icon(icon, size: 14, color: cs.onSurfaceVariant)
            : null,
      ),
    );
  }

  // ── Verse tags row (task 14/15) ───────────────────────────────────────────

  Widget _verseTagsRow({
    required ColorScheme cs,
    required VerseModel verse,
    required AppState state,
    required NotesProvider notes,
    required BuildContext dialogCtx,
  }) {
    final allTags = notes.tags;
    if (allTags.isEmpty) {
      return GestureDetector(
        onTap: () {
          Navigator.pop(dialogCtx);
          _showTagManager(context, notes);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sell_outlined, size: 14, color: cs.secondary),
            const SizedBox(width: 4),
            Text('Создать тег',
                style: TextStyle(fontSize: 12, color: cs.secondary)),
          ],
        ),
      );
    }

    return FutureBuilder<List<VerseTag>>(
      future: notes.getVerseTagsForVerse(
          state.currentBook, verse.chapter, verse.verse),
      builder: (ctx, snapshot) {
        final applied = snapshot.data ?? [];
        final appliedIds = applied.map((vt) => vt.tagId).toSet();

        return Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final tag in allTags)
              GestureDetector(
                onTap: () async {
                  if (appliedIds.contains(tag.id)) {
                    // Remove
                    final vt =
                        applied.where((v) => v.tagId == tag.id).firstOrNull;
                    if (vt != null) await notes.deleteVerseTag(vt.id);
                  } else {
                    // Add tag to verse
                    await notes.addVerseTag(
                      tagId: tag.id,
                      bookNumber: state.currentBook,
                      chapter: verse.chapter,
                      verse: verse.verse,
                    );
                    // Auto-create/append verse quote in a tag note
                    await _appendVerseToTagNote(
                      notes: notes,
                      state: state,
                      tag: tag,
                      verse: verse,
                    );
                  }
                  // Force rebuild
                  if (ctx.mounted) (ctx as Element).markNeedsBuild();
                  _reloadIndicators();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: appliedIds.contains(tag.id)
                        ? Color(tag.colorValue).withValues(alpha: 0.2)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(tag.colorValue).withValues(alpha: 0.6),
                      width: appliedIds.contains(tag.id) ? 1.5 : 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sell,
                          size: 11, color: Color(tag.colorValue)),
                      const SizedBox(width: 3),
                      Text(tag.name,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurface)),
                    ],
                  ),
                ),
              ),
            // Manage tags button
            GestureDetector(
              onTap: () {
                Navigator.pop(dialogCtx);
                _showTagManager(context, notes);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: cs.outline.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.add, size: 14, color: cs.secondary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTagManager(BuildContext context, NotesProvider notes) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _TagManagerSheet(
        notes: notes,
        onChanged: () {
          _reloadIndicators();
          if (ctx.mounted) (ctx as Element).markNeedsBuild();
        },
      ),
    );
  }

  /// Auto-create/append a verse quote into a note named after [tag].
  /// The note is placed in a "Теги" folder (created if needed).
  Future<void> _appendVerseToTagNote({
    required NotesProvider notes,
    required AppState state,
    required NoteTag tag,
    required VerseModel verse,
  }) async {
    // Build verse text
    final buf = StringBuffer();
    for (final w in verse.words) {
      final t = w.word.trim();
      if (isCriticalTag(t)) continue;
      if (isPunct(t)) {
        final s = buf.toString();
        if (s.endsWith(' ')) {
          buf.clear();
          buf.write(s.trimRight());
        }
        buf.write(t);
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(t);
      }
    }
    final verseText = buf.toString();

    final bookName = state.books
        .where((b) => b.bookNumber == state.currentBook)
        .firstOrNull
        ?.shortName ?? '${state.currentBook}';
    final ref = '$bookName ${verse.chapter}:${verse.verse}';

    // Build markdown quote block
    final quoteBlock = '\n[[$ref]]\n> $verseText\n';

    // Ensure "Теги" folder exists
    final folderId = await notes.ensureFolder('Теги');

    // Find or create the tag note
    var tagNote = notes.findNoteByTitle(tag.name);
    if (tagNote == null) {
      tagNote = await notes.createNoteWithContent(
        title: tag.name,
        content: quoteBlock.trimLeft(),
        folderId: folderId,
      );
    } else {
      // Append quote if not already present (avoid duplicates)
      if (!tagNote.content.contains('[[$ref]]')) {
        final updated = tagNote.copyWith(
          content: '${tagNote.content}\n$quoteBlock',
          updatedAt: DateTime.now(),
        );
        await notes.updateNote(updated);
      }
    }
  }

  Widget _menuBtn(
      BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: cs.primary),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: cs.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Copy verse ──────────────────────────────────────────────────────────────
  void _copyVerse(VerseModel verse) {
    final buffer = StringBuffer();
    for (final w in verse.words) {
      final t = w.word.trim();
      if (isCriticalTag(t)) continue;
      if (isPunct(t)) {
        // Remove trailing space before punctuation
        final s = buffer.toString();
        if (s.endsWith(' ')) {
          buffer.clear();
          buffer.write(s.trimRight());
        }
        buffer.write(t);
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(t);
      }
    }
    final text = buffer.toString();
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Скопировано: ${verse.chapter}:${verse.verse}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ── Parallel verses ────────────────────────────────────────────────────────
  Future<void> _showParallelVerses(VerseModel verse) async {
    final notes = context.read<NotesProvider>();
    final state = context.read<AppState>();
    final parallels = await notes.getParallelVerses(
        state.currentBook, verse.chapter, verse.verse);

    if (!mounted) return;

    if (parallels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет параллельных стихов'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ParallelVersesSheet(
        parallels: parallels,
        books: state.books,
        db: state.db,
        onNavigate: (p) {
          Navigator.pop(ctx);
          _onBibleLink(p.targetBook, p.targetChapter, p.targetVerse);
        },
        onDelete: (id) async {
          await notes.deleteParallelVerse(id);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          // Re-open list
          _showParallelVerses(verse);
        },
      ),
    );
  }

  // ── Add parallel verse ────────────────────────────────────────────────────
  void _addParallelVerse(VerseModel verse) {
    showDialog(
      context: context,
      builder: (_) => AddParallelDialog(
        sourceVerse: verse,
        sourceBook: context.read<AppState>().currentBook,
        onAdd: (targetBook, targetCh, targetV) async {
          final notes = context.read<NotesProvider>();
          final state = context.read<AppState>();
          await notes.addParallelVerse(
            sourceBook: state.currentBook,
            sourceChapter: verse.chapter,
            sourceVerse: verse.verse,
            targetBook: targetBook,
            targetChapter: targetCh,
            targetVerse: targetV,
          );
          if (mounted) {
            _reloadIndicators();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Параллельный стих добавлен'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
      ),
    );
  }

  // ── Add comment ────────────────────────────────────────────────────────────
  void _addComment(VerseModel verse) {
    showDialog(
      context: context,
      builder: (ctx) => _AutoSaveCommentDialog(
        title: 'Комментарий к ${verse.chapter}:${verse.verse}',
        onSave: (text) async {
          final notes = context.read<NotesProvider>();
          final state = context.read<AppState>();
          await notes.addVerseComment(
              state.currentBook, verse.chapter, verse.verse, text);
          _reloadIndicators();
        },
      ),
    );
  }

  // ── Show comments ──────────────────────────────────────────────────────────
  Future<void> _showComments(VerseModel verse) async {
    final notes = context.read<NotesProvider>();
    final state = context.read<AppState>();
    final comments = await notes.getVerseComments(
        state.currentBook, verse.chapter, verse.verse);

    if (!mounted) return;

    if (comments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет комментариев'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CommentsSheet(
        comments: comments,
        verse: verse,
        onDelete: (id) async {
          await notes.deleteVerseComment(id);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          _showComments(verse);
        },
        onEdit: (c) async {
          Navigator.pop(ctx);
          _editComment(c, verse);
        },
      ),
    );
  }

  void _editComment(VerseComment comment, VerseModel verse) {
    showDialog(
      context: context,
      builder: (ctx) => _AutoSaveCommentDialog(
        title: 'Редактировать комментарий',
        initialText: comment.text,
        onSave: (text) async {
          final notes = context.read<NotesProvider>();
          await notes.updateVerseComment(
              comment.copyWith(text: text, updatedAt: DateTime.now()));
          _reloadIndicators();
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _positionsListener.itemPositions.removeListener(_onPositionsChanged);
    _focusNode.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-save comment dialog
// ─────────────────────────────────────────────────────────────────────────────
class _AutoSaveCommentDialog extends StatefulWidget {
  final String title;
  final String? initialText;
  final Future<void> Function(String text) onSave;

  const _AutoSaveCommentDialog({
    required this.title,
    this.initialText,
    required this.onSave,
  });

  @override
  State<_AutoSaveCommentDialog> createState() => _AutoSaveCommentDialogState();
}

class _AutoSaveCommentDialogState extends State<_AutoSaveCommentDialog> {
  late final TextEditingController _ctrl;
  Timer? _saveTimer;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
    _ctrl.addListener(_scheduleSave);
  }

  void _scheduleSave() {
    _saved = false;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _doSave);
  }

  Future<void> _doSave() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _saved) return;
    _saved = true;
    await widget.onSave(text);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Save immediately on close
    if (!_saved && _ctrl.text.trim().isNotEmpty) {
      widget.onSave(_ctrl.text.trim());
    }
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        maxLines: 5,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Введите комментарий…',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

// ─── Verse background custom color picker ────────────────────────────────────
class _VerseBgColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _VerseBgColorPickerDialog({required this.initial});

  @override
  State<_VerseBgColorPickerDialog> createState() =>
      _VerseBgColorPickerDialogState();
}

class _VerseBgColorPickerDialogState extends State<_VerseBgColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _lightness;
  late double _alpha;

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(widget.initial);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;
    _alpha = hsl.alpha.clamp(0.05, 0.30);
  }

  Color get _currentColor =>
      HSLColor.fromAHSL(_alpha, _hue, _saturation, _lightness).toColor();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Цвет фона стиха', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outline),
              ),
            ),
            const SizedBox(height: 12),
            _sliderRow('Тон', _hue / 360,
                (v) => setState(() => _hue = v * 360)),
            _sliderRow('Насыщ.', _saturation,
                (v) => setState(() => _saturation = v)),
            _sliderRow('Яркость', _lightness,
                (v) => setState(() => _lightness = v)),
            _sliderRow('Прозрач.', _alpha / 0.30,
                (v) => setState(() => _alpha = (v * 0.30).clamp(0.05, 0.30))),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _currentColor),
          child: const Text('Применить'),
        ),
      ],
    );
  }

  Widget _sliderRow(
      String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tag Manager Sheet – create / edit / delete tags
// ---------------------------------------------------------------------------
class _TagManagerSheet extends StatefulWidget {
  final NotesProvider notes;
  final VoidCallback onChanged;

  const _TagManagerSheet({required this.notes, required this.onChanged});

  @override
  State<_TagManagerSheet> createState() => _TagManagerSheetState();
}

class _TagManagerSheetState extends State<_TagManagerSheet> {
  static const _presetColors = <int>[
    0xFF2196F3, // blue
    0xFFE53935, // red
    0xFF43A047, // green
    0xFFFFA726, // orange
    0xFF8E24AA, // purple
    0xFF00ACC1, // cyan
    0xFFFF7043, // deep orange
    0xFF5C6BC0, // indigo
    0xFFEC407A, // pink
    0xFF78909C, // blue-grey
  ];

  final _nameCtrl = TextEditingController();
  int _selectedColor = _presetColors.first;
  NoteTag? _editing; // non-null when editing existing tag

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    if (_editing != null) {
      await widget.notes.updateTag(
        NoteTag(id: _editing!.id, name: name, colorValue: _selectedColor),
      );
    } else {
      await widget.notes.createTag(name, colorValue: _selectedColor);
    }

    _nameCtrl.clear();
    _editing = null;
    _selectedColor = _presetColors.first;
    widget.onChanged();
    if (mounted) setState(() {});
  }

  void _startEdit(NoteTag tag) {
    setState(() {
      _editing = tag;
      _nameCtrl.text = tag.name;
      _selectedColor = tag.colorValue;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _nameCtrl.clear();
      _selectedColor = _presetColors.first;
    });
  }

  Future<void> _delete(NoteTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить тег?'),
        content: Text('Тег «${tag.name}» и все его привязки будут удалены.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.notes.deleteTag(tag.id);
      widget.onChanged();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tags = widget.notes.tags;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Управление тегами',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 12),

          // Existing tags
          if (tags.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tags.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final tag = tags[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.sell,
                        color: Color(tag.colorValue), size: 20),
                    title: Text(tag.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _startEdit(tag),
                          tooltip: 'Редактировать',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () => _delete(tag),
                          tooltip: 'Удалить',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Color picker row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetColors.map((c) {
              final selected = c == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: cs.onSurface, width: 2.5)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Name input + save
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Название тега',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              if (_editing != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _cancelEdit,
                  tooltip: 'Отмена',
                ),
              FilledButton(
                onPressed: _save,
                child: Text(_editing != null ? 'Сохранить' : 'Создать'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
