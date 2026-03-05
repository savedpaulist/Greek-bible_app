import 'dart:math' as math;
import 'package:flutter/material.dart';

String themeModeName(String mode) {
  switch (mode) {
    case 'dark':
      return 'Тёмная';
    case 'eink':
      return 'E-Ink';
    default:
      return 'Светлая';
  }
}

class ThemeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const ThemeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.15)
                : cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary : cs.outline.withValues(alpha: 0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: selected ? cs.primary : cs.onSurface),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.primary : cs.onSurface,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

void showColorPicker(
  BuildContext context, {
  required String title,
  required Color initial,
  required ValueChanged<Color> onPicked,
}) {
  showDialog(
    context: context,
    builder: (_) => _HSLColorPickerDialog(
      title: title,
      initial: initial,
      onPicked: onPicked,
    ),
  );
}

class _HSLColorPickerDialog extends StatefulWidget {
  final String title;
  final Color initial;
  final ValueChanged<Color> onPicked;

  const _HSLColorPickerDialog({
    required this.title,
    required this.initial,
    required this.onPicked,
  });

  @override
  State<_HSLColorPickerDialog> createState() => _HSLColorPickerDialogState();
}

class _HSLColorPickerDialogState extends State<_HSLColorPickerDialog> {
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
    _alpha = hsl.alpha;
  }

  Color get _currentColor =>
      HSLColor.fromAHSL(_alpha, _hue, _saturation, _lightness).toColor();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: _HueWheel(
                hue: _hue,
                saturation: _saturation,
                lightness: _lightness,
                onChanged: (h) => setState(() => _hue = h),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.initial,
                    borderRadius:
                        const BorderRadius.horizontal(left: Radius.circular(8)),
                    border: Border.all(color: cs.outline),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(8)),
                    border: Border.all(color: cs.outline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '#${_currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SliderRow(
              label: 'Насыщенность',
              value: _saturation,
              activeColor: _currentColor,
              onChanged: (v) => setState(() => _saturation = v),
            ),
            _SliderRow(
              label: 'Яркость',
              value: _lightness,
              activeColor: _currentColor,
              onChanged: (v) => setState(() => _lightness = v),
            ),
            _SliderRow(
              label: 'Прозрачность',
              value: _alpha,
              activeColor: _currentColor,
              onChanged: (v) => setState(() => _alpha = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            widget.onPicked(_currentColor);
            Navigator.pop(context);
          },
          child: const Text('Применить'),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: activeColor,
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${(value * 100).round()}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _HueWheel extends StatelessWidget {
  final double hue;
  final double saturation;
  final double lightness;
  final ValueChanged<double> onChanged;

  const _HueWheel({
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _handle(d.localPosition, context),
      onPanUpdate: (d) => _handle(d.localPosition, context),
      child: CustomPaint(
        painter: _HueWheelPainter(
          hue: hue,
          saturation: saturation,
          lightness: lightness,
        ),
      ),
    );
  }

  void _handle(Offset pos, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    var angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;
    onChanged(angle);
  }
}

class _HueWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double lightness;

  _HueWheelPainter({
    required this.hue,
    required this.saturation,
    required this.lightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.22;

    for (int i = 0; i < 360; i++) {
      final paint = Paint()
        ..color =
            HSLColor.fromAHSL(1, i.toDouble(), saturation, lightness).toColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      final startAngle = (i - 90) * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        math.pi / 180 * 1.5,
        false,
        paint,
      );
    }

    final selectedAngle = (hue - 90) * math.pi / 180;
    final indicatorRadius = radius - strokeWidth / 2;
    final ix = center.dx + indicatorRadius * math.cos(selectedAngle);
    final iy = center.dy + indicatorRadius * math.sin(selectedAngle);
    final selectedColor =
        HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();

    canvas.drawCircle(
        Offset(ix, iy),
        strokeWidth / 2 + 2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(ix, iy),
        strokeWidth / 2,
        Paint()
          ..color = selectedColor
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(ix, iy),
        strokeWidth / 2 + 2,
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    canvas.drawCircle(
        center,
        radius * 0.35,
        Paint()
          ..color = selectedColor
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        center,
        radius * 0.35,
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _HueWheelPainter old) =>
      old.hue != hue ||
      old.saturation != saturation ||
      old.lightness != lightness;
}
