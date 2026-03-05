// lib/core/l10n/strings_en.dart

import 'app_strings.dart';

class EnStrings implements AppStrings {
  const EnStrings();

  // ── General ───────────────────────────────────────────────────────────────
  @override String get appTitle => 'Greek Bible';
  @override String get cancel => 'Cancel';
  @override String get apply => 'Apply';
  @override String get save => 'Save';
  @override String get create => 'Create';
  @override String get delete => 'Delete';
  @override String get reset => 'Reset';
  @override String get retry => 'Retry';
  @override String get close => 'Close';
  @override String get edit => 'Edit';
  @override String get done => 'Done';
  @override String get search => 'Search';
  @override String get error => 'Error';
  @override String errorMsg(String e) => 'Error: $e';

  // ── Tabs / Navigation ─────────────────────────────────────────────────────
  @override String get tabNotes => 'Notes';
  @override String get tabBible => 'Bible';
  @override String get tabDictionaries => 'Dictionaries';
  @override String get back => 'Back';
  @override String get forward => 'Forward';

  // ── Setup screen ──────────────────────────────────────────────────────────
  @override String get setupPreparing => 'Preparing…';
  @override String get setupTitle => 'Greek Bible';
  @override String get setupSubtitle => 'Setting up the app';
  @override String get setupStorageTitle => 'Where to store data?';
  @override String get setupStorageSubtitle => 'Dictionaries take ~1 GB.\nChoose storage location:';
  @override String get setupExtracting => 'Extracting databases…';
  @override String get setupIndexing => 'Building search index…';
  @override String get setupIndexOnce => 'This only needs to be done once…';
  @override String get setupDone => 'All set!';
  @override String setupExtractError(String e) => 'Extraction error: $e';
  @override String get stepExtraction => 'Extraction';
  @override String get stepIndexing => 'Indexing';

  // ── Settings ──────────────────────────────────────────────────────────────
  @override String get settings => 'Settings';
  @override String get appearance => 'Appearance';
  @override String get appearanceSubtitle => 'Theme, colors, animations';
  @override String get bibleFont => 'Bible Font';
  @override String get noteEditor => 'Note Editor';
  @override String get noteEditorSubtitle => 'Font, size, text color';
  @override String get dictionary => 'Dictionary';
  @override String get dictionaryFontSize => 'Font size';
  @override String get hotkeys => 'Hotkeys';
  @override String get searchHistory => 'Search History';
  @override String searchHistoryLimit(int n) => 'Max $n entries';
  @override String get clearHistory => 'Clear history';
  @override String get historyCleared => 'History cleared';
  @override String get fulltextSearch => 'Full-text word search';
  // ── Appearance settings ───────────────────────────────────────────────────
  @override String get uiScale => 'UI Scale';
  @override String get uiScaleDefault => 'Default: 100%';
  @override String get palette => 'Palette';
  @override String get brightness => 'Brightness';
  @override String get brightLight => 'Light';
  @override String get brightDark => 'Dark';
  @override String get brightSystem => 'System';
  @override String get brightSchedule => 'Schedule';
  @override String get scheduleFrom => 'Light from ';
  @override String get scheduleTo => ' to ';
  @override String customizeColors(String mode) => 'Customize colors ($mode)';
  @override String get resetColors => 'Reset colors to default';
  @override String get colorsReset => 'Colors reset';
  @override String get bibleSegmentColors => 'Bible segment colors';
  @override String get resetSegmentColors => 'Reset segment colors';
  @override String get segmentColorsReset => 'Segment colors reset';
  @override String get animations => 'Animations';
  @override String get animationsSubtitle => 'Screen transitions, scrolling, word blinking';

