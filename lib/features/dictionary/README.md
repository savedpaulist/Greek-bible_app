# 📖 Dictionary Feature Module

## Overview

Provides read-only browsing of the Strong's Greek lexicon bundled with the app
as a SQLite asset (`СтрДв.dictionary.SQLite3`).

## Public API

Import `features/dictionary/dictionary_module.dart` to get access to:

| Export | Purpose |
|--------|---------|
| `DictionaryScreen` | Entry-point widget — lists available dictionaries |
| `DictionaryDetailScreen` | Searchable, paginated entry list for one dictionary |
| `DictionaryProvider` | `ChangeNotifier` — state & pagination logic |

## Architecture

```
dictionary/
├─ view/
│   ├─ dictionary_screen.dart        # list of dictionaries
│   └─ dictionary_detail_screen.dart # searchable entry list + bottom-sheet detail
├─ widgets/
│   ├─ dictionary_tile.dart          # card for each DictionaryMeta
│   └─ dictionary_entry_tile.dart    # row for each DictionaryEntry
├─ provider/
│   └─ dictionary_provider.dart      # load / search / paginate
└─ dictionary_module.dart            # barrel export
```

The provider delegates all DB access to `core/db/DictionaryService`,
which is constructed in `main.dart` using the already-opened `db.dictDb`.

## Navigation

Route `/dictionaries` is registered in `BibleApp` and can be pushed from
anywhere:

```dart
Navigator.pushNamed(context, '/dictionaries');
```

A 📖 icon button is already added to the `HomeScreen` AppBar.

## Extending

To add another dictionary (e.g. Liddell-Scott in a second SQLite file):

1. Open the new database in `DBService.init()`.
2. Expose a getter (like `dictDb`).
3. Add a second `DictionaryService` instance (or extend the existing one).
4. Add a new `DictionaryMeta` entry to `DictionaryService.availableDictionaries`.
5. Update `DictionaryProvider` / `DictionaryDetailScreen` to route to the
   correct service based on `dictionaryId`.
