// lib/features/dictionary/provider/dictionary_provider.dart

import 'package:flutter/foundation.dart';
import '../../../core/db/dictionary_service.dart';
import '../../../core/models/models.dart';

class DictionaryProvider extends ChangeNotifier {
  final DictionaryService _service;
  DictionaryProvider(this._service);

  List<DictionaryMeta> get dictionaries => _service.availableDictionaries;

  String? _currentDictId;

  List<DictionaryEntry> entries   = [];
  bool  isLoading                  = false;
  bool  isLoadingMore              = false;
  String? error;

  String _query           = '';
  bool   _searchInContent = false;   // ← флаг галочки
  int    _offset          = 0;
  int    _total           = 0;

  bool   get hasMore           => entries.length < _total;
  String get currentQuery      => _query;
  bool   get searchInContent   => _searchInContent;

  static const _pageSize = 50;

  // ── Сменить режим поиска ──────────────────────────────────────────────────
  void setSearchInContent(bool value) {
    if (_searchInContent == value) return;
    _searchInContent = value;
    // Перезапрашиваем с той же строкой, но другим флагом
    if (_currentDictId != null) {
      loadEntries(dictionaryId: _currentDictId!, query: _query);
    } else {
      notifyListeners();
    }
  }

  // ── Загрузить / сменить словарь ───────────────────────────────────────────
  Future<void> loadEntries({
    required String dictionaryId,
    String query = '',
  }) async {
    _currentDictId = dictionaryId;
    _query         = query;
    _offset        = 0;
    entries        = [];
    error          = null;
    isLoading      = true;
    notifyListeners();

    try {
      _total  = await _service.countEntries(
          dictionaryId:    dictionaryId,
          query:           query.isEmpty ? null : query,
          searchInContent: _searchInContent);
      entries = await _service.fetchEntries(
          dictionaryId:    dictionaryId,
          query:           query.isEmpty ? null : query,
          searchInContent: _searchInContent,
          limit:           _pageSize,
          offset:          0);
      _offset = entries.length;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore || _currentDictId == null) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      final next = await _service.fetchEntries(
          dictionaryId:    _currentDictId!,
          query:           _query.isEmpty ? null : _query,
          searchInContent: _searchInContent,
          limit:           _pageSize,
          offset:          _offset);
      entries.addAll(next);
      _offset += next.length;
    } catch (e) {
      debugPrint('DictionaryProvider.loadMore: $e');
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<DictionaryEntry?> lookupStrongs(String strongs) =>
      _service.fetchByStrongs(strongs);

    Future<List<DictionaryLookupHit>> lookupAcrossDictionaries(String term) =>
      _service.lookupAcrossDictionaries(term);
}
