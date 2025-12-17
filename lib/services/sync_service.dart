import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_database_service.dart';
import 'firebase_service.dart';
import '../models/game_state.dart';
import '../models/transaction.dart' as game_transaction;
import '../models/plot.dart';

/// Professional sync service
/// Handles bidirectional sync between SQLite and Firebase
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OfflineDatabaseService _offlineDb = OfflineDatabaseService();
  final FirebaseService _firebaseService = FirebaseService();
  final Connectivity _connectivity = Connectivity();

  Timer? _periodicSyncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Sync status stream
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Initialize sync service
  Future<void> initialize() async {
    print('🔄 Initializing Sync Service...');

    // Get last sync time
    _lastSyncTime = await _offlineDb.getLastSyncTime();

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _onConnectivityChanged(result.first);
    });

    // Start periodic sync (every 5 minutes)
    _startPeriodicSync();

    print('✅ Sync Service initialized');
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncNow();
    });
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    if (result != ConnectivityResult.none) {
      print('📶 Internet connected - will sync on next 5-minute interval');
      _syncStatusController.add(SyncStatus.idle);
      // Don't sync immediately - wait for periodic timer (every 5 minutes)
    } else {
      print('📵 Internet disconnected - working offline');
      _syncStatusController.add(SyncStatus.offline);
    }
  }

  /// Sync now (can be called manually)
  Future<SyncResult> syncNow() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      print('⏳ Sync already in progress');
      return SyncResult.alreadySyncing;
    }

    // Check if user is signed in
    if (!_firebaseService.isSignedIn) {
      print('🔒 User not signed in - skipping cloud sync');
      return SyncResult.notSignedIn;
    }

    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.first == ConnectivityResult.none) {
      print('📵 No internet connection');
      _syncStatusController.add(SyncStatus.offline);
      return SyncResult.noInternet;
    }

    try {
      _isSyncing = true;
      _syncStatusController.add(SyncStatus.syncing);

      print('🔄 Starting sync...');

      // STEP 1: Load local data
      final localGameState = await _offlineDb.loadGameState();
      if (localGameState == null) {
        print('⚠️ No local game state to sync');
        _isSyncing = false;
        _syncStatusController.add(SyncStatus.idle);
        return SyncResult.noLocalData;
      }

      // STEP 2: Load cloud data
      final cloudGameState = await _firebaseService.loadGameFromCloud();

      // STEP 3: Resolve conflicts and determine sync direction
      final syncStrategy = _determineSyncStrategy(localGameState, cloudGameState);

      switch (syncStrategy) {
        case SyncStrategy.uploadLocal:
          // Local is newer - upload to cloud
          print('⬆️ Uploading local data to cloud...');
          await _firebaseService.saveGameToCloud(localGameState);
          await _firebaseService.updatePlayerProfile(localGameState);
          await _offlineDb.markAllSynced();
          break;

        case SyncStrategy.downloadCloud:
          // Cloud is newer - download from cloud
          print('⬇️ Downloading cloud data to local...');
          await _offlineDb.saveGameState(cloudGameState!);
          break;

        case SyncStrategy.merge:
          // Merge both (use latest values for each field)
          print('🔀 Merging local and cloud data...');
          final mergedState = _mergeGameStates(localGameState, cloudGameState!);
          await _offlineDb.saveGameState(mergedState);
          await _firebaseService.saveGameToCloud(mergedState);
          await _firebaseService.updatePlayerProfile(mergedState);
          await _offlineDb.markAllSynced();
          break;

        case SyncStrategy.noSync:
          // Already in sync
          print('✅ Already in sync');
          break;
      }

      _lastSyncTime = DateTime.now();
      await _offlineDb.updateLastSyncTime(_lastSyncTime!);

      _syncStatusController.add(SyncStatus.synced);
      _isSyncing = false;

      print('✅ Sync completed successfully');
      return SyncResult.success;
    } catch (e) {
      print('❌ Sync failed: $e');
      _syncStatusController.add(SyncStatus.error);
      _isSyncing = false;
      return SyncResult.error;
    }
  }

  /// Determine sync strategy based on local and cloud data
  SyncStrategy _determineSyncStrategy(GameState local, GameState? cloud) {
    // No cloud data - upload local
    if (cloud == null) {
      return SyncStrategy.uploadLocal;
    }

    // Compare last modified timestamps (using experience as a proxy)
    // In a real system, each record would have a lastModified timestamp

    // If local has more progress, upload
    if (local.level > cloud.level ||
        local.cropsHarvested > cloud.cropsHarvested ||
        local.money > cloud.money) {
      return SyncStrategy.uploadLocal;
    }

    // If cloud has more progress, download
    if (cloud.level > local.level ||
        cloud.cropsHarvested > local.cropsHarvested ||
        cloud.money > local.money) {
      return SyncStrategy.downloadCloud;
    }

    // If both have different data at same level, merge
    if (local.money != cloud.money ||
        local.experience != cloud.experience) {
      return SyncStrategy.merge;
    }

    // Already in sync
    return SyncStrategy.noSync;
  }

  /// Merge two game states (conflict resolution)
  /// Strategy: Use maximum values for progress metrics, latest for others
  GameState _mergeGameStates(GameState local, GameState cloud) {
    // Merge seed inventory (keep maximum quantities)
    final mergedSeedInventory = <String, int>{...local.seedInventory};
    cloud.seedInventory.forEach((key, value) {
      mergedSeedInventory[key] = (mergedSeedInventory[key] ?? 0) > value 
          ? mergedSeedInventory[key]! 
          : value;
    });

    // Merge transactions (keep both, sorted by timestamp)
    final mergedTransactions = <game_transaction.Transaction>[
      ...local.transactions,
      ...cloud.transactions,
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Merge plots (unlock status from both)
    final mergedPlots = local.plots.map((localPlot) {
      final cloudPlot = cloud.plots.firstWhere(
        (p) => p.id == localPlot.id,
        orElse: () => localPlot,
      );
      // Use unlocked status from either (if either is unlocked, unlock it)
      return Plot(
        id: localPlot.id,
        crop: localPlot.crop ?? cloudPlot.crop,
        isUnlocked: localPlot.isUnlocked || cloudPlot.isUnlocked,
        unlockCost: localPlot.unlockCost,
      );
    }).toList();

    return GameState(
      // Use maximum progress values
      money: local.money > cloud.money ? local.money : cloud.money,
      experience: local.experience > cloud.experience ? local.experience : cloud.experience,
      level: local.level > cloud.level ? local.level : cloud.level,
      cropsHarvested: local.cropsHarvested > cloud.cropsHarvested 
          ? local.cropsHarvested 
          : cloud.cropsHarvested,
      totalEarnings: local.totalEarnings > cloud.totalEarnings 
          ? local.totalEarnings 
          : cloud.totalEarnings,
      loansRepaid: local.loansRepaid > cloud.loansRepaid 
          ? local.loansRepaid 
          : cloud.loansRepaid,
      daysPlayed: local.daysPlayed > cloud.daysPlayed 
          ? local.daysPlayed 
          : cloud.daysPlayed,
      
      // Use local for current game state
      plots: mergedPlots,
      activeWorkers: local.activeWorkers,
      activeLoan: local.activeLoan,
      ownedTools: local.ownedTools,
      seedInventory: mergedSeedInventory,
      transactions: mergedTransactions.take(100).toList(), // Keep last 100
      
      // Use local timestamps
      totalPausedSeconds: local.totalPausedSeconds,
      gameStartDate: local.gameStartDate.isBefore(cloud.gameStartDate) 
          ? local.gameStartDate 
          : cloud.gameStartDate,
      currentSeason: local.currentSeason > cloud.currentSeason 
          ? local.currentSeason 
          : cloud.currentSeason,
    );
  }

  /// Check sync status
  Future<SyncInfo> getSyncInfo() async {
    final lastSync = await _offlineDb.getLastSyncTime();
    final hasPending = await _offlineDb.hasPendingSync();
    final connectivityResult = await _connectivity.checkConnectivity();
    final isOnline = connectivityResult.first != ConnectivityResult.none;

    return SyncInfo(
      lastSyncTime: lastSync,
      hasPendingChanges: hasPending,
      isOnline: isOnline,
      isSignedIn: _firebaseService.isSignedIn,
      isSyncing: _isSyncing,
    );
  }

  /// Force upload to cloud (manual backup)
  Future<bool> forceUploadToCloud() async {
    try {
      final gameState = await _offlineDb.loadGameState();
      if (gameState == null) return false;

      await _firebaseService.saveGameToCloud(gameState);
      await _firebaseService.updatePlayerProfile(gameState);
      await _offlineDb.markAllSynced();

      print('✅ Force upload completed');
      return true;
    } catch (e) {
      print('❌ Force upload failed: $e');
      return false;
    }
  }

  /// Force download from cloud (restore backup)
  Future<bool> forceDownloadFromCloud() async {
    try {
      final gameState = await _firebaseService.loadGameFromCloud();
      if (gameState == null) return false;

      await _offlineDb.saveGameState(gameState);

      print('✅ Force download completed');
      return true;
    } catch (e) {
      print('❌ Force download failed: $e');
      return false;
    }
  }

  /// Dispose
  void dispose() {
    _periodicSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }
}

