// lib/ui/main_shell.dart
//
// Three-tab layout: Notes | Bible | Dictionaries
// Navigation via PageView.
// Each tab owns a nested Navigator so sub-screens push *inside* the tab.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../core/app_state.dart';
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
  // ── Mouse-drag gesture tracking (macOS / Windows with mouse) ───────────
  // Accumulate horizontal delta so a single mouse-wheel flick = one page change
  double _mouseHorizAccum = 0;
  static const _mousePageThreshold = 80.0;

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
    _pageController.dispose();
    super.dispose();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Jump to [page] instantly (no animation for E-Ink / performance).
  void goToPage(int page) {
    _pageController.jumpToPage(page);
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Only subscribe to the error field — avoids full-shell rebuild on every
    // AppState change (e.g. scroll updates, font size tweaks, etc.)
    final error = context.select<AppState, String?>((s) => s.error);
    Widget errorWidget = error != null && error.isNotEmpty
        ? Center(child: Text('Ошибка: $error', style: const TextStyle(color: Colors.red, fontSize: 18)))
        : const SizedBox.shrink();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            if (error != null && error.isNotEmpty)
              errorWidget
            else
              Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    final dx = event.scrollDelta.dx;
                    final dy = event.scrollDelta.dy;
                    if (dx.abs() > dy.abs() && dx.abs() > 5) {
                      _mouseHorizAccum += dx;
                      if (_mouseHorizAccum > _mousePageThreshold) {
                        _mouseHorizAccum = 0;
                        if (_currentPage < 2) goToPage(_currentPage + 1);
                      } else if (_mouseHorizAccum < -_mousePageThreshold) {
                        _mouseHorizAccum = 0;
                        if (_currentPage > 0) goToPage(_currentPage - 1);
                      }
                    } else {
                      _mouseHorizAccum = 0;
                    }
                  }
                },
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: _currentPage == 0
                      ? const _NoLeftSwipePhysics()
                      : const ClampingScrollPhysics(),
                  children: [
                    _TabNavigator(
                        navigatorKey: _navKeys[0], child: const NotesScreen()),
                    _TabNavigator(
                      navigatorKey: _navKeys[1],
                      child: const HomeScreen(),
                    ),
                    _TabNavigator(
                      navigatorKey: _navKeys[2],
                      child: const DictionaryScreen(embedded: true),
                    ),
                  ],
                ),
              ),
          ],
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
// Wraps a root widget in its own nested Navigator.
// StatefulWidget so the Navigator is NOT recreated on every parent rebuild —
// this keeps the route alive and prevents a stale closure from being used.
// ─────────────────────────────────────────────────────────────────────────────

class _TabNavigator extends StatefulWidget {
  const _TabNavigator({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<_TabNavigator> createState() => _TabNavigatorState();
}

class _TabNavigatorState extends State<_TabNavigator> {
  late Route<dynamic> _initialRoute;

  @override
  void initState() {
    super.initState();
    // Build the initial route once — no slide/fade animation so the tab
    // appears instantly when the app opens.
    _initialRoute = PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => widget.child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateInitialRoutes: (_, __) => [_initialRoute],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => widget.child,
        settings: settings,
      ),
    );
  }
}
