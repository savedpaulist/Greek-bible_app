// lib/core/l10n/app_strings.dart
//
// Abstract interface for all UI strings.
// Use `AppStrings.of(languageCode)` to get the correct implementation.

import 'strings_ru.dart';
import 'strings_en.dart';

abstract class AppStrings {
  factory AppStrings.of(String lang) =>
      lang == 'en' ? const EnStrings() : const RuStrings();

  // ── General ───────────────────────────────────────────────────────────────
  String get appTitle;
  String get cancel;
  String get apply;
  String get save;
  String get create;
  String get delete;
  String get reset;
  String get retry;
  String get close;
  String get edit;
  String get done;
  String get search;
  String get error;
  String errorMsg(String e); // "Ошибка: $e"

  // ── Tabs / Navigation ─────────────────────────────────────────────────────
  String get tabNotes;
  String get tabBible;
  String get tabDictionaries;
  String get back;
  String get forward;

  // ── Setup screen ──────────────────────────────────────────────────────────
  String get setupPreparing;
  String get setupTitle;
  String get setupSubtitle;
  String get setupStorageTitle;
  String get setupStorageSubtitle;
  String get setupExtracting;
  String get setupIndexing;
  String get setupIndexOnce;
  String get setupDone;
  String setupExtractError(String e);
  String get stepExtraction;
  String get stepIndexing;

  // ── Settings ──────────────────────────────────────────────────────────────
  String get settings;
  String get appearance;
  String get appearanceSubtitle;
  String get bibleFont;
  String get noteEditor;
  String get noteEditorSubtitle;
  String get dictionary;
  String get dictionaryFontSize;
  String get hotkeys;
  String get searchHistory;
  String searchHistoryLimit(int n);
  String get clearHistory;
  String get historyCleared;
  String get fulltextSearch;
  // ── Appearance settings ───────────────────────────────────────────────────
  String get uiScale;
  String get uiScaleDefault;
  String get palette;
  String get brightness;
  String get brightLight;
  String get brightDark;
  String get brightSystem;
  String get brightSchedule;
  String get scheduleFrom;
  String get scheduleTo;
  String customizeColors(String mode);
  String get resetColors;
  String get colorsReset;
  String get bibleSegmentColors;
  String get resetSegmentColors;
  String get segmentColorsReset;
  String get animations;
  String get animationsSubtitle;

  // ── Bible settings ────────────────────────────────────────────────────────
  String get preview;
  String get bibleText;
  String get smallPopup;
  String get largePopup;
  String get searchLabel;
  String get versePreview;
  String get criticalText;
  String get menuBookChapter;
  String get lineSpacing;
  String get verseNumbers;
  String get criticalTextLabel;
  String get criticalTextSubtitle;
  String get copyMode;

  // ── Notes settings ────────────────────────────────────────────────────────
  String get fontSettings;
  String get fontSettingsSubtitle;
  String get textSize;
  String get lineHeight;
  String get noteTitle;

  // ── Dictionary settings ───────────────────────────────────────────────────
  String get fontSize;

  // ── Home screen (Bible reader) ────────────────────────────────────────────
  String copiedVerse(int ch, int v);
  String get noParallelVerses;
  String get parallelVerseAdded;
  String commentFor(int ch, int v);
  String get noComments;
  String get editComment;
  String get enterComment;
  String get verseBackgroundColor;
  String get createTag;
  String deleteTagConfirm(String name);
  String get manageTags;
  String get tagName;

  // ── Search screen ─────────────────────────────────────────────────────────
  String get indexStillBuilding;
  String get stopSearch;
  String get nothingFound;
  String get enterQuery;
  String get searchHistoryTitle;
  String get clear;
  String get addCondition;
  String get findInVerse;
  String get dictionaries;
  String get word;

  // ── Notes screen ──────────────────────────────────────────────────────────
  String get chooseTemplate;
  String get newFolder;
  String get folderName;
  String get renameFolder;
  String get deleteFolderConfirm;
  String get deleteFolderSubtitle;
  String get folders;
  String get newNote;
  String get searchNotes;
  String get pullDownToCreate;
  String get untitled;
  String get note;
  String get share;
  String get moveToFolder;
  String get noFolder;
  String deleteNoteConfirm(String title);
  String get noteDeleted;
  String get folderColor;

  // ── Note editor ───────────────────────────────────────────────────────────
  String linkNotFound(String text);
  String noteNotFound(String title);
  String get noOtherNotes;
  String get noteLink;
  String get exportError;
  String get openNote;
  String get alreadyOpen;
  String get saved;
  String get insertVerseLink;
  String get noteLinkInsert;
  String get exportMd;
  String get noteName;
  String get contentMarkdown;
  String get goTo;
  String headingLabel(String label);
  String get noteFont;
  String get font;
  String sizeLabel(int v);
  String lineHeightLabel(String v);

  // ── Word popup ────────────────────────────────────────────────────────────
  String get underlineColor;
  String commentCharLimit(int n);
  String get highlightColor;
  String inText(String word);
  String get otherDictionaries;
  String get goToVerse;
  String get verseNotFound;
  String get saturation;
  String get brightnessLabel;
  String get opacity;

  // ── Hotkey settings ───────────────────────────────────────────────────────
  String get scrollDown;
  String get scrollUp;
  String get assign;
  String get captureKey;

  // ── Dictionary screens ────────────────────────────────────────────────────
  String get dictionariesTitle;
  String get searchHint;
  String get resetSearch;
  String get searchInContent;

  // ── Templates ─────────────────────────────────────────────────────────────
  String get noteTemplates;
  String get createTemplate;
  String get noTemplates;
  String get duplicate;
  String deleteTemplateConfirm(String name);
  String templateSaved(String name);
  String get newTemplate;
  String get editTemplate;
  String get templateName;
  String get templatePlaceholders;
  String get templateContent;

  // ── Note font settings sheet ──────────────────────────────────────────────
  String get barFading;
  String get barFadingSubtitle;
  String get textColor;

  // ── Bible segment labels ──────────────────────────────────────────────────
  String get pentateuch;
  String get historical;
  String get poetic;
  String get majorProphets;
  String get minorProphets;
  String get gospelsActs;
  String get paulEpistles;
  String get generalEpistles;

  // ── Storage helper ────────────────────────────────────────────────────────
  String get internalStorage;
  String get phoneStorage;
  String sdCard(int i);

  // ── Asset names ───────────────────────────────────────────────────────────
  String get assetBibleText;
  String get assetStrongs;
  String get assetMorphology;
  String get assetDvoretsky;

  // ── Dictionary names ──────────────────────────────────────────────────────
  String get dictStrongs;
  String get dictBDAG;
  String get dictMorphGreekEn;
  String get dictDvoretsky;

  // ── Misc ──────────────────────────────────────────────────────────────────
  String get parallelVerses;
  String get tapAgainToNavigate;
  String dictNotFound(String term);
  String get indexSearch;
}
