// lib/core/l10n/strings_ru.dart

import 'app_strings.dart';

class RuStrings implements AppStrings {
  const RuStrings();

  // ── General ───────────────────────────────────────────────────────────────
  @override String get appTitle => 'Греческая Библия';
  @override String get cancel => 'Отмена';
  @override String get apply => 'Применить';
  @override String get save => 'Сохранить';
  @override String get create => 'Создать';
  @override String get delete => 'Удалить';
  @override String get reset => 'Сбросить';
  @override String get retry => 'Повторить';
  @override String get close => 'Закрыть';
  @override String get edit => 'Редактировать';
  @override String get done => 'Готово';
  @override String get search => 'Поиск';
  @override String get error => 'Ошибка';
  @override String errorMsg(String e) => 'Ошибка: $e';

  // ── Tabs / Navigation ─────────────────────────────────────────────────────
  @override String get tabNotes => 'Заметки';
  @override String get tabBible => 'Библия';
  @override String get tabDictionaries => 'Словари';
  @override String get back => 'Назад';
  @override String get forward => 'Вперёд';

  // ── Setup screen ──────────────────────────────────────────────────────────
  @override String get setupPreparing => 'Подготовка…';
  @override String get setupTitle => 'Греческая Библия';
  @override String get setupSubtitle => 'Подготовка приложения';
  @override String get setupStorageTitle => 'Где хранить данные?';
  @override String get setupStorageSubtitle => 'Словари занимают ~1 ГБ.\nВыберите место хранения:';
  @override String get setupExtracting => 'Распаковка баз данных…';
  @override String get setupIndexing => 'Индексация для поиска…';
  @override String get setupIndexOnce => 'Это нужно сделать один раз…';
  @override String get setupDone => 'Всё готово!';
  @override String setupExtractError(String e) => 'Ошибка распаковки: $e';
  @override String get stepExtraction => 'Распаковка';
  @override String get stepIndexing => 'Индексация';

  // ── Settings ──────────────────────────────────────────────────────────────
  @override String get settings => 'Настройки';
  @override String get appearance => 'Внешний вид';
  @override String get appearanceSubtitle => 'Тема, цвета, анимации';
  @override String get bibleFont => 'Шрифт Библии';
  @override String get noteEditor => 'Редактор заметок';
  @override String get noteEditorSubtitle => 'Шрифт, размер, цвет текста';
  @override String get dictionary => 'Словарь';
  @override String get dictionaryFontSize => 'Размер шрифта';
  @override String get hotkeys => 'Горячие клавиши';
  @override String get searchHistory => 'История поиска';
  @override String searchHistoryLimit(int n) => 'Макс. $n записей';
  @override String get clearHistory => 'Очистить историю';
  @override String get historyCleared => 'История очищена';
  @override String get fulltextSearch => 'Полнотекстовый поиск по словам';
  // ── Appearance settings ───────────────────────────────────────────────────
  @override String get uiScale => 'Масштаб интерфейса';
  @override String get uiScaleDefault => 'По умолчанию: 100%';
  @override String get palette => 'Палитра';
  @override String get brightness => 'Яркость';
  @override String get brightLight => 'Светлая';
  @override String get brightDark => 'Тёмная';
  @override String get brightSystem => 'Системная';
  @override String get brightSchedule => 'Расписание';
  @override String get scheduleFrom => 'Светлая с ';
  @override String get scheduleTo => ' до ';
  @override String customizeColors(String mode) => 'Настроить цвета ($mode)';
  @override String get resetColors => 'Сбросить цвета к умолчанию';
  @override String get colorsReset => 'Цвета сброшены';
  @override String get bibleSegmentColors => 'Цвета сегментов Библии';
  @override String get resetSegmentColors => 'Сбросить цвета сегментов';
  @override String get segmentColorsReset => 'Цвета сегментов сброшены';
  @override String get animations => 'Анимации';
  @override String get animationsSubtitle => 'Переходы между экранами, прокрутка, мигание слов';

  // ── Bible settings ────────────────────────────────────────────────────────
  @override String get preview => 'Предпросмотр';
  @override String get bibleText => 'Текст Библии';
  @override String get smallPopup => 'Малый попап';
  @override String get largePopup => 'Большой попап';
  @override String get searchLabel => 'Поиск';
  @override String get versePreview => 'Просмотр стиха';
  @override String get criticalText => 'Критический текст';
  @override String get menuBookChapter => 'Меню (книга/глава)';
  @override String get lineSpacing => 'Интервал';
  @override String get verseNumbers => 'Номера стихов';
  @override String get criticalTextLabel => 'Критический текст';
  @override String get criticalTextSubtitle => 'Аппарат NA27/UBS4/Byzantine';
  @override String get copyMode => 'Режим копирования';

