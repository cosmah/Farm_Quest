import 'package:flutter/material.dart';
import 'dart:async';
import '../models/loan.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../models/crop_type.dart';
import '../models/game_state.dart';
import '../models/tool.dart';
import '../services/game_service.dart';
import '../services/sound_service.dart';
import '../services/music_player_service.dart';
import '../widgets/plot_widget.dart';
import 'game_over_screen.dart';
import 'player_profile_screen.dart';

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
  final MusicPlayerService _musicPlayer = MusicPlayerService();
  Plot? _selectedPlot;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _musicStateSubscription;
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

    // Listen to music player state changes
    _musicStateSubscription = _musicPlayer.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSubscription?.cancel();
    _musicStateSubscription?.cancel();
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
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '⏸️',
                                style: TextStyle(fontSize: 40),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Title
                          const Text(
                            'GAME PAUSED',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Everything is stopped',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Resume Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                _soundService.resumeSound();
                                _gameService.resumeGame();
                                setState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('▶️', style: TextStyle(fontSize: 22)),
                                  SizedBox(width: 12),
                                  Text(
                                    'Resume Game',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Profile Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlayerProfileScreen(gameService: _gameService),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person, size: 22),
                                  SizedBox(width: 12),
                                  Text(
                                    'Profile & Leaderboard',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Back to Home Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.home, color: Colors.orange),
                                        SizedBox(width: 12),
                                        Text('Return to Home?'),
                                      ],
                                    ),
                                    content: const Text(
                                      'Your progress will be saved. You can continue later from the home screen.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          _gameService.saveGame();
                                          Navigator.of(context).pop(); // Close dialog
                                          // Navigate back to home screen, removing all routes
                                          Navigator.of(context).pushNamedAndRemoveUntil(
                                            '/',
                                            (route) => false,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Go Home'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.home, size: 22),
                                  SizedBox(width: 12),
                                  Text(
                                    'Back to Home',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Floating music controls (left side, middle) - only show when NOT paused
            if (_musicPlayer.playlist.isNotEmpty && !isPaused)
              Positioned(
                left: 8,
                top: MediaQuery.of(context).size.height * 0.4,
                child: _buildFloatingMusicControls(),
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
          // Quick Tools section for live crops
          if (plot.hasLiveCrop && crop != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🛠️ Quick Tools',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickToolButton(
                        icon: '💧',
                        label: 'Water Can',
                        quantity: _gameService.state.getToolQuantity(ToolType.waterCan),
                        onPressed: () {
                          if (_gameService.useTool(ToolType.waterCan)) {
                            _gameService.waterCrop(plot);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('💧 Used Water Can!'), duration: Duration(seconds: 1)),
                            );
                            setState(() {});
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('❌ No Water Cans! Buy from Tools Shop'), backgroundColor: Colors.red),
                            );
                          }
                        },
                      ),
                      if (crop.hasWeeds)
                        _QuickToolButton(
                          icon: '🧴',
                          label: 'Weed Killer',
                          quantity: _gameService.state.getToolQuantity(ToolType.weedKiller),
                          onPressed: () {
                            if (_gameService.useTool(ToolType.weedKiller)) {
                              _gameService.removeWeeds(plot);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('🧴 Used Weed Killer!'), duration: Duration(seconds: 1)),
                              );
                              setState(() {});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('❌ No Weed Killer! Buy from Tools Shop'), backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                      if (crop.hasPests)
                        _QuickToolButton(
                          icon: '🧪',
                          label: 'Pesticide',
                          quantity: _gameService.state.getToolQuantity(ToolType.pesticide),
                          onPressed: () {
                            if (_gameService.useTool(ToolType.pesticide)) {
                              _gameService.removePests(plot);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('🧪 Used Pesticide!'), duration: Duration(seconds: 1)),
                              );
                              setState(() {});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('❌ No Pesticide! Buy from Tools Shop'), backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                      if (!crop.isDead && crop.growthProgress < 1.0)
                        _QuickToolButton(
                          icon: '🌸',
                          label: 'Fertilizer',
                          quantity: _gameService.state.getToolQuantity(ToolType.fertilizer),
                          onPressed: () {
                            if (_gameService.useTool(ToolType.fertilizer)) {
                              crop.growthProgress = (crop.growthProgress * 1.5).clamp(0.0, 1.0);
                              _gameService.saveGame();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('🌸 Fertilizer applied! 50% growth boost!'), backgroundColor: Colors.green),
                              );
                              setState(() {});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('❌ No Fertilizer! Buy from Tools Shop'), backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (plot.isEmpty)
            Column(
              children: [
                const Text(
                  'Select a seed to plant:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...CropType.allCrops.map((cropType) {
                  final hasSeeds = _gameService.state.hasSeeds(cropType.id, 1);
                  final seedCount = _gameService.state.getSeedQuantity(cropType.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PlantSeedButton(
                      cropType: cropType,
                      hasSeeds: hasSeeds,
                      seedCount: seedCount,
                      onPressed: hasSeeds
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
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⚠️ No seeds available! Buy from shop.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
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

  Widget _buildFloatingMusicControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Previous button
        _MusicControlButton(
          icon: '⏮️',
          onPressed: () => _musicPlayer.previous(),
        ),
        const SizedBox(height: 8),
        // Play/Pause button
        _MusicControlButton(
          icon: _musicPlayer.isPlaying ? '⏸️' : '▶️',
          onPressed: () {
            if (_musicPlayer.isPlaying) {
              _musicPlayer.pause();
            } else {
              _musicPlayer.play();
            }
          },
        ),
        const SizedBox(height: 8),
        // Next button
        _MusicControlButton(
          icon: '⏭️',
          onPressed: () => _musicPlayer.next(),
        ),
      ],
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
  final bool hasSeeds;
  final int seedCount;
  final VoidCallback? onPressed;

  const _PlantSeedButton({
    required this.cropType,
    required this.hasSeeds,
    required this.seedCount,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: hasSeeds ? Colors.green : Colors.grey,
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
                  hasSeeds 
                      ? '${cropType.growthTimeSeconds}s → \$${cropType.sellPrice}'
                      : 'No seeds! Buy from shop',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasSeeds ? Colors.white.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$seedCount',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Music control button widget
class _MusicControlButton extends StatelessWidget {
  final String icon;
  final VoidCallback onPressed;

  const _MusicControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            child: Text(
              icon,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
      ),
    );
  }
}

// Quick tool button widget
class _QuickToolButton extends StatelessWidget {
  final String icon;
  final String label;
  final int quantity;
  final VoidCallback onPressed;

  const _QuickToolButton({
    required this.icon,
    required this.label,
    required this.quantity,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasQuantity = quantity > 0;
    
    return ElevatedButton(
      onPressed: hasQuantity ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: hasQuantity ? Colors.purple : Colors.grey.shade300,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: hasQuantity ? Colors.white.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$quantity',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

