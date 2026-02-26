// lib/ui/main_shell.dart
//
// Three-tab layout: Notes | Bible | Dictionaries
// Navigation via PageView (slide animation).
// Each tab owns a nested Navigator so sub-screens push *inside* the tab
// and the bottom bar stays visible.

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:google_nav_bar/google_nav_bar.dart';
import '../features/notes/view/notes_screen.dart';
import '../features/home/view/home_screen.dart';
import '../features/dictionary/view/dictionary_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialPage = 1});

  final int initialPage;

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  final ValueNotifier<bool> _showBottomBar = ValueNotifier<bool>(true);

  void setBottomBarVisible(bool visible) {
    if (_showBottomBar.value != visible) {
      _showBottomBar.value = visible;
    }
  }

  late int _currentPage;
  late final PageController _pageController;

  // One navigator key per tab — preserves sub-screen state
  final _navKeys = List.generate(3, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _showBottomBar.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Animate to [page] from outside (e.g. deep-link, notification).
  void goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _onPageChanged(int page) => setState(() => _currentPage = page);

  /// Handle Android back-button: pop nested navigator first, then allow exit.
  Future<bool> _onWillPop() async {
    final nav = _navKeys[_currentPage].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  void _onTabTapped(int index) {
    if (index == _currentPage) {
      // Tap on already-active tab → scroll back to root
      _navKeys[index].currentState?.popUntil((r) => r.isFirst);
    } else {
      goToPage(index);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        extendBody: true,
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: _currentPage == 0
              ? const _NoLeftSwipePhysics()
              : const BouncingScrollPhysics(),
          children: [
            _TabNavigator(
                navigatorKey: _navKeys[0], child: const NotesScreen()),
            _TabNavigator(
              navigatorKey: _navKeys[1],
              child: HomeScreen(
                onScrollDirection: (direction) {
                  if (direction.toString().contains('reverse')) {
                    setBottomBarVisible(false);
                  } else {
                    setBottomBarVisible(true);
                  }
                },
              ),
            ),
            _TabNavigator(
              navigatorKey: _navKeys[2],
              child: const DictionaryScreen(embedded: true),
            ),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: _showBottomBar,
          builder: (context, show, _) => BottomPanelWidget(
            show: show,
            currentIndex: _currentPage,
            onTabChange: _onTabTapped,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Semi-transparent GNav bottom bar
// ─────────────────────────────────────────────────────────────────────────────

class BottomPanelWidget extends StatelessWidget {
  final bool show;
  final int currentIndex;
  final ValueChanged<int> onTabChange;

  const BottomPanelWidget({
    Key? key,
    required this.show,
    required this.currentIndex,
    required this.onTabChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      offset: show ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: show ? 1 : 0,
        child: _BottomNavBar(
          currentIndex: currentIndex,
          onTabChange: onTabChange,
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTabChange,
    // required this.fixedWidth,
  });

  final int currentIndex;
  final ValueChanged<int> onTabChange;
  final double fixedWidth = 200;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    //final isDark = Theme.of(context).brightness == Brightness.dark;

    // Прозрачный фон (можно заменить на Colors.transparent)
    final bgColor = const Color.fromARGB(0, 255, 255, 255);

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            // При полностью прозрачном фоне можно убрать blur,
            // но оставляем его, если хотите «стеклянный» эффект.
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              width: fixedWidth,
              // Убираем цвет и границу – оставляем только дочерний контент
              decoration: BoxDecoration(
                color: bgColor,               // ← полностью прозрачный
                // Если границу тоже не нужен, закомментируйте её:
                // border: Border(
                //   top: BorderSide(
                //     color: cs.outlineVariant.withValues(),
                //     width: 0.2,
                //   ),
                // ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: GNav(
                    selectedIndex: currentIndex,
                    onTabChange: onTabChange,
                    mainAxisAlignment: MainAxisAlignment.center,
                    tabBorderRadius: 20,
                    tabActiveBorder: Border.all(
                      color: cs.primary.withValues(),
                      width: 1,
                    ),
                    tabBackgroundColor: cs.primaryContainer.withValues(),
                    color: cs.onSurfaceVariant,
                    activeColor: cs.primary,
                    iconSize: 24,
                    gap: 4,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    tabs: const [
                      GButton(icon: Icons.note_alt_outlined, text: 'Заметки'),
                      GButton(icon: Icons.auto_stories_outlined, text: 'Библия'),
                      GButton(icon: Icons.menu_book_outlined, text: 'Словари'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom scroll physics: blocks right-swipe (back) on the first page.
// The leftmost tab has nothing to its left — prevent accidentally swiping
// into void while the Notes drawer is also a right-edge gesture.
// ─────────────────────────────────────────────────────────────────────────────

class _NoLeftSwipePhysics extends ScrollPhysics {
  const _NoLeftSwipePhysics({super.parent});

  @override
  _NoLeftSwipePhysics applyTo(ScrollPhysics? ancestor) =>
      _NoLeftSwipePhysics(parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics pos, double offset) {
    // offset > 0 means a right-swipe (trying to go left of page 0) — block it
    if (pos.pixels <= pos.minScrollExtent && offset > 0) return 0;
    return offset;
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Wraps a root widget in its own nested Navigator
// ─────────────────────────────────────────────────────────────────────────────

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }
}
