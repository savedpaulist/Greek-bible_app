// lib/ui/setup_screen.dart
//
// First-launch setup screen: storage picker → asset extraction → indexing.
// Shows animated progress for each phase.

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/asset_extractor.dart';
import '../core/db/db_service.dart';
import '../core/prefs/prefs_service.dart';
import '../core/storage_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wrapper MaterialApp for the setup screen
// ─────────────────────────────────────────────────────────────────────────────
class SetupApp extends StatelessWidget {
  final PrefsService prefs;
  final VoidCallback onComplete;

  const SetupApp({super.key, required this.prefs, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1D2021),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8EC07C),
          onPrimary: Color(0xFF1D2021),
          surface: Color(0xFF282828),
          onSurface: Color(0xFFF5ECD7),
        ),
      ),
      home: _SetupScreen(prefs: prefs, onComplete: onComplete),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup screen
// ─────────────────────────────────────────────────────────────────────────────
enum _Phase { storage, extracting, indexing, done }

class _SetupScreen extends StatefulWidget {
  final PrefsService prefs;
  final VoidCallback onComplete;

  const _SetupScreen({required this.prefs, required this.onComplete});

  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  _Phase _phase = _Phase.storage;
  String _statusText = 'Подготовка…';
  double _progress = 0.0;
  int _currentFile = 0;
  int _totalFiles = AssetExtractor.totalFiles;
  String? _error;

