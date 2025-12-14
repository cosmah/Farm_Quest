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

class GameService {
  static const String _saveKey = 'game_state';
  static const String _hasPlayedBeforeKey = 'has_played_before';

  GameState _gameState = GameState.fresh();
  Timer? _gameLoopTimer;
  final Random _random = Random();
  bool _isPaused = false;
  DateTime? _pauseStartTime;
  int _currentPauseSeconds = 0;

  final _stateController = StreamController<GameState>.broadcast();
  Stream<GameState> get stateStream => _stateController.stream;

  GameState get state => _gameState;
  bool get isPaused => _isPaused;

  // Callbacks
  Function? onGameOver;

  GameService() {
    _startGameLoop();
  }

  /// Get current pause duration in seconds
  int get currentPauseDuration {
    if (_isPaused && _pauseStartTime != null) {
      return DateTime.now().difference(_pauseStartTime!).inSeconds + _currentPauseSeconds;
    }
    return _currentPauseSeconds;
  }

  /// Pause the game (stops game loop and timer)
  void pauseGame() {
    if (!_isPaused) {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
      _gameLoopTimer?.cancel();
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

        // Update growth progress
        if (crop.growthProgress < 1.0 && !crop.isDead) {
          final secondsSincePlanted = now.difference(crop.plantedAt).inSeconds;
          double baseProgress = secondsSincePlanted / crop.type.growthTimeSeconds;

          // Slow down if has weeds
          if (crop.hasWeeds) {
            baseProgress *= 0.5;
          }

          crop.growthProgress = baseProgress.clamp(0.0, 1.0);
          needsUpdate = true;
        }

        // Check if crop should die from lack of water (accounting for pause time)
        final secondsSinceWatered = now.difference(crop.lastWatered).inSeconds - currentPauseDuration;
        if (secondsSinceWatered > crop.type.waterIntervalSeconds + 10) {
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

    // Check loan deadline
    if (_gameState.hasActiveLoan && _gameState.activeLoan!.isOverdue(currentPauseDuration)) {
      _triggerGameOver();
      return;
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

  /// Save game state
  Future<void> saveGame() async {
    _gameState.lastSaved = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_gameState.toJson());
    await prefs.setString(_saveKey, jsonString);
    await prefs.setBool(_hasPlayedBeforeKey, true);
  }

  /// Load game state
  Future<bool> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_saveKey);

    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString);
        _gameState = GameState.fromJson(json);
        _notifyStateChanged();
        return true;
      } catch (e) {
        // Error loading game, will start fresh
        return false;
      }
    }
    return false;
  }

  /// Check if player has played before
  Future<bool> hasPlayedBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasPlayedBeforeKey) ?? false;
  }

  /// Reset game (after game over)
  Future<void> resetGame() async {
    _gameState = GameState.fresh();
    await saveGame();
    _notifyStateChanged();
    _startGameLoop();
  }

  void _notifyStateChanged() {
    _stateController.add(_gameState);
  }

  void dispose() {
    _gameLoopTimer?.cancel();
    _stateController.close();
  }
}

