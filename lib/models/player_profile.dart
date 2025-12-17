/// Player profile model for Firebase Firestore
class PlayerProfile {
  final String uid;
  final String displayName;
  final int level;
  final int totalMoney;
  final int cropsHarvested;
  final int plotsUnlocked;
  final int daysPlayed;
  final int score; // Calculated score for leaderboard
  final DateTime lastUpdated;
  final DateTime createdAt;

  PlayerProfile({
    required this.uid,
    required this.displayName,
    required this.level,
    required this.totalMoney,
    required this.cropsHarvested,
    required this.plotsUnlocked,
    required this.daysPlayed,
    required this.score,
    required this.lastUpdated,
    required this.createdAt,
  });

  /// Calculate player score based on multiple factors
  static int calculateScore({
    required int level,
    required int money,
    required int cropsHarvested,
    required int plotsUnlocked,
  }) {
    return (level * 1000) +
        (money ~/ 10) +
        (cropsHarvested * 50) +
        (plotsUnlocked * 500);
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'level': level,
      'totalMoney': totalMoney,
      'cropsHarvested': cropsHarvested,
      'plotsUnlocked': plotsUnlocked,
      'daysPlayed': daysPlayed,
      'score': score,
      'lastUpdated': lastUpdated.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from Firestore document
  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    return PlayerProfile(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? 'Anonymous',
      level: map['level'] ?? 1,
      totalMoney: map['totalMoney'] ?? 0,
      cropsHarvested: map['cropsHarvested'] ?? 0,
      plotsUnlocked: map['plotsUnlocked'] ?? 3,
      daysPlayed: map['daysPlayed'] ?? 0,
      score: map['score'] ?? 0,
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  PlayerProfile copyWith({
    String? uid,
    String? displayName,
    int? level,
    int? totalMoney,
    int? cropsHarvested,
    int? plotsUnlocked,
    int? daysPlayed,
    int? score,
    DateTime? lastUpdated,
    DateTime? createdAt,
  }) {
    return PlayerProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      level: level ?? this.level,
      totalMoney: totalMoney ?? this.totalMoney,
      cropsHarvested: cropsHarvested ?? this.cropsHarvested,
      plotsUnlocked: plotsUnlocked ?? this.plotsUnlocked,
      daysPlayed: daysPlayed ?? this.daysPlayed,
      score: score ?? this.score,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

