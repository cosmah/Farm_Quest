import 'package:flutter/material.dart';
import 'dart:async';
import '../models/crop_type.dart';
import '../models/game_state.dart';
import '../services/game_service.dart';

class ShopScreen extends StatefulWidget {
  final GameService gameService;

  const ShopScreen({super.key, required this.gameService});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('🌱 Seeds Shop'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade300,
              Colors.green.shade600,
            ],
          ),
        ),
        child: Column(
          children: [
            // Money display
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💰', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    '\$${state.money}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // Seeds list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: CropType.allCrops.map((cropType) {
                  return _buildSeedCard(cropType, state);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedCard(CropType cropType, GameState state) {
    final owned = state.getSeedQuantity(cropType.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(cropType.emoji, style: const TextStyle(fontSize: 50)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cropType.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Owned: $owned seeds',
                        style: TextStyle(
                          fontSize: 16,
                          color: owned > 0 ? Colors.green : Colors.grey,
                          fontWeight: owned > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⏱️ ${cropType.growthTimeSeconds}s growth'),
                      Text('💵 Sells for \$${cropType.sellPrice}'),
                      Text('🌱 \$${cropType.seedCost}/seed'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildBuyButton(cropType, 1),
                const SizedBox(width: 8),
                _buildBuyButton(cropType, 5),
                const SizedBox(width: 8),
                _buildBuyButton(cropType, 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyButton(CropType cropType, int quantity) {
    final totalCost = cropType.seedCost * quantity;
    final canAfford = widget.gameService.state.canAfford(totalCost);

    return ElevatedButton(
      onPressed: canAfford ? () => _buySeeds(cropType, quantity) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: canAfford ? Colors.green : Colors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Column(
        children: [
          Text(
            'Buy $quantity',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          Text(
            '\$${totalCost}',
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _buySeeds(CropType cropType, int quantity) {
    if (widget.gameService.buySeeds(cropType, quantity)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌱 Bought $quantity ${cropType.name} seeds!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
      setState(() {});
    }
  }
}
