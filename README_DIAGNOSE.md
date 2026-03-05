# Диагностика пустого экрана в BibleApp

## 1. Проверка инициализации в main.dart
- Убедитесь, что в main.dart вызывается AppState.initialize() и (желательно) AppState().loadInitialData() до runApp().
- Оберните MaterialApp в MultiProvider, чтобы AppState и другие провайдеры были доступны всему дереву.

## 2. Провайдеры и State-менеджер
- AppState должен быть ChangeNotifier и добавлен в MultiProvider.
- Если используете другие провайдеры (DictionaryProvider, NotesProvider и т.д.), они тоже должны быть в MultiProvider.

## 3. BottomNavigation и IndexedStack
- В MainShell или аналогичном виджете используйте IndexedStack для переключения экранов.
- Каждый экран (HomeScreen, SearchScreen, SettingsScreen) должен быть импортирован и возвращать валидный UI.

## 4. Проверка экранов
- HomeScreen: должен получать AppState через Provider и проверять isDataReady. Если данных нет, показывать CircularProgressIndicator.
- SearchScreen: должен получать SearchProvider через Provider. Если results пустой, показывать заглушку.

## 5. Проверка базы данных
- Файл assets/bible.db должен существовать и быть прописан в pubspec.yaml.
- В DBService добавьте обработку ошибок при открытии базы и выводите debugPrint при ошибках.

## 6. Чек-лист для отладки
| Шаг | Что проверить | Где |
|-----|---------------|-----|
| 1 | AppState.initialize() и loadInitialData() вызываются | main.dart |
| 2 | AppState открывает БД и prefs | core/app_state.dart |
| 3 | MultiProvider оборачивает MainShell | ui/main_shell.dart |
| 4 | Экраны используют Provider и проверяют готовность данных | features/*/view/*.dart |
| 5 | База есть в assets и pubspec.yaml | assets/, pubspec.yaml |
| 6 | Нет скрытых try/catch без логов | *_service.dart |

## 7. Пример main.dart
```dart
import 'package:flutter/material.dart';
import 'package:bible_app/core/app_state.dart';
import 'package:bible_app/ui/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppState.initialize();
    await AppState().loadInitialData();
  } catch (e, st) {
    debugPrint('❌ Initialization error: $e\n$st');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bible App',
      theme: ThemeData.light(),
      home: const MainShell(),
    );
  }
}
```

## 8. Если проблема не решена
- Проверьте, что все провайдеры действительно создаются и используются.
- Проверьте, что база данных открывается без ошибок.
- Запустите в debug и посмотрите логи.
- Если всё равно пусто — проверьте конкретные экраны (например, HomeScreen, SearchScreen) на предмет возврата пустого контейнера или отсутствия данных.




Root causes:

HomeScreen checks only isLoadingText for the spinner, but isLoadingBooks = true initially while isLoadingText = false — so on first build, _buildText() is called with empty verses, showing a blank body
_TabNavigator recreates MaterialPageRoute closure every rebuild — the captured child goes stale
BibleApp uses context.watch<AppState>() causing full MaterialApp rebuilds on every state change, which can reset navigator state
MainShell subscribes to all AppState changes but only uses .error





