import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_state.dart';
import '../../../../core/themes.dart';
import '../../../../core/themes/palette_registry.dart';
import '_settings_common.dart';
import '_color_picker.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Внешний вид')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Масштаб интерфейса ────────────────────────────────────────
          const SectionHeader('Масштаб интерфейса'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Text(
                  '${(state.uiScale * 100).round()}%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                if ((state.uiScale - 1.0).abs() > 0.01)
                  TextButton(
                    onPressed: () => state.setUiScale(1.0),
                    child: const Text('Сбросить'),
                  ),
              ],
            ),
          ),
          Slider(
            value: state.uiScale,
            min: 0.9,
            max: 2.0,
            divisions: 22,
            label: '${(state.uiScale * 100).round()}%',
            onChanged: state.setUiScale,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('90%',
                    style: TextStyle(fontSize: 11, color: cs.secondary)),
                Text('По умолчанию: 100%',
                    style: TextStyle(fontSize: 11, color: cs.secondary)),
                Text('200%',
                    style: TextStyle(fontSize: 11, color: cs.secondary)),
              ],
            ),
          ),
          const Divider(),

          // ── Палитра ───────────────────────────────────────────────────
          const SectionHeader('Палитра'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allPalettes.map((p) {
                final selected = state.paletteName == p.id;
                return _PaletteChip(
                  palette: p,
                  selected: selected,
                  onTap: () => state.setPalette(p.id),
                );
              }).toList(),
            ),
          ),

          // ── Яркость ───────────────────────────────────────────────────
          if (state.paletteName != 'eink') ...[
            const SectionHeader('Яркость'),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ThemeButton(
                    label: 'Светлая',
                    icon: Icons.light_mode,
                    selected: state.brightnessMode == 'light',
                    onTap: () => state.setBrightness('light'),
                  ),
                  const SizedBox(width: 8),
                  ThemeButton(
                    label: 'Тёмная',
                    icon: Icons.dark_mode,
                    selected: state.brightnessMode == 'dark',
                    onTap: () => state.setBrightness('dark'),
                  ),
                  const SizedBox(width: 8),
                  ThemeButton(
                    label: 'Системная',
                    icon: Icons.settings_brightness,
                    selected: state.brightnessMode == 'system',
                    onTap: () => state.setBrightness('system'),
                  ),
                  const SizedBox(width: 8),
                  ThemeButton(
                    label: 'Расписание',
                    icon: Icons.schedule,
                    selected: state.brightnessMode == 'schedule',
                    onTap: () => state.setBrightness('schedule'),
                  ),
                ],
              ),
            ),
            // ── Schedule time pickers ───────────────────────────────────
            if (state.brightnessMode == 'schedule')
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text('Светлая с '),
                    _TimePickerButton(
                      minutes: state.scheduleStart,
                      onPicked: (m) =>
                          state.setSchedule(m, state.scheduleEnd),
                      context: context,
                    ),
                    const Text(' до '),
                    _TimePickerButton(
                      minutes: state.scheduleEnd,
                      onPicked: (m) =>
                          state.setSchedule(state.scheduleStart, m),
                      context: context,
                    ),
                  ],
                ),
              ),
          ],
          const Divider(),

          // ── Настройка цветов ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Настроить цвета (${themeModeName(state.themeMode)})',
                style: const TextStyle(fontSize: 14),
              ),
              leading: Icon(Icons.palette, size: 20, color: cs.primary),
              children: [
                ...CustomThemeColors.roleLabels.entries.map((entry) {
                  final role = entry.key;
                  final label = entry.value;
                  final color = state.customColors.getByRole(role);
                  return ListTile(
                    dense: true,
                    leading: GestureDetector(
                      onTap: () => _openColorPicker(
                          context, state, role, label, color),
                      child: Container(
                        width: 28,
                        height: 28,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.secondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    onTap: () => _openColorPicker(
                        context, state, role, label, color),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Цвета сегментов Библии',
                style: TextStyle(fontSize: 14),
              ),
              leading: Icon(Icons.color_lens, size: 20, color: cs.primary),
              children: [
                ...BibleSegment.values.map((seg) {
                  final label = segmentLabels[seg] ?? seg.name;
                  final color = state.segmentColors[seg] ??
                      defaultSegmentColors(state.themeMode)[seg]!;
                  return ListTile(
                    dense: true,
                    leading: GestureDetector(
                      onTap: () => _openSegmentColorPicker(
                        context, state, seg, label, color,
                      ),
                      child: Container(
                        width: 28,
                        height: 28,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.secondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    onTap: () => _openSegmentColorPicker(
                      context, state, seg, label, color,
                    ),
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
                        const SnackBar(
                            content: Text('Цвета сегментов сброшены')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Анимации'),
          SwitchListTile(
            title: const Text('Анимации'),
            subtitle: const Text(
              'Переходы между экранами, прокрутка, мигание слов',
            ),
            value: state.animationsEnabled,
            onChanged: state.setAnimations,
          ),
        ],
      ),
    );
  }

  void _openColorPicker(
    BuildContext context,
    AppState state,
    String role,
    String label,
    Color color,
  ) {
    showColorPicker(
      context,
      title: label,
      initial: color,
      onPicked: (c) => state.setThemeColor(role, c),
    );
  }

  void _openSegmentColorPicker(
    BuildContext context,
    AppState state,
    BibleSegment seg,
    String label,
    Color color,
  ) {
    showColorPicker(
      context,
      title: label,
      initial: color,
      onPicked: (c) => state.setSegmentColor(seg, c),
    );
  }
}

// ── Palette chip widget ─────────────────────────────────────────────────────

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: 0.2)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? palette.accent : cs.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              palette.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Time picker button ──────────────────────────────────────────────────────

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.minutes,
    required this.onPicked,
    required this.context,
  });

  final int minutes;
  final ValueChanged<int> onPicked;
  final BuildContext context;

  @override
  Widget build(BuildContext outerContext) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return TextButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: h, minute: m),
        );
        if (picked != null) {
          onPicked(picked.hour * 60 + picked.minute);
        }
      },
      child: Text('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}'),
    );
  }
}
