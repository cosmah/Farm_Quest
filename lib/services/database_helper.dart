import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'farm_quest.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Music library table
    await db.execute('''
      CREATE TABLE music_library (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        duration INTEGER,
        added_at TEXT NOT NULL
      )
    ''');

    // User statistics table
    await db.execute('''
      CREATE TABLE user_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stat_key TEXT UNIQUE NOT NULL,
        stat_value INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Game sessions table (for analytics)
    await db.execute('''
      CREATE TABLE game_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_start TEXT NOT NULL,
        session_end TEXT,
        crops_harvested INTEGER DEFAULT 0,
        money_earned INTEGER DEFAULT 0,
        level_reached INTEGER DEFAULT 1
      )
    ''');

    // Achievements table
    await db.execute('''
      CREATE TABLE achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        achievement_key TEXT UNIQUE NOT NULL,
        unlocked_at TEXT,
        is_unlocked INTEGER DEFAULT 0
      )
    ''');
  }

  // === MUSIC LIBRARY METHODS ===

  Future<int> addSong(String filePath, String fileName, {int? duration}) async {
    final db = await database;
    return await db.insert('music_library', {
      'file_path': filePath,
      'file_name': fileName,
      'duration': duration,
      'added_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllSongs() async {
    final db = await database;
    return await db.query('music_library', orderBy: 'added_at DESC');
  }

  Future<int> deleteSong(int id) async {
    final db = await database;
    return await db.delete('music_library', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearMusicLibrary() async {
    final db = await database;
    await db.delete('music_library');
  }

  // === USER STATS METHODS ===

  Future<void> setStat(String key, int value) async {
    final db = await database;
    await db.insert(
      'user_stats',
      {
        'stat_key': key,
        'stat_value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getStat(String key, {int defaultValue = 0}) async {
    final db = await database;
    final results = await db.query(
      'user_stats',
      where: 'stat_key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return defaultValue;
    return results.first['stat_value'] as int;
  }

  Future<Map<String, int>> getAllStats() async {
    final db = await database;
    final results = await db.query('user_stats');
    
    final stats = <String, int>{};
    for (var row in results) {
      stats[row['stat_key'] as String] = row['stat_value'] as int;
    }
    return stats;
  }

  Future<void> incrementStat(String key, {int by = 1}) async {
    final currentValue = await getStat(key);
    await setStat(key, currentValue + by);
  }

  // === GAME SESSION METHODS ===

  Future<int> startSession() async {
    final db = await database;
    return await db.insert('game_sessions', {
      'session_start': DateTime.now().toIso8601String(),
    });
  }

  Future<void> endSession(int sessionId, {
    required int cropsHarvested,
    required int moneyEarned,
    required int levelReached,
  }) async {
    final db = await database;
    await db.update(
      'game_sessions',
      {
        'session_end': DateTime.now().toIso8601String(),
        'crops_harvested': cropsHarvested,
        'money_earned': moneyEarned,
        'level_reached': levelReached,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentSessions({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'game_sessions',
      orderBy: 'session_start DESC',
      limit: limit,
    );
  }

  // === ACHIEVEMENTS METHODS ===

  Future<void> unlockAchievement(String key) async {
    final db = await database;
    await db.insert(
      'achievements',
      {
        'achievement_key': key,
        'unlocked_at': DateTime.now().toIso8601String(),
        'is_unlocked': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isAchievementUnlocked(String key) async {
    final db = await database;
    final results = await db.query(
      'achievements',
      where: 'achievement_key = ? AND is_unlocked = 1',
      whereArgs: [key],
    );
    return results.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getAllAchievements() async {
    final db = await database;
    return await db.query('achievements');
  }

  // === UTILITY METHODS ===

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('music_library');
    await db.delete('user_stats');
    await db.delete('game_sessions');
    await db.delete('achievements');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

