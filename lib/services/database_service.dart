import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/player.dart';
import '../models/throw_record.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'baseball_coach.db'),
      version: 1,
      onCreate: _onCreate,
    );
  }

  Database get db {
    if (_db == null) throw StateError('Database not initialized');
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE players (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        position TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE throw_records (
        id TEXT PRIMARY KEY,
        player_id TEXT NOT NULL,
        rotation_angle_deg REAL NOT NULL,
        rotation_speed_rpm REAL NOT NULL,
        ball_speed_kmh REAL NOT NULL,
        pitch_type TEXT NOT NULL,
        curve_estimate_cm REAL NOT NULL,
        drop_estimate_cm REAL NOT NULL,
        recorded_at TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─── Players ────────────────────────────────────────────────────────────────

  Future<List<Player>> getPlayers() async {
    final rows = await db.query('players', orderBy: 'name ASC');
    return rows.map(Player.fromMap).toList();
  }

  Future<void> insertPlayer(Player player) async {
    await db.insert('players', player.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePlayer(String id) async {
    await db.delete('players', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Throw Records ───────────────────────────────────────────────────────────

  Future<List<ThrowRecord>> getThrowsForPlayer(String playerId) async {
    final rows = await db.query(
      'throw_records',
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'recorded_at DESC',
    );
    return rows.map(ThrowRecord.fromMap).toList();
  }

  Future<void> insertThrow(ThrowRecord record) async {
    await db.insert('throw_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteThrow(String id) async {
    await db.delete('throw_records', where: 'id = ?', whereArgs: [id]);
  }
}
