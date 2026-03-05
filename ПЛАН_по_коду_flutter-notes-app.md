# План улучшений — строго по коду flutter-notes-app-master

Каждый пункт привязан к конкретному файлу оригинала и конкретному файлу твоего проекта.

---

## Фича 1 — FadeRoute: плавный переход при открытии заметки

**Откуда:** `lib/components/faderoute.dart` — весь файл, 25 строк  
**Куда:** `lib/features/notes/view/notes_screen.dart` → метод `_openEditor`

### Что сейчас (твой код):
```dart
void _openEditor(NavigatorState nav, NotesProvider provider, NoteModel note) {
  nav.push(
    MaterialPageRoute(           // ← стандартный slide с правой стороны
      builder: (_) => ChangeNotifierProvider.value(...)
    ),
  );
}
```

### Что в оригинале (`faderoute.dart`):
```dart
class FadeRoute extends PageRouteBuilder {
  final Widget page;
  FadeRoute({this.page}) : super(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
```

### Как сделать у тебя:
Создать файл `lib/features/notes/view/fade_route.dart` (точная копия концепта):
```dart
class NotesFadeRoute<T> extends PageRouteBuilder<T> {
  NotesFadeRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (ctx, _, __) => builder(ctx),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
}
```

Заменить в `_openEditor`:
```dart
void _openEditor(NavigatorState nav, NotesProvider provider, NoteModel note) {
  nav.push(NotesFadeRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: NoteEditorScreen(note: note),
    ),
  ));
}
```

**Затрагиваемые файлы:** только `notes_screen.dart` + новый `fade_route.dart`

---

## Фича 2 — headerShouldHide: заголовок списка сжимается перед переходом

**Откуда:** `lib/screens/home.dart` — методы `openNoteToRead`, `buildHeaderWidget`  
**Куда:** `lib/features/notes/view/notes_screen.dart`

### Что в оригинале (home.dart):
```dart
// Состояние:
bool headerShouldHide = false;

// Виджет заголовка:
AnimatedContainer(
  duration: Duration(milliseconds: 200),
  curve: Curves.easeIn,
  width: headerShouldHide ? 0 : 200,    // ← ширина схлопывается до 0
  child: Text('Your Notes', ...),
  overflow: TextOverflow.clip,           // ← текст обрезается без переноса
  softWrap: false,
)

// Навигация с анимацией:
void openNoteToRead(NotesModel noteData) async {
  setState(() { headerShouldHide = true; });
  await Future.delayed(Duration(milliseconds: 230), () {});  // ждём анимацию
  Navigator.push(context, FadeRoute(page: ViewNotePage(...)));
  await Future.delayed(Duration(milliseconds: 300), () {});  // ждём fade in
  setState(() { headerShouldHide = false; });                // возвращаем заголовок
}
```

### Как сделать у тебя:

**В `_NotesScreenState` добавить:**
```dart
bool _headerShouldHide = false;
```

**Текущий `AppBar.title: const Text('Notes')` заменить на:**
```dart
title: AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeIn,
  width: _headerShouldHide ? 0 : 160,
  child: const Text(
    'Notes',
    overflow: TextOverflow.clip,
    softWrap: false,
  ),
),
```

**Метод `_openEditor` обновить:**
```dart
Future<void> _openEditor(NavigatorState nav, NotesProvider provider, NoteModel note) async {
  setState(() => _headerShouldHide = true);
  await Future.delayed(const Duration(milliseconds: 200));
  if (!mounted) return;
  nav.push(NotesFadeRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: NoteEditorScreen(note: note),
    ),
  ));
  await Future.delayed(const Duration(milliseconds: 300));
  if (!mounted) return;
  setState(() => _headerShouldHide = false);
}
```

Заметь: метод становится `async`, нужно обновить все 3 места вызова `_openEditor` в файле.

**Затрагиваемые файлы:** только `notes_screen.dart`

---

## Фича 3 — AnimatedContainer для кнопки «Сохранить» в редакторе

**Откуда:** `lib/screens/edit.dart` — AnimatedContainer в Stack AppBar  
**Куда:** `lib/features/notes/view/note_editor_screen.dart`

