// lib/ui/ui_scale_wrapper.dart
//
// B2: Масштабирование всего UI через Transform.scale + переопределение
// MediaQuery. Контент "думает", что экран меньше в scale раз, а
// Transform.scale возвращает его к реальному размеру — визуально всё крупнее.

import 'package:flutter/material.dart';

class UiScaleWrapper extends StatelessWidget {
  final double scale;
  final Widget child;

  const UiScaleWrapper({
    super.key,
    required this.scale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // При scale == 1.0 — полностью пропускаем без лишних виджетов
    if ((scale - 1.0).abs() < 0.001) return child;

    final mq = MediaQuery.of(context);

    // Виртуальный размер: вдвое меньше реального при scale=2, и т.д.
    final scaledSize = Size(
      mq.size.width / scale,
      mq.size.height / scale,
    );

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: scaledSize.width,
        maxWidth: scaledSize.width,
        minHeight: scaledSize.height,
        maxHeight: scaledSize.height,
        child: MediaQuery(
          data: mq.copyWith(
            size: scaledSize,
            // Сбрасываем textScaler чтобы не было двойного масштабирования
            textScaler: TextScaler.noScaling,
            // Масштабируем системные отступы (notch, home indicator, клавиатура)
            padding: mq.padding / scale,
            viewPadding: mq.viewPadding / scale,
            viewInsets: mq.viewInsets / scale,
            systemGestureInsets: mq.systemGestureInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
