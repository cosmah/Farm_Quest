import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../models/crop.dart';
import '../models/crop_type.dart';
import '../models/plot.dart';
import '../models/loan.dart';

class GameService {
  static const String _saveKey = 'game_state';
  static const String _hasPlayedBeforeKey = 'has_played_before';

  GameState _gameState = GameState.fresh();
  Timer? _gameLoopTimer;
  final Random _random = Random();

  final _stateController = StreamController<GameState>.broadcast();
  Stream<GameState> get stateStream => _stateController.stream;

  GameState get state => _gameState;

  // Callbacks
  Function? onGameOver;

  GameService() {
    _startGameLoop();
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
    final now = DateTime.now();
    bool needsUpdate = false;

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

        // Check if crop should die from lack of water
        final secondsSinceWatered = now.difference(crop.lastWatered).inSeconds;
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

        // Random pest spawn
        if (!crop.hasPests && !crop.isDead && _random.nextDouble() < crop.type.pestSpawnChance / 60) {
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
    if (_gameState.hasActiveLoan && _gameState.activeLoan!.isOverdue) {
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

  void _triggerGameOver() {
    _gameLoopTimer?.cancel();
    onGameOver?.call();
  }

  /// Plant a crop on a plot
  bool plantCrop(Plot plot, CropType cropType) {
    if (!plot.isEmpty || !_gameState.canAfford(cropType.seedCost)) {
      return false;
    }

    if (_gameState.spendMoney(cropType.seedCost)) {
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
      _gameState.earnMoney(crop.type.sellPrice);
      _gameState.cropsHarvested++;
      plot.clearCrop();
      _notifyStateChanged();
      saveGame();
      return true;
    }
    return false;
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
      if (_gameState.spendMoney(plot.unlockCost)) {
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
    _gameState.earnMoney(loan.principal);
    _notifyStateChanged();
    saveGame();
  }

  /// Repay the active loan
  bool repayLoan() {
    if (_gameState.hasActiveLoan && 
        _gameState.canAfford(_gameState.activeLoan!.totalAmount)) {
      _gameState.payLoan();
      _notifyStateChanged();
      saveGame();
      return true;
    }
    return false;
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

