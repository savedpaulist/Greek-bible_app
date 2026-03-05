// lib/search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_state.dart';
import '../../../core/db/db_service.dart' show normalizeGreek;
import '../../../core/models/models.dart';
import '../../dictionary/provider/dictionary_provider.dart';
import '../../dictionary/view/dictionary_article_screen.dart';

enum _SearchMode { word, multiWord, allDictionaries }

/// Static cache so search results survive navigation away and back.
class _SearchCache {
  static _SearchMode mode = _SearchMode.word;
  static String queryText = '';
  static List<_RichResult> results = [];
  static List<DictionaryLookupHit> dictHits = [];
  static bool searched = false;

  /// Saved multi-word terms: list of (type, text) pairs.
  static List<(SearchTermType, String)> multiTerms = [];
  static double scrollOffset = 0;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  _SearchMode _mode = _SearchMode.word;

  // Single search
  final _ctrl = TextEditingController();

  // Multi-word search
  final List<_TermInput> _terms = [_TermInput()];

  List<_RichResult> _results = [];
  List<DictionaryLookupHit> _dictHits = [];
  bool _loading = false;
  bool _searched = false;
  int _searchGen = 0; // generation counter for cancellation

  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    // Restore cached search state.
    _mode = _SearchCache.mode;
    _ctrl.text = _SearchCache.queryText;
    _results = _SearchCache.results;
    _dictHits = _SearchCache.dictHits;
    _searched = _SearchCache.searched;
    if (_SearchCache.multiTerms.isNotEmpty) {
      for (final t in _terms) {
        t.ctrl.dispose();
      }
      _terms.clear();
      for (final (type, text) in _SearchCache.multiTerms) {
        final ti = _TermInput()..type = type;
        ti.ctrl.text = text;
        _terms.add(ti);
      }
    }
    _scrollCtrl =
        ScrollController(initialScrollOffset: _SearchCache.scrollOffset);
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    _SearchCache.scrollOffset = _scrollCtrl.offset;
  }

  @override
  void dispose() {
    // Save state to cache before dispose.
    _SearchCache.mode = _mode;
    _SearchCache.queryText = _ctrl.text;
    _SearchCache.results = _results;
    _SearchCache.dictHits = _dictHits;
    _SearchCache.searched = _searched;
    _SearchCache.multiTerms = _terms.map((t) => (t.type, t.ctrl.text)).toList();
    if (_scrollCtrl.hasClients) {
      _SearchCache.scrollOffset = _scrollCtrl.offset;
    }
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _ctrl.dispose();
    for (final t in _terms) {
      t.ctrl.dispose();
    }
    super.dispose();
  }

  // ── Search dispatcher ──────────────────────────────────────────────────────
  void _cancelSearch() {
    _searchGen++;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _search() async {
    final db = context.read<AppState>().db;
    final appState = context.read<AppState>();
    final dictProvider = context.read<DictionaryProvider>();
    setState(() {
      _loading = true;
      _results = [];
    });
    _SearchCache.scrollOffset = 0;
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    final gen = ++_searchGen;

    try {
      List<SearchResult> raw;
      String? historyEntry;

      switch (_mode) {
        case _SearchMode.word:
          final q = _ctrl.text.trim();
          if (q.isEmpty) {
            setState(() => _loading = false);
            return;
          }
          historyEntry = q;
          // Auto-detect Strongs: digits only or G/Г prefix + digits
          final strongsMatch = RegExp(r'^[GgГг]?(\d+)$').firstMatch(q);
          if (strongsMatch != null) {
            raw = await db.searchByStrongs(strongsMatch.group(1)!);
          } else {
            raw = await db.searchByWord(q);
          }
          _dictHits = await dictProvider.lookupAcrossDictionaries(q);
          break;

        case _SearchMode.multiWord:
          final terms = _terms
              .where((t) => t.ctrl.text.trim().isNotEmpty)
              .map((t) => SearchTerm(type: t.type, value: t.ctrl.text.trim()))
              .toList();
          if (terms.isEmpty) {
            setState(() => _loading = false);
            return;
          }
          raw = await db.searchMultiTerm(terms);
          _dictHits = [];
          break;

        case _SearchMode.allDictionaries:
          final q = _ctrl.text.trim();
          if (q.isEmpty) {
            setState(() => _loading = false);
            return;
          }
          historyEntry = q;
          raw = [];
          _dictHits = await dictProvider.lookupAcrossDictionaries(q);
          // Also search across all dictionaries with broader match
          final allDictHits = await _searchAllDictionaries(dictProvider, q);
          _dictHits = allDictHits;
          break;
      }

      // Save to history
      if (gen != _searchGen) return; // cancelled
      if (historyEntry != null) {
        appState.addSearchQuery(historyEntry);
      }

      // Load full verses in batch (single SQL instead of N sequential queries)
      if (gen != _searchGen) return; // cancelled
      final refs = raw
          .map((r) => (book: r.bookNumber, chapter: r.chapter, verse: r.verse))
          .toList();
      final batchWords = await db.getVerseWordsBatch(refs);
      final rich = <_RichResult>[];
      for (final r in raw) {
        final key = '${r.bookNumber}:${r.chapter}:${r.verse}';
        rich.add(_RichResult(result: r, verseWords: batchWords[key] ?? []));
      }
      setState(() {
        _results = rich;
        _searched = true;
      });

      // Inform user if index is still building (results may be empty/partial)
      if (mounted && raw.isEmpty && appState.isIndexing) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Индекс ещё строится. Попробуйте позже.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<DictionaryLookupHit>> _searchAllDictionaries(
      DictionaryProvider provider, String query) async {
    final hits = await provider.lookupAcrossDictionaries(query);
    return hits;
  }

  // ── Active query for highlight ─────────────────────────────────────────────
  bool get _isStrongsQuery {
    final q = _ctrl.text.trim();
    return RegExp(r'^[GgГг]?\d+$').hasMatch(q);
  }

  List<String> get _matchNorms {
    if (_mode == _SearchMode.word && !_isStrongsQuery) {
      return [normalizeGreek(_ctrl.text.trim())];
    }
    if (_mode == _SearchMode.multiWord) {
      return _terms
          .where((t) => t.type == SearchTermType.word && t.ctrl.text.isNotEmpty)
          .map((t) => normalizeGreek(t.ctrl.text.trim()))
          .toList();
    }
    return [];
  }

  List<String> get _matchStrongs {
    if (_mode == _SearchMode.word && _isStrongsQuery) {
      return [_ctrl.text.trim().replaceAll(RegExp(r'^[GgА-Яа-яГг]+'), '')];
    }
    if (_mode == _SearchMode.multiWord) {
      return _terms
          .where(
              (t) => t.type == SearchTermType.strongs && t.ctrl.text.isNotEmpty)
          .map((t) =>
              t.ctrl.text.trim().replaceAll(RegExp(r'^[GgА-Яа-яГг]+'), ''))
          .toList();
    }
    return [];
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск')),
      body: Column(children: [
        if (state.isIndexing)
          ValueListenableBuilder<double>(
            valueListenable: state.indexProgress,
            builder: (context, progress, _) =>
                LinearProgressIndicator(value: progress, minHeight: 6),
          ),

        // Mode chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            _chip('Слово / Стронг', _SearchMode.word),
            const SizedBox(width: 8),
            _chip('Несколько слов', _SearchMode.multiWord),
            const SizedBox(width: 8),
            _chip('Все словари', _SearchMode.allDictionaries),
          ]),
        ),

        // Input area
        ..._buildInput(),

        const SizedBox(height: 4),

        // Results
        Expanded(
          child: _loading
              ? Center(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.stop),
                      label: const Text('Остановить'),
                      onPressed: _cancelSearch,
                    ),
                  ],
                ))
              : (_results.isEmpty && _dictHits.isEmpty && !_searched)
                  ? _buildHistory(state)
                  : (_results.isEmpty && _dictHits.isEmpty)
                      ? Center(
                          child: Text('Ничего не найдено',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary)))
                      : _SearchResultsBody(
                          results: _results,
                          dictionaryHits: _dictHits,
                          matchNorms: _matchNorms,
                          matchStrongs: _matchStrongs,
                          scrollController: _scrollCtrl,
                        ),
        ),
      ]),
    );
  }

  Widget _buildHistory(AppState state) {
    if (state.searchHistory.isEmpty) {
      return Center(
          child: Text('Введите запрос',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.secondary)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text('История поиска',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  )),
              const Spacer(),
              TextButton(
                onPressed: () => state.clearSearchHistory(),
                child: const Text('Очистить', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.searchHistory.length,
            itemBuilder: (ctx, idx) {
              final q = state.searchHistory[idx];
              return ListTile(
                leading: const Icon(Icons.history, size: 20),
                title: Text(q, style: const TextStyle(fontSize: 15)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => state.removeSearchQuery(q),
                ),
                onTap: () {
                  _ctrl.text = q;
                  _search();
                },
                dense: true,
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildInput() {
    switch (_mode) {
      case _SearchMode.multiWord:
        return [
          ..._terms.asMap().entries.map((e) => _TermRow(
                input: e.value,
                index: e.key,
                onRemove: _terms.length > 1
                    ? () => setState(() {
                          _terms[e.key].ctrl.dispose();
                          _terms.removeAt(e.key);
                        })
                    : null,
              )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Ещё условие'),
                  onPressed: () => setState(() => _terms.add(_TermInput()))),
              const Spacer(),
              ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Найти (в одном стихе)'),
                  onPressed: _search),
            ]),
          ),
        ];

      default:
        return [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _mode == _SearchMode.allDictionaries
                    ? 'Слово для поиска по всем словарям'
                    : 'Слово или номер Стронга (напр. 1234, G1234)',
                hintStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.38),
                  fontWeight: FontWeight.w400,
                ),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.search), onPressed: _search),
              ),
              onSubmitted: (_) => _search(),
            ),
          )
        ];
    }
  }

  Widget _chip(String label, _SearchMode m) => ChoiceChip(
        label: Text(label),
        selected: _mode == m,
        onSelected: (_) => setState(() {
          _mode = m;
          _results = [];
          _searched = false;
        }),
      );
}

