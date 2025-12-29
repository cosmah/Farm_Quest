import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../models/loan.dart';
import 'farm_screen.dart';
import 'shop_menu_screen.dart';
import 'bank_info_screen.dart';
import 'music_screen.dart';
import 'inventory_screen.dart';

class MainGameScreen extends StatefulWidget {
  final Loan? initialLoan;
  final GameService? gameService;

  const MainGameScreen({super.key, this.initialLoan, this.gameService});

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  late GameService _gameService;
  int _currentIndex = 0;
  late List<Widget> _screens;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    _gameService = widget.gameService ?? GameService();

    // If no game service was provided, we need to handle new game initialization
    if (widget.gameService == null) {
      if (widget.initialLoan != null) {
        // This is a new game - reset any existing state first
        await _gameService.resetGame();
      } else {
        // Try to load existing game state
        final loaded = await _gameService.loadGame();
        if (!loaded) {
          // No existing game found, start fresh
          await _gameService.resetGame();
        }
      }
    } else {
      // Game service was provided (continue game), ensure it's started
      _gameService.startGame();
    }

    // Take initial loan if provided (for new games)
    if (widget.initialLoan != null) {
      _gameService.takeLoan(widget.initialLoan!);
    }

    _screens = [
      FarmScreen(gameService: _gameService),
      ShopMenuScreen(gameService: _gameService),
      BankInfoScreen(gameService: _gameService),
      const MusicScreen(),
      InventoryScreen(gameService: _gameService),
    ];

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green.shade300,
                Colors.green.shade700,
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Loading your farm...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Text('🌾', style: TextStyle(fontSize: 24)),
            label: 'Farm',
          ),
          BottomNavigationBarItem(
            icon: Text('🛒', style: TextStyle(fontSize: 24)),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Text('🏦', style: TextStyle(fontSize: 24)),
            label: 'Bank',
          ),
          BottomNavigationBarItem(
            icon: Text('🎵', style: TextStyle(fontSize: 24)),
            label: 'Music',
          ),
          BottomNavigationBarItem(
            icon: Text('📦', style: TextStyle(fontSize: 24)),
            label: 'Inventory',
          ),
        ],
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey.shade600,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }

  @override
  void dispose() {
    // Save game state before disposing
    if (_isInitialized) {
      _gameService.saveGame();
    }
    super.dispose();
  }
}

