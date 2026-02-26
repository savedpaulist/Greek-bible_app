// lib/features/notes/view/notes_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/notes_provider.dart';
import '../data/note_model.dart';
import 'note_editor_screen.dart';
import 'template_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  /// Exposed so MainShell can programmatically open the drawer on swipe.
  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();

  // Expanded folders in the drawer tree
  final Set<String> _expandedFolders = {};
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
      _openEditor(nav, provider, note);
      return;
    }

    final tpl = await showModalBottomSheet<NoteTemplate?>(
      context: context,
      showDragHandle: true,
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
      _openEditor(nav, provider, note);
    }
  }

  void _openEditor(NavigatorState nav, NotesProvider provider, NoteModel note) {
    nav.push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: NoteEditorScreen(note: note),
        ),
      ),
    );
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

    return Scaffold(
      key: NotesScreen.scaffoldKey,
      appBar: AppBar(
        title: const Text('Заметки'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Папки',
          onPressed: () => NotesScreen.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Новая заметка',
            onPressed: () => _createNote(context),
          ),
        ],
      ),
      drawer: _buildDrawer(provider, cs),
      body: Column(
        children: [
          // Search bar
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

          // Notes list (swipe down to create new note)
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
                              height: MediaQuery.of(context).size.height * 0.5,
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
                            final title = note.title.isEmpty
                                ? 'Без названия'
                                : note.title;
                            final subtitle = _extractSubtitle(note.content);

                            return Dismissible(
                              key: ValueKey(note.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: cs.error,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: Icon(Icons.delete, color: cs.onError),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                  context: ctx,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Удалить заметку?'),
                                    content: Text(title),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Отмена'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Удалить'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (_) => provider.deleteNote(note.id),
                              child: ListTile(
                                title: Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: subtitle.isNotEmpty
                                    ? Text(subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)
                                    : null,
                                trailing: Text(
                                  _formatDate(note.updatedAt),
                                  style: TextStyle(
                                      fontSize: 12, color: cs.secondary),
                                ),
                                onTap: () => _openEditor(Navigator.of(ctx),
                                    ctx.read<NotesProvider>(), note),
                                onLongPress: () => _showNoteOptions(note),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Note long-press options (move to folder) ──────────────────────────────
  void _showNoteOptions(NoteModel note) {
    final provider = context.read<NotesProvider>();
    final folders = provider.folders;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text('Переместить в папку',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.onSurface)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Без папки'),
              selected: note.folderId == null,
              onTap: () async {
                await provider.moveNoteToFolder(note.id, null);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
            ),
            for (final f in folders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f['name'] as String? ?? ''),
                selected: note.folderId == f['id'],
                onTap: () async {
                  await provider.moveNoteToFolder(note.id, f['id'] as String);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Sidebar drawer (Obsidian-style tree) ──────────────────────────────────
  Widget _buildDrawer(NotesProvider provider, ColorScheme cs) {
    final rootNotes = provider.notes.where((n) => n.folderId == null).toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.folder_copy_outlined, color: cs.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Заметки',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.create_new_folder_outlined),
                    tooltip: 'Создать папку',
                    onPressed: _createFolder,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Folders ──
                  for (final folder in provider.folders)
                    _buildFolderTile(provider, folder, cs),

                  // ── Root notes (без папки) ──
                  if (rootNotes.isNotEmpty) ...[
                    if (provider.folders.isNotEmpty) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                      child: Text('Без папки',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.secondary,
                              fontWeight: FontWeight.w600)),
                    ),
                    for (final note in rootNotes)
                      _buildDrawerNoteTile(note, cs),
                  ],

                  // ── Empty state ──
                  if (provider.folders.isEmpty && rootNotes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 32),
                      child: Center(
                        child: Text('Нет заметок',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.4))),
                      ),
                    ),
                ],
              ),
            ),

            // ── Template manager link ──
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.dashboard_customize_outlined,
                  color: cs.primary, size: 22),
              title: const Text('Шаблоны'),
              dense: true,
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: provider,
                      child: const TemplateListScreen(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderTile(
      NotesProvider provider, Map<String, dynamic> folder, ColorScheme cs) {
    final folderId = folder['id'] as String;
    final folderName = folder['name'] as String? ?? '';
    final folderNotes =
        provider.notes.where((n) => n.folderId == folderId).toList();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: const Color(0x00000000)),
      child: GestureDetector(
        onLongPress: () => _showFolderMenu(folderId, folderName),
        child: ExpansionTile(
          key: PageStorageKey(folderId),
          initiallyExpanded: _expandedFolders.contains(folderId),
          onExpansionChanged: (expanded) {
            if (expanded) {
              _expandedFolders.add(folderId);
            } else {
              _expandedFolders.remove(folderId);
            }
          },
          leading: Icon(
            _expandedFolders.contains(folderId)
                ? Icons.folder_open
                : Icons.folder_outlined,
            size: 20,
            color: cs.primary,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(folderName, style: const TextStyle(fontSize: 14)),
              ),
              Text('${folderNotes.length}',
                  style: TextStyle(fontSize: 12, color: cs.secondary)),
            ],
          ),
          children: folderNotes.isEmpty
              ? [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Text('Пусто',
                        style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: cs.secondary)),
                  )
                ]
              : folderNotes
                  .map((note) => _buildDrawerNoteTile(note, cs))
                  .toList(),
        ),
      ),
    );
  }

  void _showFolderMenu(String id, String name) {
    showModalBottomSheet(
      context: context,
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

  Widget _buildDrawerNoteTile(NoteModel note, ColorScheme cs) {
    final title = note.title.isEmpty ? 'Без названия' : note.title;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(Icons.description_outlined, size: 18, color: cs.secondary),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13)),
      trailing: Text(_formatDate(note.updatedAt),
          style: TextStyle(fontSize: 10, color: cs.secondary)),
      onTap: () {
        Navigator.pop(context); // close drawer
        _openEditor(Navigator.of(context), context.read<NotesProvider>(), note);
      },
      onLongPress: () {
        Navigator.pop(context); // close drawer
        _showNoteOptions(note);
      },
    );
  }
}
