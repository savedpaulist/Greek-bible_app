// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_state.dart';
import 'core/db/db_service.dart';
import 'core/db/dictionary_service.dart';
import 'core/prefs/prefs_service.dart';

// import 'features/home/home_module.dart';
import 'features/dictionary/dictionary_module.dart';
import 'features/settings/view/settings_screen.dart';
import 'ui/main_shell.dart';
import 'ui/ui_scale_wrapper.dart';
import 'features/notes/provider/notes_provider.dart';
import 'features/notes/data/notes_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = DBService();
  final prefs = PrefsService();

  await prefs.init();
  final basePath = prefs.dbStoragePath; // null если не задано
  await db.initBible(basePath: basePath);

  // Fire and forget: load dictionaries in background
  db.initDictionaries();

  final dictService = DictionaryService(db);

  final notesDb = NotesDB();
  await notesDb.init(basePath: basePath);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(db: db, prefs: prefs)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => DictionaryProvider(dictService),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = NotesProvider(notesDb);
            provider.setPrefs(prefs); // A2: передаём prefs для recentTagIds
            provider.load();
            return provider;
          },
        ),
      ],
      child: const BibleApp(),
    ),
  );
}

class BibleApp extends StatelessWidget {
  const BibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Only watch theme-related fields to avoid rebuilding MaterialApp
    // on every AppState change (which would reset navigator state)
    final theme = context.select<AppState, ThemeData>((s) => s.currentTheme);

    return MaterialApp(
      title: 'Греческая Библия',
      debugShowCheckedModeBanner: false,
      theme: theme,
      // B2: масштабирование всего UI
      builder: (ctx, child) {
        final scale = ctx.select<AppState, double>((s) => s.uiScale);
        return UiScaleWrapper(
          scale: scale,
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (_) => const MainShell(),
        '/dictionaries': (ctx) => const DictionaryScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
