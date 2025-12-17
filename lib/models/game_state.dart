import 'plot.dart';
import 'loan.dart';
import 'worker.dart';
import 'tool.dart';
import 'transaction.dart';

/// Global game state
class GameState {
  int money;
  List<Plot> plots;
  Loan? activeLoan;
  List<Worker> activeWorkers;
  List<Tool> ownedTools; // Player's tool inventory
  Map<String, int> seedInventory; // cropType.id -> quantity
  List<Transaction> transactions; // Financial history
  
  // Season tracking
  int currentSeason;
  DateTime lastTaxPayment;
  bool taxesPaidThisSeason;
  
  // Lifetime statistics
  int totalEarnings;
  int loansRepaid;
  int cropsHarvested;
  int daysPlayed;
  DateTime gameStartDate;
  
  // Experience system
  int experience;
  int level;
  
  // Pause tracking
  int totalPausedSeconds;
  
  DateTime lastSaved;

  GameState({
    this.money = 0,
    List<Plot>? plots,
    this.activeLoan,
    List<Worker>? activeWorkers,
    List<Tool>? ownedTools,
    Map<String, int>? seedInventory,
    List<Transaction>? transactions,
    this.currentSeason = 1,
    DateTime? lastTaxPayment,
    this.taxesPaidThisSeason = false,
    this.totalEarnings = 0,
    this.loansRepaid = 0,
    this.cropsHarvested = 0,
    this.daysPlayed = 0,
    DateTime? gameStartDate,
    this.experience = 0,
    this.level = 1,
    this.totalPausedSeconds = 0,
    DateTime? lastSaved,
  })  : plots = plots ?? _createInitialPlots(),
        activeWorkers = activeWorkers ?? [],
        ownedTools = ownedTools ?? [],
        seedInventory = seedInventory ?? {},
        transactions = transactions ?? [],
        gameStartDate = gameStartDate ?? DateTime.now(),
        lastTaxPayment = lastTaxPayment ?? DateTime.now(),
        lastSaved = lastSaved ?? DateTime.now();

  static List<Plot> _createInitialPlots() {
    return [
      // Level 1: 3 free plots (changed from 4)
      Plot(id: '0', isUnlocked: true, unlockCost: 0),
      Plot(id: '1', isUnlocked: true, unlockCost: 0),
      Plot(id: '2', isUnlocked: true, unlockCost: 0),
      // Level 1: Plot 4
      Plot(id: '3', unlockCost: 200),
      // Level 3: plots 5-6
      Plot(id: '4', unlockCost: 300),
      Plot(id: '5', unlockCost: 400),
      // Level 5: plots 7-8
      Plot(id: '6', unlockCost: 600),
      Plot(id: '7', unlockCost: 800),
      // Level 7: plots 9-10
      Plot(id: '8', unlockCost: 1000),
      Plot(id: '9', unlockCost: 1200),
      // Level 10: plots 11-12
      Plot(id: '10', unlockCost: 1500),
      Plot(id: '11', unlockCost: 1800),
      // Level 12: plots 13-14
      Plot(id: '12', unlockCost: 2000),
      Plot(id: '13', unlockCost: 2500),
      // Level 15: plot 15
      Plot(id: '14', unlockCost: 3000),
    ];
  }

  bool get hasActiveLoan => activeLoan != null && !activeLoan!.isPaid;
  
  int get unlockedPlotsCount => plots.where((p) => p.isUnlocked).length;

  List<Plot> get unlockedPlots => plots.where((p) => p.isUnlocked).toList();
  
  // Compatibility getters
  int get totalCropsHarvested => cropsHarvested;
  
  // Calculate XP needed for next level
  int get experienceToNextLevel {
    // Progressive XP requirements: 100, 250, 500, 1000, etc.
    return 100 * level + (level * level * 50);
  }

  void earnMoney(int amount, {TransactionCategory? category, String? description}) {
    money += amount;
    totalEarnings += amount;
    if (category != null) {
      _recordTransaction(Transaction(
        type: TransactionType.income,
        category: category,
        amount: amount,
        description: description ?? category.toString(),
        timestamp: DateTime.now(),
        seasonNumber: currentSeason,
      ));
    }
  }

  bool spendMoney(int amount, {TransactionCategory? category, String? description}) {
    if (money >= amount) {
      money -= amount;
      if (category != null) {
        _recordTransaction(Transaction(
          type: TransactionType.expense,
          category: category,
          amount: amount,
          description: description ?? category.toString(),
          timestamp: DateTime.now(),
          seasonNumber: currentSeason,
        ));
      }
      return true;
    }
    return false;
  }

