import 'package:flutter/material.dart';
import '../models/loan.dart';
import '../services/game_service.dart';
import 'main_game_screen.dart';

class BankScreen extends StatelessWidget {
  final GameService? gameService;

  const BankScreen({super.key, this.gameService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A237E),
              const Color(0xFF283593),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Bank icon
                  const Text('🏦', style: TextStyle(fontSize: 80)),
                  const SizedBox(height: 16),
                  const Text(
                    'First Bank',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Bank manager
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🧑‍💼', style: TextStyle(fontSize: 60)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Dialogue
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Welcome, aspiring farmer!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'I can offer you a loan to start your farm. '
                          'Choose wisely - you must repay within the deadline, '
                          'or you\'ll lose everything!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Loan options
                  _LoanOption(
                    title: 'Small Loan',
                    emoji: '💵',
                    amount: '\$500',
                    interest: '5%',
                    time: '5 minutes',
                    totalRepay: '\$525',
                    color: Colors.green,
                    onTap: () => _selectLoan(context, Loan.small()),
                  ),
                  const SizedBox(height: 16),
                  _LoanOption(
                    title: 'Medium Loan',
                    emoji: '💰',
                    amount: '\$2,000',
                    interest: '8%',
                    time: '10 minutes',
                    totalRepay: '\$2,160',
                    color: Colors.orange,
                    onTap: () => _selectLoan(context, Loan.medium()),
                  ),
                  const SizedBox(height: 16),
                  _LoanOption(
                    title: 'Large Loan',
                    emoji: '💎',
                    amount: '\$5,000',
                    interest: '12%',
                    time: '15 minutes',
                    totalRepay: '\$5,600',
                    color: Colors.red,
                    onTap: () => _selectLoan(context, Loan.large()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectLoan(BuildContext context, Loan loan) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainGameScreen(
          initialLoan: loan,
          gameService: gameService,
        ),
      ),
    );
  }
}

class _LoanOption extends StatelessWidget {
  final String title;
  final String emoji;
  final String amount;
  final String interest;
  final String time;
  final String totalRepay;
  final Color color;
  final VoidCallback onTap;

  const _LoanOption({
    required this.title,
    required this.emoji,
    required this.amount,
    required this.interest,
    required this.time,
    required this.totalRepay,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        amount,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoChip(label: 'Interest', value: interest),
                _InfoChip(label: 'Time', value: time),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total to Repay:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    totalRepay,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

