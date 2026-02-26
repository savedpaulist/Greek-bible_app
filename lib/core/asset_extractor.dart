// lib/core/asset_extractor.dart
//
// Streaming extraction of gzip-compressed SQLite assets with progress.
// Handles both compressed (.gz) and uncompressed fallback assets.
// Uses atomic writes (tmp → rename) for crash resilience.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// One SQLite asset to extract.
class AssetEntry {
  final String gzAssetPath;  // compressed asset path
  final String rawAssetPath; // original uncompressed asset path (fallback)
  final String targetFile;   // file name on disk
  final String label;        // human-readable label

  const AssetEntry({
    required this.gzAssetPath,
    required this.rawAssetPath,
    required this.targetFile,
    required this.label,
  });
}

/// Progress info for extraction.
class ExtractionProgress {
  final int currentFile;
  final int totalFiles;
  final String currentLabel;
  final double overallProgress; // 0.0 – 1.0

  const ExtractionProgress({
    required this.currentFile,
    required this.totalFiles,
    required this.currentLabel,
    required this.overallProgress,
  });
}

class AssetExtractor {
  static const List<AssetEntry> assets = [
    AssetEntry(
      gzAssetPath: 'assets/LXX_BYZ_WORDS_ONLY.SQLite3.gz',
      rawAssetPath: 'assets/LXX_BYZ_WORDS_ONLY.SQLite3',
      targetFile: 'bible.db',
      label: 'Библейский текст',
    ),
    AssetEntry(
      gzAssetPath: 'assets/СтрДв.dictionary.SQLite3.gz',
      rawAssetPath: 'assets/СтрДв.dictionary.SQLite3',
      targetFile: 'dict_strongs.db',
      label: 'Словарь Стронга',
    ),
    AssetEntry(
      gzAssetPath: 'assets/BDAG3.dictionary.SQLite3.gz',
      rawAssetPath: 'assets/BDAG3.dictionary.SQLite3',
      targetFile: 'dict_bdag3.db',
      label: 'BDAG',
    ),
    AssetEntry(
      gzAssetPath: 'assets/TDNT.dictionary 2.SQLite3.gz',
      rawAssetPath: 'assets/TDNT.dictionary 2.SQLite3',
      targetFile: 'dict_tdnt.db',
      label: 'TDNT',
    ),
    AssetEntry(
      gzAssetPath: 'assets/CBTEL.dictionary.SQLite3.gz',
      rawAssetPath: 'assets/CBTEL.dictionary.SQLite3',
      targetFile: 'dict_cbtel.db',
      label: 'CBTEL',
    ),
    AssetEntry(
      gzAssetPath: 'assets/gr-en.dictionary.SQLite3.gz',
      rawAssetPath: 'assets/gr-en.dictionary.SQLite3',
      targetFile: 'dict_morph_gr_en.db',
      label: 'Морфологический словарь',
    ),
    AssetEntry(
      gzAssetPath: 'assets/DvorFull.sqlite3.gz',
      rawAssetPath: 'assets/DvorFull.sqlite3',
      targetFile: 'dict_dvor.db',
      label: 'Словарь Дворецкого',
    ),
    AssetEntry(
      gzAssetPath: 'assets/LSJ.dictionary.SQLite3.gz',
      rawAssetPath: 'assets/LSJ.dictionary.SQLite3',
      targetFile: 'dict_lsj.db',
      label: 'LSJ',
    ),
    AssetEntry(
      gzAssetPath: 'assets/Cambridge.sqlite3.gz',
      rawAssetPath: 'assets/Cambridge.sqlite3',
      targetFile: 'dict_cambridge.db',
      label: 'Cambridge',
    ),
  ];

  static int get totalFiles => assets.length;

  /// Extract all assets to [targetDir] with progress.
  /// Skips files that already exist on disk.
  static Future<void> extractAll({
    required String targetDir,
    void Function(ExtractionProgress)? onProgress,
  }) async {
    final dir = Directory(targetDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    for (int i = 0; i < assets.length; i++) {
      final entry = assets[i];
      final targetPath = p.join(targetDir, entry.targetFile);

      onProgress?.call(ExtractionProgress(
        currentFile: i,
        totalFiles: assets.length,
        currentLabel: entry.label,
        overallProgress: i / assets.length,
      ));

      // Skip already extracted
      if (File(targetPath).existsSync() &&
          File(targetPath).lengthSync() > 0) {
        continue;
      }

      await _extractOne(entry, targetPath);

      // Allow UI to update between files
      await Future.delayed(Duration.zero);
    }

    onProgress?.call(ExtractionProgress(
      currentFile: assets.length,
      totalFiles: assets.length,
      currentLabel: 'Готово',
      overallProgress: 1.0,
    ));
  }

  /// Extract a single asset to [targetPath].
  /// Tries compressed (.gz) first, falls back to uncompressed.
  /// Uses atomic write: .tmp → rename.
  static Future<void> _extractOne(AssetEntry entry, String targetPath) async {
    final tmpPath = '$targetPath.tmp';

    // Clean up any partial extraction from a previous interrupted attempt
    final tmpFile = File(tmpPath);
    if (tmpFile.existsSync()) tmpFile.deleteSync();

    Uint8List bytes;
    bool isCompressed = false;

    // Try compressed asset first
    try {
      final data = await rootBundle.load(entry.gzAssetPath);
      bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      isCompressed = true;
    } catch (_) {
      // Fallback: load uncompressed original
      try {
        final data = await rootBundle.load(entry.rawAssetPath);
        bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      } catch (e) {
        debugPrint('AssetExtractor: не найден ассет для ${entry.label}: $e');
        rethrow;
      }
    }

    if (isCompressed) {
      // Streaming gzip decompression to file.
      // This keeps memory low: only compressed bytes + decoder buffer.
      final output = File(tmpPath).openWrite();
      await Stream<List<int>>.value(bytes)
          .transform(gzip.decoder)
          .pipe(output);
    } else {
      // Write uncompressed bytes directly
      await File(tmpPath).writeAsBytes(bytes, flush: true);
    }

    // Atomic rename: ensures we never have a half-written database
    File(tmpPath).renameSync(targetPath);

    debugPrint('AssetExtractor: ✓ ${entry.label} → ${entry.targetFile}');
  }

  /// Check if all assets exist on disk.
  static bool isFullyExtracted(String targetDir) {
    for (final entry in assets) {
      final path = p.join(targetDir, entry.targetFile);
      if (!File(path).existsSync() || File(path).lengthSync() == 0) {
        return false;
      }
    }
    return true;
  }

  /// Resolve the default database directory (used when no custom path is set).
  static Future<String> defaultDbDir() async {
    return await getDatabasesPath();
  }
}
