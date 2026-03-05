import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_state.dart';
import '_settings_common.dart';

class DictionarySettingsScreen extends StatelessWidget {
  const DictionarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Словарь')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SectionHeader('Размер шрифта'),
          FontSizeSlider(
            label: 'Размер шрифта',
            value: state.dictionaryFontSize,
            min: 12,
            max: 28,
            divisions: 16,
            onChanged: state.setDictionaryFontSize,
            showPreview: true,
            fontFamily: state.fontFamily,
          ),
        ],
      ),
    );
  }
}
