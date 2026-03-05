// lib/features/dictionary/view/dictionary_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_state.dart';
import '../../../core/utils/tab_drag_mixin.dart';
import '../provider/dictionary_provider.dart';
import '../widgets/dictionary_tile.dart';
import 'dictionary_detail_screen.dart';

class DictionaryScreen extends StatefulWidget {
  /// When embedded in PageView, don't show back button
  final bool embedded;
  const DictionaryScreen({super.key, this.embedded = false});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen>
    with AutomaticKeepAliveClientMixin, TabDragMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<DictionaryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Словари'),
        automaticallyImplyLeading: !widget.embedded,
      ),
      body: wrapWithTabDrag(
        context: context,
        onSwipeRight: () => goToTab(context, 1),
        child: Selector<AppState, (int, String)>(
          selector: (_, s) => (s.activeTab, s.themeMode),
          shouldRebuild: (prev, next) {
            if (next.$1 != 2) return false;
            return prev != next;
          },
          builder: (context, _, __) => ListView.builder(
            key: const PageStorageKey('dictionary-list'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: provider.dictionaries.length,
            itemBuilder: (context, index) {
              final dict = provider.dictionaries[index];
              return DictionaryTile(
                dictionary: dict,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: provider,
                      child: DictionaryDetailScreen(
                        dictionaryId: dict.id,
                        dictionaryTitle: dict.title,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
