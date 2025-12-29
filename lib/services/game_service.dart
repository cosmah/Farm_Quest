import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
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

class GameService with WidgetsBindingObserver {
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
    // Don't start game loop immediately - wait for proper initialization
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _startAutoSnapshot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('📱 App lifecycle changed to: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Auto-pause when app goes to background
        print('📱 App backgrounded - saving and pausing game');
        _saveSnapshot(); // Save immediately
        saveGame(); // Also save via regular method
        if (!_isPaused) {
          pauseGame();
          print('🔄 Game auto-paused (app backgrounded)');
        }
        break;
      case AppLifecycleState.resumed:
        // Don't auto-resume - let user manually resume
        print('📱 App resumed - game remains paused');
        break;
      case AppLifecycleState.detached:
        // Save before app termination
        print('📱 App terminating - final save');
        _saveSnapshot();
        saveGame();
        break;
      case AppLifecycleState.hidden:
        // App is hidden but not paused
        print('📱 App hidden');
        break;
    }
  }

  /// Initialize offline-first services
  Future<void> _initializeServices() async {
    await _syncService.initialize();
    
    // Listen to sync status
    _syncService.syncStatusStream.listen((status) {
      print('🔄 Sync status: $status');
    });
  }

  /// Start the game (call after loading/resetting state)
  void startGame() {
    _startGameLoop();
    print('✅ Game started with game loop running');
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
      print('🔄 Saving snapshot - Money: ${_gameState.money}, Loan: ${_gameState.activeLoan != null}, Plots: ${_gameState.plots.length}');
      
      // Capture COMPLETE game state - use the GameState's own toJson for consistency
      final gameStateJson = _gameState.toJson();
      
      // Add GameService-specific state that's not in GameState
      final snapshot = {
        'gameState': gameStateJson, // This contains ALL GameState data
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isPaused': _isPaused,
        'pauseStartTime': _pauseStartTime?.millisecondsSinceEpoch,
        'currentPauseSeconds': _currentPauseSeconds,
        // Add any GameService-specific data
        'gameServiceState': {
          'isPaused': _isPaused,
          'pauseStartTime': _pauseStartTime?.millisecondsSinceEpoch,
          'currentPauseSeconds': _currentPauseSeconds,
        },
      };

      // Save snapshot (overwrites previous - PRIMARY KEY conflict resolution)
      await _offlineDb.saveScreenState('game_snapshot', snapshot);
      
      // Also save full game state to main tables
      await _offlineDb.saveGameState(_gameState);
      
      print('✅ Snapshot saved successfully - All data captured');
    } catch (e) {
      print('❌ Error saving snapshot: $e');
    }
  }

  /// Load latest snapshot on game start
  Future<bool> loadSnapshot() async {
    try {
      print('🔄 Attempting to load snapshot...');
      final snapshot = await _offlineDb.loadScreenState('game_snapshot');
      if (snapshot == null) {
        print('⚠️ No snapshot found');
        return false;
      }

      print('📦 Snapshot found, loading...');
      
      // Restore game state
      _gameState = GameState.fromJson(snapshot['gameState'] as Map<String, dynamic>);
      
      print('✅ Game state restored - Money: ${_gameState.money}, Loan: ${_gameState.activeLoan != null}');
      
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
    bool needsSave = false;

    // Worker auto-actions
    _performWorkerActions();

    // Permanent equipment effects
    _applyEquipmentEffects();

    // Update all crops (batch updates)
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

          final newProgress = baseProgress.clamp(0.0, 1.0);
          if ((newProgress - crop.growthProgress).abs() > 0.01) { // Only update if significant change
            crop.growthProgress = newProgress;
            needsUpdate = true;
          }
        }

        // Check if crop should die from lack of water (accounting for paused time)
        // Use game time, not real time
        final gameTimeSinceWatered = now.difference(crop.lastWatered).inSeconds - _gameState.totalPausedSeconds;
        if (gameTimeSinceWatered > crop.type.waterIntervalSeconds + 10) {
          if (!crop.isDead) {
            crop.isDead = true;
            needsUpdate = true;
            needsSave = true;
          }
        }

        // Random weed spawn (check every second, but use minute-based chance)
        if (!crop.hasWeeds && !crop.isDead && _random.nextDouble() < crop.type.weedSpawnChance / 60) {
          crop.hasWeeds = true;
          needsUpdate = true;
          needsSave = true;
        }

        // Random pest spawn - reduced by pest trap
        double pestChance = crop.type.pestSpawnChance / 60;
        if (_gameState.hasToolType(ToolType.pestTrap)) {
          pestChance *= 0.5; // 50% less pests with trap
        }
        if (!crop.hasPests && !crop.isDead && _random.nextDouble() < pestChance) {
          crop.hasPests = true;
          needsUpdate = true;
          needsSave = true;
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

    // Auto-save every 5 updates (5 seconds instead of 10) - but only if changes occurred
    if (needsSave || DateTime.now().difference(_gameState.lastSaved).inSeconds >= 5) {
      saveGame();
    }

    // Only notify UI if there were actual changes
    if (needsUpdate) {
      _notifyStateChanged();
    }
  }

  /// Perform worker auto-actions
  void _performWorkerActions() {
    try {
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
    } catch (e) {
      print('❌ Error in worker actions: $e');
    }
  }

  /// Apply permanent equipment effects
  void _applyEquipmentEffects() {
    try {
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
    } catch (e) {
      print('❌ Error in equipment effects: $e');
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
    try {
      if (plot.hasLiveCrop && plot.crop != null) {
        plot.crop!.lastWatered = DateTime.now();
        _notifyStateChanged();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error watering crop: $e');
      return false;
    }
  }

  /// Remove weeds from a crop
  bool removeWeeds(Plot plot) {
    try {
      if (plot.hasLiveCrop && plot.crop != null && plot.crop!.hasWeeds) {
        plot.crop!.hasWeeds = false;
        _notifyStateChanged();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error removing weeds: $e');
      return false;
    }
  }

  /// Remove pests from a crop
  bool removePests(Plot plot) {
    try {
      if (plot.hasLiveCrop && plot.crop != null && plot.crop!.hasPests) {
        plot.crop!.hasPests = false;
        _notifyStateChanged();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error removing pests: $e');
      return false;
    }
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
    print('💰 Taking loan: \$${loan.principal}');
    
    _gameState.activeLoan = loan;
    _gameState.earnMoney(
      loan.principal,
      category: TransactionCategory.loanTaken,
      description: 'Loan: \$${loan.principal}',
    );
    
    print('💰 Loan taken - New money: \$${_gameState.money}');
    
    _notifyStateChanged();
    saveGame(); // Save immediately after taking loan
    _saveSnapshot(); // Also save snapshot
    
    print('💾 Game saved after loan');
  }

  /// Repay the active loan
  bool repayLoan() {
    if (_gameState.hasActiveLoan && 
        _gameState.canAfford(_gameState.activeLoan!.totalAmount)) {
      
      // Prevent double-spending by checking again inside the transaction
      final loanAmount = _gameState.activeLoan!.totalAmount;
      
      if (_gameState.spendMoney(
        loanAmount,
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
    try {
      print('💾 Saving game - Money: ${_gameState.money}, Loan: ${_gameState.activeLoan != null}');
      
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
      
      print('✅ Game saved to SQLite and SharedPreferences');
    } catch (e) {
      print('❌ Error saving game: $e');
    }
  }

  /// Load game state (OFFLINE-FIRST: Snapshot → SQLite → SharedPrefs → Firebase)
  Future<bool> loadGame() async {
    try {
      print('🔄 Starting game load process...');
      
      // 1. PRIORITY: Try loading latest snapshot (most recent state)
      final snapshotLoaded = await loadSnapshot();
      if (snapshotLoaded) {
        print('✅ Loaded from snapshot');
        // Firebase sync happens automatically every 5 minutes via periodic timer
        startGame(); // Start game loop after loading
        return true;
      }

      // 2. Fallback: Try loading from SQLite (primary storage)
      print('🔄 Trying SQLite...');
      final sqliteState = await _offlineDb.loadGameState();
      
      if (sqliteState != null) {
        _gameState = sqliteState;
        _notifyStateChanged();
        print('✅ Game loaded from SQLite - Money: ${_gameState.money}');
        
        // Firebase sync happens automatically every 5 minutes via periodic timer
        startGame(); // Start game loop after loading
        return true;
      }

      // 3. Fallback: Try loading from SharedPreferences (legacy)
      print('🔄 Trying SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_saveKey);

      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        _gameState = GameState.fromJson(json);
        
        // Migrate to SQLite
        await _offlineDb.saveGameState(_gameState);
        
        _notifyStateChanged();
        print('✅ Game loaded from SharedPreferences - Money: ${_gameState.money} (migrated to SQLite)');
        startGame(); // Start game loop after loading
        return true;
      }

      // 4. Fallback: Try loading from cloud (if signed in)
      print('🔄 Trying cloud...');
      final cloudState = await _syncService.forceDownloadFromCloud();
      if (cloudState) {
        final loadedState = await _offlineDb.loadGameState();
        if (loadedState != null) {
          _gameState = loadedState;
          _notifyStateChanged();
          print('✅ Game loaded from cloud - Money: ${_gameState.money}');
          startGame(); // Start game loop after loading
          return true;
        }
      }

      print('⚠️ No saved game found anywhere');
      return false;
    } catch (e) {
      print('❌ Error loading game: $e');
      return false;
    }
  }

  /// Check if player has played before
  Future<bool> hasPlayedBefore() async {
    try {
      // Check SQLite first
      final hasSqliteData = await _offlineDb.hasGameState();
      print('🔍 SQLite has data: $hasSqliteData');
      
      if (hasSqliteData) return true;

      // Check for snapshot
      final snapshot = await _offlineDb.loadScreenState('game_snapshot');
      print('🔍 Snapshot exists: ${snapshot != null}');
      
      if (snapshot != null) return true;

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final hasSharedPrefs = prefs.getBool(_hasPlayedBeforeKey) ?? false;
      print('🔍 SharedPreferences has data: $hasSharedPrefs');
      
      return hasSharedPrefs;
    } catch (e) {
      print('❌ Error checking if played before: $e');
      return false;
    }
  }

  /// Reset game (after game over or for new game)
  Future<void> resetGame() async {
    _gameLoopTimer?.cancel(); // Stop current game loop
    _gameState = GameState.fresh();
    await _offlineDb.deleteGameState();
    await saveGame();
    _notifyStateChanged();
    startGame(); // Start fresh game loop
    print('✅ Game reset to fresh state');
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
    WidgetsBinding.instance.removeObserver(this);
    _gameLoopTimer?.cancel();
    _snapshotTimer?.cancel();
    _saveSnapshot(); // Final snapshot before dispose
    _stateController.close();
    _syncService.dispose();
  }
}

