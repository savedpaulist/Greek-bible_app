// Shared widgets for settings sections
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class FontSizeSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final bool showPreview;
  final String? fontFamily;

  const FontSizeSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 10,
    this.max = 32,
    this.divisions = 22,
    this.showPreview = false,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text(
                '${value.toStringAsFixed(0)} pt',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
          if (showPreview && fontFamily != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Λόγος — ${value.round()} pt',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: value,
                  color: cs.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
