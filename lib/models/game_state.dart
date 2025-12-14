import 'plot.dart';
import 'loan.dart';

/// Global game state
class GameState {
  int money;
  List<Plot> plots;
  Loan? activeLoan;
  int workersHired;
  
  // Lifetime statistics
  int totalEarnings;
  int loansRepaid;
  int cropsHarvested;
  
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
    this.workersHired = 0,
    this.totalEarnings = 0,
    this.loansRepaid = 0,
    this.cropsHarvested = 0,
    this.experience = 0,
    this.level = 1,
    this.totalPausedSeconds = 0,
    DateTime? lastSaved,
  })  : plots = plots ?? _createInitialPlots(),
        lastSaved = lastSaved ?? DateTime.now();

  static List<Plot> _createInitialPlots() {
    return [
      Plot(id: '0', isUnlocked: true, unlockCost: 0),
      Plot(id: '1', isUnlocked: true, unlockCost: 0),
      Plot(id: '2', isUnlocked: true, unlockCost: 0),
      Plot(id: '3', isUnlocked: true, unlockCost: 0),
      Plot(id: '4', unlockCost: 150),
      Plot(id: '5', unlockCost: 300),
      Plot(id: '6', unlockCost: 500),
      Plot(id: '7', unlockCost: 800),
    ];
  }

  bool get hasActiveLoan => activeLoan != null && !activeLoan!.isPaid;
  
  int get unlockedPlotsCount => plots.where((p) => p.isUnlocked).length;

  List<Plot> get unlockedPlots => plots.where((p) => p.isUnlocked).toList();

  void earnMoney(int amount) {
    money += amount;
    totalEarnings += amount;
  }

  bool spendMoney(int amount) {
    if (money >= amount) {
      money -= amount;
      return true;
    }
    return false;
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
        'workersHired': workersHired,
        'totalEarnings': totalEarnings,
        'loansRepaid': loansRepaid,
        'cropsHarvested': cropsHarvested,
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
      workersHired: json['workersHired'] ?? 0,
      totalEarnings: json['totalEarnings'] ?? 0,
      loansRepaid: json['loansRepaid'] ?? 0,
      cropsHarvested: json['cropsHarvested'] ?? 0,
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
      workersHired: 0,
      totalEarnings: 0,
      loansRepaid: 0,
      cropsHarvested: 0,
      experience: 0,
      level: 1,
      totalPausedSeconds: 0,
    );
  }
}