  // ── Bible settings ────────────────────────────────────────────────────────
  @override String get preview => 'Preview';
  @override String get bibleText => 'Bible Text';
  @override String get smallPopup => 'Small Popup';
  @override String get largePopup => 'Large Popup';
  @override String get searchLabel => 'Search';
  @override String get versePreview => 'Verse Preview';
  @override String get criticalText => 'Critical Text';
  @override String get menuBookChapter => 'Menu (book/chapter)';
  @override String get lineSpacing => 'Spacing';
  @override String get verseNumbers => 'Verse numbers';
  @override String get criticalTextLabel => 'Critical text';
  @override String get criticalTextSubtitle => 'NA27/UBS4/Byzantine apparatus';
  @override String get copyMode => 'Copy mode';

  // ── Notes settings ────────────────────────────────────────────────────────
  @override String get fontSettings => 'Font settings';
  @override String get fontSettingsSubtitle => 'Font, size, text color';
  @override String get textSize => 'Text size';
  @override String get lineHeight => 'Line height';
  @override String get noteTitle => 'Note title';

  // ── Dictionary settings ───────────────────────────────────────────────────
  @override String get fontSize => 'Font size';

  // ── Home screen ───────────────────────────────────────────────────────────
  @override String copiedVerse(int ch, int v) => 'Copied: $ch:$v';
  @override String get noParallelVerses => 'No parallel verses';
  @override String get parallelVerseAdded => 'Parallel verse added';
  @override String commentFor(int ch, int v) => 'Comment for $ch:$v';
  @override String get noComments => 'No comments';
  @override String get editComment => 'Edit comment';
  @override String get enterComment => 'Enter comment…';
  @override String get verseBackgroundColor => 'Verse background color';
  @override String get createTag => 'Create tag';
  @override String deleteTagConfirm(String name) => 'Tag "$name" and all its bindings will be deleted.';
  @override String get manageTags => 'Manage tags';
  @override String get tagName => 'Tag name';

  // ── Search screen ─────────────────────────────────────────────────────────
  @override String get indexStillBuilding => 'Index is still building. Try later.';
  @override String get stopSearch => 'Stop';
  @override String get nothingFound => 'Nothing found';
  @override String get enterQuery => 'Enter query';
  @override String get searchHistoryTitle => 'Search history';
  @override String get clear => 'Clear';
  @override String get addCondition => 'Add condition';
  @override String get findInVerse => 'Find (in one verse)';
  @override String get dictionaries => 'Dictionaries';
  @override String get word => 'Word';

  // ── Notes screen ──────────────────────────────────────────────────────────
  @override String get chooseTemplate => 'Choose template';
  @override String get newFolder => 'New folder';
  @override String get folderName => 'Folder name';
  @override String get renameFolder => 'Rename folder';
  @override String get deleteFolderConfirm => 'Delete folder?';
  @override String get deleteFolderSubtitle => 'Notes will be moved to "No folder".';
  @override String get folders => 'Folders';
  @override String get newNote => 'New note';
  @override String get searchNotes => 'Search notes…';
  @override String get pullDownToCreate => 'Pull down to create';
  @override String get untitled => 'Untitled';
  @override String get note => 'Note';
  @override String get share => 'Share';
  @override String get moveToFolder => 'Move to folder';
  @override String get noFolder => 'No folder';
  @override String deleteNoteConfirm(String title) => 'Note "$title" will be permanently deleted.';
  @override String get noteDeleted => 'Note deleted';
  @override String get folderColor => 'Folder color';

  // ── Note editor ───────────────────────────────────────────────────────────
  @override String linkNotFound(String text) => 'Could not parse link: $text';
  @override String noteNotFound(String title) => 'Note "$title" not found';
  @override String get noOtherNotes => 'No other notes to link';
  @override String get noteLink => 'Note link';
  @override String get exportError => 'Export error';
  @override String get openNote => 'Open note';
  @override String get alreadyOpen => 'Already open';
  @override String get saved => 'Saved';
  @override String get insertVerseLink => 'Insert verse link';
  @override String get noteLinkInsert => 'Note link';
  @override String get exportMd => 'Export .md';
  @override String get noteName => 'Note name';
  @override String get contentMarkdown => 'Content (Markdown)…';
  @override String get goTo => 'Go to';
  @override String headingLabel(String label) => 'Heading $label';
  @override String get noteFont => 'Note font';
  @override String get font => 'Font';
  @override String sizeLabel(int v) => 'Size: $v';
  @override String lineHeightLabel(String v) => 'Line height: $v';

