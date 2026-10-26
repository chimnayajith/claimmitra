import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../features/cases/models/case.dart';

class DuplicateCaseNumberException implements Exception {
  final String caseNumber;
  const DuplicateCaseNumberException(this.caseNumber);

  @override
  String toString() => 'Case number $caseNumber already exists.';
}

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
        version: 3,
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
              award_type TEXT,
              award_amount REAL,
              award_amount_interest_cost REAL,
              deposit_date TEXT,
              deposit_amount REAL,
              fees_received_date TEXT,
              fees_amount REAL,
              ep_filed_date TEXT,
              execution_deposit_date TEXT,
              execution_deposit_amount REAL,
              court_filed TEXT NOT NULL DEFAULT '',
              advocates TEXT NOT NULL DEFAULT '',
              ep_filing_type TEXT,
              is_archived INTEGER NOT NULL DEFAULT 0,
              archived_at TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_cases_received_date ON cases(received_date)');
          await db.execute('CREATE INDEX idx_cases_case_number ON cases(case_number)');
          await db.execute('''CREATE TABLE case_audit (
            id INTEGER PRIMARY KEY AUTOINCREMENT, case_id TEXT NOT NULL,
            case_number TEXT, action TEXT NOT NULL, actor TEXT NOT NULL,
            occurred_at TEXT NOT NULL
          )''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE cases ADD COLUMN award_type TEXT');
            await db.execute('ALTER TABLE cases ADD COLUMN award_amount REAL');
            await db.execute('ALTER TABLE cases ADD COLUMN award_amount_interest_cost REAL');
          }
          if (oldVersion < 3) {
            // Before schema v3, the form wrote YEAR/NUMBER. Normalize those
            // rows once during the same SQLite upgrade transaction. New v3
            // writes already use NUMBER/YEAR.
            await db.execute('''
              UPDATE cases
              SET case_number = substr(case_number, instr(case_number, '/') + 1)
                || '/' || substr(case_number, 1, instr(case_number, '/') - 1)
              WHERE case_number IS NOT NULL
                AND length(case_number) - length(replace(case_number, '/', '')) = 1
                AND length(substr(case_number, 1, instr(case_number, '/') - 1)) = 4
                AND length(substr(case_number, instr(case_number, '/') + 1)) > 0
                AND substr(case_number, 1, instr(case_number, '/') - 1) NOT GLOB '*[^0-9]*'
                AND CAST(substr(case_number, 1, instr(case_number, '/') - 1) AS INTEGER) BETWEEN 1900 AND 2200
                AND substr(case_number, instr(case_number, '/') + 1) NOT GLOB '*[^0-9]*'
            ''');
            await db.execute("ALTER TABLE cases ADD COLUMN court_filed TEXT NOT NULL DEFAULT ''");
            await db.execute("ALTER TABLE cases ADD COLUMN advocates TEXT NOT NULL DEFAULT ''");
            await db.execute('ALTER TABLE cases ADD COLUMN ep_filing_type TEXT');
            await db.execute('ALTER TABLE cases ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0');
            await db.execute('ALTER TABLE cases ADD COLUMN archived_at TEXT');
            await db.execute("UPDATE cases SET ep_filing_type = 'EP' WHERE ep_filed_date IS NOT NULL AND ep_filing_type IS NULL");
            await db.execute('''CREATE TABLE case_audit (
              id INTEGER PRIMARY KEY AUTOINCREMENT, case_id TEXT NOT NULL,
              case_number TEXT, action TEXT NOT NULL, actor TEXT NOT NULL,
              occurred_at TEXT NOT NULL
            )''');
          }
        },
      ),
    );
    return _database!;
  }

  Future<List<CaseRecord>> allCases({bool includeArchived = false}) async {
    final db = await database;
    final rows = await db.query('cases', where: includeArchived ? null : 'is_archived = 0', orderBy: 'received_date DESC, case_number ASC, client_name COLLATE NOCASE ASC');
    return rows.map(CaseRecord.fromMap).toList();
  }

  Future<CaseRecord?> getCase(String id) async {
    final db = await database;
    final rows = await db.query('cases', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : CaseRecord.fromMap(rows.first);
  }

  Future<void> save(CaseRecord record) async {
    final db = await database;
    await _ensureCaseNumberAvailable(db, record);
    await db.insert('cases', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> saveMany(List<CaseRecord> records) async {
    if (records.isEmpty) return 0;
    final db = await database;
    var saved = 0;
    await db.transaction((txn) async {
      final usedNumbers = <String, String>{};
      final existing = await txn.query('cases', columns: ['id', 'case_number']);
      for (final row in existing) {
        final number = normalizeCaseNumber(row['case_number'] as String?);
        if (number != null) usedNumbers[number] = row['id'] as String;
      }
      final batch = txn.batch();
      for (final record in records) {
        final number = normalizeCaseNumber(record.caseNumber);
        if (number != null) {
          final existingId = usedNumbers[number];
          if (existingId != null && existingId != record.id) continue;
          usedNumbers[number] = record.id;
        }
        batch.insert('cases', record.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
        saved++;
      }
      await batch.commit(noResult: true);
    });
    return saved;
  }

  Future<void> _ensureCaseNumberAvailable(Database db, CaseRecord record) async {
    final number = normalizeCaseNumber(record.caseNumber);
    if (number == null) return;
    final rows = await db.query('cases', columns: ['id', 'case_number']);
    for (final row in rows) {
      final existingNumber = normalizeCaseNumber(row['case_number'] as String?);
      if (existingNumber == number && row['id'] != record.id) {
        throw DuplicateCaseNumberException(record.caseNumber!.trim());
      }
    }
  }

  static String? normalizeCaseNumber(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final compact = trimmed.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final parts = compact.split('/');
    if (parts.length != 2) return compact;
    final hasYear = parts.any((part) {
      final year = int.tryParse(part);
      return part.length == 4 && year != null && year >= 1900 && year <= 2200;
    });
    if (parts.every((part) => RegExp(r'^\d+$').hasMatch(part)) && hasYear) {
      parts.sort();
      return parts.join('/');
    }
    return compact;
  }

  Future<void> archive(String id, {String actor = 'local user'}) async {
    await setArchived([id], archived: true, actor: actor);
  }

  Future<void> restore(String id, {String actor = 'local user'}) async {
    await setArchived([id], archived: false, actor: actor);
  }

  Future<void> setArchived(List<String> ids, {required bool archived, String actor = 'local user'}) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      for (final id in ids) {
        final rows = await txn.query('cases', columns: ['case_number', 'is_archived'], where: 'id = ?', whereArgs: [id]);
        if (rows.isEmpty) continue;
        if (((rows.first['is_archived'] as int? ?? 0) != 0) == archived) continue;
        await txn.update('cases', {
          'is_archived': archived ? 1 : 0,
          'archived_at': archived ? now : null,
          'updated_at': now,
        }, where: 'id = ?', whereArgs: [id]);
        await txn.insert('case_audit', {
          'case_id': id,
          'case_number': rows.first['case_number'],
          'action': archived ? 'archive' : 'restore',
          'actor': actor,
          'occurred_at': now,
        });
      }
    });
  }

  Future<int> count() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM cases WHERE is_archived = 0');
    return (rows.first['total'] as int?) ?? 0;
  }
}
