// lib/core/keyboard_scroll_helpers.dart
//
// Shared keyboard + scroll helpers used by multiple screens.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

/// Shared keyboard handler for page-scroll shortcuts.
///
/// Returns [KeyEventResult.handled] when the event matches
/// the user's configured scroll-up/down keys.
KeyEventResult handleScrollKeys(
  BuildContext context,
  KeyEvent event, {
  required VoidCallback onPageDown,
  required VoidCallback onPageUp,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  final s = context.read<AppState>();
  if (s.isScrollDownKey(event.logicalKey)) {
    onPageDown();
    return KeyEventResult.handled;
  }
  if (s.isScrollUpKey(event.logicalKey)) {
    onPageUp();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// Page-scroll a standard [ScrollController] by 92% of the viewport.
///
/// [forward] = true  → scroll down
/// [forward] = false → scroll up
void pageScroll(
  ScrollController ctrl, {
  required bool forward,
  required bool animate,
}) {
  if (!ctrl.hasClients) return;
  final vp = ctrl.position.viewportDimension * 0.92;
  final target = (ctrl.offset + (forward ? vp : -vp))
      .clamp(0.0, ctrl.position.maxScrollExtent);
  if (animate) {
    ctrl.animateTo(target,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  } else {
    ctrl.jumpTo(target);
  }
}
