# План доработки Flutter-приложения (lib v17)

## Контекст проекта

Flutter-приложение с тремя основными вкладками:
- **Заметки** (`features/notes/`) — markdown-редактор с вкладками, превью, ссылками на стихи
- **Библия** (`features/home/`) — постраничный просмотр стихов, разметка слов, комментарии
- **Словари** (`features/dictionary/`) — словарные статьи с HTML-рендером

Ключевые файлы:
- `lib/features/notes/view/note_editor_screen.dart` — редактор заметок (~1000 строк)
- `lib/features/home/view/home_screen.dart` — экран Библии
- `lib/features/home/view/verse_widgets.dart` — виджеты стихов/слов
- `lib/features/dictionary/view/dictionary_article_screen.dart` — статья словаря
- `lib/features/settings/view/settings_screen.dart` — настройки (~1129 строк)
- `lib/ui/main_shell.dart` — основная оболочка с PageView и вложенными Navigator
- `lib/core/themes.dart` — темы оформления
- `lib/core/app_state.dart` — глобальный стейт (Provider)

---

## А. Редактор заметок

### А.1 — Перенос markdown-тулбара вниз + объединение кнопок заголовков

**Текущее состояние:**
`_MarkdownToolbar` расположен вверху редактора (внутри `Column` в `_buildEditor()`). Три отдельные кнопки `H1`, `H2`, `H3`.

**Что сделать:**

1. Переместить `_MarkdownToolbar` из `Column.children` в `bottomNavigationBar` Scaffold:
```dart
bottomNavigationBar: _preview
    ? null
    : SafeArea(child: _MarkdownToolbar(...)),
```

2. Убрать тулбар из `Column` в `_buildEditor()`.

3. В классе `_MarkdownToolbar` заменить три вызова `_headerBtn('H1', onH1)`, `_headerBtn('H2', onH2)`, `_headerBtn('H3', onH3)` на один виджет `_HeadingButton`:
```dart
_HeadingButton(
  cs: cs,
  onH1: onH1,
  onH2: onH2,
  onH3: onH3,
),
```

4. Реализация `_HeadingButton`:
```dart
class _HeadingButton extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onH1, onH2, onH3;
  const _HeadingButton({required this.cs, required this.onH1, required this.onH2, required this.onH3});

  void _showPicker(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx + 40, offset.dy + 40),
      items: [
        PopupMenuItem(value: 1, child: Text('H1 — Заголовок 1', style: TextStyle(fontWeight: FontWeight.bold))),
        PopupMenuItem(value: 2, child: Text('H2 — Заголовок 2')),
        PopupMenuItem(value: 3, child: Text('H3 — Заголовок 3')),
      ],
    ).then((v) {
      if (v == 1) onH1();
      if (v == 2) onH2();
      if (v == 3) onH3();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onH1, // по умолчанию H1
      onLongPress: () => _showPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text('H',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
              color: cs.onSurface.withValues(alpha: 0.8))),
      ),
    );
  }
}
```

---

### А.2 — Автоскролл: активная строка в верхней трети экрана

**Текущее состояние:**
В `_AutoListTextFieldState._scrollToCursorCenter()` целевая позиция курсора — `viewportHeight / 2`. При открытой клавиатуре это центр всего экрана, а не видимой области, поэтому курсор уходит под клавиатуру.

**Что сделать:**

Найти и заменить логику в методе `_scrollToCursorCenter()` файла `note_editor_screen.dart`:

```dart
// БЫЛО:
final bool desktopNoKeyboard = ...;
final defaultLine = desktopNoKeyboard ? viewportHeight * 0.33 : viewportHeight / 2;
final constrainedLine = keyboardHeight > 0 ? keyboardTop - minAboveKeyboard : defaultLine;
final desiredLine = keyboardHeight > 0 ? constrainedLine : defaultLine;
if (cursorY <= desiredLine) return;
final targetOffset = (cursorY - desiredLine).clamp(0.0, sc.position.maxScrollExtent);

// СТАЛО:
final visibleHeight = viewportHeight - keyboardHeight; // реальная видимая область
final desiredLine = visibleHeight * 0.33;              // верхняя треть видимой области

if (cursorY - sc.offset <= desiredLine) return;        // уже в безопасной зоне

final targetOffset =
    (sc.offset + (cursorY - sc.offset) - desiredLine)
        .clamp(0.0, sc.position.maxScrollExtent);

sc.animateTo(
  targetOffset,
  duration: const Duration(milliseconds: 120),
  curve: Curves.easeOut,
);
```