  void _recordTransaction(Transaction transaction) {
    transactions.add(transaction);
    // Keep only last 100 transactions to avoid memory bloat
    if (transactions.length > 100) {
      transactions.removeAt(0);
    }
  }

  void payLoan() {
    if (activeLoan != null && money >= activeLoan!.totalAmount) {
      money -= activeLoan!.totalAmount;
      activeLoan!.isPaid = true;
      loansRepaid++;
      activeLoan = null;
    }
  }

  bool canAfford(int cost) => money >= cost;

  // Worker management
  int get workersHired => activeWorkers.length;

  void hireWorker(Worker worker) {
    activeWorkers.add(worker);
  }

  void endAllWorkerContracts() {
    activeWorkers.clear();
  }

  bool hasWorkerType(WorkerType type) {
    return activeWorkers.any((w) => w.type == type);
  }

  bool hasToolType(ToolType type) {
    return ownedTools.any((t) => t.type == type && (t.isConsumable ? t.quantityOwned > 0 : true));
  }

  Worker? getWorkerForPlot(int plotIndex) {
    return activeWorkers.firstWhere(
      (w) => w.managesPlot(plotIndex),
      orElse: () => activeWorkers.first, // Return any worker if none specific
    );
  }

  List<Worker> getWorkersManagingPlot(int plotIndex) {
    return activeWorkers.where((w) => w.managesPlot(plotIndex)).toList();
  }

  // Check if all crops are harvested (season end condition)
  bool get isSeasonEnd {
    final unlockedPlotsWithCrops = plots
        .where((p) => p.isUnlocked && p.crop != null && !p.crop!.isHarvested)
        .toList();
    return unlockedPlotsWithCrops.isEmpty;
  }

  // Seed inventory management
  void addSeeds(String cropTypeId, int quantity) {
    seedInventory[cropTypeId] = (seedInventory[cropTypeId] ?? 0) + quantity;
  }

  bool useSeeds(String cropTypeId, int quantity) {
    final current = seedInventory[cropTypeId] ?? 0;
    if (current >= quantity) {
      seedInventory[cropTypeId] = current - quantity;
      return true;
    }
    return false;
  }

  int getSeedQuantity(String cropTypeId) {
    return seedInventory[cropTypeId] ?? 0;
  }

  bool hasSeeds(String cropTypeId, int quantity) {
    return getSeedQuantity(cropTypeId) >= quantity;
  }

  // Tax system
  int calculateTaxes() {
    // Tax = 15% of income this season
    final seasonIncome = transactions
        .where((t) => t.isIncome && t.seasonNumber == currentSeason)
        .fold<int>(0, (sum, t) => sum + t.amount);
    return (seasonIncome * 0.15).round();
  }

  int get seasonIncome {
    return transactions
        .where((t) => t.isIncome && t.seasonNumber == currentSeason)
        .fold<int>(0, (sum, t) => sum + t.amount);
  }

  int get seasonExpenses {
    return transactions
        .where((t) => t.isExpense && t.seasonNumber == currentSeason)
        .fold<int>(0, (sum, t) => sum + t.amount);
  }

  List<Transaction> get seasonTransactions {
    return transactions.where((t) => t.seasonNumber == currentSeason).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first
  }

  bool payTaxes() {
    final taxAmount = calculateTaxes();
    if (spendMoney(taxAmount, category: TransactionCategory.taxPayment, description: 'Season $currentSeason Taxes')) {
      taxesPaidThisSeason = true;
      lastTaxPayment = DateTime.now();
      return true;
    }
    return false;
  }

  // Tool management
  void buyTool(Tool tool) {
    if (tool.isConsumable) {
      // Check if already own this consumable
      final existing = ownedTools.firstWhere(
        (t) => t.type == tool.type,
        orElse: () => tool,
      );
      if (existing.type == tool.type && ownedTools.contains(existing)) {
        // Increase quantity
        ownedTools.remove(existing);
        ownedTools.add(existing.copyWith(quantityOwned: existing.quantityOwned + tool.quantityOwned));
      } else {
        ownedTools.add(tool);
      }
    } else {
      // Equipment - just add
      ownedTools.add(tool);
    }
  }

