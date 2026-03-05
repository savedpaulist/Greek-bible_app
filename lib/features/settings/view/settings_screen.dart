// lib/features/settings/view/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../hotkey_settings/view/hotkey_settings_screen.dart';
import 'sections/appearance_settings.dart';
import 'sections/bible_settings.dart';
import 'sections/notes_settings.dart';
import 'sections/dictionary_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    final s = state.strings;

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Language ──────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language / Язык'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ru', label: Text('RU')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {state.language},
              onSelectionChanged: (v) => state.setLanguage(v.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(s.appearance),
            subtitle: Text(s.appearanceSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AppearanceSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(s.bibleFont),
            subtitle: Text(s.bibleText),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BibleSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(s.noteEditor),
            subtitle: Text(s.noteEditorSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotesSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: Text(s.dictionary),
            subtitle: Text(s.dictionaryFontSize),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DictionarySettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: Text(s.hotkeys),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HotkeySettingsScreen(),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(s.searchHistory),
            subtitle: Text(s.searchHistoryLimit(state.searchHistoryLimit)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSearchHistorySettings(context, state),
          ),
          if (state.searchHistory.isNotEmpty)
            ListTile(
              title: Text(s.clearHistory),
              leading: const Icon(Icons.delete_outline),
              onTap: () {
                state.clearSearchHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.historyCleared)),
                );
              },
            ),
          const Divider(),
          ListTile(
            leading: Icon(
              state.indexError != null
                  ? Icons.error_outline
                  : state.isIndexing
                      ? Icons.hourglass_top
                      : Icons.build,
              color: state.indexError != null
                  ? cs.error
                  : state.isIndexing
                      ? cs.primary
                      : null,
            ),
            title: Text(
              state.indexError != null
                  ? s.error
                  : state.isIndexing
                      ? s.indexSearch
                      : s.fulltextSearch,
            ),
            subtitle: state.isIndexing
                ? ValueListenableBuilder<double>(
                    valueListenable: state.indexProgress,
                    builder: (context, progress, _) => Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: cs.secondary),
                    ),
                  )
                : state.indexError != null
                    ? Text(
                        state.indexError!,
                        style: TextStyle(fontSize: 12, color: cs.error),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(s.fulltextSearch),
            onTap: state.isIndexing ? null : () => state.rebuildIndex(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showSearchHistorySettings(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.strings.searchHistory,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButton<int>(
              value: state.searchHistoryLimit,
              isExpanded: true,
              items: const [5, 10, 20, 50, 100, 200, 500, 1000]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) {
                if (v != null) state.setSearchHistoryLimit(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