### Что в оригинале (edit.dart):
```dart
// Флаг «есть несохранённые изменения»:
bool isDirty = false;

void markTitleAsDirty(String title) => setState(() { isDirty = true; });
void markContentAsDirty(String content) => setState(() { isDirty = true; });

// Анимированная кнопка в AppBar:
AnimatedContainer(
  margin: EdgeInsets.only(left: 10),
  duration: Duration(milliseconds: 200),
  width: isDirty ? 100 : 0,        // ← выезжает когда есть изменения
  height: 42,
  curve: Curves.decelerate,
  child: RaisedButton.icon(
    icon: Icon(Icons.done),
    label: Text('SAVE'),
    onPressed: handleSave,
  ),
)
```

### Что у тебя сейчас:
Автосохранение по таймеру (800ms). Пользователь не видит, сохранено ли.

### Как сделать у тебя:

У тебя уже есть `_scheduleSave()` и `_save()`. Нужно только добавить визуальный индикатор:

**В `_NoteEditorScreenState` добавить:**
```dart
bool _isDirty = false;   // есть несохранённые изменения
bool _isSaving = false;  // сохранение в процессе
```

**В `_scheduleSave` обновить:**
```dart
void _scheduleSave() {
  setState(() => _isDirty = true);   // ← добавить
  _saveTimer?.cancel();
  _saveTimer = Timer(const Duration(milliseconds: 800), _save);
}
```

**В `_save` обновить:**
```dart
Future<void> _save() async {
  if (!mounted) return;
  setState(() { _isDirty = false; _isSaving = true; });   // ← добавить
  // ... существующий код сохранения ...
  if (mounted) setState(() => _isSaving = false);         // ← добавить
}
```

**В AppBar actions — в начало списка добавить:**
```dart
// Индикатор сохранения — выезжает справа когда есть изменения
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  curve: Curves.decelerate,
  width: _isDirty ? 80 : 0,
  height: 32,
  margin: const EdgeInsets.only(right: 4),
  child: _isDirty
      ? FilledButton.icon(
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check, size: 16),
          label: const Text('Сохр.', style: TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: _save,
        )
      : const SizedBox.shrink(),
),
```

**Затрагиваемые файлы:** только `note_editor_screen.dart`

---

## Фича 4 — BackdropFilter: размытый плавающий AppBar в редакторе

**Откуда:** `lib/screens/edit.dart` и `lib/screens/view.dart` — Stack + ClipRect + BackdropFilter  
**Куда:** `lib/features/notes/view/note_editor_screen.dart`

### Что в оригинале (edit.dart):
```dart
Scaffold(
  body: Stack(
    children: [
      ListView(children: [...]),      // ← контент под AppBar
      ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 80,
            color: Theme.of(context).canvasColor.withOpacity(0.3),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.arrow_back), onPressed: handleBack),
                  Spacer(),
                  // ... остальные кнопки ...
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
)
```
Нет `appBar:` — он убран совсем. Верхняя панель — просто `Container(height: 80)` поверх контента.

### Как сделать у тебя:

Это **самое сложное** изменение — нужно переписать Scaffold редактора. У тебя есть TabBar (полоса вкладок) — её нужно оставить.

**Заменить структуру Scaffold:**
```dart
Scaffold(
  // ← appBar: убрать полностью
  body: Stack(
    children: [
      // ── Основной контент ────────────────────────────────────
      Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 56), // отступ под AppBar
          _buildTabBar(cs),
          Expanded(
            child: _preview ? _buildPreview(cs, appState) : _buildEditor(cs, appState),
          ),
        ],
      ),
      // ── Размытая плавающая панель сверху ────────────────────
      Positioned(
        top: 0, left: 0, right: 0,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: MediaQuery.of(context).padding.top + 56,
              color: Theme.of(context).canvasColor.withOpacity(0.85),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    const Spacer(),
                    // ... все существующие IconButton из actions ...
                    AnimatedContainer(...),  // кнопка сохранения из Фичи 3
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
)
```

Нужен `import 'dart:ui'` для `ImageFilter`.

**Затрагиваемые файлы:** только `note_editor_screen.dart`

---

## Фича 5 — AnimatedOpacity: заголовок и дата плавно появляются при открытии заметки

**Откуда:** `lib/screens/view.dart` — `headerShouldShow` + `AnimatedOpacity`  
**Куда:** `lib/features/notes/view/note_editor_screen.dart`

