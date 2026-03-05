// lib/features/notes/widgets/auto_list_text_field.dart
//
// TextField with auto-list continuation and typewriter-style cursor scrolling.

import 'package:flutter/material.dart';

class AutoListTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final VoidCallback onNewLine;
  final bool typewriterMode;
  final TextStyle style;
  final InputDecoration decoration;

  const AutoListTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.onNewLine,
    required this.typewriterMode,
    required this.style,
    required this.decoration,
  });

  @override
  State<AutoListTextField> createState() => _AutoListTextFieldState();
}

class _AutoListTextFieldState extends State<AutoListTextField> {
  int _prevLength = 0;
  int _prevNewlines = 0;

  @override
  void initState() {
    super.initState();
    _prevLength = widget.controller.text.length;
    _prevNewlines = '\n'.allMatches(widget.controller.text).length;
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  // When keyboard opens, scroll cursor into view at 1/3 position
  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCursorThird());
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final newlines = '\n'.allMatches(text).length;

    // Detect newline insertion (not deletion) for auto-list
    if (text.length > _prevLength && newlines > _prevNewlines) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onNewLine();
        _scrollToCursorThird();
      });
    } else {
      // Keep cursor at 1/3 on every edit
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCursorThird());
    }

    _prevLength = text.length;
    _prevNewlines = newlines;
  }

  /// Scroll so the cursor sits at ~1/3 from the top of the viewport.
  void _scrollToCursorThird() {
    final sc = widget.scrollController;
    if (!sc.hasClients) return;
    final sel = widget.controller.selection;
    if (!sel.isValid) return;
    final offset = sel.baseOffset.clamp(0, widget.controller.text.length);
    final textBeforeCursor = widget.controller.text.substring(0, offset);
    final lineCount = '\n'.allMatches(textBeforeCursor).length;
    final lineHeightEstimate =
        widget.style.fontSize! * (widget.style.height ?? 1.5);
    final cursorY = lineCount * lineHeightEstimate;
    final viewportHeight = sc.position.viewportDimension;
    // Target: cursor at 1/3 from top
    final targetOffset =
        (cursorY - viewportHeight / 3).clamp(0.0, sc.position.maxScrollExtent);
    if ((sc.offset - targetOffset).abs() > lineHeightEstimate) {
      sc.jumpTo(targetOffset);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollController: widget.scrollController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: widget.style,
      decoration: widget.decoration,
    );
  }
}
