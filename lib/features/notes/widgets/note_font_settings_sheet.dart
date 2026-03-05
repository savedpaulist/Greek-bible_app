// lib/features/notes/widgets/note_font_settings_sheet.dart
import 'package:flutter/material.dart';
import '../../../core/app_state.dart';

class NoteFontSettingsSheet extends StatefulWidget {
  final AppState appState;
  const NoteFontSettingsSheet({super.key, required this.appState});

  @override
  State<NoteFontSettingsSheet> createState() => _NoteFontSettingsSheetState();
}

class _NoteFontSettingsSheetState extends State<NoteFontSettingsSheet> {
  late String _fontFamily;

  static const _presetColors = <Color>[
    Color(0xFFE53935), // red
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFFFF8F00), // amber
    Color(0xFF8E24AA), // purple
    Color(0xFF827717), // lime
    Color(0xFF5D4037), // brown
    Color(0xFF607D8B), // blue grey
  ];

  @override
  void initState() {
    super.initState();
    _fontFamily = widget.appState.noteFontFamily;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurf = cs.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Шрифт заметок',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: onSurf,
                ),
              ),
              const SizedBox(height: 16),

              // Font family
              Text(
                'Шрифт',
                style: TextStyle(
                    fontSize: 13, color: onSurf.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: AppState.availableFonts.entries.map((e) {
                  final selected = _fontFamily == e.key;
                  return ChoiceChip(
                    label: Text(
                      e.value,
                      style: TextStyle(
                        fontFamily: e.value,
                        fontSize: 13,
                        color: selected ? cs.onPrimary : onSurf,
                      ),
                    ),
                    selected: selected,
                    selectedColor: cs.primary,
                    onSelected: (_) {
                      setState(() => _fontFamily = e.key);
                      widget.appState.setNoteFontFamily(e.key);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Font sizes
              Text(
                'Размеры шрифта',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: onSurf,
                ),
              ),
              Divider(color: cs.outlineVariant),

              _sizeSlider('Текст', widget.appState.noteFontSize, 10, 32,
                  (v) => widget.appState.setNoteFontSize(v)),
              _sizeSlider('Заголовок', widget.appState.noteTitleSize, 14, 48,
                  (v) => widget.appState.setNoteTitleSize(v)),
              _sizeSlider('H1', widget.appState.noteH1Size, 14, 60,
                  (v) => widget.appState.setNoteH1Size(v)),
              _sizeSlider('H2', widget.appState.noteH2Size, 14, 54,
                  (v) => widget.appState.setNoteH2Size(v)),
              _sizeSlider('H3', widget.appState.noteH3Size, 14, 48,
                  (v) => widget.appState.setNoteH3Size(v)),
              _sizeSlider('H4', widget.appState.noteH4Size, 14, 42,
                  (v) => widget.appState.setNoteH4Size(v)),
              _sizeSlider('Проводник', widget.appState.noteExplorerFontSize, 10,
                  24, (v) => widget.appState.setNoteExplorerFontSize(v)),

              _sizeSlider('Межстрочный', widget.appState.noteLineHeight, 1.0,
                  2.5, (v) => widget.appState.setNoteLineHeight(v),
                  isLineHeight: true),

              const SizedBox(height: 8),

              const SizedBox(height: 8),

              // Color
              Row(
                children: [
                  Text('Цвет текста',
                      style: TextStyle(
                          fontSize: 13, color: onSurf.withValues(alpha: 0.7))),
                  const Spacer(),
                  if (widget.appState.noteFontColor != null)
                    TextButton(
                      onPressed: () {
                        setState(() {});
                        widget.appState.setNoteFontColor(null);
                      },
                      child: const Text('Сбросить',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected =
                      widget.appState.noteFontColor == color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      setState(() {});
                      widget.appState.setNoteFontColor(color.toARGB32());
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? cs.primary
                              : onSurf.withValues(alpha: 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check,
                              size: 18,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sizeSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {bool isLineHeight = false}) {
    final cs = Theme.of(context).colorScheme;
    final onSurf = cs.onSurface;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label: ${isLineHeight ? value.toStringAsFixed(1) : value.round()}',
            style:
                TextStyle(fontSize: 13, color: onSurf.withValues(alpha: 0.8)),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: cs.primary,
            inactiveColor: cs.primary.withValues(alpha: 0.2),
            divisions:
                isLineHeight ? ((max - min) * 10).round() : (max - min).round(),
            onChanged: (v) {
              setState(() {});
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
