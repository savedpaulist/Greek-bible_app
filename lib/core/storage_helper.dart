// lib/core/storage_helper.dart
//
// Обнаружение доступных хранилищ (Android: внутренняя + SD‑карта).
// На других платформах возвращается только внутреннее хранилище.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// One available storage location.
class StorageOption {
  final String path;
  final String label;
  final bool isExternal;

  const StorageOption({
    required this.path,
    required this.label,
    this.isExternal = false,
  });
}

/// Returns a list of usable storage paths.
/// On Android with an SD card, the list will contain ≥ 2 entries.
Future<List<StorageOption>> getAvailableStoragePaths() async {
  final options = <StorageOption>[];

  // Internal storage – always available
  final internalPath = await getDatabasesPath();
  options.add(StorageOption(
    path: internalPath,
    label: 'Внутренняя память',
  ));

  if (Platform.isAndroid) {
    try {
      final dirs = await getExternalStorageDirectories();
      if (dirs != null) {
        for (int i = 0; i < dirs.length; i++) {
          final dbDir = Directory(p.join(dirs[i].path, 'databases'));
          if (!dbDir.existsSync()) {
            dbDir.createSync(recursive: true);
          }
          // Check that the directory is actually writable
          final testFile = File(p.join(dbDir.path, '.probe'));
          try {
            testFile.writeAsStringSync('ok');
            testFile.deleteSync();
          } catch (_) {
            continue; // not writable – skip
          }

          // Index 0 is primary "external" (phone's shared storage, not SD).
          // Index 1+ are removable SD cards.
          if (i == 0) {
            // This is the primary external storage — typically larger than
            // the internal databases dir but still on the phone.
            // Only offer it when it differs from internal path.
            if (dbDir.path != internalPath) {
              options.add(StorageOption(
                path: dbDir.path,
                label: 'Общая память телефона',
                isExternal: false,
              ));
            }
          } else {
            options.add(StorageOption(
              path: dbDir.path,
              label: 'SD‑карта${dirs.length > 2 ? ' $i' : ''}',
              isExternal: true,
            ));
          }
        }
      }
    } catch (_) {
      // path_provider failed — fall through (internal only)
    }
  }

  return options;
}