class _SearchResultsBody extends StatelessWidget {
  final List<_RichResult> results;
  final List<DictionaryLookupHit> dictionaryHits;
  final List<String> matchNorms;
  final List<String> matchStrongs;
  final ScrollController? scrollController;

  const _SearchResultsBody({
    required this.results,
    required this.dictionaryHits,
    required this.matchNorms,
    required this.matchStrongs,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      children: [
        if (dictionaryHits.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
            child:
                Text('Словари', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...dictionaryHits.map((hit) => ListTile(
                title: Text(hit.entry.term),
                subtitle: Text(hit.dictionaryTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DictionaryArticleScreen(entry: hit.entry),
                  ),
                ),
              )),
          const Divider(height: 1),
        ],
        _ResultsList(
          results: results,
          matchNorms: matchNorms,
          matchStrongs: matchStrongs,
        ),
      ],
    );
  }
}

// ── Multi-word term input ──────────────────────────────────────────────────
class _TermInput {
  SearchTermType type = SearchTermType.word;
  final TextEditingController ctrl = TextEditingController();
}

class _TermRow extends StatefulWidget {
  final _TermInput input;
  final int index;
  final VoidCallback? onRemove;
  const _TermRow({required this.input, required this.index, this.onRemove});
  @override
  State<_TermRow> createState() => _TermRowState();
}