### Что в оригинале (view.dart):
```dart
bool headerShouldShow = false;

@override
void initState() {
  super.initState();
  // Запускаем через 100ms после initState
  Future.delayed(Duration(milliseconds: 100), () {
    setState(() { headerShouldShow = true; });
  });
}

// Заголовок:
AnimatedOpacity(
  opacity: headerShouldShow ? 1 : 0,
  duration: Duration(milliseconds: 200),
  curve: Curves.easeIn,
  child: Text(note.title, style: TextStyle(fontSize: 36, ...)),
)

// Дата (дольше):
AnimatedOpacity(
  duration: Duration(milliseconds: 500),   // ← медленнее чем заголовок
  opacity: headerShouldShow ? 1 : 0,
  child: Text(DateFormat...),
)
```

### Как сделать у тебя:

**В `_NoteEditorScreenState` добавить:**
```dart
bool _contentVisible = false;

@override
void initState() {
  super.initState();
  _addTab(widget.note);
  _activeTabIdx = 0;
  _attachListeners();
  // ← добавить:
  Future.delayed(const Duration(milliseconds: 120), () {
    if (mounted) setState(() => _contentVisible = true);
  });
}
```

**Обернуть `_buildTabBar` и контент-область:**
```dart
AnimatedOpacity(
  opacity: _contentVisible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeIn,
  child: Column(
    children: [
      _buildTabBar(cs),
      Expanded(child: _preview ? _buildPreview(...) : _buildEditor(...)),
    ],
  ),
)
```

**Затрагиваемые файлы:** только `note_editor_screen.dart`

---

## Фича 6 — Цветной BoxShadow на карточках заметок

**Откуда:** `lib/components/cards.dart` — `buildBoxShadow`, `colorList`  
**Куда:** `lib/features/notes/view/notes_screen.dart`

### Что в оригинале (cards.dart):
```dart
List<Color> colorList = [
  Colors.blue, Colors.green, Colors.indigo, Colors.red,
  Colors.cyan, Colors.teal, Colors.amber.shade900, Colors.deepOrange
];

// Детерминированный цвет по длине заголовка:
Color color = colorList.elementAt(noteData.title.length % colorList.length);

// BoxShadow меняется для тёмной/светлой темы:
BoxShadow buildBoxShadow(Color color, BuildContext context) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return BoxShadow(
        color: Colors.black.withAlpha(100),
        blurRadius: 8, offset: Offset(0, 8));
  }
  return BoxShadow(
      color: color.withAlpha(25),   // ← light: цвет заметки
      blurRadius: 8, offset: Offset(0, 8));
}
```

### Как сделать у тебя:

У тебя карточки — `ListTile` без внешнего `Container`. Добавить обёртку с тенью:

**Добавить в `_NotesScreenState` (константа):**
```dart
static const _noteAccentColors = [
  Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFF3F51B5), Color(0xFFF44336),
  Color(0xFF00BCD4), Color(0xFF009688), Color(0xFFE65100), Color(0xFFFF5722),
];

Color _accentForNote(NoteModel note) =>
    _noteAccentColors[note.title.length % _noteAccentColors.length];
```

**Обернуть `ListTile` в карточку с тенью:**
```dart
// Вместо голого ListTile:
Builder(builder: (ctx) {
  final color = _accentForNote(note);
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(ctx).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withAlpha(60)
              : color.withAlpha(30),        // ← цвет по заголовку
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        splashColor: color.withAlpha(20),
        highlightColor: color.withAlpha(10),
        onTap: () => _openEditor(Navigator.of(context), provider, note),
        onLongPress: () => _showNoteOptions(note),
        child: _existingListTile,   // ← вставить текущий ListTile без onTap/onLongPress
      ),
    ),
  );
})
```

**Затрагиваемые файлы:** только `notes_screen.dart`

---

## Фича 7 — AnimatedCrossFade для индикатора «поиск активен»

**Откуда:** `lib/screens/home.dart` — `buildImportantIndicatorText()`  
**Куда:** `lib/features/notes/view/notes_screen.dart`

### Что в оригинале (home.dart):
```dart
Widget buildImportantIndicatorText() {
  return AnimatedCrossFade(
    duration: Duration(milliseconds: 200),
    firstChild: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text('Only showing notes marked important'.toUpperCase(),
          style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500)),
    ),
    secondChild: Container(height: 2),  // ← «пустое» состояние
    crossFadeState: isFlagOn
        ? CrossFadeState.showFirst
        : CrossFadeState.showSecond,
  );
}
```

