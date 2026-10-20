import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'case_database.dart';

/// Creates a verified SQLite snapshot at most once every 24 hours and keeps
/// the 10 most recent successful snapshots.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const backupInterval = Duration(hours: 24);
  static const maxBackups = 10;
  static const _prefix = 'claimmitra_';
  static const _suffix = '.sqlite';

  Future<Directory> get backupDirectory async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'backups'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<List<File>> listBackups() async {
    final dir = await backupDirectory;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => p.basename(file.path).startsWith(_prefix) &&
            p.basename(file.path).endsWith(_suffix))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Returns true when a new backup was created, false when not yet due.
  Future<bool> createAutomaticBackupIfDue() async {
    final existing = await listBackups();
    if (existing.isNotEmpty) {
      final latest = existing.first;
      final age = DateTime.now().difference(await latest.lastModified());
      if (age < backupInterval) return false;
    }
    await createBackup();
    return true;
  }

  /// Creates and verifies a consistent snapshot while the database is open.
  Future<File> createBackup() async {
    final db = await CaseDatabase.instance.database;
    final dir = await backupDirectory;
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final file = File(p.join(dir.path, '$_prefix$stamp$_suffix'));
    if (await file.exists()) await file.delete();

    // VACUUM INTO produces a consistent SQLite snapshot, including data that
    // may currently be in the source database's WAL file.
    final escapedPath = file.absolute.path.replaceAll("'", "''");
    try {
      await db.execute("VACUUM INTO '$escapedPath'");
      if (!await file.exists() || await file.length() == 0) {
        throw StateError('Backup file was not created or is empty.');
      }

      final checkDb = await databaseFactoryFfi.openDatabase(file.path);
      try {
        final result = await checkDb.rawQuery('PRAGMA integrity_check');
        if (result.isEmpty || result.first.values.first != 'ok') {
          throw StateError('SQLite integrity check failed for the backup.');
        }
      } finally {
        await checkDb.close();
      }

      await _pruneOldBackups();
      return file;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> _pruneOldBackups() async {
    final files = await listBackups();
    for (final file in files.skip(maxBackups)) {
      await file.delete();
    }
  }
}
