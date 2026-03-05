// lib/features/notes/view/notes_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/app_state.dart';
import '../../../ui/main_shell.dart';
import '../widgets/note_font_settings_sheet.dart';
import '../data/note_model.dart';
import '../provider/notes_provider.dart';
import 'note_editor_screen.dart';
import 'template_editor_screen.dart';
import 'fade_route.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  /// Exposed so MainShell can programmatically open the drawer on swipe.
  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with AutomaticKeepAliveClientMixin {
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
  static const _noteAccentColors = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFF3F51B5), Color(0xFFF44336),
    Color(0xFF00BCD4), Color(0xFF009688), Color(0xFFE65100), Color(0xFFFF5722),
  ];

  Color _accentForNote(NoteModel note) =>
      _noteAccentColors[note.title.length % _noteAccentColors.length];
  final TextEditingController _searchCtrl = TextEditingController();

  bool _headerShouldHide = false;

  // Expanded folders in the drawer tree
  final Set<String> _expandedFolders = {};

  // Accumulate horizontal drag delta for swipe detection on main content.
  double _dragDelta = 0;

  // Same for drawer, so a left swipe there closes it.
  double _drawerDragDelta = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final provider = context.read<NotesProvider>();
      provider.load();
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createNote(BuildContext context,
      {String? folderId, bool closeDrawer = false}) async {
    if (closeDrawer) {
      NotesScreen.scaffoldKey.currentState?.closeDrawer();
    }
    final provider = context.read<NotesProvider>();
    final nav = Navigator.of(context);
    final templates = provider.templates;

    if (templates.length <= 1) {
      final note = await provider.createNote(folderId: folderId);
      if (!mounted) return;
        await _openEditor(nav, provider, note);
      return;
    }

    final tpl = await showModalBottomSheet<NoteTemplate?>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (sheetCtx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Выберите шаблон',
                style: Theme.of(sheetCtx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          for (final t in templates)
            ListTile(
              title: Text(t.name),
              leading: const Icon(Icons.description_outlined),
              onTap: () => Navigator.pop(sheetCtx, t),
            ),
        ],
      ),
    );

    if (tpl != null && mounted) {
      final note =
          await provider.createNote(templateId: tpl.id, folderId: folderId);
      if (!mounted) return;
      await _openEditor(nav, provider, note);
    }
  }


  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _extractSubtitle(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) continue;
      final clean = trimmed
          .replaceAll(RegExp(r'\*\*|__'), '')
          .replaceAll(RegExp(r'\*|_'), '')
          .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
          .replaceAll(RegExp(r'\[\[([^\]]+)\]\]'), r'$1')
          .trim();
      if (clean.isNotEmpty) {
        return clean.length > 80 ? '${clean.substring(0, 80)}…' : clean;
      }
    }
    return '';
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая папка'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Название папки',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<NotesProvider>().createFolder(name);
      setState(() {});
    }
  }

  Future<void> _renameFolder(String id, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать папку'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<NotesProvider>().renameFolder(id, name);
      setState(() {});
    }
  }

  Future<void> _deleteFolder(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить папку?'),
        content: const Text('Заметки из папки будут перемещены в «Без папки».'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<NotesProvider>().deleteFolder(id);
      _expandedFolders.remove(id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<NotesProvider>();
    final cs = Theme.of(context).colorScheme;

    // Apply search filter
    List<NoteModel> notes = List.from(provider.notes);
    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      notes = notes
          .where((n) =>
              n.title.toLowerCase().contains(q) ||
              n.content.toLowerCase().contains(q))
          .toList();
    }

    final appState = context.watch<AppState>();

    return Scaffold(
      key: NotesScreen.scaffoldKey,
      drawerEdgeDragWidth: 150,
      drawerEnableOpenDragGesture: true,
      appBar: AppBar(
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
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Папки',
          onPressed: () => NotesScreen.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_format),
            tooltip: 'Настройки шрифта',
            onPressed: () => _showNoteFontSettings(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Новая заметка',
            onPressed: () => _createNote(context),
          ),
        ],
      ),
      drawer: _buildDrawer(provider, cs, appState),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_searchCtrl.text.isEmpty) {
            setState(() {}); // hide search if empty
          }
        },
        onHorizontalDragUpdate: (details) {
          _dragDelta += details.delta.dx;
          if (details.delta.dx > 12) {
            NotesScreen.scaffoldKey.currentState?.openDrawer();
          }
        },
        onHorizontalDragEnd: (details) {
          if (_dragDelta < -80 || details.velocity.pixelsPerSecond.dx < -200) {
            final shell = context.findAncestorStateOfType<MainShellState>();
            if (shell != null) shell.goToPage(1);
          }
          _dragDelta = 0;
        },
        onHorizontalDragCancel: () {
          _dragDelta = 0;
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Поиск заметок…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            provider.search('');
                            setState(() {});
                          })
                      : null,
                ),
                onChanged: (q) {
                  provider.search(q);
                  setState(() {});
                },
              ),
            ),
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _createNote(context),
                displacement: 20,
                child: provider.loading
                    ? const Center(child: CircularProgressIndicator())
                    : notes.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.note_alt_outlined,
                                          size: 64,
                                          color: cs.secondary
                                              .withValues(alpha: 0.4)),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchCtrl.text.isEmpty
                                            ? 'Нет заметок'
                                            : 'Ничего не найдено',
                                        style: TextStyle(
                                            color: cs.secondary, fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Потяните вниз для создания',
                                          style: TextStyle(
                                              color: cs.secondary
                                                  .withValues(alpha: 0.5),
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: notes.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (ctx, idx) {
                              final note = notes[idx];
                              final title = note.title.isEmpty ? 'Без названия' : note.title;
                              final subtitle = _extractSubtitle(note.content);

                              // Синхронно из кэша (Правка 9)
                              final tags = provider.tagsForNote(note.id);

                              // LEADING: тег > папка > ничего
                              Widget? leading;
                              if (tags.isNotEmpty) {
                                final primaryTag = tags.first;
                                leading = CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(primaryTag.colorValue).withValues(alpha: 0.12),
                                  child: Icon(Icons.label, color: Color(primaryTag.colorValue), size: 18),
                                );
                              } else {
                                Map<String, dynamic>? folder;
                                if (note.folderId != null) {
                                  final found = provider.folders.where((f) => f['id'] == note.folderId);
                                  folder = found.isNotEmpty ? found.first : null;
                                }
                                if (folder != null) {
                                  leading = CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Color(folder['color_value'] ?? 0xFFBDBDBD).withValues(alpha: 0.12),
                                    child: Icon(
                                      Icons.folder_outlined,
                                      color: Color(folder['color_value'] ?? 0xFFBDBDBD),
                                      size: 18,
                                    ),
                                  );
                                }
                              }

                              // TITLE: если есть теги — "TagName · NoteTitle"
                              String displayTitle;
                              if (tags.isNotEmpty) {
                                final tagName = tags.first.name;
                                displayTitle = (note.title.isEmpty || note.title == tagName)
                                    ? tagName
                                    : '$tagName · ${note.title}';
                              } else {
                                displayTitle = title;
                              }

                              // SUBTITLE: контент + остальные теги
                              final parts = <String>[];
                              if (subtitle.isNotEmpty) parts.add(subtitle);
                              if (tags.length > 1) {
                                parts.add(tags.skip(1).map((t) => '#${t.name}').join(' '));
                              }
                              final subtitleText = parts.isNotEmpty ? parts.join('  ·  ') : null;

                              return Builder(builder: (ctx) {
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
                                            : color.withAlpha(30),
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
                                      onTap: () async => await _openEditor(Navigator.of(context), provider, note),
                                      onLongPress: () => _showNoteOptions(note),
                                      child: ListTile(
                                        key: ValueKey(note.id),
                                        leading: leading,
                                        title: Text(displayTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: subtitleText != null
                                            ? Text(subtitleText, maxLines: 1, overflow: TextOverflow.ellipsis)
                                            : null,
                                        trailing: Text(
                                          _formatDate(note.updatedAt),
                                          style: TextStyle(fontSize: 12, color: cs.secondary),
                                        ),
                                        // onTap/onLongPress handled by InkWell
                                      ),
                                    ),
                                  ),
                                );
                              });
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteOptions(NoteModel note) {
    final cs = Theme.of(context).colorScheme;
    final onSurf = cs.onSurface;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                note.title.isEmpty ? 'Заметка' : note.title,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: onSurf),
              ),
            ),
            Divider(color: cs.outlineVariant, height: 1),
            ListTile(
              leading: Icon(Icons.share_outlined, color: onSurf),
              title: Text('Поделиться', style: TextStyle(color: onSurf)),
              onTap: () {
                Navigator.pop(ctx);
                _shareNote(note);
              },
            ),
            ListTile(
              leading: Icon(Icons.drive_file_move_outlined, color: onSurf),
              title:
                  Text('Переместить в папку', style: TextStyle(color: onSurf)),
              onTap: () {
                Navigator.pop(ctx);
                _showMoveToFolderDialog(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteNote(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveToFolderDialog(NoteModel note) {
    final provider = context.read<NotesProvider>();
    final folders = provider.folders;
    final cs = Theme.of(context).colorScheme;
    final onSurf = cs.onSurface;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Переместить в папку',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: onSurf),
              ),
            ),
            Divider(color: cs.outlineVariant, height: 1),
            ListTile(
              leading: Icon(Icons.folder_off_outlined, color: onSurf),
              title: Text('Без папки', style: TextStyle(color: onSurf)),
              selected: note.folderId == null,
              onTap: () async {
                await provider.moveNoteToFolder(note.id, null);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
            ),
            for (final f in folders)
              ListTile(
                leading: Icon(Icons.folder_outlined, color: onSurf),
                title: Text(f['name'] as String? ?? '',
                    style: TextStyle(color: onSurf)),
                selected: note.folderId == f['id'],
                onTap: () async {
                  await provider.moveNoteToFolder(note.id, f['id'] as String);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showNoteFontSettings() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) =>
          NoteFontSettingsSheet(appState: context.read<AppState>()),
    );
  }

  Future<void> _shareNote(NoteModel note) async {
    final fullContent = note.title.isNotEmpty
        ? '# ${note.title}\n\n${note.content}'
        : note.content;
    await Share.share(fullContent, subject: note.title);
  }

  Future<void> _confirmDeleteNote(NoteModel note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: Text(
            'Заметка «${note.title.isEmpty ? 'Без названия' : note.title}» будет удалена безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<NotesProvider>().deleteNote(note.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заметка удалена')),
      );
    }
  }

  Widget _buildDrawer(
      NotesProvider provider, ColorScheme cs, AppState appState) {
    final rootNotes = provider.notes.where((n) => n.folderId == null).toList();
    final isDark = cs.brightness == Brightness.dark;
    final textCol = isDark ? Colors.white : Colors.black;

    return Drawer(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          _drawerDragDelta += details.delta.dx;
        },
        onHorizontalDragEnd: (details) {
          if (_drawerDragDelta < -80 ||
              details.velocity.pixelsPerSecond.dx < -200) {
            Navigator.pop(context);
          }
          _drawerDragDelta = 0;
        },
        onHorizontalDragCancel: () {
          _drawerDragDelta = 0;
        },
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
          InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      size: 16, color: textCol.withValues(alpha: 0.5)),
                  const Spacer(),
                  Icon(Icons.settings_outlined,
                      size: 18, color: textCol.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildFolderItem(
                  id: 'templates_root',
                  name: 'Templates',
                  icon: Icons.description_outlined,
                  color: cs.tertiary,
                  appState: appState,
                  isExpanded: _expandedFolders.contains('templates_root'),
                  onToggle: () {
                    setState(() {
                      if (_expandedFolders.contains('templates_root')) {
                        _expandedFolders.remove('templates_root');
                      } else {
                        _expandedFolders.add('templates_root');
                      }
                    });
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: _createTemplate,
                    tooltip: 'Add Template',
                  ),
                  children: provider.templates.map((t) {
                    return _buildTreeNoteItem(
                      title: t.name,
                      icon: Icons.description_outlined,
                      appState: appState,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: provider,
                              child: const TemplateListScreen(),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                for (final folder in provider.folders)
                  _buildFolderItem(
                    id: folder['id'] as String,
                    name: folder['name'] as String? ?? '',
                    icon: null,
                    appState: appState,
                    color: folder['color_value'] != null
                        ? Color(folder['color_value'] as int)
                        : cs.primary,
                    isExpanded: _expandedFolders.contains(folder['id']),
                    onToggle: () {
                      setState(() {
                        final id = folder['id'] as String;
                        if (_expandedFolders.contains(id)) {
                          _expandedFolders.remove(id);
                        } else {
                          _expandedFolders.add(id);
                        }
                      });
                    },
                    children: provider.notes
                        .where((n) => n.folderId == folder['id'])
                        .map((note) => _buildTreeNoteItem(
                              title: note.title.isEmpty
                                  ? 'Без названия'
                                  : note.title,
                              appState: appState,
                              onTap: () {
                                Navigator.pop(context);
                                _openEditor(
                                    Navigator.of(context), provider, note);
                              },
                              onLongPress: () {
                                Navigator.pop(context);
                                _showNoteOptions(note);
                              },
                            ))
                        .toList(),
                  ),
                for (final note in rootNotes)
                  _buildTreeNoteItem(
                    title: note.title.isEmpty ? 'Без названия' : note.title,
                    appState: appState,
                    onTap: () {
                      Navigator.pop(context);
                      _openEditor(Navigator.of(context), provider, note);
                    },
                    onLongPress: () {
                      Navigator.pop(context);
                      _showNoteOptions(note);
                    },
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_document, size: 20),
                  onPressed: () => _createNote(context, closeDrawer: true),
                  tooltip: 'Новая заметка',
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  onPressed: _createFolder,
                  tooltip: 'Новая папка',
                ),
                IconButton(
                  icon: const Icon(Icons.note_add_outlined, size: 20),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: const TemplateListScreen(),
                        ),
                      ),
                    );
                  },
                  tooltip: 'Templates',
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Files',
                    style: TextStyle(
                      fontSize: appState.noteExplorerFontSize,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.unfold_more,
                      size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    ), // end GestureDetector
  ); // end Drawer
  }

  Widget _buildFolderItem({
    required String id,
    required String name,
    required IconData? icon,
    required Color color,
    required bool isExpanded,
    required VoidCallback onToggle,
    Widget? trailing,
    required List<Widget> children,
    required AppState appState,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          onLongPress: id == 'templates_root'
              ? null
              : () {
                  Navigator.pop(context);
                  _showFolderMenu(id, name);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Icon(
                  icon ??
                      (isExpanded ? Icons.folder_open : Icons.folder_outlined),
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: appState.noteExplorerFontSize,
                      fontWeight:
                          isExpanded ? FontWeight.bold : FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...children.map((c) => Padding(
                padding: const EdgeInsets.only(left: 12),
                child: c,
              )),
      ],
    );
  }

  Widget _buildTreeNoteItem({
    required String title,
    IconData icon = Icons.description_outlined,
    required AppState appState,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 4, 12, 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: appState.noteExplorerFontSize - 1,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTemplate() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('New Template'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Template name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      final provider = context.read<NotesProvider>();
      final template = NoteTemplate(
        id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        content: '',
      );
      await provider.saveTemplate(template);
      setState(() {});
    }
  }

  void _showFolderMenu(String id, String name) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('Новая заметка'),
              onTap: () {
                Navigator.pop(ctx);
                _createNote(context, folderId: id, closeDrawer: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Цвет папки'),
              onTap: () {
                Navigator.pop(ctx);
                _showFolderColorPicker(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Переименовать'),
              onTap: () {
                Navigator.pop(ctx);
                _renameFolder(id, name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить папку'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteFolder(id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFolderColorPicker(String folderId) {
    final provider = context.read<NotesProvider>();
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Цвет папки', style: TextStyle(fontSize: 16)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final color in [
              const Color(0xFF42A5F5),
              const Color(0xFF66BB6A),
              const Color(0xFFFF7043),
              const Color(0xFFAB47BC),
              const Color(0xFFFFCA28),
              const Color(0xFFEF5350),
              const Color(0xFF26A69A),
              const Color(0xFF78909C),
            ])
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  await provider.updateFolderColor(folderId, color.toARGB32());
                  if (mounted) setState(() {});
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(ctx)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }
}