// ==================== ENUMS & DATA CLASSES ====================

enum SyncStatus {
  idle,
  syncing,
  synced,
  offline,
  error,
}

enum SyncResult {
  success,
  noInternet,
  notSignedIn,
  alreadySyncing,
  noLocalData,
  error,
}

enum SyncStrategy {
  uploadLocal,    // Local is newer
  downloadCloud,  // Cloud is newer
  merge,          // Merge both
  noSync,         // Already in sync
}

class SyncInfo {
  final DateTime? lastSyncTime;
  final bool hasPendingChanges;
  final bool isOnline;
  final bool isSignedIn;
  final bool isSyncing;

  SyncInfo({
    this.lastSyncTime,
    required this.hasPendingChanges,
    required this.isOnline,
    required this.isSignedIn,
    required this.isSyncing,
  });

  String get statusText {
    if (isSyncing) return 'Syncing...';
    if (!isSignedIn) return 'Not signed in';
    if (!isOnline) return 'Offline';
    if (hasPendingChanges) return 'Pending changes';
    if (lastSyncTime != null) {
      final diff = DateTime.now().difference(lastSyncTime!);
      if (diff.inMinutes < 1) return 'Just synced';
      if (diff.inHours < 1) return 'Synced ${diff.inMinutes}m ago';
      if (diff.inDays < 1) return 'Synced ${diff.inHours}h ago';
      return 'Synced ${diff.inDays}d ago';
    }
    return 'Never synced';
  }

  bool get canSync => isSignedIn && isOnline && !isSyncing;
}

