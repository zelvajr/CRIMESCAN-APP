import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/case_model.dart';
import '../../models/evidence_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'forensic_spidercam.db'),
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cases (
        id           TEXT PRIMARY KEY,
        case_number  TEXT NOT NULL,
        fir_number   TEXT,
        officer_name TEXT NOT NULL,
        agency       TEXT,
        location     TEXT,
        scene_type   TEXT,
        notes        TEXT,
        latitude     REAL,
        longitude    REAL,
        created_at   TEXT NOT NULL,
        is_active    INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE evidence (
        id               TEXT PRIMARY KEY,
        case_id          TEXT NOT NULL,
        evidence_number  TEXT NOT NULL,
        category         TEXT NOT NULL,
        photo_path       TEXT,
        video_path       TEXT,
        voice_note_path  TEXT,
        notes            TEXT,
        latitude         REAL,
        longitude        REAL,
        sha256_hash      TEXT NOT NULL,
        collected_by     TEXT NOT NULL,
        timestamp        TEXT NOT NULL,
        synced           INTEGER DEFAULT 0,
        FOREIGN KEY (case_id) REFERENCES cases(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp  TEXT NOT NULL,
        action     TEXT NOT NULL,
        details    TEXT,
        officer    TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        evidence_id   TEXT NOT NULL,
        status        TEXT DEFAULT 'PENDING',
        attempts      INTEGER DEFAULT 0,
        last_attempt  TEXT
      )
    ''');
  }

  // ── CASES ──────────────────────────────────
  Future<void> insertCase(CaseModel c) async =>
      await _db!.insert('cases', c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<CaseModel>> getCases() async {
    final maps = await _db!.query('cases', orderBy: 'created_at DESC');
    return maps.map(CaseModel.fromMap).toList();
  }

  Future<CaseModel?> getCase(String id) async {
    final maps = await _db!.query('cases', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : CaseModel.fromMap(maps.first);
  }

  // ── EVIDENCE ───────────────────────────────
  Future<void> insertEvidence(EvidenceModel e) async =>
      await _db!.insert('evidence', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<EvidenceModel>> getEvidenceForCase(String caseId) async {
    final maps = await _db!.query('evidence',
        where: 'case_id = ?',
        whereArgs: [caseId],
        orderBy: 'timestamp ASC');
    return maps.map(EvidenceModel.fromMap).toList();
  }

  Future<void> markEvidenceSynced(String evidenceId) async =>
      await _db!.update('evidence', {'synced': 1},
          where: 'id = ?', whereArgs: [evidenceId]);

  Future<List<EvidenceModel>> getUnsyncedEvidence() async {
    final maps = await _db!.query('evidence',
        where: 'synced = 0', orderBy: 'timestamp ASC');
    return maps.map(EvidenceModel.fromMap).toList();
  }

  // ── AUDIT ──────────────────────────────────
  Future<void> log(String action,
      {String? details, String? officer}) async =>
      await _db!.insert('audit_log', {
        'timestamp': DateTime.now().toIso8601String(),
        'action':    action,
        'details':   details,
        'officer':   officer ?? 'UNKNOWN',
      });

  // ── SYNC QUEUE ─────────────────────────────
  Future<void> addToSyncQueue(String evidenceId) async =>
      await _db!.insert('sync_queue', {'evidence_id': evidenceId});

  Future<void> updateSyncStatus(int queueId, String status) async =>
      await _db!.update('sync_queue',
          {'status': status, 'last_attempt': DateTime.now().toIso8601String()},
          where: 'id = ?', whereArgs: [queueId]);

  // ── EVIDENCE COUNT ─────────────────────────
  Future<int> getEvidenceCount(String caseId) async {
    final result = await _db!.rawQuery(
        'SELECT COUNT(*) as count FROM evidence WHERE case_id = ?', [caseId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}