import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'database/backup_service.dart';
import 'database/case_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Backups must never prevent the app from opening. Failures are logged and
  // can be surfaced in the UI in a follow-up improvement.
  try {
    await CaseDatabase.instance.database;
    await BackupService.instance.createAutomaticBackupIfDue();
  } catch (error, stackTrace) {
    debugPrint('ClaimMitra automatic backup failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const CaseManagerApp());
}
