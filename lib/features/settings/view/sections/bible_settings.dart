import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_state.dart';
import '_settings_common.dart';

class BibleSettingsScreen extends StatelessWidget {
  const BibleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Шрифт Библии')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SectionHeader('Шрифт'),
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
                  Text('Предпросмотр',
                      style: TextStyle(fontSize: 12, color: cs.secondary)),
                  const SizedBox(height: 8),
                  Text(
                    'Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος ἦν πρὸς τὸν θεόν.',
                    style: TextStyle(
                      fontFamily: state.fontFamily,
                      fontSize: state.fontSize,
                      height: state.lineHeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Размеры'),
          FontSizeSlider(
            label: 'Текст Библии',
            value: state.fontSize,
            min: 10,
            max: 40,
            divisions: 30,
            onChanged: state.setFontSize,
            showPreview: true,
            fontFamily: state.fontFamily,
          ),
          FontSizeSlider(
            label: 'Малый попап',
            value: state.popupFontSize,
            min: 10,
            max: 28,
            divisions: 18,
            onChanged: state.setPopupFontSize,
          ),
          FontSizeSlider(
            label: 'Большой попап',
            value: state.fullPopupFontSize,
            min: 10,
            max: 40,
            divisions: 30,
            onChanged: state.setFullPopupFontSize,
          ),
          FontSizeSlider(
            label: 'Поиск',
            value: state.searchFontSize,
            min: 10,
            max: 40,
            divisions: 30,
            onChanged: state.setSearchFontSize,
          ),
          FontSizeSlider(
            label: 'Просмотр стиха',
            value: state.versePreviewFontSize,
            min: 10,
            max: 40,
            divisions: 30,
            onChanged: state.setVersePreviewFontSize,
          ),
          FontSizeSlider(
            label: 'Критический текст',
            value: state.criticalTextFontSize,
            min: 8,
            max: 36,
            divisions: 28,
            onChanged: state.setCriticalTextFontSize,
          ),
          FontSizeSlider(
            label: 'Меню (книга/глава)',
            value: state.appBarFontSize,
            min: 12,
            max: 30,
            divisions: 18,
            onChanged: state.setAppBarFontSize,
          ),
          const SectionHeader('Межстрочный интервал'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Интервал', style: TextStyle(fontSize: 14)),
                    Text(
                      state.lineHeight.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: state.lineHeight,
                  min: 1.0,
                  max: 2.5,
                  divisions: 30,
                  label: state.lineHeight.toStringAsFixed(2),
                  onChanged: state.setLineHeight,
                ),
              ],
            ),
          ),
          const SectionHeader('Отображение'),
          SwitchListTile(
            title: const Text('Номера стихов'),
            value: state.showVerseNumbers,
            onChanged: state.setShowVerseNumbers,
          ),
          SwitchListTile(
            title: const Text('Критический текст'),
            subtitle: const Text('Аппарат NA27/UBS4/Byzantine'),
            value: state.showCriticalText,
            onChanged: state.setShowCriticalText,
          ),
          SwitchListTile(
            title: const Text('Режим копирования'),
            subtitle: const Text(
              'Выделение текста жестом. Долгий тап на стихе недоступен.',
            ),
            value: state.textSelectionEnabled,
            onChanged: state.setTextSelectionEnabled,
          ),
        ],
      ),
    );
  }
}
