import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../features/cases/models/case.dart';

class CaseDatabase {
  CaseDatabase._();
  static final CaseDatabase instance = CaseDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dir = await getApplicationSupportDirectory();
    final file = p.join(dir.path, 'claimmitra.sqlite');
    _database = await databaseFactoryFfi.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cases (
              id TEXT PRIMARY KEY,
              case_number TEXT,
              received_date TEXT NOT NULL,
              accident_date TEXT,
              client_name TEXT NOT NULL,
              address TEXT NOT NULL DEFAULT '',
              phone TEXT NOT NULL DEFAULT '',
              police_station TEXT NOT NULL DEFAULT '',
              responsible_party TEXT NOT NULL DEFAULT '',
              police_documents_date TEXT,
              case_filed_date TEXT,
              evidence_date TEXT,
              award_date TEXT,
              deposit_date TEXT,
              deposit_amount REAL,
              fees_received_date TEXT,
              fees_amount REAL,
              ep_filed_date TEXT,
              execution_deposit_date TEXT,
              execution_deposit_amount REAL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_cases_received_date ON cases(received_date)');
          await db.execute('CREATE INDEX idx_cases_case_number ON cases(case_number)');
        },
      ),
    );
    return _database!;
  }

  Future<List<CaseRecord>> allCases() async {
    final db = await database;
    final rows = await db.query('cases', orderBy: 'received_date DESC, case_number ASC, client_name COLLATE NOCASE ASC');
    return rows.map(CaseRecord.fromMap).toList();
  }

  Future<CaseRecord?> getCase(String id) async {
    final db = await database;
    final rows = await db.query('cases', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : CaseRecord.fromMap(rows.first);
  }

  Future<void> save(CaseRecord record) async {
    final db = await database;
    await db.insert('cases', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveMany(List<CaseRecord> records) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in records) {
        batch.insert('cases', record.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.delete('cases', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMany(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in ids) {
        batch.delete('cases', where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> count() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM cases');
    return (rows.first['total'] as int?) ?? 0;
  }
}