### Как сделать у тебя:

Сейчас поиск фильтрует список, но нет индикатора что фильтр активен. Добавить под `AppBar` перед списком заметок:

```dart
// В build(), перед ListView со списком заметок:
AnimatedCrossFade(
  duration: const Duration(milliseconds: 200),
  firstChild: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: cs.secondaryContainer.withValues(alpha: 0.5),
    child: Row(children: [
      Icon(Icons.search, size: 14, color: cs.secondary),
      const SizedBox(width: 6),
      Text(
        'Поиск: «${_searchCtrl.text}»  ·  ${notes.length} результатов',
        style: TextStyle(fontSize: 12, color: cs.secondary),
      ),
      const Spacer(),
      GestureDetector(
        onTap: () { _searchCtrl.clear(); setState(() {}); },
        child: Icon(Icons.close, size: 14, color: cs.secondary),
      ),
    ]),
  ),
  secondChild: const SizedBox(height: 0),
  crossFadeState: _searchCtrl.text.isNotEmpty
      ? CrossFadeState.showFirst
      : CrossFadeState.showSecond,
),
```

**Затрагиваемые файлы:** только `notes_screen.dart`

---

## Фича 8 — InputDecoration.collapsed в полях редактора

**Откуда:** `lib/screens/edit.dart` — оба `TextField`  
**Куда:** `lib/features/notes/view/note_editor_screen.dart`

### Что в оригинале (edit.dart):
```dart
TextField(
  decoration: InputDecoration.collapsed(   // ← убирает ВСЕ декорации
    hintText: 'Enter a title',
    hintStyle: TextStyle(color: Colors.grey.shade400, ...),
    border: InputBorder.none,
  ),
)
```

`InputDecoration.collapsed` убирает подчёркивание, border, contentPadding — чище чем `InputDecoration(border: InputBorder.none)`.

### Что у тебя сейчас:
```dart
decoration: InputDecoration(
  hintText: 'Название заметки',
  border: InputBorder.none,
  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
),
```

### Как сделать у тебя:

**Заменить для поля заголовка:**
```dart
decoration: InputDecoration.collapsed(
  hintText: 'Название заметки',
  hintStyle: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: cs.onSurface.withValues(alpha: 0.35),
  ),
),
```

**Для поля контента** (внутри `_AutoListTextField` — там `decoration` передаётся снаружи):
```dart
decoration: InputDecoration.collapsed(
  hintText: 'Содержание (Markdown)…',
  hintStyle: TextStyle(
    color: cs.onSurface.withValues(alpha: 0.35),
  ),
),
```

Разница незначительная визуально, но убирает padding-артефакты и лишние размеры.

**Затрагиваемые файлы:** только `note_editor_screen.dart`

---

## Приоритеты реализации

```
Быстро и видно (по 30-60 мин каждая):
  1. Фича 1  — FadeRoute             (1 новый файл + 1 правка)
  2. Фича 7  — AnimatedCrossFade     (1 блок кода в notes_screen)
  3. Фича 8  — InputDecoration       (2 строки в note_editor_screen)
  4. Фича 5  — AnimatedOpacity       (3 строки + обёртка)

Средние по сложности:
  5. Фича 3  — AnimatedContainer Save (добавить флаги + 1 виджет в AppBar)
  6. Фича 2  — headerShouldHide      (async _openEditor + AnimatedContainer)
  7. Фича 6  — BoxShadow карточки    (обернуть ListTile)

Сложное:
  8. Фича 4  — BackdropFilter AppBar  (переписать Scaffold, нужна аккуратность
                                       с отступами и SafeArea)
```

---

## Что из оригинала НЕ подходит тебе

- **Dismissible (свайп для удаления)** — ты сам правильно отметил: сломает горизонтальный свайп между вкладками.
- **CupertinoPageRoute для настроек** — у тебя своя навигация через вложенные Navigator, не нужно.
- **`colorList` по length % length без seed** — у тебя заголовки на русском/греческом, длина непредсказуема. Лучше взять первые 2 байта `note.id` как seed для детерминированного цвета.
- **Архитектура без провайдеров** — у них `setState` напрямую и `NotesDatabaseService.db` глобальный синглтон. У тебя правильнее.