  List<StorageOption>? _storageOptions;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Android: check for multiple storage locations
    if (Platform.isAndroid && !widget.prefs.dbStoragePathSet) {
      try {
        final options = await getAvailableStoragePaths();
        if (options.length > 1) {
          if (!mounted) return;
          setState(() {
            _storageOptions = options;
            _phase = _Phase.storage;
          });
          return;
        }
        // Only one option → auto-select
        await widget.prefs.setDbStoragePath(options.first.path);
      } catch (_) {
        // Fallback to default
      }
    }
    _startExtraction();
  }

  Future<void> _onStoragePicked(String path) async {
    await widget.prefs.setDbStoragePath(path);
    _startExtraction();
  }

  Future<void> _startExtraction() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.extracting;
      _statusText = 'Распаковка баз данных…';
      _progress = 0;
    });

    final targetDir =
        widget.prefs.dbStoragePath ?? await AssetExtractor.defaultDbDir();

    try {
      await AssetExtractor.extractAll(
        targetDir: targetDir,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _currentFile = p.currentFile;
            _totalFiles = p.totalFiles;
            _statusText = p.currentLabel;
            _progress = p.overallProgress;
          });
        },
      );

      await widget.prefs.setAssetsExtracted(true);
      _startIndexing(targetDir);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка распаковки: $e';
      });
    }
  }

  Future<void> _startIndexing(String targetDir) async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.indexing;
      _statusText = 'Индексация для поиска…';
      _progress = 0;
    });

    try {
      // Open databases temporarily for indexing
      final db = DBService();
      await db.initBible(basePath: targetDir);
      await db.initDictionaries();

      await db.buildIndex(onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _statusText = 'Индексация… ${(p * 100).toInt()}%';
        });
      });

      await widget.prefs.setIndexBuilt(true);
      await widget.prefs.setIndexVersion(2);
      db.dispose();

      _onSetupDone();
    } catch (e) {
      debugPrint('Setup: index error: $e');
      // Indexing failure is not critical — let the user proceed.
      // It will be attempted again on the next launch.
      _onSetupDone();
    }
  }

  void _onSetupDone() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.done;
      _statusText = 'Готово!';
      _progress = 1.0;
    });

    // No delay — proceed immediately.
    widget.onComplete();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Icon (no animation) ──
              const Icon(
                Icons.auto_stories_rounded,
                size: 80,
                color: Color(0xFF8EC07C),
              ),
                const SizedBox(height: 16),
                const Text(
                  'Греческая Библия',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF5ECD7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Подготовка приложения',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFFF5ECD7).withValues(alpha: 0.5),
                  ),
                ),

                const Spacer(),

                // ── Phase content ──
                if (_error != null)
                  _buildError()
                else if (_phase == _Phase.storage)
                  _buildStorageChoice()
                else if (_phase == _Phase.extracting)
                  _buildExtractingProgress()
                else if (_phase == _Phase.indexing)
                  _buildIndexingProgress()
                else if (_phase == _Phase.done)
                  _buildDone(),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  // ── Storage choice ──────────────────────────────────────────────────────

  Widget _buildStorageChoice() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.storage_rounded, size: 36, color: Color(0xFF8EC07C)),
        const SizedBox(height: 12),
        const Text(
          'Где хранить данные?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Словари занимают ~1 ГБ.\nВыберите место хранения:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFFF5ECD7).withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        if (_storageOptions != null)
          ...(_storageOptions!.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: Icon(
                        opt.isExternal ? Icons.sd_card : Icons.phone_android),
                    label: Text(opt.label),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                      backgroundColor: const Color(0xFF3C3836),
                    ),
                    onPressed: () => _onStoragePicked(opt.path),
                  ),
                ),
              ))),
      ],
    );
  }

  // ── Extraction progress ─────────────────────────────────────────────────

  Widget _buildExtractingProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Step indicator
        _StepRow(
          steps: const ['Распаковка', 'Индексация'],
          current: 0,
        ),
        const SizedBox(height: 28),

        // File counter
        Text(
          '${_currentFile + 1} из $_totalFiles',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8EC07C),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _statusText,
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFFF5ECD7).withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),

        // Progress bar
        _AnimatedProgressBar(progress: _progress),

        const SizedBox(height: 8),
        Text(
          '${(_progress * 100).toInt()}%',
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFFF5ECD7).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ── Indexing progress ───────────────────────────────────────────────────

  Widget _buildIndexingProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepRow(
          steps: const ['Распаковка', 'Индексация'],
          current: 1,
        ),
        const SizedBox(height: 28),
        const Icon(
          Icons.manage_search_rounded,
          size: 36,
          color: Color(0xFF8EC07C),
        ),
        const SizedBox(height: 12),
        const Text(
          'Создание поискового индекса',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Это нужно сделать один раз…',
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFFF5ECD7).withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 20),
        _AnimatedProgressBar(progress: _progress),
        const SizedBox(height: 8),
        Text(
          '${(_progress * 100).toInt()}%',
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFFF5ECD7).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ── Done ────────────────────────────────────────────────────────────────

  Widget _buildDone() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFF8EC07C),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 36,
            color: Color(0xFF1D2021),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Всё готово!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8EC07C),
          ),
        ),
      ],
    );
  }

  // ── Error ───────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _startExtraction,
          child: const Text('Повторить'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator
// ─────────────────────────────────────────────────────────────────────────────
class _StepRow extends StatelessWidget {
  final List<String> steps;
  final int current;

  const _StepRow({required this.steps, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Container(
              width: 32,
              height: 2,
              color: i <= current
                  ? const Color(0xFF8EC07C)
                  : const Color(0xFF504945),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < current
                      ? const Color(0xFF8EC07C)
                      : i == current
                          ? const Color(0xFF8EC07C).withValues(alpha: 0.3)
                          : const Color(0xFF504945),
                  border: i == current
                      ? Border.all(color: const Color(0xFF8EC07C), width: 2)
                      : null,
                ),
                child: Center(
                  child: i < current
                      ? const Icon(Icons.check,
                          size: 16, color: Color(0xFF1D2021))
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: i == current
                                ? const Color(0xFF8EC07C)
                                : const Color(0xFFA89984),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[i],
                style: TextStyle(
                  fontSize: 11,
                  color: i <= current
                      ? const Color(0xFFF5ECD7)
                      : const Color(0xFF928374),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smooth animated progress bar
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedProgressBar extends StatelessWidget {
  final double progress;

  const _AnimatedProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 30,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFF3C3836),
          valueColor: const AlwaysStoppedAnimation(Color(0xFF8EC07C)),
        ),
      ),
    );
  }
}