> **Важно:** `TextPainter.getOffsetForCaret()` возвращает позицию относительно начала **всего** текста, а не viewport'а. Поэтому сравнивать нужно `cursorY - sc.offset` (позиция курсора в видимой области), а `targetOffset` считать как смещение скролла.

---

### А.3 — Скрытие клавиатуры при смене вкладки и тапе по свободной области

**Что сделать:**

**1. При смене вкладки** — в `main_shell.dart`, метод `_onPageChanged()`, добавить первой строкой:
```dart
void _onPageChanged(int page) {
  FocusManager.instance.primaryFocus?.unfocus(); // ← добавить
  setState(() => _currentPage = page);
  context.read<AppState>().setActiveTab(page);
  _checkAutoHide();
}
```

**2. Тап по свободной области редактора** — в `note_editor_screen.dart`, метод `_buildEditor()`, обернуть возвращаемый `Column` в `GestureDetector`:
```dart
Widget _buildEditor(ColorScheme cs, AppState appState) {
  return GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => FocusScope.of(context).unfocus(),
    child: Column(
      children: [
        // ... весь существующий контент
      ],
    ),
  );
}
```

---

## Б. Темы — централизация в отдельном файле

**Текущее состояние:**
`core/themes.dart` существует, но части ThemeData могут быть рассыпаны по `app_state.dart` и `settings_screen.dart`.

**Что сделать:**

1. В `core/themes.dart` добавить публичные фабричные функции:
```dart
ThemeData buildLightTheme(CustomThemeColors colors) { ... }
ThemeData buildDarkTheme(CustomThemeColors colors) { ... }
ThemeData buildEinkTheme(CustomThemeColors colors) { ... }

// Единая точка входа:
ThemeData buildTheme(String mode, CustomThemeColors colors) {
  switch (mode) {
    case 'dark': return buildDarkTheme(colors);
    case 'eink': return buildEinkTheme(colors);
    default:     return buildLightTheme(colors);
  }
}
```

2. В `core/app_state.dart` заменить любые inline `ThemeData(...)` на:
```dart
ThemeData get currentTheme => buildTheme(themeMode, customColors);
```

3. В `main.dart` (или где создаётся `MaterialApp`) использовать только `appState.currentTheme`.

4. Из `settings_screen.dart` убрать любые цветовые константы — только читать из `themes.dart`.

---

## В. Библия — множественный выбор стихов для копирования

### Описание функции

- Долгий тап на стихе → контекстное меню предлагает пункт **«Выбрать несколько стихов»**
- При входе в режим: попап слова скрывается, стих добавляется в выборку
- Пользователь тапает по другим стихам — они добавляются/убираются из выборки
- В режиме выбора тапы по **словам** не срабатывают — весь стих считается одной кнопкой
- В AppBar появляется кнопка **«Копировать (N)»**
- Нажатие копирует стихи в буфер в порядке номеров, режим выключается

### Изменения в `home_screen.dart`

Добавить состояние:
```dart
bool _multiSelectMode = false;
final Set<int> _selectedVerses = {};
```

Методы:
```dart
void _enterMultiSelectMode(VerseModel verse) {
  dismissActiveWordOverlay();
  setState(() {
    _multiSelectMode = true;
    _selectedVerses = {verse.verse};
  });
}

void _toggleVerseSelection(int verseNum) {
  setState(() {
    if (_selectedVerses.contains(verseNum))
      _selectedVerses.remove(verseNum);
    else
      _selectedVerses.add(verseNum);
  });
}

void _exitMultiSelectMode() {
  setState(() {
    _multiSelectMode = false;
    _selectedVerses.clear();
  });
}

Future<void> _copySelectedVerses() async {
  // Собрать тексты стихов в порядке возрастания номера
  final sorted = _selectedVerses.toList()..sort();
  final lines = <String>[];
  for (final vNum in sorted) {
    final verse = _currentVerses.firstWhere((v) => v.verse == vNum);
    final text = verse.words.map((w) => w.word).join(' ');
    lines.add('$vNum $text');
  }
  await Clipboard.setData(ClipboardData(text: lines.join('\n')));
  if (mounted) ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Скопировано ${sorted.length} стихов')));
  _exitMultiSelectMode();
}
```

