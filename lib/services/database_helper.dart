import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'user_device_service.dart';
import '../models/gps_log.dart';
import '../models/journey_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('location_tracking.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE location_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journey_id TEXT NOT NULL,
        user_id TEXT NOT NULL DEFAULT '',
        user_name TEXT NOT NULL DEFAULT '',
        device_id TEXT NOT NULL DEFAULT '',
        device_model TEXT NOT NULL DEFAULT '',
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL NOT NULL,
        speed REAL NOT NULL,
        bearing REAL NOT NULL,
        altitude REAL NOT NULL,
        activity TEXT NOT NULL,
        battery_level INTEGER NOT NULL,
        provider TEXT NOT NULL,
        upload_status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE journey_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journey_id TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        json_data TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journey_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        event_type TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS journey_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          journey_id TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL,
          json_data TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE location_logs ADD COLUMN journey_id TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          journey_id TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          event_type TEXT NOT NULL,
          description TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      try {
        await db.execute("ALTER TABLE location_logs ADD COLUMN user_id TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE location_logs ADD COLUMN user_name TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE location_logs ADD COLUMN device_id TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE location_logs ADD COLUMN device_model TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
    }
  }

  /// Immediately save raw GPS log into SQLite
  Future<int> insertLog(GpsLog log) async {
    if (log.userId.trim().isEmpty || !UserDeviceService.instance.hasValidUserProfile) {
      print('DatabaseHelper Blocked: Cannot insert log without verified Sales Rep Profile!');
      return -1;
    }
    final db = await instance.database;
    return await db.insert('location_logs', log.toMap());
  }

  /// Save completed Journey Analysis Report
  Future<int> insertJourneyReport(JourneyAnalysisResult result) async {
    final db = await instance.database;
    return await db.insert(
      'journey_reports',
      {
        'journey_id': result.journeyId,
        'created_at': DateTime.now().toIso8601String(),
        'json_data': result.toJsonString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all completed Journey Reports sorted by created_at DESC
  Future<List<JourneyAnalysisResult>> getAllJourneyReports() async {
    final db = await instance.database;
    final res = await db.query(
      'journey_reports',
      orderBy: 'id DESC',
    );
    return res
        .map((row) => JourneyAnalysisResult.fromJsonString(row['json_data'] as String))
        .toList();
  }

  /// Retrieve latest Journey Analysis Report
  Future<JourneyAnalysisResult?> getLatestJourneyReport() async {
    final reports = await getAllJourneyReports();
    if (reports.isNotEmpty) return reports.first;
    return null;
  }

  /// Retrieve raw GPS logs belonging strictly to a specific journeyId
  Future<List<GpsLog>> getLogsForJourney(String journeyId) async {
    final db = await instance.database;
    final result = await db.query(
      'location_logs',
      where: 'journey_id = ?',
      whereArgs: [journeyId],
      orderBy: 'id ASC',
    );
    return result.map((json) => GpsLog.fromMap(json)).toList();
  }

  /// Retrieve the journey_id of the most recently recorded GPS log
  Future<String?> getLatestJourneyId() async {
    final db = await instance.database;
    final result = await db.query(
      'location_logs',
      columns: ['journey_id'],
      where: "journey_id != '' AND journey_id IS NOT NULL",
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['journey_id'] as String?;
    }
    return null;
  }

  /// Delete a specific journey report and its raw logs
  Future<void> deleteJourneyReport(String journeyId) async {
    final db = await instance.database;
    await db.delete('journey_reports', where: 'journey_id = ?', whereArgs: [journeyId]);
    await db.delete('location_logs', where: 'journey_id = ?', whereArgs: [journeyId]);
  }

  /// Retrieve all pending records for upload queue
  Future<List<GpsLog>> getPendingLogs() async {
    final db = await instance.database;
    final result = await db.query(
      'location_logs',
      where: 'upload_status = ?',
      whereArgs: ['Pending'],
      orderBy: 'id ASC',
    );
    return result.map((json) => GpsLog.fromMap(json)).toList();
  }

  /// Mark batch of records as Uploaded upon successful sync
  Future<int> markLogsAsUploaded(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await instance.database;
    final idList = ids.join(',');
    return await db.rawUpdate(
      'UPDATE location_logs SET upload_status = ? WHERE id IN ($idList)',
      ['Uploaded'],
    );
  }

  /// Get recent logs for UI display
  Future<List<GpsLog>> getAllLogs({int limit = 100}) async {
    final db = await instance.database;
    final result = await db.query(
      'location_logs',
      orderBy: 'id DESC',
      limit: limit,
    );
    return result.map((json) => GpsLog.fromMap(json)).toList();
  }

  /// Get summary statistics of logs
  Future<Map<String, int>> getStats() async {
    final db = await instance.database;
    final totalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM location_logs'),
    ) ?? 0;
    
    final pendingCount = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM location_logs WHERE upload_status = 'Pending'"),
    ) ?? 0;

    final uploadedCount = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM location_logs WHERE upload_status = 'Uploaded'"),
    ) ?? 0;

    return {
      'total': totalCount,
      'pending': pendingCount,
      'uploaded': uploadedCount,
    };
  }

  /// Clear database & reset AUTOINCREMENT counters back to 1
  Future<void> clearAllLogs() async {
    final db = await instance.database;
    await db.delete('location_logs');
    await db.delete('journey_reports');
    await db.delete('audit_logs');
    try {
      await db.delete('sqlite_sequence');
    } catch (_) {}
  }

  /// Insert a security or system audit log
  Future<int> insertAuditLog(String journeyId, String eventType, String description) async {
    final db = await instance.database;
    return await db.insert('audit_logs', {
      'journey_id': journeyId,
      'timestamp': DateTime.now().toIso8601String(),
      'event_type': eventType,
      'description': description,
    });
  }

  /// Retrieve all audit logs for a specific journeyId
  Future<List<Map<String, dynamic>>> getAuditLogs(String journeyId) async {
    final db = await instance.database;
    return await db.query(
      'audit_logs',
      where: 'journey_id = ?',
      whereArgs: [journeyId],
      orderBy: 'id ASC',
    );
  }
}