  // ── Word popup ────────────────────────────────────────────────────────────
  @override String get underlineColor => 'Underline color';
  @override String commentCharLimit(int n) => 'Comment (up to $n characters)';
  @override String get highlightColor => 'Highlight color';
  @override String inText(String word) => 'in text: $word';
  @override String get otherDictionaries => 'Other dictionaries';
  @override String get goToVerse => 'Go to';
  @override String get verseNotFound => 'Verse not found';
  @override String get saturation => 'Saturation';
  @override String get brightnessLabel => 'Brightness';
  @override String get opacity => 'Opacity';

  // ── Hotkey settings ───────────────────────────────────────────────────────
  @override String get scrollDown => 'Scroll DOWN (next page)';
  @override String get scrollUp => 'Scroll UP (previous page)';
  @override String get assign => 'Assign';
  @override String get captureKey => 'Capture key';

  // ── Dictionary screens ────────────────────────────────────────────────────
  @override String get dictionariesTitle => 'Dictionaries';
  @override String get searchHint => 'Search…';
  @override String get resetSearch => 'Reset';
  @override String get searchInContent => 'search in content';

  // ── Templates ─────────────────────────────────────────────────────────────
  @override String get noteTemplates => 'Note templates';
  @override String get createTemplate => 'Create template';
  @override String get noTemplates => 'No templates';
  @override String get duplicate => 'Duplicate';
  @override String deleteTemplateConfirm(String name) => 'Template "$name" will be permanently deleted.';
  @override String templateSaved(String name) => 'Template "$name" saved';
  @override String get newTemplate => 'New template';
  @override String get editTemplate => 'Edit template';
  @override String get templateName => 'Template name';
  @override String get templatePlaceholders => 'Placeholders: {{title}}, {{date}}, {{book}}, {{chapter}}, {{verse}}';
  @override String get templateContent => 'Template content (Markdown)…';

  // ── Note font settings sheet ──────────────────────────────────────────────
  @override String get barFading => 'Bar fading';
  @override String get barFadingSubtitle => 'Hide bottom bar after 1s';
  @override String get textColor => 'Text color';

  // ── Bible segment labels ──────────────────────────────────────────────────
  @override String get pentateuch => 'Pentateuch';
  @override String get historical => 'Historical Books';
  @override String get poetic => 'Poetic Books';
  @override String get majorProphets => 'Major Prophets';
  @override String get minorProphets => 'Minor Prophets';
  @override String get gospelsActs => 'Gospels & Acts';
  @override String get paulEpistles => "Paul's Epistles";
  @override String get generalEpistles => 'General Epistles & Revelation';

  // ── Storage helper ────────────────────────────────────────────────────────
  @override String get internalStorage => 'Internal storage';
  @override String get phoneStorage => 'Phone storage';
  @override String sdCard(int i) => i > 0 ? 'SD card $i' : 'SD card';

  // ── Asset names ───────────────────────────────────────────────────────────
  @override String get assetBibleText => 'Bible text';
  @override String get assetStrongs => "Strong's Dictionary";
  @override String get assetMorphology => 'Morphology dictionary';
  @override String get assetDvoretsky => 'Dvoretsky Dictionary';

  // ── Dictionary names ──────────────────────────────────────────────────────
  @override String get dictStrongs => "Strong's Dictionary";
  @override String get dictBDAG => 'BDAG (3rd ed.)';
  @override String get dictMorphGreekEn => 'Morphological Greek-English';
  @override String get dictDvoretsky => 'Dvoretsky Dictionary';

  // ── Misc ──────────────────────────────────────────────────────────────────
  @override String get parallelVerses => 'Parallel verses';
  @override String get tapAgainToNavigate => 'Tap again to navigate';
  @override String dictNotFound(String term) => 'Not found in dictionaries: $term';
  @override String get indexSearch => 'Building search index';
}
