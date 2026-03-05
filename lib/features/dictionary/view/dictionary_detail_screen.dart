// lib/features/dictionary/view/dictionary_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_state.dart';
import '../../../core/db/db_service.dart';
import '../../../core/utils/tab_drag_mixin.dart';
import '../provider/dictionary_provider.dart';
import '../widgets/dictionary_entry_tile.dart';
import 'dictionary_article_screen.dart';

class DictionaryDetailScreen extends StatefulWidget {
  const DictionaryDetailScreen({
    super.key,
    required this.dictionaryId,
    required this.dictionaryTitle,
  });

  final String dictionaryId;
  final String dictionaryTitle;

  @override
  State<DictionaryDetailScreen> createState() => _DictionaryDetailScreenState();
}

class _DictionaryDetailScreenState extends State<DictionaryDetailScreen>
    with AutomaticKeepAliveClientMixin, TabDragMixin {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _searchActive = false;
  bool _initialLoadDone = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialLoadDone) {
        _initialLoadDone = true;
        context.read<DictionaryProvider>().loadEntries(
              dictionaryId: widget.dictionaryId,
            );
      }
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.extentAfter < 200) {
      context.read<DictionaryProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _runSearch(String q) => context.read<DictionaryProvider>().loadEntries(
        dictionaryId: widget.dictionaryId,
        query: q,
      );

  void _clearSearch() {
    _searchCtrl.clear();
    _runSearch('');
    setState(() => _searchActive = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<DictionaryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(
                    color: Theme.of(context).appBarTheme.foregroundColor),
                cursorColor: Theme.of(context).appBarTheme.foregroundColor,
                decoration: InputDecoration(
                  hintText: 'Поиск…',
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .appBarTheme
                          .foregroundColor
                          ?.withValues(alpha: 0.54)),
                  border: InputBorder.none,
                ),
                onChanged: _runSearch,
              )
            : Text(widget.dictionaryTitle),
        actions: [
          if (_searchActive)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Сбросить',
              onPressed: _clearSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Поиск',
              onPressed: () => setState(() => _searchActive = true),
            ),
        ],
        bottom: _searchActive
            ? PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: _SearchOptionsBar(
                  searchInContent: provider.searchInContent,
                  onChanged: provider.setSearchInContent,
                ),
              )
            : null,
      ),
      body: wrapWithTabDrag(
        context: context,
        onSwipeRight: () => goToTab(context, 1),
        child: _buildBody(provider, context.read<AppState>().db),
      ),
    );
  }

  Widget _buildBody(DictionaryProvider provider, DBService db) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFB00020)),
            const SizedBox(height: 12),
            Text(provider.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _runSearch(provider.currentQuery),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (provider.entries.isEmpty) {
      return Center(
        child: Text('Ничего не найдено',
            style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    return ListView.separated(
      key: PageStorageKey('dict-entries-${widget.dictionaryId}'),
      controller: _scrollCtrl,
      itemCount: provider.entries.length + (provider.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, i) {
        if (i >= provider.entries.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final entry = provider.entries[i];
        return DictionaryEntryTile(
          entry: entry,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DictionaryArticleScreen(entry: entry),
            ),
          ),
        );
      },
    );
  }
}

// ── Панель опций поиска ───────────────────────────────────────────────────────
class _SearchOptionsBar extends StatelessWidget {
  const _SearchOptionsBar({
    required this.searchInContent,
    required this.onChanged,
  });

  final bool searchInContent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: searchInContent,
              onChanged: (v) => onChanged(v ?? false),
              checkColor: Theme.of(context).colorScheme.primary,
              fillColor: WidgetStateProperty.resolveWith((states) {
                final fg = Theme.of(context).appBarTheme.foregroundColor ??
                    const Color(0xFFFFFFFF);
                return states.contains(WidgetState.selected)
                    ? fg
                    : fg.withValues(alpha: 0);
              }),
              side: BorderSide(
                  color: (Theme.of(context).appBarTheme.foregroundColor ??
                          const Color(0xFFFFFFFF))
                      .withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged(!searchInContent),
            child: Text(
              'искать в содержании',
              style: TextStyle(
                  color: Theme.of(context).appBarTheme.foregroundColor,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