В `_showVerseMenu(verse)` добавить пункт:
```dart
ListTile(
  leading: const Icon(Icons.select_all),
  title: const Text('Выбрать несколько стихов'),
  onTap: () {
    Navigator.pop(context);
    _enterMultiSelectMode(verse);
  },
),
```

AppBar (условно):
```dart
appBar: AppBar(
  title: _multiSelectMode
      ? Text('Выбрано: ${_selectedVerses.length}')
      : Text(/* обычный заголовок */),
  actions: [
    if (_multiSelectMode) ...[
      IconButton(icon: const Icon(Icons.copy), onPressed: _copySelectedVerses),
      IconButton(icon: const Icon(Icons.close), onPressed: _exitMultiSelectMode),
    ],
    // ... остальные кнопки
  ],
),
```

### Изменения в `verse_widgets.dart` — `VerseBlock`

Добавить параметры:
```dart
final bool multiSelectMode;    // default: false
final bool isSelected;         // default: false
final VoidCallback? onVerseSelect;
```

В методе `build()` обернуть итоговый виджет:
```dart
Widget result = Wrap(children: finalWidgets); // существующее

if (multiSelectMode) {
  result = GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onVerseSelect,
    child: ColoredBox(
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
          : Colors.transparent,
      child: result,
    ),
  );
}
```

В `WordTile` передавать `interactionEnabled = !multiSelectMode`. Если `false` — `onTap: null`.

---

## Г. Словари — устранение лишних ребилдов

**Текущая проблема:**
`DictionaryArticleScreen` использует `context.watch<AppState>()`, что вызывает полный ребилд при **любом** изменении глобального стейта. Виджет `Html(...)` из `flutter_html` — тяжёлый. При переходе между вкладками и возврате экран пересобирается.

**Паттерн из `home_screen.dart`** (уже работает правильно):
- `AutomaticKeepAliveClientMixin` — сохраняет состояние при уходе с вкладки
- `Selector` с `shouldRebuild` — ребилд только при изменении нужных данных
- `RepaintBoundary` — изолирует перерисовку тяжёлых виджетов

### Изменения в `dictionary_article_screen.dart`

