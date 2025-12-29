import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/game_state.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../models/crop_type.dart';
import '../models/worker.dart';
import '../models/tool.dart';
import '../models/transaction.dart' as game_transaction;
import '../models/loan.dart';

/// Professional offline-first database service
/// SQLite is the primary storage, Firebase is for cloud backup
class OfflineDatabaseService {
  static final OfflineDatabaseService _instance = OfflineDatabaseService._internal();
  factory OfflineDatabaseService() => _instance;
  OfflineDatabaseService._internal();

  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'farm_quest_v2.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create all tables with proper schema
  Future<void> _onCreate(Database db, int version) async {
    // 1. GAME STATE TABLE (Main game data)
    await db.execute('''
      CREATE TABLE game_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        money INTEGER NOT NULL DEFAULT 0,
        experience INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1,
        experience_to_next_level INTEGER NOT NULL DEFAULT 100,
        crops_harvested INTEGER NOT NULL DEFAULT 0,
        total_earnings INTEGER NOT NULL DEFAULT 0,
        loans_repaid INTEGER NOT NULL DEFAULT 0,
        days_played INTEGER NOT NULL DEFAULT 0,
        game_start_date INTEGER,
        total_paused_seconds INTEGER NOT NULL DEFAULT 0,
        is_paused INTEGER NOT NULL DEFAULT 0,
        last_saved INTEGER NOT NULL,
        last_synced INTEGER,
        sync_pending INTEGER NOT NULL DEFAULT 0,
        data_json TEXT NOT NULL
      )
    ''');

    // 2. PLOTS TABLE (Individual plot data)
    await db.execute('''
      CREATE TABLE plots (
        plot_id INTEGER PRIMARY KEY,
        is_unlocked INTEGER NOT NULL DEFAULT 0,
        unlock_cost INTEGER NOT NULL,
        last_updated INTEGER NOT NULL,
        sync_pending INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. CROPS TABLE (Active crops on plots)
    await db.execute('''
      CREATE TABLE crops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plot_id INTEGER NOT NULL,
        crop_type TEXT NOT NULL,
        planted_at INTEGER NOT NULL,
        paused_seconds INTEGER NOT NULL DEFAULT 0,
        is_watered INTEGER NOT NULL DEFAULT 0,
        has_pests INTEGER NOT NULL DEFAULT 0,
        has_weeds INTEGER NOT NULL DEFAULT 0,
        fertilizer_used INTEGER NOT NULL DEFAULT 0,
        lab_kit_used INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL,
        sync_pending INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (plot_id) REFERENCES plots (plot_id) ON DELETE CASCADE
      )
    ''');

    // 4. WORKERS TABLE (Hired workers)
    await db.execute('''
      CREATE TABLE workers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        worker_type TEXT NOT NULL,
        hired_at INTEGER NOT NULL,
        contract_start INTEGER NOT NULL,
        contract_duration INTEGER NOT NULL,
        assigned_plots TEXT NOT NULL,
        cost INTEGER NOT NULL,
        last_updated INTEGER NOT NULL,
        sync_pending INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 5. TOOLS INVENTORY TABLE (Consumable tools and equipment)
    await db.execute('''
      CREATE TABLE tools_inventory (
        tool_type TEXT PRIMARY KEY,
        quantity_owned INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL,
        sync_pending INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 6. SEEDS INVENTORY TABLE (Seed quantities)
    await db.execute('''
      CREATE TABLE seeds_inventory (
        seed_type TEXT PRIMARY KEY,
        quantity INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL,
        sync_pending INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 7. TRANSACTIONS TABLE (Financial history)
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        description TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        season_id INTEGER,
        category TEXT,
        last_updated INTEGER NOT NULL,
        sync_pending INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 8. LOANS TABLE (Active and repaid loans)
    await db.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        interest_rate REAL NOT NULL,
        duration_seconds INTEGER NOT NULL,
        taken_at INTEGER NOT NULL,
        paused_time_seconds INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_updated INTEGER NOT NULL,
        sync_pending INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 9. SCREEN STATES TABLE (UI state persistence)
    await db.execute('''
      CREATE TABLE screen_states (
        screen_name TEXT PRIMARY KEY,
        state_json TEXT NOT NULL,
        last_updated INTEGER NOT NULL,
        sync_pending INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 10. SYNC METADATA TABLE (Track sync status)
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_crops_plot ON crops(plot_id)');
    await db.execute('CREATE INDEX idx_transactions_timestamp ON transactions(timestamp)');
    await db.execute('CREATE INDEX idx_workers_contract ON workers(contract_start)');
    await db.execute('CREATE INDEX idx_sync_pending ON game_state(sync_pending)');

    print('✅ Database created successfully with all tables');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns or tables for version 2
      await db.execute('ALTER TABLE game_state ADD COLUMN game_start_date INTEGER');
      await db.execute('ALTER TABLE game_state ADD COLUMN days_played INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE game_state ADD COLUMN experience_to_next_level INTEGER NOT NULL DEFAULT 100');
    }
  }

  // ==================== GAME STATE OPERATIONS ====================

  /// Save complete game state
  Future<void> saveGameState(GameState state) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'game_state',
      {
        'id': 1,
        'money': state.money,
        'experience': state.experience,
        'level': state.level,
        'experience_to_next_level': state.experienceToNextLevel,
        'crops_harvested': state.cropsHarvested,
        'total_earnings': state.totalEarnings,
        'loans_repaid': state.loansRepaid,
        'days_played': state.daysPlayed,
        'game_start_date': state.gameStartDate?.millisecondsSinceEpoch,
        'total_paused_seconds': state.totalPausedSeconds,
        'is_paused': 0, // GameState doesn't track isPaused, handled by GameService
        'last_saved': now,
        'sync_pending': 1,
        'data_json': jsonEncode(state.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save all related entities
    await _savePlots(state.plots, db);
    await _saveWorkers(state.activeWorkers, db);
    await _saveLoans(state.activeLoan, db);
    await _saveToolsInventory(state.ownedTools, db);
    await _saveSeedsInventory(state.seedInventory, db);
    await _saveTransactions(state.transactions, db);

    print('✅ Game state saved to SQLite');
  }

  /// Load complete game state
  Future<GameState?> loadGameState() async {
    final db = await database;
    final results = await db.query('game_state', where: 'id = 1', limit: 1);

    if (results.isEmpty) return null;

    final data = results.first;
    final jsonData = jsonDecode(data['data_json'] as String);
    
    return GameState.fromJson(jsonData);
  }

  /// Check if game state exists
  Future<bool> hasGameState() async {
    final db = await database;
    final results = await db.query('game_state', where: 'id = 1', limit: 1);
    return results.isNotEmpty;
  }

  /// Delete game state (for new game)
  Future<void> deleteGameState() async {
    final db = await database;
    await db.delete('game_state');
    await db.delete('plots');
    await db.delete('crops');
    await db.delete('workers');
    await db.delete('tools_inventory');
    await db.delete('seeds_inventory');
    await db.delete('transactions');
    await db.delete('loans');
    print('✅ Game state deleted from SQLite');
  }

  // ==================== PLOTS OPERATIONS ====================

  Future<void> _savePlots(List<Plot> plots, Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    for (final plot in plots) {
      batch.insert(
        'plots',
        {
          'plot_id': plot.id,
          'is_unlocked': plot.isUnlocked ? 1 : 0,
          'unlock_cost': plot.unlockCost,
          'last_updated': now,
          'sync_pending': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Save crop if exists
      if (plot.crop != null) {
        final crop = plot.crop!;
        batch.insert(
          'crops',
          {
            'plot_id': plot.id,
            'crop_type': crop.type.name,
            'planted_at': crop.plantedAt.millisecondsSinceEpoch,
            'paused_seconds': 0, // Crop model doesn't have pausedSeconds
            'is_watered': 0, // Crop model doesn't track isWatered separately
            'has_pests': crop.hasPests ? 1 : 0,
            'has_weeds': crop.hasWeeds ? 1 : 0,
            'fertilizer_used': 0, // Not in Crop model
            'lab_kit_used': 0, // Not in Crop model
            'last_updated': now,
            'sync_pending': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        // Remove crop if plot is empty
        batch.delete('crops', where: 'plot_id = ?', whereArgs: [plot.id]);
      }
    }

    await batch.commit(noResult: true);
  }

  // ==================== WORKERS OPERATIONS ====================

  Future<void> _saveWorkers(List<Worker> workers, Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    // Clear existing workers
    batch.delete('workers');

    for (final worker in workers) {
      batch.insert('workers', {
        'worker_type': worker.type.name,
        'hired_at': worker.hiredAt.millisecondsSinceEpoch,
        'contract_start': worker.hiredAt.millisecondsSinceEpoch, // Use hiredAt as contract start
        'contract_duration': 0, // Workers don't have contract duration in model
        'assigned_plots': jsonEncode(worker.assignedPlotIndices ?? []),
        'cost': worker.cost,
        'last_updated': now,
        'sync_pending': 1,
      });
    }

    await batch.commit(noResult: true);
  }

  // ==================== LOANS OPERATIONS ====================

  Future<void> _saveLoans(Loan? activeLoan, Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    // Clear existing loans
    batch.delete('loans');

    if (activeLoan != null) {
      batch.insert('loans', {
        'amount': activeLoan.principal,
        'interest_rate': activeLoan.interestRate,
        'duration_seconds': activeLoan.durationSeconds,
        'taken_at': activeLoan.takenAt.millisecondsSinceEpoch,
        'paused_time_seconds': activeLoan.pausedTimeSeconds,
        'is_active': activeLoan.isPaid ? 0 : 1,
        'last_updated': now,
        'sync_pending': 1,
      });
    }

    await batch.commit(noResult: true);
  }

  // ==================== TOOLS INVENTORY OPERATIONS ====================

  Future<void> _saveToolsInventory(List<Tool> tools, Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    for (final tool in tools) {
      batch.insert(
        'tools_inventory',
        {
          'tool_type': tool.type.name,
          'quantity_owned': tool.quantityOwned,
          'last_updated': now,
          'sync_pending': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ==================== SEEDS INVENTORY OPERATIONS ====================

  Future<void> _saveSeedsInventory(Map<String, int> seeds, Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    for (final entry in seeds.entries) {
      batch.insert(
        'seeds_inventory',
        {
          'seed_type': entry.key, // Key is already a String (crop type ID)
          'quantity': entry.value,
          'last_updated': now,
          'sync_pending': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ==================== TRANSACTIONS OPERATIONS ====================

  Future<void> _saveTransactions(List<game_transaction.Transaction> transactions, Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    // Clear existing transactions
    batch.delete('transactions');

    for (int i = 0; i < transactions.length; i++) {
      final transaction = transactions[i];
      batch.insert('transactions', {
        'id': '${transaction.timestamp.millisecondsSinceEpoch}_$i', // Generate ID from timestamp + index
        'type': transaction.type.toString().split('.').last,
        'amount': transaction.amount,
        'description': transaction.description,
        'timestamp': transaction.timestamp.millisecondsSinceEpoch,
        'season_id': transaction.seasonNumber,
        'category': transaction.category.toString().split('.').last,
        'last_updated': now,
        'sync_pending': 1,
      });
    }

    await batch.commit(noResult: true);
  }

  // ==================== SCREEN STATE OPERATIONS ====================

  /// Save screen-specific state (e.g., scroll position, selected tab)
  Future<void> saveScreenState(String screenName, Map<String, dynamic> state) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'screen_states',
      {
        'screen_name': screenName,
        'state_json': jsonEncode(state),
        'last_updated': now,
        'sync_pending': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load screen-specific state
  Future<Map<String, dynamic>?> loadScreenState(String screenName) async {
    final db = await database;
    final results = await db.query(
      'screen_states',
      where: 'screen_name = ?',
      whereArgs: [screenName],
      limit: 1,
    );

    if (results.isEmpty) return null;

    return jsonDecode(results.first['state_json'] as String) as Map<String, dynamic>;
  }

  // ==================== SYNC METADATA OPERATIONS ====================

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final db = await database;
    final results = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: ['last_sync'],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final timestamp = int.parse(results.first['value'] as String);
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Update last sync timestamp
  Future<void> updateLastSyncTime(DateTime time) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'key': 'last_sync',
        'value': time.millisecondsSinceEpoch.toString(),
        'last_updated': time.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all items pending sync
  Future<bool> hasPendingSync() async {
    final db = await database;
    
    // Check if any table has pending sync
    final gameState = await db.query('game_state', where: 'sync_pending = 1');
    if (gameState.isNotEmpty) return true;

    final plots = await db.query('plots', where: 'sync_pending = 1', limit: 1);
    if (plots.isNotEmpty) return true;

    final crops = await db.query('crops', where: 'sync_pending = 1', limit: 1);
    if (crops.isNotEmpty) return true;

    return false;
  }

  /// Clear sync pending flags after successful sync
  Future<void> markAllSynced() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    batch.update('game_state', {'sync_pending': 0, 'last_synced': now});
    batch.update('plots', {'sync_pending': 0});
    batch.update('crops', {'sync_pending': 0});
    batch.update('workers', {'sync_pending': 0});
    batch.update('tools_inventory', {'sync_pending': 0});
    batch.update('seeds_inventory', {'sync_pending': 0});
    batch.update('transactions', {'sync_pending': 0});
    batch.update('loans', {'sync_pending': 0});
    batch.update('screen_states', {'sync_pending': 0});

    await batch.commit(noResult: true);
    await updateLastSyncTime(DateTime.now());
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Clear all data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('game_state');
    await db.delete('plots');
    await db.delete('crops');
    await db.delete('workers');
    await db.delete('tools_inventory');
    await db.delete('seeds_inventory');
    await db.delete('transactions');
    await db.delete('loans');
    await db.delete('screen_states');
    await db.delete('sync_metadata');
    print('✅ All data cleared from SQLite');
  }
}