  // ── Notes settings ────────────────────────────────────────────────────────
  @override String get fontSettings => 'Настройки шрифта';
  @override String get fontSettingsSubtitle => 'Шрифт, размер, цвет текста';
  @override String get textSize => 'Размер текста';
  @override String get lineHeight => 'Межстрочный интервал';
  @override String get noteTitle => 'Заголовок заметки';

  // ── Dictionary settings ───────────────────────────────────────────────────
  @override String get fontSize => 'Размер шрифта';

  // ── Home screen ───────────────────────────────────────────────────────────
  @override String copiedVerse(int ch, int v) => 'Скопировано: $ch:$v';
  @override String get noParallelVerses => 'Нет параллельных стихов';
  @override String get parallelVerseAdded => 'Параллельный стих добавлен';
  @override String commentFor(int ch, int v) => 'Комментарий к $ch:$v';
  @override String get noComments => 'Нет комментариев';
  @override String get editComment => 'Редактировать комментарий';
  @override String get enterComment => 'Введите комментарий…';
  @override String get verseBackgroundColor => 'Цвет фона стиха';
  @override String get createTag => 'Создать тег';
  @override String deleteTagConfirm(String name) => 'Тег «$name» и все его привязки будут удалены.';
  @override String get manageTags => 'Управление тегами';
  @override String get tagName => 'Название тега';

  // ── Search screen ─────────────────────────────────────────────────────────
  @override String get indexStillBuilding => 'Индекс ещё строится. Попробуйте позже.';
  @override String get stopSearch => 'Остановить';
  @override String get nothingFound => 'Ничего не найдено';
  @override String get enterQuery => 'Введите запрос';
  @override String get searchHistoryTitle => 'История поиска';
  @override String get clear => 'Очистить';
  @override String get addCondition => 'Ещё условие';
  @override String get findInVerse => 'Найти (в одном стихе)';
  @override String get dictionaries => 'Словари';
  @override String get word => 'Слово';

  // ── Notes screen ──────────────────────────────────────────────────────────
  @override String get chooseTemplate => 'Выберите шаблон';
  @override String get newFolder => 'Новая папка';
  @override String get folderName => 'Название папки';
  @override String get renameFolder => 'Переименовать папку';
  @override String get deleteFolderConfirm => 'Удалить папку?';
  @override String get deleteFolderSubtitle => 'Заметки из папки будут перемещены в «Без папки».';
  @override String get folders => 'Папки';
  @override String get newNote => 'Новая заметка';
  @override String get searchNotes => 'Поиск заметок…';
  @override String get pullDownToCreate => 'Потяните вниз для создания';
  @override String get untitled => 'Без названия';
  @override String get note => 'Заметка';
  @override String get share => 'Поделиться';
  @override String get moveToFolder => 'Переместить в папку';
  @override String get noFolder => 'Без папки';
  @override String deleteNoteConfirm(String title) => 'Заметка «$title» будет удалена безвозвратно.';
  @override String get noteDeleted => 'Заметка удалена';
  @override String get folderColor => 'Цвет папки';

  // ── Note editor ───────────────────────────────────────────────────────────
  @override String linkNotFound(String text) => 'Не удалось распознать ссылку: $text';
  @override String noteNotFound(String title) => 'Заметка «$title» не найдена';
  @override String get noOtherNotes => 'Нет других заметок для ссылки';
  @override String get noteLink => 'Ссылка на заметку';
  @override String get exportError => 'Ошибка экспорта';
  @override String get openNote => 'Открыть заметку';
  @override String get alreadyOpen => 'Уже открыта';
  @override String get saved => 'Сохр.';
  @override String get insertVerseLink => 'Вставить ссылку на стих';
  @override String get noteLinkInsert => 'Ссылка на заметку';
  @override String get exportMd => 'Экспорт .md';
  @override String get noteName => 'Название заметки';
  @override String get contentMarkdown => 'Содержание (Markdown)…';
  @override String get goTo => 'Перейти';
  @override String headingLabel(String label) => 'Заголовок $label';
  @override String get noteFont => 'Шрифт заметок';
  @override String get font => 'Шрифт';
  @override String sizeLabel(int v) => 'Размер: $v';
  @override String lineHeightLabel(String v) => 'Межстрочный: $v';

