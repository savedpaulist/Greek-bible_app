import 'package:flutter/material.dart';

/// Instant page route (no animation) for notes navigation.
class NotesFadeRoute<T> extends PageRouteBuilder<T> {
  NotesFadeRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (ctx, _, __) => builder(ctx),
        );
}