class _TermRowState extends State<_TermRow> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Row(children: [
        // Type toggle
        SegmentedButton<SearchTermType>(
          segments: const [
            ButtonSegment(value: SearchTermType.word, label: Text('Слово')),
            ButtonSegment(value: SearchTermType.strongs, label: Text('G#')),
          ],
          selected: {widget.input.type},
          onSelectionChanged: (s) =>
              setState(() => widget.input.type = s.first),
          style: const ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.input.ctrl,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: widget.input.type == SearchTermType.strongs
                  ? 'Номер Стронга'
                  : 'Греческое слово',
              hintStyle: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.38),
                fontWeight: FontWeight.w400,
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        if (widget.onRemove != null)
          IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: widget.onRemove),
      ]),
    );
  }
}

// ── Rich result ────────────────────────────────────────────────────────────
class _RichResult {
  final SearchResult result;
  final List<WordModel> verseWords;

  /// Pre-normalized word forms (computed once, used in _isMatch).
  final List<String> normalizedWords;
  _RichResult({required this.result, required this.verseWords})
      : normalizedWords =
            verseWords.map((w) => normalizeGreek(w.word)).toList();
}

// ── Results list ─────────────────────────────────────────────────────────────
class _ResultsList extends StatelessWidget {
  final List<_RichResult> results;
  final List<String> matchNorms;
  final List<String> matchStrongs;

  const _ResultsList({
    required this.results,
    required this.matchNorms,
    required this.matchStrongs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Найдено: ${results.length}${results.length >= 300 ? '+' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary)))),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 12),
        itemBuilder: (_, i) => _ResultTile(
          rich: results[i],
          matchNorms: matchNorms,
          matchStrongs: matchStrongs,
        ),
      ),
    ]);
  }
}

class _ResultTile extends StatelessWidget {
  final _RichResult rich;
  final List<String> matchNorms;
  final List<String> matchStrongs;

  const _ResultTile(
      {required this.rich,
      required this.matchNorms,
      required this.matchStrongs});

  bool _isMatch(WordModel w, String normWord) {
    for (final q in matchNorms) {
      if (q.isNotEmpty && normWord.contains(q)) return true;
    }
    for (final s in matchStrongs) {
      if (s.isNotEmpty && (w.strongs ?? '').contains(s)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final r = rich.result;
    final s = context.read<AppState>();
    final fs = s.searchFontSize;

    final spans = <InlineSpan>[];
    for (int i = 0; i < rich.verseWords.length; i++) {
      final w = rich.verseWords[i];
      final matched = _isMatch(w, rich.normalizedWords[i]);
      spans.add(TextSpan(
        text: '${w.word} ',
        style: TextStyle(
          fontSize: matched ? fs + 1 : fs - 2,
          fontWeight: matched ? FontWeight.bold : FontWeight.normal,
          color: matched
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ));
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        s.navigateToVerse(r.bookNumber, r.chapter, r.verse,
            highlightStrongs: r.strongs);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 60,
              child: Column(children: [
                Text(r.bookShortName,
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                Text('${r.chapter}:${r.verse}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.secondary),
                    textAlign: TextAlign.center),
              ])),
          const SizedBox(width: 8),
          Expanded(child: RichText(text: TextSpan(children: spans))),
        ]),
      ),
    );
  }
}
