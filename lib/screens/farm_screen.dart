import 'package:flutter/material.dart';
import 'dart:async';
import '../models/loan.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../models/game_state.dart';
import '../services/game_service.dart';
import '../widgets/plot_widget.dart';
import '../widgets/shop_bottom_sheet.dart';
import 'game_over_screen.dart';

class FarmScreen extends StatefulWidget {
  final Loan? initialLoan;
  final GameService? gameService;

  const FarmScreen({super.key, this.initialLoan, this.gameService});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> {
  late GameService _gameService;
  Plot? _selectedPlot;
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _gameService = widget.gameService ?? GameService();
    _gameService.onGameOver = _handleGameOver;

    // Take initial loan if provided
    if (widget.initialLoan != null) {
      _gameService.takeLoan(widget.initialLoan!);
    }

    // Listen to game state changes
    _stateSubscription = _gameService.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  void _handleGameOver() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameOverScreen(
          totalEarnings: _gameService.state.totalEarnings,
          cropsHarvested: _gameService.state.cropsHarvested,
          loansRepaid: _gameService.state.loansRepaid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _gameService.state;
    final hasLoan = state.hasActiveLoan;
    final loan = state.activeLoan;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade300,
              Colors.green.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Status bar
              _buildStatusBar(state, hasLoan, loan),
              // Farm plots
              Expanded(
                child: _buildFarmGrid(state),
              ),
              // Action panel (when plot selected)
              if (_selectedPlot != null) _buildActionPanel(),
              // Bottom navigation
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(GameState state, bool hasLoan, Loan? loan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    '\$${state.money}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              if (hasLoan && loan != null)
                Row(
                  children: [
                    const Text('📄', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'Debt: \$${loan.totalAmount}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (hasLoan && loan != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('⏰', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  loan.formattedTimeRemaining,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: loan.timeRemaining.inSeconds < 60
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
                const Spacer(),
                if (state.canAfford(loan.totalAmount))
                  ElevatedButton.icon(
                    onPressed: () {
                      _gameService.repayLoan();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Loan repaid! You\'re debt-free!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Text('💵'),
                    label: const Text('Repay Loan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: loan.timeProgress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                loan.timeRemaining.inSeconds < 60 ? Colors.red : Colors.orange,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFarmGrid(GameState state) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: state.plots.length,
      itemBuilder: (context, index) {
        final plot = state.plots[index];
        return PlotWidget(
          plot: plot,
          isSelected: _selectedPlot?.id == plot.id,
          onTap: () {
            setState(() {
              if (plot.isUnlocked) {
                _selectedPlot = plot;
              } else {
                // Try to unlock
                if (_gameService.unlockPlot(plot)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 Plot unlocked for \$${plot.unlockCost}!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Need \$${plot.unlockCost} to unlock this plot'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            });
          },
          gameService: _gameService,
        );
      },
    );
  }

  Widget _buildActionPanel() {
    final plot = _selectedPlot!;
    final crop = plot.crop;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plot ${int.parse(plot.id) + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedPlot = null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (plot.isEmpty)
            _ActionButton(
              icon: '🌱',
              label: 'Plant Seed',
              onPressed: () => _showShopBottomSheet(),
            )
          else if (plot.hasDeadCrop)
            _ActionButton(
              icon: '🗑️',
              label: 'Clear Dead Crop',
              onPressed: () {
                _gameService.clearDeadCrop(plot);
                setState(() => _selectedPlot = null);
              },
            )
          else if (plot.hasReadyCrop)
            _ActionButton(
              icon: '✂️',
              label: 'Harvest (+\$${crop!.type.sellPrice})',
              color: Colors.green,
              onPressed: () {
                if (_gameService.harvestCrop(plot)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 Harvested ${crop.type.name} for \$${crop.type.sellPrice}!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() => _selectedPlot = null);
                }
              },
            )
          else if (plot.hasLiveCrop) ...[
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: '💧',
                    label: 'Water',
                    color: crop!.state == CropState.needsWater ||
                            crop.state == CropState.wilting
                        ? Colors.blue
                        : Colors.grey,
                    onPressed: () {
                      _gameService.waterCrop(plot);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('💧 Watered!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: '🌿',
                    label: 'Remove Weeds',
                    color: crop.hasWeeds ? Colors.green : Colors.grey,
                    onPressed: crop.hasWeeds
                        ? () {
                            _gameService.removeWeeds(plot);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🌿 Weeds removed!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: '🐛',
              label: 'Remove Pests',
              color: crop.hasPests ? Colors.red : Colors.grey,
              onPressed: crop.hasPests
                  ? () {
                      _gameService.removePests(plot);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🐛 Pests removed!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavButton(
            icon: '🛒',
            label: 'Shop',
            onPressed: () => _showShopBottomSheet(),
          ),
          _NavButton(
            icon: '🏦',
            label: 'Bank',
            onPressed: () => _showBankInfo(),
          ),
          _NavButton(
            icon: '📊',
            label: 'Stats',
            onPressed: () => _showStats(),
          ),
        ],
      ),
    );
  }

  void _showShopBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ShopBottomSheet(
        gameService: _gameService,
        selectedPlot: _selectedPlot,
        onPlantSuccess: () {
          setState(() => _selectedPlot = null);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showBankInfo() {
    final state = _gameService.state;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('🏦'),
            SizedBox(width: 8),
            Text('Bank Info'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.hasActiveLoan) ...[
              Text('Active Loan: \$${state.activeLoan!.principal}'),
              Text('Interest: ${(state.activeLoan!.interestRate * 100).toStringAsFixed(0)}%'),
              Text('Total to Repay: \$${state.activeLoan!.totalAmount}'),
              Text('Time Remaining: ${state.activeLoan!.formattedTimeRemaining}'),
            ] else ...[
              const Text('No active loan'),
              const SizedBox(height: 8),
              const Text('You can take a new loan once you pay off the current one!'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStats() {
    final state = _gameService.state;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('📊'),
            SizedBox(width: 8),
            Text('Statistics'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💰 Current Money: \$${state.money}'),
            Text('📈 Total Earnings: \$${state.totalEarnings}'),
            Text('🌾 Crops Harvested: ${state.cropsHarvested}'),
            Text('🏦 Loans Repaid: ${state.loansRepaid}'),
            Text('🌱 Unlocked Plots: ${state.unlockedPlotsCount}/${state.plots.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onPressed;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

