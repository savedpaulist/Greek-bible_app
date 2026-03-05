// lib/core/utils/tab_drag_mixin.dart
//
// Reusable horizontal drag-to-switch-tab gesture handler.
// Replaces identical code in dictionary_screen, dictionary_detail_screen,
// dictionary_article_screen, and notes_screen.

import 'package:flutter/material.dart';
import '../../ui/main_shell.dart';

/// Mixin that provides a [GestureDetector] wrapper for horizontal tab switching.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with TabDragMixin {
///   @override
///   Widget build(BuildContext context) {
///     return wrapWithTabDrag(
///       context: context,
///       child: Scaffold(...),
///       onSwipeRight: () => goToTab(context, 1),
///       onSwipeLeft: () => goToTab(context, 2),
///     );
///   }
/// }
/// ```
mixin TabDragMixin<T extends StatefulWidget> on State<T> {
  double _tabDragDelta = 0;
  static const double _dragThreshold = 80;
  static const double _velocityThreshold = 200;

  /// Navigate to a specific tab page via [MainShellState].
  void goToTab(BuildContext context, int page) {
    final shell = context.findAncestorStateOfType<MainShellState>();
    shell?.goToPage(page);
  }

  /// Wraps [child] in a [GestureDetector] that detects horizontal swipes.
  ///
  /// [onSwipeRight] fires when user swipes left→right (positive dx).
  /// [onSwipeLeft] fires when user swipes right→left (negative dx).
  Widget wrapWithTabDrag({
    required BuildContext context,
    required Widget child,
    VoidCallback? onSwipeRight,
    VoidCallback? onSwipeLeft,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        _tabDragDelta += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dx;
        if (_tabDragDelta > _dragThreshold || velocity > _velocityThreshold) {
          onSwipeRight?.call();
        } else if (_tabDragDelta < -_dragThreshold ||
            velocity < -_velocityThreshold) {
          onSwipeLeft?.call();
        }
        _tabDragDelta = 0;
      },
      onHorizontalDragCancel: () {
        _tabDragDelta = 0;
      },
      child: child,
    );
  }
}