  bool useConsumableTool(ToolType type) {
    try {
      final tool = ownedTools.firstWhere((t) => t.type == type);
      if (tool.isConsumable && tool.quantityOwned > 0) {
        if (tool.quantityOwned > 1) {
          ownedTools.remove(tool);
          ownedTools.add(tool.copyWith(quantityOwned: tool.quantityOwned - 1));
        } else {
          ownedTools.remove(tool);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  bool hasTool(ToolType type) {
    return ownedTools.any((t) => t.type == type && (!t.isConsumable || t.quantityOwned > 0));
  }

  int getToolQuantity(ToolType type) {
    final tool = ownedTools.where((t) => t.type == type).firstOrNull;
    return tool?.quantityOwned ?? 0;
  }

  Tool? getToolForPlot(int plotIndex, ToolType type) {
    return ownedTools.firstWhere(
      (t) => t.type == type && t.isInstalledOnPlot(plotIndex),
      orElse: () => ownedTools.first,
    );
  }

  // Experience system
  int get xpForNextLevel => level * 100; // 100 XP for level 2, 200 for level 3, etc.
  double get xpProgress => experience / xpForNextLevel;

  void addExperience(int xp) {
    experience += xp;
    _checkLevelUp();
  }

  void _checkLevelUp() {
    while (experience >= xpForNextLevel) {
      experience -= xpForNextLevel;
      level++;
    }
  }

  Map<String, dynamic> toJson() => {
        'money': money,
        'plots': plots.map((p) => p.toJson()).toList(),
        'activeLoan': activeLoan?.toJson(),
        'activeWorkers': activeWorkers.map((w) => w.toJson()).toList(),
        'ownedTools': ownedTools.map((t) => t.toJson()).toList(),
        'seedInventory': seedInventory,
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'currentSeason': currentSeason,
        'lastTaxPayment': lastTaxPayment.toIso8601String(),
        'taxesPaidThisSeason': taxesPaidThisSeason,
        'totalEarnings': totalEarnings,
        'loansRepaid': loansRepaid,
        'cropsHarvested': cropsHarvested,
        'daysPlayed': daysPlayed,
        'gameStartDate': gameStartDate.toIso8601String(),
        'experience': experience,
        'level': level,
        'totalPausedSeconds': totalPausedSeconds,
        'lastSaved': lastSaved.toIso8601String(),
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      money: json['money'] ?? 0,
      plots: (json['plots'] as List<dynamic>?)
              ?.map((p) => Plot.fromJson(p))
              .toList() ??
          _createInitialPlots(),
      activeLoan: json['activeLoan'] != null
          ? Loan.fromJson(json['activeLoan'])
          : null,
      activeWorkers: (json['activeWorkers'] as List<dynamic>?)
              ?.map((w) => Worker.fromJson(w))
              .toList() ??
          [],
      ownedTools: (json['ownedTools'] as List<dynamic>?)
              ?.map((t) => Tool.fromJson(t))
              .toList() ??
          [],
      seedInventory: Map<String, int>.from(json['seedInventory'] ?? {}),
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((t) => Transaction.fromJson(t))
              .toList() ??
          [],
      currentSeason: json['currentSeason'] ?? 1,
      lastTaxPayment: json['lastTaxPayment'] != null
          ? DateTime.parse(json['lastTaxPayment'])
          : DateTime.now(),
      taxesPaidThisSeason: json['taxesPaidThisSeason'] ?? false,
      totalEarnings: json['totalEarnings'] ?? 0,
      loansRepaid: json['loansRepaid'] ?? 0,
      cropsHarvested: json['cropsHarvested'] ?? 0,
      daysPlayed: json['daysPlayed'] ?? 0,
      gameStartDate: json['gameStartDate'] != null
          ? DateTime.parse(json['gameStartDate'])
          : DateTime.now(),
      experience: json['experience'] ?? 0,
      level: json['level'] ?? 1,
      totalPausedSeconds: json['totalPausedSeconds'] ?? 0,
      lastSaved: json['lastSaved'] != null
          ? DateTime.parse(json['lastSaved'])
          : DateTime.now(),
    );
  }

  /// Create a fresh game state (for new game or after game over)
  factory GameState.fresh() {
    return GameState(
      money: 0,
      plots: _createInitialPlots(),
      activeLoan: null,
      activeWorkers: [],
      ownedTools: [],
      totalEarnings: 0,
      loansRepaid: 0,
      cropsHarvested: 0,
      experience: 0,
      level: 1,
      totalPausedSeconds: 0,
    );
  }
}

