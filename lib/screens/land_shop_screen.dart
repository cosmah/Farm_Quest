import 'package:flutter/material.dart';
import 'dart:async';
import '../services/game_service.dart';

class LandShopScreen extends StatefulWidget {
  final GameService gameService;

  const LandShopScreen({super.key, required this.gameService});

  @override
  State<LandShopScreen> createState() => _LandShopScreenState();
}

class _LandShopScreenState extends State<LandShopScreen> {
  StreamSubscription? _stateSubscription;

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
    final plots = state.plots;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏞️ Land Shop'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.brown.shade300, Colors.brown.shade600],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    '🗺️ Farm Expansion',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlocked: ${state.unlockedPlotsCount} / ${plots.length} plots',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...plots.asMap().entries.map((entry) {
              final index = entry.key;
              final plot = entry.value;
              return _buildPlotCard(plot, index + 1, state);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlotCard(plot, int plotNumber, state) {
    if (plot.isUnlocked) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plot $plotNumber',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Unlocked & Active',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ],
          ),
        ),
      );
    }

    final canAfford = state.canAfford(plot.unlockCost);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('🟫', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plot $plotNumber',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Expand your farm',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${plot.unlockCost}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: canAfford ? () => _unlockPlot(plot, plotNumber) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAfford ? Colors.brown : Colors.grey,
                  ),
                  child: const Text('Unlock'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _unlockPlot(plot, int plotNumber) {
    final state = widget.gameService.state;
    if (state.spendMoney(plot.unlockCost)) {
      plot.isUnlocked = true;
      widget.gameService.saveGame();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🏞️ Plot $plotNumber unlocked!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    }
  }
}

