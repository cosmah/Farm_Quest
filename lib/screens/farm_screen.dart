import 'package:flutter/material.dart';
import 'dart:async';
import '../models/loan.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../models/crop_type.dart';
import '../models/game_state.dart';
import '../services/game_service.dart';
import '../services/sound_service.dart';
import '../widgets/plot_widget.dart';
import 'game_over_screen.dart';

class FarmScreen extends StatefulWidget {
  final Loan? initialLoan;
  final GameService? gameService;

  const FarmScreen({super.key, this.initialLoan, this.gameService});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> with WidgetsBindingObserver {
  late GameService _gameService;
  final SoundService _soundService = SoundService();
  Plot? _selectedPlot;
  StreamSubscription? _stateSubscription;
  int _previousLevel = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameService = widget.gameService ?? GameService();
    _gameService.onGameOver = _handleGameOver;
    _previousLevel = _gameService.state.level;

    // Take initial loan if provided
    if (widget.initialLoan != null) {
      _gameService.takeLoan(widget.initialLoan!);
    }

    // Listen to game state changes
    _stateSubscription = _gameService.stateStream.listen((state) {
      if (mounted) {
        // Check for level up
        if (state.level > _previousLevel) {
          _showLevelUpNotification(state.level);
          _previousLevel = state.level;
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Only pause when app goes to background completely
    if (state == AppLifecycleState.paused) {
      // App going to background - save but keep running
      _gameService.saveGame();
    } else if (state == AppLifecycleState.detached) {
      // App closing - pause and save
      _gameService.pauseGame();
      _gameService.saveGame();
    }
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

  void _showLevelUpNotification(int newLevel) {
    _soundService.levelUpSound();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LEVEL UP!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'You reached Level $newLevel!',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.purple.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _gameService.state;
    final hasLoan = state.hasActiveLoan;
    final loan = state.activeLoan;
    final isPaused = _gameService.isPaused;

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
        child: Stack(
          children: [
            SafeArea(
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
                ],
              ),
            ),
            // Paused overlay
            if (isPaused)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '⏸️',
                          style: TextStyle(fontSize: 80),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'GAME PAUSED',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Everything is stopped',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            _gameService.resumeGame();
                            setState(() {});
                          },
                          icon: const Text('▶️', style: TextStyle(fontSize: 24)),
                          label: const Text(
                            'Resume Game',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(GameState state, bool hasLoan, Loan? loan) {
    final isPaused = _gameService.isPaused;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPaused 
            ? Colors.orange.shade100.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pause button
              InkWell(
                onTap: () {
                  if (_gameService.isPaused) {
                    _soundService.resumeSound();
                    _gameService.resumeGame();
                  } else {
                    _soundService.pauseSound();
                    _gameService.pauseGame();
                  }
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gameService.isPaused ? Colors.orange : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _gameService.isPaused ? Colors.orange.shade700 : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _gameService.isPaused ? '▶️' : '⏸️',
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (_gameService.isPaused) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'PAUSED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Money
              Expanded(
                child: Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text(
                      '\$${state.money}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              // Level & XP
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      'Lv${state.level}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Debt
              if (hasLoan && loan != null)
                Row(
                  children: [
                    const Text('📄', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      '\$${loan.totalAmount}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
              // Timer
              if (hasLoan && loan != null)
                Row(
                  children: [
                    const Text('⏰', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      loan.formattedTimeRemaining(_gameService.currentPauseDuration),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: loan.timeRemaining(_gameService.currentPauseDuration).inSeconds < 60
                            ? Colors.red
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              // Repay button (compact)
              if (hasLoan && loan != null && state.canAfford(loan.totalAmount)) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    _gameService.repayLoan();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎉 Loan repaid!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('💵', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 4),
                        Text(
                          'Pay',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          // XP Progress bar
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: state.xpProgress,
                    backgroundColor: Colors.purple.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.purple.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${state.experience}/${state.xpForNextLevel}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Loan progress bar (compact)
          if (hasLoan && loan != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: loan.timeProgress(_gameService.currentPauseDuration),
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  loan.timeRemaining(_gameService.currentPauseDuration).inSeconds < 60 
                      ? Colors.red 
                      : Colors.orange,
                ),
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
            Column(
              children: [
                const Text(
                  'Select a seed to plant:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...CropType.allCrops.map((cropType) {
                  final canAfford = _gameService.state.canAfford(cropType.seedCost);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PlantSeedButton(
                      cropType: cropType,
                      canAfford: canAfford,
                      onPressed: canAfford
                          ? () {
                              if (_gameService.plantCrop(plot, cropType)) {
                                _soundService.plantSound();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🌱 Planted ${cropType.name}!'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                                setState(() => _selectedPlot = null);
                              }
                            }
                          : null,
                    ),
                  );
                }),
              ],
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
                  _soundService.harvestSound();
                  _soundService.coinSound();
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
                  child:                   _ActionButton(
                    icon: '💧',
                    label: 'Water',
                    color: crop!.getState(_gameService.currentPauseDuration) == CropState.needsWater ||
                            crop.getState(_gameService.currentPauseDuration) == CropState.wilting
                        ? Colors.blue
                        : Colors.grey,
                    onPressed: () {
                      _soundService.waterSound();
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
                            _soundService.weedSound();
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
                      _soundService.pestSound();
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

class _PlantSeedButton extends StatelessWidget {
  final CropType cropType;
  final bool canAfford;
  final VoidCallback? onPressed;

  const _PlantSeedButton({
    required this.cropType,
    required this.canAfford,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: canAfford ? Colors.green : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Text(cropType.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cropType.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${cropType.growthTimeSeconds}s → \$${cropType.sellPrice}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '\$${cropType.seedCost}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

