import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_state.dart';
import '_settings_common.dart';
import '../../../notes/widgets/note_font_settings_sheet.dart';

class NotesSettingsScreen extends StatelessWidget {
  const NotesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Редактор заметок')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SectionHeader('Шрифт и размер'),
          ListTile(
            leading: const Icon(Icons.text_format),
            title: const Text('Настройки шрифта'),
            subtitle: const Text('Шрифт, размер, цвет текста'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showModalBottomSheet(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (ctx) => NoteFontSettingsSheet(appState: state),
            ),
          ),
          FontSizeSlider(
            label: 'Размер текста',
            value: state.noteFontSize,
            min: 10,
            max: 28,
            divisions: 18,
            onChanged: state.setNoteFontSize,
            showPreview: true,
            fontFamily: state.noteFontFamily,
          ),
          FontSizeSlider(
            label: 'Межстрочный интервал',
            value: state.noteLineHeight,
            min: 1.0,
            max: 2.5,
            divisions: 15,
            onChanged: state.setNoteLineHeight,
          ),
          FontSizeSlider(
            label: 'Заголовок заметки',
            value: state.noteTitleSize,
            min: 14,
            max: 32,
            divisions: 18,
            onChanged: state.setNoteTitleSize,
          ),
          FontSizeSlider(
            label: 'H1',
            value: state.noteH1Size,
            min: 14,
            max: 36,
            divisions: 22,
            onChanged: state.setNoteH1Size,
          ),
          FontSizeSlider(
            label: 'H2',
            value: state.noteH2Size,
            min: 14,
            max: 30,
            divisions: 16,
            onChanged: state.setNoteH2Size,
          ),
          FontSizeSlider(
            label: 'H3',
            value: state.noteH3Size,
            min: 14,
            max: 28,
            divisions: 14,
            onChanged: state.setNoteH3Size,
          ),
        ],
      ),
    );
  }
}
