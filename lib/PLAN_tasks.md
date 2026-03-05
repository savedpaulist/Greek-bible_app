# План доработок — lib_24

> Дата: март 2026  
> Статус: к исполнению

---

## Содержание

1. [A1 — Заметки-теги: правильная папка «Теги»](#a1)
2. [A2 — Long-press на стихе: последние 5 тегов + выпадающий список](#a2)
3. [B1 — Bottom bar: правильный z-index (ниже попапов)](#b1)
4. [B2 — Масштаб интерфейса: настройка 90–200%](#b2)
5. [Зависимости и порядок реализации](#order)
6. [Контрольный список рисков](#risks)

---

## A1 — Заметки-теги: правильная папка «Теги» {#a1}

### Проблема
`_appendVerseToTagNote` в `home_screen.dart` создаёт новую заметку с `folderId` папки «Теги», но **если заметка уже существует** (нашлась через `findNoteByTitle`), она обновляется без изменения `folderId`. В результате существующие заметки-теги остаются в той папке, где они были, а не в «Теги».

### Затронутые файлы

| Файл | Строки |
|------|--------|
| `lib/features/home/view/home_screen.dart` | ~1137–1152 (`_appendVerseToTagNote`) |

### Изменения

**`_appendVerseToTagNote` — блок `else` (обновление существующей заметки):**

```dart
// БЫЛО:
} else {
  if (!tagNote.content.contains('[[$ref]]')) {
    final updated = tagNote.copyWith(
      content: '${tagNote.content}\n$quoteBlock',
      updatedAt: DateTime.now(),
    );
    await notes.updateNote(updated);
  }
}

// СТАЛО:
} else {
  // Убедиться, что заметка находится в папке «Теги»
  NoteModel noteToUpdate = tagNote;
  if (tagNote.folderId != folderId) {
    noteToUpdate = tagNote.copyWith(folderId: folderId, updatedAt: DateTime.now());
  }
  if (!tagNote.content.contains('[[$ref]]')) {
    noteToUpdate = noteToUpdate.copyWith(
      content: '${noteToUpdate.content}\n$quoteBlock',
      updatedAt: DateTime.now(),
    );
  }
  if (noteToUpdate != tagNote) {
    await notes.updateNote(noteToUpdate);
  }
}
```

> **Примечание о `copyWith`:** `NoteModel.copyWith` в текущей реализации не принимает `folderId` как nullable-изменяемое значение (нет `Object? folderId = _sentinel`). Нужно убедиться, что метод поддерживает явную передачу `folderId`.

### Проверка `NoteModel.copyWith`

В `note_model.dart` текущий `copyWith`:
```dart
NoteModel copyWith({String? folderId, ...})
```
Передаётся как `folderId ?? this.folderId`. Это означает, что передать `null` нельзя. Но для задачи A1 нам нужно передать новый `folderId`, а не `null`, поэтому достаточно существующей сигнатуры.

---

## A2 — Long-press на стихе: последние 5 тегов + выпадающий список {#a2}

### Проблема
`_verseTagsRow` показывает **все** теги (`for (final tag in allTags)`). При большом количестве тегов это захламляет UI. Нужно:
- Показывать только **последние 5 использованных** тегов
- Остальные — в выпадающем меню (кнопка «+N ещё»)

### Что значит «последние использованные»
«Последние 5» = теги, к которым последний раз добавлялся стих (в порядке по времени применения). Это **не** «последние созданные», а **последние применённые к стихам**.

### Затронутые файлы

| Файл | Изменения |
|------|-----------|
| `lib/features/notes/provider/notes_provider.dart` | Добавить `recentTagIds`, `markTagUsed()` |
| `lib/core/prefs/prefs_service.dart` | Хранение `recent_tag_ids` |
| `lib/features/home/view/home_screen.dart` | Рефакторинг `_verseTagsRow` |

### Шаг 1 — `PrefsService`

Добавить в `prefs_service.dart`:

```dart
static const _kRecentTagIds = 'recent_tag_ids';

List<String> get recentTagIds {
  final raw = _p.getString(_kRecentTagIds);
  if (raw == null) return [];
  return List<String>.from(json.decode(raw) as List);
}

Future<void> setRecentTagIds(List<String> ids) =>
    _p.setString(_kRecentTagIds, json.encode(ids));
```

### Шаг 2 — `NotesProvider`

Добавить поле и метод:

```dart
// Поле (инициализируется из prefs при load())
List<String> _recentTagIds = [];
List<String> get recentTagIds => List.unmodifiable(_recentTagIds);

/// Отметить тег как «только что использованный».
/// Перемещает tagId в начало списка, обрезает до 5.
Future<void> markTagUsed(String tagId) async {
  _recentTagIds.removeWhere((id) => id == tagId);
  _recentTagIds.insert(0, tagId);
  if (_recentTagIds.length > 5) {
    _recentTagIds = _recentTagIds.sublist(0, 5);
  }
  await _prefs.setRecentTagIds(_recentTagIds); // _prefs — PrefsService
  notifyListeners();
}
```

В методе `load()` добавить:
```dart
_recentTagIds = _prefs.recentTagIds;
```

> **Зависимость:** `NotesProvider` должен иметь доступ к `PrefsService`. Проверить, передаётся ли он в конструкторе. Если нет — добавить.

### Шаг 3 — `_verseTagsRow` в `home_screen.dart`

**Логика разбиения тегов:**
```dart
// Получить все теги
final allTags = notes.tags; // List<NoteTag>

// Получить ID последних 5 использованных
final recentIds = notes.recentTagIds; // List<String> (max 5)

// Отсортировать: сначала recent (в порядке recent), остальные — после
final recentTags = recentIds
    .map((id) => allTags.where((t) => t.id == id).firstOrNull)
    .whereNotNull()
    .toList();

final otherTags = allTags
    .where((t) => !recentIds.contains(t.id))
    .toList();

// Показываем recentTags (<=5) + кнопку «+N» если otherTags не пустой
```

**Новый виджет тега** — вынести в отдельный builder-метод `_tagChip(tag, isApplied, onTap)`.

**Кнопка «+N ещё»:**
```dart
if (otherTags.isNotEmpty)
  GestureDetector(
    onTap: () => _showAllTagsDropdown(context, otherTags, appliedIds, ...),
    child: Container(
      // styling: rounded border, «+N» text
      child: Text('+${otherTags.length}'),
    ),
  ),
```

**`_showAllTagsDropdown`** — использовать `showMenu` (PopupMenu) или `showModalBottomSheet` с компактным списком всех оставшихся тегов. Рекомендуется `showMenu` для нативного dropdown-поведения:

```dart
void _showAllTagsDropdown(
  BuildContext context,
  List<NoteTag> tags,
  Set<String> appliedIds,
  List<VerseTag> applied,
  VerseModel verse,
  AppState state,
  NotesProvider notes,
  BuildContext dialogCtx,
) {
  final RenderBox box = context.findRenderObject() as RenderBox;
  final offset = box.localToGlobal(Offset.zero);
  showMenu<NoteTag>(
    context: context,
    useRootNavigator: true,
    position: RelativeRect.fromLTRB(
      offset.dx, offset.dy - 8,
      offset.dx + box.size.width,
      offset.dy,
    ),
    items: [
      for (final tag in tags)
        PopupMenuItem<NoteTag>(
          value: tag,
          child: Row(children: [
            Icon(Icons.sell, size: 14, color: Color(tag.colorValue)),
            SizedBox(width: 6),
            Text(tag.name),
            if (appliedIds.contains(tag.id)) ...[
              Spacer(),
              Icon(Icons.check, size: 14),
            ],
          ]),
        ),
    ],
  ).then((tag) async {
    if (tag == null) return;
    // Тот же toggle-код, что и в основном _verseTagsRow
    await _toggleVerseTag(tag, applied, appliedIds, verse, state, notes);
    if (dialogCtx.mounted) (dialogCtx as Element).markNeedsBuild();
    _reloadIndicators();
  });
}
```

**Вызов `markTagUsed` при применении тега:**
В блоке «Add tag to verse» добавить:
```dart
await notes.markTagUsed(tag.id);
```

---

## B1 — Bottom bar: правильный z-index {#b1}

### Диагноз

`MainShell` использует `Scaffold.bottomNavigationBar`. Все 3 таба обёрнуты в `_TabNavigator`, который создаёт **вложенный `Navigator`**. Модальные окна, вызываемые без `useRootNavigator: true`, попадают в оверлей вложенного навигатора — **внутри** `Scaffold.body`. А `bottomNavigationBar` рендерится Scaffold-ом **поверх** body.

### Иерархия отрисовки (текущая)

```
MaterialApp Navigator Overlay           ← useRootNavigator:true → поверх всего
  └─ MainShell Scaffold
       ├─ bottomNavigationBar           ← поверх body
       └─ body (PageView)
            └─ _TabNavigator (nested Navigator)
                 └─ nested Overlay      ← модалки без useRootNavigator → под баром ✗
```

### Решение: `useRootNavigator: true` везде

Самое чистое и безопасное решение — добавить `useRootNavigator: true` ко всем вызовам `showModalBottomSheet` и `showDialog` во всём приложении. После этого все модалки попадают в оверлей MaterialApp, который находится **над** `Scaffold.bottomNavigationBar`.

#### Аудит файлов

| Файл | Метод | Текущее состояние |
|------|-------|-------------------|
| `home_screen.dart` | `showGeneralDialog` в `_showVerseMenu` | нет `useRootNavigator` |
| `home_screen.dart` | `showModalBottomSheet` в `_showTagManager` | нет |
| `home_screen.dart` | `showModalBottomSheet` в `_showShareBottomSheet` | нет |
| `home_screen.dart` | `showDialog` в `_showColorPickerForWord` | нет |
| `home_screen.dart` | `showDialog` в `_confirmDeleteMarkup` | нет |
| `home_screen.dart` | `showModalBottomSheet` в `_TagManagerSheet` | нет |
| `notes_screen.dart` | все `showModalBottomSheet` / `showDialog` | часть есть |
| `note_editor_screen.dart` | все `showModalBottomSheet` / `showDialog` | часть есть |
| `comment_sheets.dart` | `showModalBottomSheet` | нет |
| `settings_screen.dart` | нет модалок, только push → OK | — |

#### Изменение для `showGeneralDialog`

У `showGeneralDialog` нет параметра `useRootNavigator`. Вместо него нужно передать `context` от корневого навигатора:

```dart
// Получить root context
final rootCtx = Navigator.of(context, rootNavigator: true).context;
showGeneralDialog(
  context: rootCtx, // ← использовать root context
  ...
);
```

Или оставить как есть и использовать `Builder` в `MaterialApp` для проброса контекста. Рекомендуется первый вариант.

### Дополнительная мера: `extendBody`

В `main_shell.dart` стоит `extendBody: true`. Это позволяет контенту уходить под бар. При этом `Scaffold` создаёт `_ScaffoldLayout`, в котором `bottomNavigationBar` позиционируется **над** body.

С `useRootNavigator: true` это уже не проблема. Но для полноты: 
- `extendBody: true` — оставить (нужно для красивого полупрозрачного бара с градиентом).
- Добавить `SafeArea` или `padding` нижней части у контента в HomeScreen если надо.

### Порядок правок

1. `home_screen.dart` — исправить `_showVerseMenu` (root context для `showGeneralDialog`)
2. `home_screen.dart` — добавить `useRootNavigator: true` во все `showModalBottomSheet` / `showDialog`
3. `notes_screen.dart` — проверить и добавить там, где отсутствует
4. `note_editor_screen.dart` — то же
5. `comment_sheets.dart` — то же
6. Прочие модульные файлы — проверить grep: `grep -rn "showModalBottomSheet\|showDialog" lib/ | grep -v "useRootNavigator: true"`

---

## B2 — Масштаб интерфейса: настройка 90–200% {#b2}

### Архитектура

Использовать **`Transform.scale` + переопределение `MediaQuery.size`** на уровне `MaterialApp.builder`. Это единственный способ масштабировать **всё** (отступы, иконки, текст, виджеты) без правки каждого файла.

Принцип:
1. Сообщаем дочерним виджетам, что экран меньше в `scale` раз → они рендерят уменьшенный контент
2. Масштабируем (`Transform.scale`) обратно до реального размера экрана
3. В итоге всё выглядит увеличенным в `scale` раз при масштабе > 1.0

```
Реальный экран: 390×844
scale = 1.3 (130%)
Виджеты думают, что экран: 300×649
Transform.scale(1.3) → возвращает к 390×844
Результат: всё на 30% крупнее
```

### Затронутые файлы

| Файл | Изменения |
|------|-----------|
| `lib/core/prefs/prefs_service.dart` | Добавить `uiScale` |
| `lib/core/app_state.dart` | Добавить `uiScale`, `setUiScale()` |
| `lib/main.dart` | `MaterialApp.builder` с `UiScaleWrapper` |
| `lib/features/settings/view/sections/appearance_settings.dart` | Секция «Масштаб» |

### Шаг 1 — `PrefsService`

```dart
static const _kUiScale = 'ui_scale';

double get uiScale => _p.getDouble(_kUiScale) ?? 1.0;
Future<void> setUiScale(double v) => _p.setDouble(_kUiScale, v.clamp(0.9, 2.0));
```

### Шаг 2 — `AppState`

```dart
// Поле
double uiScale = 1.0;

// В initialize():
uiScale = prefs.uiScale;

// Метод:
Future<void> setUiScale(double v) async {
  uiScale = v.clamp(0.9, 2.0);
  await prefs.setUiScale(uiScale);
  notifyListeners();
}
```

### Шаг 3 — `UiScaleWrapper` виджет (новый файл `lib/ui/ui_scale_wrapper.dart`)

```dart
import 'package:flutter/material.dart';

/// Масштабирует всё дочернее дерево без ущерба для touch events.
class UiScaleWrapper extends StatelessWidget {
  final double scale;
  final Widget child;

  const UiScaleWrapper({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    if (scale == 1.0) return child;

    final mq = MediaQuery.of(context);
    final scaledSize = Size(
      mq.size.width / scale,
      mq.size.height / scale,
    );

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: scaledSize.width,
        maxWidth: scaledSize.width,
        minHeight: scaledSize.height,
        maxHeight: scaledSize.height,
        child: MediaQuery(
          data: mq.copyWith(
            size: scaledSize,
            // Сбросить textScaler чтобы не двойное масштабирование
            textScaler: TextScaler.noScaling,
            // Масштабировать padding (notch, home bar) обратно
            padding: mq.padding / scale,
            viewPadding: mq.viewPadding / scale,
            viewInsets: mq.viewInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
```

> **Важно:** `OverflowBox` нужен, чтобы вложенный виджет «думал», что у него размер `scaledSize`, а не ограничивался реальным размером. Иначе возникнут layout overflow.

### Шаг 4 — `main.dart`

В `MaterialApp` или `MaterialApp.router` добавить `builder`:

```dart
MaterialApp(
  // ...
  builder: (context, child) {
    return Consumer<AppState>(
      builder: (ctx, state, _) => UiScaleWrapper(
        scale: state.uiScale,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  },
)
```

> **Порядок важен:** `builder` вызывается до `home`/`routes`, после инициализации Provider.

### Шаг 5 — UI в настройках (`appearance_settings.dart`)

Добавить новую секцию **перед** секцией «Тема оформления» или отдельным блоком:

```dart
const SectionHeader('Масштаб интерфейса'),

// Текущее значение и сброс
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
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
      if (state.uiScale != 1.0)
        TextButton(
          onPressed: () => state.setUiScale(1.0),
          child: const Text('Сбросить'),
        ),
    ],
  ),
),

// Слайдер
Slider(
  value: state.uiScale,
  min: 0.9,
  max: 2.0,
  divisions: 22,  // шаг 5%: (2.0 - 0.9) / 0.05 = 22
  label: '${(state.uiScale * 100).round()}%',
  onChanged: (v) => state.setUiScale(v),
),

// Подсказка для пользователя
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('90%', style: TextStyle(fontSize: 12, color: cs.secondary)),
      Text('По умолчанию: 100%', style: TextStyle(fontSize: 12, color: cs.secondary)),
      Text('200%', style: TextStyle(fontSize: 12, color: cs.secondary)),
    ],
  ),
),

// Предупреждение о перезапуске не нужно — изменение мгновенное
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  child: Text(
    'Масштабирует весь интерфейс. Изменение применяется мгновенно.',
    style: TextStyle(fontSize: 12, color: cs.secondary),
  ),
),
```

### Потенциальные проблемы масштабирования и решения

| Проблема | Решение |
|----------|---------|
| Keyboard insets не масштабируются | `MediaQuery.viewInsets / scale` ✓ (уже в шаге 3) |
| SafeArea padding двоится | `mq.padding / scale` ✓ (уже в шаге 3) |
| `showModalBottomSheet` и `showDialog` показываются в немасштабированном контексте | Если используют `useRootNavigator: true` (задача B1), то контекст уже масштабирован через MaterialApp.builder ✓ |
| Overlay записи (OverlayEntry в NoteEditor) | Работают корректно, т.к. Overlay находится внутри масштабированного дерева |
| `Transform.scale` с `Alignment.topLeft` — контент уходит вправо/вниз при > 1.0 | Это норма для больших экранов. Если нужно центрирование — изменить `alignment: Alignment.topCenter` |
| Анимации и hero-переходы | Работают корректно |

---

## Зависимости и порядок реализации {#order}

```
A1 (простая правка, изолирована)
  ↓
A2 (требует изменений в NotesProvider + PrefsService)
  ↓
B1 (правки во многих файлах, добавить useRootNavigator: true)
  ↓
B2 (требует AppState + PrefsService + main.dart + settings UI)
```

**Рекомендуемый порядок реализации:**

1. **A1** — 1 файл, 10 строк, нулевой риск
2. **B1 (диагностика)** — сначала запустить grep и составить полный список всех модалок
3. **B1 (правки)** — добавить `useRootNavigator: true` / root context
4. **A2** — добавить `recentTagIds` в Provider + префы, рефакторинг `_verseTagsRow`
5. **B2** — `UiScaleWrapper`, AppState, prefs, settings UI

---

## Контрольный список рисков {#risks}

### A1
- [ ] `NoteModel.copyWith` поддерживает явную передачу `folderId` (не null) — ✅ поддерживает
- [ ] `updateNote` в `NotesProvider` обновляет `folderId` в БД — проверить SQL

### A2
- [ ] `NotesProvider` имеет доступ к `PrefsService` — если нет, добавить в конструктор
- [ ] При первом запуске `recentTagIds` пустой → показываем все теги в порядке `allTags` (первые 5)
- [ ] `showMenu` корректно работает с `useRootNavigator: true` — проверить
- [ ] При удалении тега из `NotesProvider.tags` — очистить его из `recentTagIds`

### B1
- [ ] `showGeneralDialog` не имеет `useRootNavigator` — использовать root context
- [ ] Все `BottomSheet`-и с state callbacks (например `onChanged`) работают когда используют root navigator
- [ ] `_TagManagerSheet` не теряет `context.read<NotesProvider>()` при root navigator
- [ ] Тест: открыть любой bottom sheet на Bible экране → он должен покрывать bottom bar

### B2
- [ ] При scale > 1.3 на маленьком экране контент может обрезаться по правому краю — добавить горизонтальный scroll или ограничить max scale для маленьких экранов
- [ ] `MediaQuery.viewInsets` для клавиатуры масштабируется — протестировать на реальном устройстве
- [ ] `SelectableText` и `TextField` в note editor корректно работают при scale ≠ 1.0
- [ ] Тест: scale 150% → открыть настройки → scale вернуть к 100% → всё должно работать без hot restart
- [ ] В `Consumer<AppState>` в `builder` — убедиться, что `AppState` инициализирован до `MaterialApp.builder`
- [ ] `OverflowBox` в сочетании с `PageView` — проверить что свайп работает
- [ ] Bottom safe area (home indicator на iPhone) корректно масштабируется

---

## Файловая карта изменений

```
lib/
├── main.dart                                           ← B2: добавить builder с UiScaleWrapper
├── ui/
│   ├── main_shell.dart                                 ← B1: root context для showGeneralDialog
│   └── ui_scale_wrapper.dart                           ← B2: НОВЫЙ ФАЙЛ
├── core/
│   ├── app_state.dart                                  ← B2: uiScale, setUiScale()
│   └── prefs/
│       └── prefs_service.dart                          ← A2: recentTagIds | B2: uiScale
├── features/
│   ├── home/
│   │   └── view/
│   │       └── home_screen.dart                        ← A1, A2, B1
│   ├── notes/
│   │   ├── provider/
│   │   │   └── notes_provider.dart                     ← A2: recentTagIds, markTagUsed()
│   │   └── view/
│   │       ├── notes_screen.dart                       ← B1: useRootNavigator
│   │       └── note_editor_screen.dart                 ← B1: useRootNavigator
│   └── settings/
│       └── view/
│           └── sections/
│               └── appearance_settings.dart            ← B2: слайдер масштаба
```

**Итого файлов:** 9 (из них 1 новый)

---

*Конец плана*
