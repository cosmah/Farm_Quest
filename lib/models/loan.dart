/// Represents a bank loan
class Loan {
  final int principal; // Original loan amount
  final double interestRate; // Interest rate (e.g., 0.05 for 5%)
  final DateTime takenAt; // When the loan was taken
  final int durationSeconds; // How long to repay
  bool isPaid;
  int pausedTimeSeconds; // Total time the game was paused

  Loan({
    required this.principal,
    required this.interestRate,
    required this.takenAt,
    required this.durationSeconds,
    this.isPaid = false,
    this.pausedTimeSeconds = 0,
  });

  /// Total amount to repay (principal + interest)
  int get totalAmount => (principal * (1 + interestRate)).round();

  /// Time remaining to repay the loan (accounting for pause time)
  Duration timeRemaining(int additionalPausedSeconds) {
    final totalPaused = pausedTimeSeconds + additionalPausedSeconds;
    final deadline = takenAt.add(Duration(seconds: durationSeconds + totalPaused));
    final now = DateTime.now();
    final remaining = deadline.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Is the loan deadline passed?
  bool isOverdue(int additionalPausedSeconds) => 
      timeRemaining(additionalPausedSeconds) == Duration.zero;

  /// Progress of time elapsed (0.0 to 1.0)
  double timeProgress(int additionalPausedSeconds) {
    final totalPaused = pausedTimeSeconds + additionalPausedSeconds;
    final elapsed = DateTime.now().difference(takenAt).inSeconds - totalPaused;
    return (elapsed / durationSeconds).clamp(0.0, 1.0);
  }

  /// Formatted time remaining string
  String formattedTimeRemaining(int additionalPausedSeconds) {
    final duration = timeRemaining(additionalPausedSeconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'principal': principal,
        'interestRate': interestRate,
        'takenAt': takenAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'isPaid': isPaid,
        'pausedTimeSeconds': pausedTimeSeconds,
      };

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      principal: json['principal'],
      interestRate: json['interestRate'],
      takenAt: DateTime.parse(json['takenAt']),
      durationSeconds: json['durationSeconds'],
      isPaid: json['isPaid'] ?? false,
      pausedTimeSeconds: json['pausedTimeSeconds'] ?? 0,
    );
  }

  // Predefined loan options
  static Loan small() => Loan(
        principal: 500,
        interestRate: 0.05,
        takenAt: DateTime.now(),
        durationSeconds: 300, // 5 minutes
      );

  static Loan medium() => Loan(
        principal: 2000,
        interestRate: 0.08,
        takenAt: DateTime.now(),
        durationSeconds: 600, // 10 minutes
      );

  static Loan large() => Loan(
        principal: 5000,
        interestRate: 0.12,
        takenAt: DateTime.now(),
        durationSeconds: 900, // 15 minutes
      );
}