```dart
class _DictionaryArticleScreenState extends State<DictionaryArticleScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // обязательно при AutomaticKeepAliveClientMixin

    return Focus(
      autofocus: false,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.entry.term,
              style: const TextStyle(fontFamily: 'Gentium')),
        ),
        body: Selector<AppState, ({double fontSize, bool animationsEnabled})>(
          selector: (_, s) => (
            fontSize: s.dictionaryFontSize,
            animationsEnabled: s.animationsEnabled,
          ),
          builder: (context, data, _) {
            return RepaintBoundary(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                child: Html(
                  data: cleanStrongsHtml(widget.entry.definitionHtml),
                  style: {
                    'body': Style(
                      fontSize: FontSize(data.fontSize),
                      fontFamily: 'Gentium',
                      lineHeight: LineHeight(1.7),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                    // ... остальные стили
                  },
                  // ... onLinkTap
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

### Изменения в `dictionary_screen.dart`

Для списка словарей применить аналогичный `shouldRebuild`:
```dart
Selector<AppState, (int, String)>(
  selector: (_, s) => (s.activeTab, s.themeMode),
  shouldRebuild: (prev, next) {
    if (next.$1 != 2) return false; // вкладка словарей = 2
    return prev != next;
  },
  builder: (context, _, __) => /* список словарей */,
)
```

---

## Д. Реструктуризация настроек

**Текущее состояние:**
`settings_screen.dart` — 1129 строк, один монолитный `ListView`. Регулировка шрифтов через кнопки `+/−`.

### Новая структура файлов

```
lib/features/settings/
├── view/
│   ├── settings_screen.dart          ← только список разделов
│   └── sections/
│       ├── appearance_settings.dart  ← тема, цвета, анимации
│       ├── bible_settings.dart       ← шрифт/размер/интервал Библии
│       ├── notes_settings.dart       ← шрифт/размер заметок, typewriter
│       ├── dictionary_settings.dart  ← шрифт словаря
│       └── hotkeys_settings.dart     ← роутинг к HotkeySettingsScreen
```

### Главный экран настроек (`settings_screen.dart`)

Превращается в простой список навигации:
```dart
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Внешний вид'),
            subtitle: const Text('Тема, цвета, анимации'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Шрифт Библии'),
            subtitle: const Text('Размер, межстрочный интервал, критический текст'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BibleSettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Редактор заметок'),
            subtitle: const Text('Шрифт, размер, цвет текста'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotesSettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: const Text('Словарь'),
            subtitle: const Text('Размер шрифта'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DictionarySettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('Горячие клавиши'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HotkeySettingsScreen())),
          ),
        ],
      ),
    );
  }
}
```

### Ползунки вместо кнопок +/−

Применить во всех секциях где есть числовые настройки шрифта:

```dart
// БЫЛО:
Row(children: [
  IconButton(
    icon: const Icon(Icons.remove),
    onPressed: () => state.setBibleFontSize(state.bibleFS - 1),
  ),
  Text('${state.bibleFS.toInt()}'),
  IconButton(
    icon: const Icon(Icons.add),
    onPressed: () => state.setBibleFontSize(state.bibleFS + 1),
  ),
])

// СТАЛО:
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Размер шрифта'),
        Text('${state.bibleFS.toStringAsFixed(0)} pt',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
    Slider(
      value: state.bibleFS,
      min: 10,
      max: 32,
      divisions: 22,
      label: state.bibleFS.toStringAsFixed(0),
      onChanged: (v) => state.setBibleFontSize(v),
    ),
  ],
)
```

То же самое применить для:
- `noteFontSize` (мин: 10, макс: 28)
- `noteLineHeight` (мин: 1.0, макс: 2.5, divisions: 15)
- `dictionaryFontSize` (мин: 12, макс: 28)
- `noteTitleSize`, `noteH1Size`, `noteH2Size`, `noteH3Size`

---

## Сводная таблица — что менять и где

| # | Задача | Файл | Сложность |
|---|--------|------|-----------|
| А.3 | Скрытие клавиатуры при смене вкладки | `main_shell.dart` | 🟢 2-3 строки |
| А.2 | Автоскролл к верхней трети | `note_editor_screen.dart` | 🟢 ~10 строк |
| А.1 | Тулбар вниз + объединение H-кнопок | `note_editor_screen.dart` | 🟡 ~50 строк |
| Г | Оптимизация ребилдов словаря | `dictionary_article_screen.dart`, `dictionary_screen.dart` | 🟡 ~30 строк |
| Б | Централизация тем | `core/themes.dart`, `core/app_state.dart` | 🟡 рефакторинг |
| В | Мультивыбор стихов | `home_screen.dart`, `verse_widgets.dart` | 🔴 новая фича |
| Д | Реструктуризация настроек | `settings/view/*` (новые файлы) | 🔴 большой рефакторинг |

**Рекомендуемый порядок:** А.3 → А.2 → А.1 → Г → Б → В → Д

---

## Общие Flutter best practices для этого проекта

- Использовать `Selector<AppState, T>` вместо `context.watch<AppState>()` везде где нужны только отдельные поля
- `RepaintBoundary` оборачивать тяжёлые виджеты (Html, кастомные Canvas, длинные списки)
- `AutomaticKeepAliveClientMixin` для экранов в PageView/TabView чтобы не пересоздавать состояние
- `const` конструкторы везде где возможно
- `shouldRebuild` в Selector проверять `activeTab` чтобы замораживать неактивные вкладки
- `FocusManager.instance.primaryFocus?.unfocus()` предпочтительнее `FocusScope.of(context).unfocus()` в глобальных обработчиках (не требует BuildContext)
