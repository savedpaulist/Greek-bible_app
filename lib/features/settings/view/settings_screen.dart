// lib/features/settings/view/settings_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_state.dart';
import '../../../core/themes.dart';
import '../../hotkey_settings/view/hotkey_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs    = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Theme (grouped) ────────────────────────────────────────────────
          _SectionHeader('Тема оформления'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _ThemeButton(
                  label: 'Светлая',
                  icon: Icons.light_mode,
                  selected: state.themeMode == 'light',
                  onTap: () => state.setThemeMode('light'),
                ),
                const SizedBox(width: 12),
                _ThemeButton(
                  label: 'Тёмная',
                  icon: Icons.dark_mode,
                  selected: state.themeMode == 'dark',
                  onTap: () => state.setThemeMode('dark'),
                ),
                const SizedBox(width: 12),
                _ThemeButton(
                  label: 'E-Ink',
                  icon: Icons.chrome_reader_mode,
                  selected: state.themeMode == 'eink',
                  onTap: () => state.setThemeMode('eink'),
                ),
              ],
            ),
          ),
          // Colors — nested inside an ExpansionTile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Настроить цвета (${_themeName(state.themeMode)})',
                  style: const TextStyle(fontSize: 14)),
              leading: Icon(Icons.palette, size: 20, color: cs.primary),
              children: [
                ...CustomThemeColors.roleLabels.entries.map((entry) {
                  final role  = entry.key;
                  final label = entry.value;
                  final color = state.customColors.getByRole(role);
                  return ListTile(
                    dense: true,
                    leading: GestureDetector(
                      onTap: () => _openColorPicker(context, state, role, label, color),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cs.outline, width: 1),
                        ),
                      ),
                    ),
                    title: Text(label, style: const TextStyle(fontSize: 14)),
                    trailing: Text(
                      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                      style: TextStyle(fontSize: 12, color: cs.secondary, fontFamily: 'monospace'),
                    ),
                    onTap: () => _openColorPicker(context, state, role, label, color),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Сбросить цвета к умолчанию'),
                    onPressed: () {
                      state.resetThemeColors();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Цвета сброшены')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Segment colors ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Цвета сегментов Библии',
                  style: const TextStyle(fontSize: 14)),
              leading: Icon(Icons.color_lens, size: 20, color: cs.primary),
              children: [
                ...BibleSegment.values.map((seg) {
                  final label = segmentLabels[seg] ?? seg.name;
                  final color = state.segmentColors[seg] ??
                      defaultSegmentColors(state.themeMode)[seg]!;
                  return ListTile(
                    dense: true,
                    leading: GestureDetector(
                      onTap: () => _openSegmentColorPicker(context, state, seg, label, color),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cs.outline, width: 1),
                        ),
                      ),
                    ),
                    title: Text(label, style: const TextStyle(fontSize: 14)),
                    trailing: Text(
                      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                      style: TextStyle(fontSize: 12, color: cs.secondary, fontFamily: 'monospace'),
                    ),
                    onTap: () => _openSegmentColorPicker(context, state, seg, label, color),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Сбросить цвета сегментов'),
                    onPressed: () {
                      state.resetSegmentColors();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Цвета сегментов сброшены')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // ── Font (grouped) ─────────────────────────────────────────────────
          _SectionHeader('Шрифты'),
          // Font family chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppState.availableFonts.entries.map((e) {
                final isSelected = state.fontFamily == e.key;
                return ChoiceChip(
                  label: Text(e.value),
                  selected: isSelected,
                  onSelected: (_) => state.setFontFamily(e.key),
                );
              }).toList(),
            ),
          ),
          // Font preview
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Предпросмотр шрифта',
                      style: TextStyle(fontSize: 12, color: cs.secondary)),
                  const SizedBox(height: 8),
                  Text(
                    'Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος ἦν πρὸς τὸν θεόν, '
                    'καὶ θεὸς ἦν ὁ λόγος.',
                    style: TextStyle(
                      fontFamily: state.fontFamily,
                      fontSize: state.fontSize,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppState.availableFonts[state.fontFamily]} · '
                    '${state.fontSize.round()} pt',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // All font previews
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: ExpansionTile(
              title: const Text('Все шрифты'),
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              children: AppState.availableFonts.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.primary)),
                      const SizedBox(height: 2),
                      Text(
                        'Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος ἦν πρὸς τὸν θεόν',
                        style: TextStyle(
                          fontFamily: e.key,
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // Font sizes — nested inside an ExpansionTile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Размеры шрифтов', style: TextStyle(fontSize: 14)),
              leading: Icon(Icons.format_size, size: 20, color: cs.primary),
              children: [
                _FontSizeRow(
                  label: 'Текст Библии',
                  value: state.fontSize,
                  preview: true,
                  fontFamily: state.fontFamily,
                  onChanged: state.setFontSize,
                  min: 10, max: 40,
                ),
                _FontSizeRow(
                  label: 'Малый попап',
                  value: state.popupFontSize,
                  preview: true,
                  fontFamily: state.fontFamily,
                  onChanged: state.setPopupFontSize,
                  min: 10, max: 28,
                ),
                _FontSizeRow(
                  label: 'Большой попап',
                  value: state.fullPopupFontSize,
                  preview: true,
                  fontFamily: state.fontFamily,
                  onChanged: state.setFullPopupFontSize,
                  min: 10, max: 40,
                ),
                _FontSizeRow(
                  label: 'Словарь',
                  value: state.dictionaryFontSize,
                  preview: true,
                  fontFamily: state.fontFamily,
                  onChanged: state.setDictionaryFontSize,
                  min: 10, max: 40,
                ),
                _FontSizeRow(
                  label: 'Поиск',
                  value: state.searchFontSize,
                  preview: true,
                  fontFamily: state.fontFamily,
                  onChanged: state.setSearchFontSize,
                  min: 10, max: 40,
                ),
                _FontSizeRow(
                  label: 'Просмотр стиха',
                  value: state.versePreviewFontSize,
                  preview: true,
                  fontFamily: state.fontFamily,
                  onChanged: state.setVersePreviewFontSize,
                  min: 10, max: 40,
                ),
                _FontSizeRow(
                  label: 'Критический текст',
                  value: state.criticalTextFontSize,
                  preview: true,
                  fontFamily: state.fontFamily,
                  onChanged: state.setCriticalTextFontSize,
                  min: 8, max: 36,
                ),
                _FontSizeRow(
                  label: 'Меню (книга/глава)',
                  value: state.appBarFontSize,
                  preview: false,
                  fontFamily: state.fontFamily,
                  onChanged: state.setAppBarFontSize,
                  min: 12, max: 30,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Line height ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.format_line_spacing, size: 20, color: cs.primary),
                const SizedBox(width: 12),
                const Text('Межстрочный интервал', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Text(state.lineHeight.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: state.lineHeight,
              min: 1.0,
              max: 2.5,
              divisions: 30,
              label: state.lineHeight.toStringAsFixed(2),
              onChanged: (v) => state.setLineHeight(v),
            ),
          ),

          const Divider(),
          _SectionHeader('Критический текст'),
          SwitchListTile(
            title: const Text('Показывать критический текст'),
            subtitle: const Text('Аппарат NA27/UBS4/Byzantine'),
            value: state.showCriticalText,
            onChanged: (v) => state.setShowCriticalText(v),
          ),

          const Divider(),

          // ── Text selection toggle ─────────────────────────────────────────
          _SectionHeader('Выделение текста'),
          SwitchListTile(
            title: const Text('Режим копирования'),
            subtitle: const Text(
              'Позволяет выделять текст жестом.\n'
              'Когда включён, долгий тап на стихе недоступен.',
            ),
            value: state.textSelectionEnabled,
            onChanged: (v) => state.setTextSelectionEnabled(v),
          ),

          const Divider(),

          // ── Animations ────────────────────────────────────────────────────
          _SectionHeader('Анимации'),
          SwitchListTile(
            title: const Text('Анимации'),
            subtitle: const Text(
              'Переходы между экранами, прокрутка, мигание слов',
            ),
            value: state.animationsEnabled,
            onChanged: (v) => state.setAnimations(v),
          ),

          const Divider(),

          // ── Search history limit ──────────────────────────────────────────
          _SectionHeader('История поиска'),
          ListTile(
            title: const Text('Максимум записей'),
            trailing: DropdownButton<int>(
              value: state.searchHistoryLimit,
              items: const [5, 10, 20, 50, 100, 200, 500, 1000]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) {
                if (v != null) state.setSearchHistoryLimit(v);
              },
            ),
          ),
          if (state.searchHistory.isNotEmpty)
            ListTile(
              title: const Text('Очистить историю'),
              leading: const Icon(Icons.delete_outline),
              onTap: () {
                state.clearSearchHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('История очищена')),
                );
              },
            ),

          const Divider(),

          // ── Hotkeys ────────────────────────────────────────────────────────
          _SectionHeader('Горячие клавиши'),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('Настроить горячие клавиши'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HotkeySettingsScreen())),
          ),

          const Divider(),

          // ── Index ──────────────────────────────────────────────────────────
          _SectionHeader('Поисковый индекс'),
          ListTile(
            leading: Icon(
              state.indexError != null
                  ? Icons.error_outline
                  : state.isIndexing ? Icons.hourglass_top : Icons.build,
              color: state.indexError != null
                  ? cs.error
                  : state.isIndexing ? cs.primary : null,
            ),
            title: Text(
              state.indexError != null
                  ? 'Ошибка индексации'
                  : state.isIndexing ? 'Построение индекса…' : 'Перестроить индекс',
            ),
            subtitle: state.isIndexing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: state.indexProgress,
                          minHeight: 8,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(state.indexProgress * 100).round()}%',
                        style: TextStyle(fontSize: 12, color: cs.secondary),
                      ),
                    ],
                  )
                : state.indexError != null
                    ? Text(state.indexError!,
                        style: TextStyle(fontSize: 12, color: cs.error),
                        maxLines: 3, overflow: TextOverflow.ellipsis)
                    : const Text('Полнотекстовый поиск по словам'),
            onTap: state.isIndexing ? null : () => state.rebuildIndex(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

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

// ── Theme button ────────────────────────────────────────────────────────────
class _ThemeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeButton({
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
              Icon(icon,
                  size: 28,
                  color: selected ? cs.primary : cs.onSurface),
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

// ── Font size row with preview ──────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Line height slider with debounce + live preview
// ─────────────────────────────────────────────────────────────────────────────
class _LineHeightSlider extends StatefulWidget {
  final double value;
  final String fontFamily;
  final double fontSize;
  final ValueChanged<double> onChanged;

  const _LineHeightSlider({
    required this.value,
    required this.fontFamily,
    required this.fontSize,
    required this.onChanged,
  });

  @override
  State<_LineHeightSlider> createState() => _LineHeightSliderState();
}

class _LineHeightSliderState extends State<_LineHeightSlider> {
  late double _local;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _local = widget.value;
  }

  @override
  void didUpdateWidget(covariant _LineHeightSlider old) {
    super.didUpdateWidget(old);
    if (_debounce?.isActive != true) {
      _local = widget.value;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSlider(double v) {
    setState(() => _local = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      widget.onChanged(_local);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_line_spacing, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              const Text('Межстрочный интервал',
                  style: TextStyle(fontSize: 14)),
              const Spacer(),
              Text(_local.toStringAsFixed(2),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          Slider(
            value: _local,
            min: 1.0,
            max: 2.5,
            divisions: 30,
            label: _local.toStringAsFixed(2),
            onChanged: _onSlider,
          ),
          // Preview
          Container(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Ἐν ἀρχῇ ἦν ὁ λόγος,\nκαὶ ὁ λόγος ἦν πρὸς τὸν θεόν,\nκαὶ θεὸς ἦν ὁ λόγος.',
              style: TextStyle(
                fontFamily: widget.fontFamily,
                fontSize: widget.fontSize,
                height: _local,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeRow extends StatelessWidget {
  final String label;
  final double value;
  final bool preview;
  final String fontFamily;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  const _FontSizeRow({
    required this.label,
    required this.value,
    this.preview = false,
    this.fontFamily = 'Gentium',
    required this.onChanged,
    this.min = 10,
    this.max = 40,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14)),
              ),
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: value > min ? () => onChanged(value - 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${value.round()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: value < max ? () => onChanged(value + 1) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          if (preview)
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

// ── Helpers ─────────────────────────────────────────────────────────────────

String _themeName(String mode) {
  switch (mode) {
    case 'dark':  return 'Тёмная';
    case 'eink':  return 'E-Ink';
    default:      return 'Светлая';
  }
}

void _openColorPicker(
    BuildContext context, AppState state, String role, String label, Color current) {
  showDialog(
    context: context,
    builder: (_) => _HSLColorPickerDialog(
      title: label,
      initial: current,
      onPicked: (c) => state.setThemeColor(role, c),
    ),
  );
}

void _openSegmentColorPicker(
    BuildContext context, AppState state, BibleSegment seg, String label, Color current) {
  showDialog(
    context: context,
    builder: (_) => _HSLColorPickerDialog(
      title: label,
      initial: current,
      onPicked: (c) => state.setSegmentColor(seg, c),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HSL color picker dialog with hue wheel + saturation / lightness sliders
// ─────────────────────────────────────────────────────────────────────────────

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
    _hue        = hsl.hue;
    _saturation = hsl.saturation;
    _lightness  = hsl.lightness;
    _alpha      = hsl.alpha;
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
            // ── Hue wheel ──
            SizedBox(
              width: 220, height: 220,
              child: _HueWheel(
                hue: _hue,
                saturation: _saturation,
                lightness: _lightness,
                onChanged: (h) => setState(() => _hue = h),
              ),
            ),
            const SizedBox(height: 16),

            // ── Preview ──
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: widget.initial,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    border: Border.all(color: cs.outline),
                  ),
                ),
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    border: Border.all(color: cs.outline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '#${_currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Saturation ──
            _SliderRow(
              label: 'Насыщенность',
              value: _saturation,
              activeColor: _currentColor,
              onChanged: (v) => setState(() => _saturation = v),
            ),

            // ── Lightness ──
            _SliderRow(
              label: 'Яркость',
              value: _lightness,
              activeColor: _currentColor,
              onChanged: (v) => setState(() => _lightness = v),
            ),

            // ── Alpha ──
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

// ── Slider row helper ───────────────────────────────────────────────────────
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
              min: 0, max: 1,
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

// ─────────────────────────────────────────────────────────────────────────────
// HSL Hue wheel (custom painter)
// ─────────────────────────────────────────────────────────────────────────────

class _HueWheel extends StatelessWidget {
  final double hue;        // 0..360
  final double saturation; // 0..1
  final double lightness;  // 0..1
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
      onPanDown:   (d) => _handle(d.localPosition, context),
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
    final box  = context.findRenderObject() as RenderBox;
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

    // Draw hue ring
    for (int i = 0; i < 360; i++) {
      final paint = Paint()
        ..color = HSLColor.fromAHSL(1, i.toDouble(), saturation, lightness).toColor()
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

    // Selected colour indicator
    final selectedAngle = (hue - 90) * math.pi / 180;
    final indicatorRadius = radius - strokeWidth / 2;
    final ix = center.dx + indicatorRadius * math.cos(selectedAngle);
    final iy = center.dy + indicatorRadius * math.sin(selectedAngle);
    final selectedColor = HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();

    // White outline
    canvas.drawCircle(Offset(ix, iy), strokeWidth / 2 + 2,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    // Selected colour fill
    canvas.drawCircle(Offset(ix, iy), strokeWidth / 2,
        Paint()..color = selectedColor..style = PaintingStyle.fill);
    // Thin dark border
    canvas.drawCircle(Offset(ix, iy), strokeWidth / 2 + 2,
        Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Centre colour preview
    canvas.drawCircle(center, radius * 0.35,
        Paint()..color = selectedColor..style = PaintingStyle.fill);
    canvas.drawCircle(center, radius * 0.35,
        Paint()..color = Colors.black12..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _HueWheelPainter old) =>
      old.hue != hue || old.saturation != saturation || old.lightness != lightness;
}
