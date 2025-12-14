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

  @override
  void initState() {
    super.initState();
    _gameService = widget.gameService ?? GameService();

    // Take initial loan if provided
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
  }

  @override
  Widget build(BuildContext context) {
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
}

