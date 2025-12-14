enum TransactionType {
  income,
  expense,
}

enum TransactionCategory {
  // Income
  cropSale,
  loanTaken,
  
  // Expenses
  seedPurchase,
  workerHire,
  toolPurchase,
  plotUnlock,
  loanRepayment,
  taxPayment,
}

class Transaction {
  final TransactionType type;
  final TransactionCategory category;
  final int amount;
  final String description;
  final DateTime timestamp;
  final int seasonNumber; // Track which season this belongs to

  Transaction({
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.seasonNumber,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toString(),
        'category': category.toString(),
        'amount': amount,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'seasonNumber': seasonNumber,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      type: TransactionType.values.firstWhere((e) => e.toString() == json['type']),
      category: TransactionCategory.values.firstWhere((e) => e.toString() == json['category']),
      amount: json['amount'],
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']),
      seasonNumber: json['seasonNumber'] ?? 1,
    );
  }

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  String get emoji {
    switch (category) {
      case TransactionCategory.cropSale:
        return '🌾';
      case TransactionCategory.loanTaken:
        return '🏦';
      case TransactionCategory.seedPurchase:
        return '🌱';
      case TransactionCategory.workerHire:
        return '👨‍🌾';
      case TransactionCategory.toolPurchase:
        return '🛠️';
      case TransactionCategory.plotUnlock:
        return '🏞️';
      case TransactionCategory.loanRepayment:
        return '💳';
      case TransactionCategory.taxPayment:
        return '🏛️';
    }
  }
}

