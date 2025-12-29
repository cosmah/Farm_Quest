import 'package:flutter/material.dart';
import 'dart:async';
import '../models/loan.dart';
import '../models/game_state.dart';
import '../models/transaction.dart';
import '../services/game_service.dart';
import 'package:intl/intl.dart';

class BankInfoScreen extends StatefulWidget {
  final GameService gameService;

  const BankInfoScreen({super.key, required this.gameService});

  @override
  State<BankInfoScreen> createState() => _BankInfoScreenState();
}

class _BankInfoScreenState extends State<BankInfoScreen> {
  StreamSubscription? _stateSubscription;
  int _selectedTab = 0; // 0=Loan, 1=Finances, 2=Taxes
  bool _isProcessingLoan = false;
  bool _isProcessingRepayment = false;

  @override
  void initState() {
    super.initState();
    _stateSubscription = widget.gameService.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.gameService.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏦 First Bank'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTabButton(0, '💳 Loan'),
                _buildTabButton(1, '📊 Finances'),
                _buildTabButton(2, '🏛️ Taxes'),
              ],
            ),
          ),
        ),
      ),
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
        child: _buildSelectedTab(state),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF1A237E) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF1A237E) : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTab(GameState state) {
    switch (_selectedTab) {
      case 0:
        return _buildLoanTab(state);
      case 1:
        return _buildFinancesTab(state);
      case 2:
        return _buildTaxesTab(state);
      default:
        return const SizedBox();
    }
  }

  // LOAN TAB
  Widget _buildLoanTab(GameState state) {
    final hasLoan = state.hasActiveLoan;
    final loan = state.activeLoan;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasLoan) ...[
          _buildLoanCard(loan!, state),
          const SizedBox(height: 16),
          _buildRepayButton(loan, state),
        ] else
          _buildNoLoanCard(),
      ],
    );
  }

  Widget _buildLoanCard(Loan loan, GameState state) {
    // Use current pause session seconds (loan already has stored pausedTimeSeconds)
    final timeLeft = loan.timeRemaining(widget.gameService.currentPauseSessionSeconds);
    final hours = timeLeft.inHours;
    final minutes = timeLeft.inMinutes % 60;
    final seconds = timeLeft.inSeconds % 60;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Loan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildLoanInfo('Principal', '\$${loan.principal}'),
            _buildLoanInfo('Interest', '${(loan.interestRate * 100).toStringAsFixed(0)}%'),
            _buildLoanInfo('Total to Repay', '\$${loan.totalAmount}'),
            const SizedBox(height: 12),
            const Text('Time Remaining:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '$hours h $minutes m $seconds s',
              style: TextStyle(
                fontSize: 24,
                color: timeLeft.inSeconds < 60 ? Colors.red : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: loan.timeProgress(widget.gameService.currentPauseSessionSeconds),
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                timeLeft.inSeconds < 60 ? Colors.red : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRepayButton(Loan loan, GameState state) {
    final canRepay = state.canAfford(loan.totalAmount);
    return ElevatedButton(
      onPressed: canRepay ? () => _repayLoan() : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: canRepay ? Colors.green : Colors.grey,
        padding: const EdgeInsets.all(16),
      ),
      child: Text(
        canRepay ? 'Repay Loan (\$${loan.totalAmount})' : 'Insufficient Funds',
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }

  Widget _buildNoLoanCard() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  '✅',
                  style: TextStyle(fontSize: 60),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Active Loan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have no outstanding loans!',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _showLoanOptions(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: const Text(
            '💰 Take New Loan',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showLoanOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Loan Amount'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLoanOption(500, 0.1, 300),
              _buildLoanOption(1000, 0.15, 600),
              _buildLoanOption(2000, 0.2, 900),
              _buildLoanOption(5000, 0.25, 1200),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanOption(int principal, double interestRate, int durationSeconds) {
    final interest = (principal * interestRate).round();
    final total = principal + interest;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text('\$$principal'),
        subtitle: Text(
          'Interest: ${(interestRate * 100).toStringAsFixed(0)}% • Total: \$$total\n'
          'Duration: ${(durationSeconds / 60).round()} minutes',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ElevatedButton(
          onPressed: () {
            final loan = Loan(
              principal: principal,
              interestRate: interestRate,
              durationSeconds: durationSeconds,
              takenAt: DateTime.now(),
            );
            widget.gameService.takeLoan(loan);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('💰 Loan of \$$principal approved!'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() {});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Take', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  void _repayLoan() async {
    if (_isProcessingRepayment) return;
    
    setState(() => _isProcessingRepayment = true);
    
    try {
      if (widget.gameService.repayLoan()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Loan repaid successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingRepayment = false);
      }
    }
  }

  // FINANCES TAB
  Widget _buildFinancesTab(GameState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFinanceSummaryCard(state),
        const SizedBox(height: 16),
        _buildTransactionsList(state),
      ],
    );
  }

  Widget _buildFinanceSummaryCard(GameState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Season ${state.currentSeason} Summary',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('💰 Income', '\$${state.seasonIncome}', Colors.green),
                _buildSummaryItem('💸 Expenses', '\$${state.seasonExpenses}', Colors.red),
                _buildSummaryItem('📈 Net', '\$${state.seasonIncome - state.seasonExpenses}', 
                  state.seasonIncome >= state.seasonExpenses ? Colors.green : Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(GameState state) {
    final transactions = state.seasonTransactions;
    
    if (transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No transactions this season',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Recent Transactions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        ...transactions.take(20).map((transaction) => _buildTransactionCard(transaction)),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isIncome = transaction.isIncome;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(transaction.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(transaction.description),
        subtitle: Text(DateFormat('MMM d, h:mm a').format(transaction.timestamp)),
        trailing: Text(
          '${isIncome ? "+" : "-"}\$${transaction.amount}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  // TAXES TAB
  Widget _buildTaxesTab(GameState state) {
    final taxAmount = state.calculateTaxes();
    final canPay = state.canAfford(taxAmount);
    final taxesPaid = state.taxesPaidThisSeason;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🏛️ Tax Information',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Season: ${state.currentSeason}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tax Rate: 15% of income',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const Divider(height: 32),
                _buildLoanInfo('Season Income', '\$${state.seasonIncome}'),
                _buildLoanInfo('Tax Amount (15%)', '\$${taxAmount}'),
                const SizedBox(height: 16),
                if (taxesPaid)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Row(
                      children: [
                        Text('✅', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Taxes paid for this season!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: canPay ? () => _payTaxes(taxAmount) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canPay ? const Color(0xFF1A237E) : Colors.grey,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Text(
                      canPay ? 'Pay Taxes (\$${taxAmount})' : 'Insufficient Funds',
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('💡', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 8),
                    Text(
                      'Tax Tips',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Taxes are calculated per season\n'
                  '• Pay before season ends to avoid penalties\n'
                  '• Only income is taxed, not expenses\n'
                  '• Tax resets each new season',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _payTaxes(int taxAmount) {
    if (widget.gameService.state.payTaxes()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🏛️ Paid \$${taxAmount} in taxes for Season ${widget.gameService.state.currentSeason}!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    }
  }
}
