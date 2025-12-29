import 'package:flutter/material.dart';
import '../models/crop_type.dart';
import '../models/plot.dart';
import '../services/game_service.dart';

class ShopBottomSheet extends StatelessWidget {
  final GameService gameService;
  final Plot? selectedPlot;
  final VoidCallback? onPlantSuccess;

  const ShopBottomSheet({
    super.key,
    required this.gameService,
    this.selectedPlot,
    this.onPlantSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final state = gameService.state;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Row(
            children: [
              const Text('🛒', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              const Text(
                'Seed Shop',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 4),
                  Text(
                    '\$${state.money}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Info message
          if (selectedPlot == null || !selectedPlot.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select an empty plot to plant',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Select a seed to plant on Plot ${selectedPlot != null ? int.parse(selectedPlot.id) + 1 : "?"}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          const SizedBox(height: 16),
          // Crop list
          ...CropType.allCrops.map((cropType) {
            final canAfford = state.canAfford(cropType.seedCost);
            final canPlant = selectedPlot != null &&
                selectedPlot.isEmpty &&
                canAfford;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SeedCard(
                cropType: cropType,
                canAfford: canAfford,
                canPlant: canPlant,
                onTap: canPlant
                    ? () {
                        if (gameService.plantCrop(selectedPlot!, cropType)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '🌱 Planted ${cropType.name} seed!',
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                          onPlantSuccess?.call();
                        }
                      }
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SeedCard extends StatelessWidget {
  final CropType cropType;
  final bool canAfford;
  final bool canPlant;
  final VoidCallback? onTap;

  const _SeedCard({
    required this.cropType,
    required this.canAfford,
    required this.canPlant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: canAfford
              ? Colors.green.shade50
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canAfford
                ? Colors.green.shade300
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Opacity(
              opacity: canAfford ? 1.0 : 0.5,
              child: Text(
                cropType.emoji,
                style: const TextStyle(
                  fontSize: 40,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cropType.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: canAfford ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _InfoBadge(
                        icon: '⏱️',
                        text: '${cropType.growthTimeSeconds}s',
                      ),
                      const SizedBox(width: 8),
                      _InfoBadge(
                        icon: '💰',
                        text: '+\$${cropType.sellPrice}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Price
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: canAfford ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\$${cropType.seedCost}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Profit: \$${cropType.sellPrice - cropType.seedCost}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String icon;
  final String text;

  const _InfoBadge({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

