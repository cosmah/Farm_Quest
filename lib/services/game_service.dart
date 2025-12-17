import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../models/crop.dart';
import '../models/crop_type.dart';
import '../models/plot.dart';
import '../models/loan.dart';
import '../models/worker.dart';
import '../models/tool.dart';
import '../models/transaction.dart';
import 'offline_database_service.dart';
import 'sync_service.dart';

class GameService {
  static const String _saveKey = 'game_state';
  static const String _hasPlayedBeforeKey = 'has_played_before';

  GameState _gameState = GameState.fresh();
  Timer? _gameLoopTimer;
  Timer? _snapshotTimer; // Auto-snapshot every 5 seconds
  final Random _random = Random();
  bool _isPaused = false;
  DateTime? _pauseStartTime;
  int _currentPauseSeconds = 0;

  // NEW: Offline-first storage services
  final OfflineDatabaseService _offlineDb = OfflineDatabaseService();
  final SyncService _syncService = SyncService();

  final _stateController = StreamController<GameState>.broadcast();
  Stream<GameState> get stateStream => _stateController.stream;

  GameState get state => _gameState;
  bool get isPaused => _isPaused;

  // Callbacks
  Function? onGameOver;

  GameService() {
    _startGameLoop();
    _initializeServices();
    _startAutoSnapshot();
  }

  /// Initialize offline-first services
  Future<void> _initializeServices() async {
    await _syncService.initialize();
    
    // Listen to sync status
    _syncService.syncStatusStream.listen((status) {
      print('🔄 Sync status: $status');
    });
  }

