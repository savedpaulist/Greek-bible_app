// lib/features/notes/view/template_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../data/note_model.dart';
import '../provider/notes_provider.dart';

/// Screen listing all templates with add / edit / delete / preview.
class TemplateListScreen extends StatelessWidget {
  const TemplateListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шаблоны заметок'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Создать шаблон',
            onPressed: () => _openEditor(context, null),
          ),
        ],
      ),
      body: Consumer<NotesProvider>(
        builder: (_, provider, __) {
          final templates = provider.templates;
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined,
                      size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('Нет шаблонов',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Создать шаблон'),
                    onPressed: () => _openEditor(context, null),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: templates.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: cs.outlineVariant),
            itemBuilder: (_, i) {
              final t = templates[i];
              return ListTile(
                leading: Icon(Icons.description_outlined,
                    color: cs.primary),
                title: Text(t.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  t.content.isEmpty
                      ? 'Пустой шаблон'
                      : t.content.length > 80
                          ? '${t.content.substring(0, 80)}…'
                          : t.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                trailing: PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Редактировать'))),
                    const PopupMenuItem(
                        value: 'preview',
                        child: ListTile(
                            leading: Icon(Icons.visibility),
                            title: Text('Предпросмотр'))),
                    const PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                            leading: Icon(Icons.copy),
                            title: Text('Дублировать'))),
                    const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                            leading:
                                Icon(Icons.delete, color: Colors.red),
                            title: Text('Удалить',
                                style:
                                    TextStyle(color: Colors.red)))),
                  ],
                  onSelected: (action) =>
                      _onAction(context, action, t),
                ),
                onTap: () => _openEditor(context, t),
              );
            },
          );
        },
      ),
    );
  }

  void _onAction(
      BuildContext context, String action, NoteTemplate t) {
    switch (action) {
      case 'edit':
        _openEditor(context, t);
        break;
      case 'preview':
        _showPreview(context, t);
        break;
      case 'duplicate':
        _duplicate(context, t);
        break;
      case 'delete':
        _confirmDelete(context, t);
        break;
    }
  }

  void _openEditor(BuildContext context, NoteTemplate? existing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<NotesProvider>(),
          child: _TemplateEditorPage(template: existing),
        ),
      ),
    );
  }

  void _showPreview(BuildContext context, NoteTemplate t) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(t.name,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ),
            const Divider(height: 1),
            Expanded(
              child: Markdown(
                data: t.content,
                controller: ctrl,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _duplicate(BuildContext context, NoteTemplate t) {
    final provider = context.read<NotesProvider>();
    final copy = NoteTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${t.name} (копия)',
      content: t.content,
    );
    provider.saveTemplate(copy);
  }

  void _confirmDelete(BuildContext context, NoteTemplate t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить шаблон?'),
        content: Text('Шаблон «${t.name}» будет удалён безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              context.read<NotesProvider>().deleteTemplate(t.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single template editor (name + markdown content)
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateEditorPage extends StatefulWidget {
  final NoteTemplate? template;
  const _TemplateEditorPage({this.template});

  @override
  State<_TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<_TemplateEditorPage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _contentCtrl;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template?.name ?? '');
    _contentCtrl =
        TextEditingController(text: widget.template?.content ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название шаблона')),
      );
      return;
    }

    final provider = context.read<NotesProvider>();
    final tpl = NoteTemplate(
      id: widget.template?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      content: _contentCtrl.text,
    );
    provider.saveTemplate(tpl);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Шаблон «$name» сохранён')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNew = widget.template == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Новый шаблон' : 'Редактировать шаблон'),
        actions: [
          IconButton(
            icon: Icon(_preview ? Icons.edit_note : Icons.visibility,
                size: 22),
            tooltip: _preview ? 'Редактировать' : 'Предпросмотр',
            onPressed: () => setState(() => _preview = !_preview),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Сохранить'),
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _preview ? _buildPreview(cs) : _buildEditor(cs),
    );
  }

  Widget _buildEditor(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _nameCtrl,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'Название шаблона',
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            maxLines: 1,
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        // Toolbar hint
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Используйте Markdown разметку. '
            'Плейсхолдеры: {{title}}, {{date}}, {{book}}, {{chapter}}, {{verse}}',
            style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _contentCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                height: 1.5,
                color: cs.onSurface,
              ),
              decoration: const InputDecoration(
                hintText: 'Содержание шаблона (Markdown)…',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    final content = _contentCtrl.text.isEmpty
        ? '*Шаблон пуст*'
        : _contentCtrl.text;

    return Markdown(
      data: '# ${_nameCtrl.text}\n\n$content',
      selectable: true,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: cs.onSurface),
        h2: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: cs.onSurface),
        h3: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: cs.onSurface),
        p: TextStyle(fontSize: 15, height: 1.6, color: cs.onSurface),
        code: TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          backgroundColor: cs.surfaceContainerHighest,
          color: cs.primary,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: cs.primary, width: 3)),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        listBullet: TextStyle(color: cs.primary),
      ),
    );
  }
}