  // ── Word popup ────────────────────────────────────────────────────────────
  @override String get underlineColor => 'Цвет подчёркивания';
  @override String commentCharLimit(int n) => 'Комментарий (до $n символов)';
  @override String get highlightColor => 'Цвет выделения';
  @override String inText(String word) => 'в тексте: $word';
  @override String get otherDictionaries => 'Другие словари';
  @override String get goToVerse => 'Перейти';
  @override String get verseNotFound => 'Стих не найден';
  @override String get saturation => 'Насыщенность';
  @override String get brightnessLabel => 'Яркость';
  @override String get opacity => 'Прозрачность';

  // ── Hotkey settings ───────────────────────────────────────────────────────
  @override String get scrollDown => 'Прокрутка ВНИЗ (следующая страница)';
  @override String get scrollUp => 'Прокрутка ВВЕРХ (предыдущая страница)';
  @override String get assign => 'Назначить';
  @override String get captureKey => 'Захват клавиши';

  // ── Dictionary screens ────────────────────────────────────────────────────
  @override String get dictionariesTitle => 'Словари';
  @override String get searchHint => 'Поиск…';
  @override String get resetSearch => 'Сбросить';
  @override String get searchInContent => 'искать в содержании';

  // ── Templates ─────────────────────────────────────────────────────────────
  @override String get noteTemplates => 'Шаблоны заметок';
  @override String get createTemplate => 'Создать шаблон';
  @override String get noTemplates => 'Нет шаблонов';
  @override String get duplicate => 'Дублировать';
  @override String deleteTemplateConfirm(String name) => 'Шаблон «$name» будет удалён безвозвратно.';
  @override String templateSaved(String name) => 'Шаблон «$name» сохранён';
  @override String get newTemplate => 'Новый шаблон';
  @override String get editTemplate => 'Редактировать шаблон';
  @override String get templateName => 'Название шаблона';
  @override String get templatePlaceholders => 'Плейсхолдеры: {{title}}, {{date}}, {{book}}, {{chapter}}, {{verse}}';
  @override String get templateContent => 'Содержание шаблона (Markdown)…';

  // ── Note font settings sheet ──────────────────────────────────────────────
  @override String get barFading => 'Затухание бара';
  @override String get barFadingSubtitle => 'Скрывать нижнюю панель через 1с';
  @override String get textColor => 'Цвет текста';

  // ── Bible segment labels ──────────────────────────────────────────────────
  @override String get pentateuch => 'Пятикнижие';
  @override String get historical => 'Исторические книги';
  @override String get poetic => 'Поэтические книги';
  @override String get majorProphets => 'Большие пророки';
  @override String get minorProphets => 'Малые пророки';
  @override String get gospelsActs => 'Евангелия и Деяния';
  @override String get paulEpistles => 'Послания Павла';
  @override String get generalEpistles => 'Соборные послания и Откровение';

  // ── Storage helper ────────────────────────────────────────────────────────
  @override String get internalStorage => 'Внутренняя память';
  @override String get phoneStorage => 'Общая память телефона';
  @override String sdCard(int i) => i > 0 ? 'SD‑карта $i' : 'SD‑карта';

  // ── Asset names ───────────────────────────────────────────────────────────
  @override String get assetBibleText => 'Библейский текст';
  @override String get assetStrongs => 'Словарь Стронга';
  @override String get assetMorphology => 'Морфологический словарь';
  @override String get assetDvoretsky => 'Словарь Дворецкого';

  // ── Dictionary names ──────────────────────────────────────────────────────
  @override String get dictStrongs => 'Словарь Стронга (СтрДв)';
  @override String get dictBDAG => 'BDAG (3-е изд.)';
  @override String get dictMorphGreekEn => 'Морфологический греко-английский';
  @override String get dictDvoretsky => 'Словарь Дворецкого';

  // ── Misc ──────────────────────────────────────────────────────────────────
  @override String get parallelVerses => 'Параллельные стихи';
  @override String get tapAgainToNavigate => 'Нажмите ещё раз для перехода';
  @override String dictNotFound(String term) => 'Не найдено в словарях: $term';
  @override String get indexSearch => 'Создание поискового индекса';
}
