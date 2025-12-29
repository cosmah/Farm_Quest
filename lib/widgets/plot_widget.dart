import 'package:flutter/material.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../services/game_service.dart';

class PlotWidget extends StatelessWidget {
  final Plot plot;
  final bool isSelected;
  final VoidCallback onTap;
  final GameService gameService;

  const PlotWidget({
    super.key,
    required this.plot,
    required this.isSelected,
    required this.onTap,
    required this.gameService,
  });

  @override
  Widget build(BuildContext context) {
    if (!plot.isUnlocked) {
      return _buildLockedPlot();
    }

    return _buildUnlockedPlot();
  }

  Widget _buildLockedPlot() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade600,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              '\$${plot.unlockCost}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Tap to unlock',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedPlot() {
    final crop = plot.crop;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _getPlotColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.brown.shade700,
            width: isSelected ? 4 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.amber.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: isSelected ? 10 : 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (crop == null)
                    const Text(
                      '🟫',
                      style: TextStyle(fontSize: 50),
                    )
                  else ...[
                    Text(
                      crop.emoji,
                      style: const TextStyle(fontSize: 50),
                    ),
                    const SizedBox(height: 8),
                    if (!crop.isDead && crop.growthProgress < 1.0)
                      SizedBox(
                        width: 60,
                        child: LinearProgressIndicator(
                          value: crop.growthProgress,
                          backgroundColor: Colors.brown.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getProgressColor(crop),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            // Indicators
            if (crop != null) ...[
              // Worker badge (top-left, priority position)
              ...gameService.state.getWorkersManagingPlot(int.parse(plot.id)).map((worker) {
                return Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(worker.icon, style: const TextStyle(fontSize: 16)),
                  ),
                );
              }).toList(),
              // Water indicator
              if (crop.getState(gameService.state.totalPausedSeconds) == CropState.needsWater ||
                  crop.getState(gameService.state.totalPausedSeconds) == CropState.wilting)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: crop.getState(gameService.state.totalPausedSeconds) == CropState.wilting
                          ? Colors.red
                          : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('💧', style: TextStyle(fontSize: 16)),
                  ),
                ),
              // Weeds indicator
              if (crop.hasWeeds)
                const Positioned(
                  bottom: 8,
                  left: 8,
                  child: Text('🌿', style: TextStyle(fontSize: 20)),
                ),
              // Pests indicator
              if (crop.hasPests)
                const Positioned(
                  bottom: 8,
                  right: 8,
                  child: Text('🐛', style: TextStyle(fontSize: 20)),
                ),
              // Ready indicator (centered bottom)
              if (crop.getState(gameService.state.totalPausedSeconds) == CropState.ready)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '✓ Ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPlotColor() {
    if (plot.crop == null) {
      return Colors.brown.shade400;
    }
    final crop = plot.crop;
    if (crop == null) return Colors.brown.shade400;
    
    if (crop.isDead) {
      return Colors.grey.shade600;
    }
    if (crop.getState(gameService.state.totalPausedSeconds) == CropState.ready) {
      return Colors.green.shade400;
    }
    if (crop.getState(gameService.state.totalPausedSeconds) == CropState.wilting) {
      return Colors.brown.shade600;
    }
    return Colors.brown.shade300;
  }

  Color _getProgressColor(Crop crop) {
    if (crop.hasWeeds) return Colors.orange;
    if (crop.hasPests) return Colors.red;
    return Colors.green;
  }
}