  /// Start automatic snapshot timer (every 5 seconds)
  void _startAutoSnapshot() {
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isPaused) {
        _saveSnapshot();
      }
    });
  }

  /// Save complete game state snapshot (overwrites previous)
  Future<void> _saveSnapshot() async {
    try {
      // Capture complete game state with all data
      final snapshot = {
        'gameState': _gameState.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isPaused': _isPaused,
        'pauseStartTime': _pauseStartTime?.millisecondsSinceEpoch,
        'currentPauseSeconds': _currentPauseSeconds,
        // Include all plots with complete crop states (growth progress, disasters, achievements)
        'plots': _gameState.plots.map((plot) => plot.toJson()).toList(),
        // Include all workers
        'workers': _gameState.activeWorkers.map((worker) => {
          'type': worker.type.name,
          'hiredAt': worker.hiredAt.millisecondsSinceEpoch,
          'assignedPlotIndices': worker.assignedPlotIndices,
          'cost': worker.cost,
        }).toList(),
        // Include all tools
        'tools': _gameState.ownedTools.map((tool) => {
          'type': tool.type.name,
          'quantityOwned': tool.quantityOwned,
        }).toList(),
        // Include seed inventory
        'seedInventory': _gameState.seedInventory,
        // Include transactions
        'transactions': _gameState.transactions.map((t) => {
          'type': t.type.toString().split('.').last,
          'amount': t.amount,
          'description': t.description,
          'timestamp': t.timestamp.millisecondsSinceEpoch,
          'seasonNumber': t.seasonNumber,
          'category': t.category.toString().split('.').last,
        }).toList(),
        // Include active loan
        'activeLoan': _gameState.activeLoan != null ? {
          'principal': _gameState.activeLoan!.principal,
          'interestRate': _gameState.activeLoan!.interestRate,
          'durationSeconds': _gameState.activeLoan!.durationSeconds,
          'takenAt': _gameState.activeLoan!.takenAt.millisecondsSinceEpoch,
          'pausedTimeSeconds': _gameState.activeLoan!.pausedTimeSeconds,
          'isPaid': _gameState.activeLoan!.isPaid,
        } : null,
      };

      // Save snapshot (overwrites previous - PRIMARY KEY conflict resolution)
      await _offlineDb.saveScreenState('game_snapshot', snapshot);
      
      // Also save full game state to main tables
      await _offlineDb.saveGameState(_gameState);
      
    } catch (e) {
      print('❌ Error saving snapshot: $e');
    }
  }

  /// Load latest snapshot on game start
  Future<bool> loadSnapshot() async {
    try {
      final snapshot = await _offlineDb.loadScreenState('game_snapshot');
      if (snapshot == null) return false;

      // Restore game state
      _gameState = GameState.fromJson(snapshot['gameState'] as Map<String, dynamic>);
      
      // Restore pause state
      _isPaused = snapshot['isPaused'] as bool? ?? false;
      if (snapshot['pauseStartTime'] != null) {
        _pauseStartTime = DateTime.fromMillisecondsSinceEpoch(snapshot['pauseStartTime'] as int);
      }
      _currentPauseSeconds = snapshot['currentPauseSeconds'] as int? ?? 0;

      _notifyStateChanged();
      print('✅ Snapshot loaded - resumed from exact state');
      return true;
    } catch (e) {
      print('❌ Error loading snapshot: $e');
      return false;
    }
  }

  /// Get total pause duration (for UI display - uses GameState's totalPausedSeconds)
  int get currentPauseDuration {
    // Return total paused seconds from game state (includes all past pauses)
    // If currently paused, add current pause session
    if (_isPaused && _pauseStartTime != null) {
      return _gameState.totalPausedSeconds + DateTime.now().difference(_pauseStartTime!).inSeconds;
    }
    return _gameState.totalPausedSeconds;
  }

  /// Get additional paused seconds for current pause session (for loan calculations)
  int get currentPauseSessionSeconds {
    if (_isPaused && _pauseStartTime != null) {
      return DateTime.now().difference(_pauseStartTime!).inSeconds;
    }
    return 0;
  }

  /// Pause the game (stops game loop and timer)
  void pauseGame() {
    if (!_isPaused) {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
      _gameLoopTimer?.cancel();
      _snapshotTimer?.cancel(); // Stop auto-snapshot when paused
      _saveSnapshot(); // Save final snapshot before pausing
      _notifyStateChanged();
    }
  }

  /// Resume the game (restarts game loop)
  void resumeGame() {
    if (_isPaused && _pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!).inSeconds;
      _currentPauseSeconds += pauseDuration;
      
      // Add pause time to game state
      _gameState.totalPausedSeconds += pauseDuration;
      
      // Add pause time to active loan
      if (_gameState.activeLoan != null) {
        _gameState.activeLoan!.pausedTimeSeconds += pauseDuration;
      }
      
      _isPaused = false;
      _pauseStartTime = null;
      _startGameLoop();
      _startAutoSnapshot(); // Resume auto-snapshot
      _notifyStateChanged();
    }
  }

  /// Start the game loop (updates every second)
  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateGame();
    });
  }

  /// Main game update logic
  void _updateGame() {
    // Skip update if game is paused
    if (_isPaused) {
      return;
    }
    
    final now = DateTime.now();
    bool needsUpdate = false;

    // Worker auto-actions
    _performWorkerActions();

    // Permanent equipment effects
    _applyEquipmentEffects();

    // Update all crops
    for (var plot in _gameState.unlockedPlots) {
      if (plot.hasLiveCrop && plot.crop != null) {
        final crop = plot.crop!;

        // Update growth progress (accounting for paused time)
        if (crop.growthProgress < 1.0 && !crop.isDead) {
          // Calculate game time (real time minus paused time)
          final gameTimeSincePlanted = now.difference(crop.plantedAt).inSeconds - _gameState.totalPausedSeconds;
          double baseProgress = gameTimeSincePlanted / crop.type.growthTimeSeconds;

          // Slow down if has weeds
          if (crop.hasWeeds) {
            baseProgress *= 0.5;
          }

          crop.growthProgress = baseProgress.clamp(0.0, 1.0);
          needsUpdate = true;
        }

        // Check if crop should die from lack of water (accounting for paused time)
        // Use game time, not real time
        final gameTimeSinceWatered = now.difference(crop.lastWatered).inSeconds - _gameState.totalPausedSeconds;
        if (gameTimeSinceWatered > crop.type.waterIntervalSeconds + 10) {
          if (!crop.isDead) {
            crop.isDead = true;
            needsUpdate = true;
          }
        }

        // Random weed spawn (check every second, but use minute-based chance)
        if (!crop.hasWeeds && !crop.isDead && _random.nextDouble() < crop.type.weedSpawnChance / 60) {
          crop.hasWeeds = true;
          needsUpdate = true;
        }

        // Random pest spawn - reduced by pest trap
        double pestChance = crop.type.pestSpawnChance / 60;
        if (_gameState.hasToolType(ToolType.pestTrap)) {
          pestChance *= 0.5; // 50% less pests with trap
        }
        if (!crop.hasPests && !crop.isDead && _random.nextDouble() < pestChance) {
          crop.hasPests = true;
          needsUpdate = true;
        }

        // Pests kill crop after 15 seconds
        if (crop.hasPests && !crop.isDead) {
          // We'd need to track when pest appeared, for now kill immediately if ignored too long
          // This is simplified - in full version, track pest appearance time
        }
      }
    }

    // Check loan deadline (use total paused seconds, not current pause duration)
    if (_gameState.hasActiveLoan) {
      // Calculate additional paused seconds for current pause session
      final additionalPaused = _isPaused && _pauseStartTime != null
          ? DateTime.now().difference(_pauseStartTime!).inSeconds
          : 0;
      if (_gameState.activeLoan!.isOverdue(additionalPaused)) {
        _triggerGameOver();
        return;
      }
    }

    // Auto-save every 10 updates (10 seconds)
    if (DateTime.now().difference(_gameState.lastSaved).inSeconds >= 10) {
      saveGame();
    }

    if (needsUpdate) {
      _notifyStateChanged();
    }
  }

  /// Perform worker auto-actions
  void _performWorkerActions() {
    // Farmhand: Auto-water crops that need water
    if (_gameState.hasWorkerType(WorkerType.farmhand)) {
      for (var plot in _gameState.unlockedPlots) {
        if (plot.hasLiveCrop && plot.crop != null) {
          final crop = plot.crop!;
          final cropState = crop.getState(_gameState.totalPausedSeconds);
          if (cropState == CropState.needsWater || cropState == CropState.wilting) {
            waterCrop(plot);
          }
        }
      }
    }

    // Pest Controller: Auto-remove pests
    if (_gameState.hasWorkerType(WorkerType.pestController)) {
      for (var plot in _gameState.unlockedPlots) {
        if (plot.hasLiveCrop && plot.crop != null && plot.crop!.hasPests) {
          removePests(plot);
        }
      }
    }

    // Gardener: Auto-remove weeds
    if (_gameState.hasWorkerType(WorkerType.gardener)) {
      for (var plot in _gameState.unlockedPlots) {
        if (plot.hasLiveCrop && plot.crop != null && plot.crop!.hasWeeds) {
          removeWeeds(plot);
        }
      }
    }

    // Supervisor & Master Farmer: Full plot management
    for (var worker in _gameState.activeWorkers) {
      if (worker.type == WorkerType.supervisor || worker.type == WorkerType.masterFarmer) {
        final assignedPlots = worker.assignedPlotIndices ?? [];
        for (var plotIndex in assignedPlots) {
          if (plotIndex < _gameState.plots.length) {
            final plot = _gameState.plots[plotIndex];
            if (plot.isUnlocked && plot.hasLiveCrop && plot.crop != null) {
              final crop = plot.crop!;
              final cropState = crop.getState(_gameState.totalPausedSeconds);
              
              // Auto-water
              if (cropState == CropState.needsWater || cropState == CropState.wilting) {
                waterCrop(plot);
              }
              // Auto-remove pests
              if (crop.hasPests) {
                removePests(plot);
              }
              // Auto-remove weeds
              if (crop.hasWeeds) {
                removeWeeds(plot);
              }
              // Auto-harvest when ready
              if (cropState == CropState.ready) {
                harvestCrop(plot);
              }
            }
          }
        }
      }
    }
  }

  /// Apply permanent equipment effects
  void _applyEquipmentEffects() {
    // Sprinkler: Auto-water all plots
    if (_gameState.hasToolType(ToolType.sprinkler)) {
      for (var plot in _gameState.unlockedPlots) {
        if (plot.hasLiveCrop && plot.crop != null) {
          final cropState = plot.crop!.getState(_gameState.totalPausedSeconds);
          if (cropState == CropState.needsWater || cropState == CropState.wilting) {
            waterCrop(plot);
          }
        }
      }
    }
  }

  void _triggerGameOver() {
    _gameLoopTimer?.cancel();
    onGameOver?.call();
  }

  /// Plant a crop on a plot
  bool plantCrop(Plot plot, CropType cropType) {
    if (!plot.isEmpty) {
      return false;
    }

    // Check if player has seeds in inventory
    if (!_gameState.hasSeeds(cropType.id, 1)) {
      return false;
    }

    // Consume one seed from inventory
    if (_gameState.useSeeds(cropType.id, 1)) {
      final now = DateTime.now();
      plot.plantCrop(Crop(
        type: cropType,
        plantedAt: now,
        lastWatered: now,
      ));
      _notifyStateChanged();
      saveGame();
      return true;
    }
    return false;
  }

  /// Water a crop
  bool waterCrop(Plot plot) {
    if (plot.hasLiveCrop && plot.crop != null) {
      plot.crop!.lastWatered = DateTime.now();
      _notifyStateChanged();
      return true;
    }
    return false;
  }

  /// Remove weeds from a crop
  bool removeWeeds(Plot plot) {
    if (plot.hasLiveCrop && plot.crop != null && plot.crop!.hasWeeds) {
      plot.crop!.hasWeeds = false;
      _notifyStateChanged();
      return true;
    }
    return false;
  }

  /// Remove pests from a crop
  bool removePests(Plot plot) {
    if (plot.hasLiveCrop && plot.crop != null && plot.crop!.hasPests) {
      plot.crop!.hasPests = false;
      _notifyStateChanged();
      return true;
    }
    return false;
  }

  /// Harvest a crop
  bool harvestCrop(Plot plot) {
    if (plot.hasReadyCrop && plot.crop != null) {
      final crop = plot.crop!;
      
      // Calculate sell price with Lab Kit bonus
      int sellPrice = crop.type.sellPrice;
      if (_gameState.hasToolType(ToolType.labKit)) {
        sellPrice = (sellPrice * 1.1).round(); // +10% bonus from Lab Kit
      }
      
      _gameState.earnMoney(
        sellPrice,
        category: TransactionCategory.cropSale,
        description: '${crop.type.name} harvest',
      );
      _gameState.cropsHarvested++;
      
      // Award XP based on crop type
      int xpReward = 10; // Base XP
      if (crop.type.id == 'corn') xpReward = 15;
      if (crop.type.id == 'tomato') xpReward = 20;
      _gameState.addExperience(xpReward);
      
      plot.clearCrop();
      
      // Check if season ended
      if (_gameState.isSeasonEnd) {
        _endSeason();
      }
      
      _notifyStateChanged();
      saveGame();
      return true;
    }
    return false;
  }

  /// End the season (dismiss all workers, advance season)
  void _endSeason() {
    if (_gameState.activeWorkers.isNotEmpty) {
      _gameState.endAllWorkerContracts();
    }
    _gameState.currentSeason++;
    _gameState.taxesPaidThisSeason = false;
    saveGame();
  }

  /// Clear a dead crop
  void clearDeadCrop(Plot plot) {
    if (plot.hasDeadCrop) {
      plot.clearCrop();
      _notifyStateChanged();
    }
  }

  /// Unlock a plot
  bool unlockPlot(Plot plot) {
    if (!plot.isUnlocked && _gameState.canAfford(plot.unlockCost)) {
      if (_gameState.spendMoney(
        plot.unlockCost,
        category: TransactionCategory.plotUnlock,
        description: 'Unlocked Plot ${int.parse(plot.id) + 1}',
      )) {
        plot.isUnlocked = true;
        _notifyStateChanged();
        saveGame();
        return true;
      }
    }
    return false;
  }

  /// Take a loan
  void takeLoan(Loan loan) {
    _gameState.activeLoan = loan;
    _gameState.earnMoney(
      loan.principal,
      category: TransactionCategory.loanTaken,
      description: 'Loan: \$${loan.principal}',
    );
    _notifyStateChanged();
    saveGame();
  }

  /// Repay the active loan
  bool repayLoan() {
    if (_gameState.hasActiveLoan && 
        _gameState.canAfford(_gameState.activeLoan!.totalAmount)) {
      if (_gameState.spendMoney(
        _gameState.activeLoan!.totalAmount,
        category: TransactionCategory.loanRepayment,
        description: 'Loan repayment with interest',
      )) {
        _gameState.activeLoan!.isPaid = true;
        _gameState.loansRepaid++;
        _gameState.activeLoan = null;
        _notifyStateChanged();
        saveGame();
        return true;
      }
    }
    return false;
  }

  /// Buy seeds for inventory
  bool buySeeds(CropType cropType, int quantity) {
    final totalCost = cropType.seedCost * quantity;
    if (_gameState.spendMoney(
      totalCost,
      category: TransactionCategory.seedPurchase,
      description: '$quantity ${cropType.name} seeds',
    )) {
      _gameState.addSeeds(cropType.id, quantity);
      _notifyStateChanged();
      saveGame();
      return true;
    }
    return false;
  }

  /// Use a consumable tool (if available)
  bool useTool(ToolType toolType) {
    return _gameState.useConsumableTool(toolType);
  }

  /// Check if player has a specific tool type
  bool hasTool(ToolType toolType) {
    return _gameState.hasToolType(toolType);
  }

  /// Save game state (OFFLINE-FIRST: SQLite primary, Firebase sync every 5 minutes)
  Future<void> saveGame() async {
    _gameState.lastSaved = DateTime.now();
    
    // 1. Save to SQLite (primary storage - always fast)
    await _offlineDb.saveGameState(_gameState);
    
    // 2. Also save to SharedPreferences for backward compatibility
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_gameState.toJson());
    await prefs.setString(_saveKey, jsonString);
    await prefs.setBool(_hasPlayedBeforeKey, true);
    
    // 3. Firebase sync happens automatically every 5 minutes via periodic timer
    //    (No immediate sync - saves are fast and local)
    
    print('✅ Game saved to SQLite (primary storage)');
  }

  /// Load game state (OFFLINE-FIRST: Snapshot → SQLite → SharedPrefs → Firebase)
  Future<bool> loadGame() async {
    try {
      // 1. PRIORITY: Try loading latest snapshot (most recent state)
      final snapshotLoaded = await loadSnapshot();
      if (snapshotLoaded) {
        // Firebase sync happens automatically every 5 minutes via periodic timer
        return true;
      }

      // 2. Fallback: Try loading from SQLite (primary storage)
      final sqliteState = await _offlineDb.loadGameState();
      
      if (sqliteState != null) {
        _gameState = sqliteState;
        _notifyStateChanged();
        print('✅ Game loaded from SQLite');
        
        // Firebase sync happens automatically every 5 minutes via periodic timer
        return true;
      }

      // 3. Fallback: Try loading from SharedPreferences (legacy)
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_saveKey);

      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        _gameState = GameState.fromJson(json);
        
        // Migrate to SQLite
        await _offlineDb.saveGameState(_gameState);
        
        _notifyStateChanged();
        print('✅ Game loaded from SharedPreferences (migrated to SQLite)');
        return true;
      }

      // 4. Fallback: Try loading from cloud (if signed in)
      final cloudState = await _syncService.forceDownloadFromCloud();
      if (cloudState) {
        final loadedState = await _offlineDb.loadGameState();
        if (loadedState != null) {
          _gameState = loadedState;
          _notifyStateChanged();
          print('✅ Game loaded from cloud');
          return true;
        }
      }

      print('⚠️ No saved game found');
      return false;
    } catch (e) {
      print('❌ Error loading game: $e');
      return false;
    }
  }

  /// Check if player has played before
  Future<bool> hasPlayedBefore() async {
    // Check SQLite first
    final hasSqliteData = await _offlineDb.hasGameState();
    if (hasSqliteData) return true;

    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasPlayedBeforeKey) ?? false;
  }

  /// Reset game (after game over)
  Future<void> resetGame() async {
    _gameState = GameState.fresh();
    await _offlineDb.deleteGameState();
    await saveGame();
    _notifyStateChanged();
    _startGameLoop();
  }

  /// Get sync info (for UI display)
  Future<SyncInfo> getSyncInfo() async {
    return await _syncService.getSyncInfo();
  }

  /// Force sync now (manual sync button)
  Future<SyncResult> forceSyncNow() async {
    return await _syncService.syncNow();
  }

  void _notifyStateChanged() {
    _stateController.add(_gameState);
  }

  void dispose() {
    _gameLoopTimer?.cancel();
    _snapshotTimer?.cancel();
    _saveSnapshot(); // Final snapshot before dispose
    _stateController.close();
    _syncService.dispose();
  }
}

