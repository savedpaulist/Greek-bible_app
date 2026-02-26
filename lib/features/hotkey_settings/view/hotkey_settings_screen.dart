// lib/hotkey_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/app_state.dart';

class HotkeySettingsScreen extends StatelessWidget {
  const HotkeySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Горячие клавиши')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer<AppState>(
          builder: (_, state, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Настройте клавиши физических кнопок устройства (например, Onyx Boox).',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),

              _HotkeyRow(
                label: 'Прокрутка ВНИЗ (следующая страница)',
                currentKeyId: state.scrollDownKeyId,
                icon: Icons.arrow_downward,
                onSet: (id) => state.setScrollDownKey(id),
                onClear: () => state.setScrollDownKey(0),
              ),
              const SizedBox(height: 16),

              _HotkeyRow(
                label: 'Прокрутка ВВЕРХ (предыдущая страница)',
                currentKeyId: state.scrollUpKeyId,
                icon: Icons.arrow_upward,
                onSet: (id) => state.setScrollUpKey(id),
                onClear: () => state.setScrollUpKey(0),
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              Text(
                'Как это работает:\n'
                '• Нажмите «Назначить» рядом с нужным действием\n'
                '• В появившемся диалоге нажмите физическую клавишу\n'
                '• Клавиша будет запомнена\n'
                '• При чтении Библии эта клавиша прокрутит экран на одну страницу',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _HotkeyRow extends StatelessWidget {
  final String label;
  final int currentKeyId;
  final IconData icon;
  final void Function(int) onSet;
  final VoidCallback onClear;

  const _HotkeyRow({
    required this.label,
    required this.currentKeyId,
    required this.icon,
    required this.onSet,
    required this.onClear,
  });

  String _keyName(int id) {
    if (id == 0) return 'не назначено';
    // Try to find a human-readable name
    try {
      final key = LogicalKeyboardKey.findKeyByKeyId(id);
      return key?.keyLabel ?? 'keyId: $id';
    } catch (_) {
      return 'keyId: $id';
    }
  }

  Future<void> _captureKey(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _KeyCaptureDialog(),
    );
    if (result != null && result != 0) onSet(result);
  }

  @override
  Widget build(BuildContext context) {
    final keyName = _keyName(currentKeyId);
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          'Назначена: $keyName',
          style: TextStyle(
            color: currentKeyId == 0
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.primary,
            fontWeight: currentKeyId == 0
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _captureKey(context),
              child: const Text('Назначить'),
            ),
            if (currentKeyId != 0)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Сбросить',
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: waits for a key press and returns its keyId
// ─────────────────────────────────────────────────────────────────────────────
class _KeyCaptureDialog extends StatefulWidget {
  const _KeyCaptureDialog();

  @override
  State<_KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<_KeyCaptureDialog> {
  String _status = 'Нажмите любую клавишу…';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Захват клавиши'),
      content: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) {
            final id = event.logicalKey.keyId;
            final navigator = Navigator.of(context);
            setState(() {
              _status = 'Клавиша: ${event.logicalKey.keyLabel}\n(keyId: $id)';
            });
            // Small delay so user sees the name, then close
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) navigator.pop(id);
            });
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SizedBox(
          width: 260,
          height: 80,
          child: Center(
            child: Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
