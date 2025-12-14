import 'package:flutter/material.dart';
import '../services/game_service.dart';
import 'shop_screen.dart'; // Seeds shop (existing)
import 'workers_shop_screen.dart';
import 'tools_shop_screen.dart';
import 'land_shop_screen.dart';

class ShopMenuScreen extends StatelessWidget {
  final GameService gameService;

  const ShopMenuScreen({super.key, required this.gameService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade300,
              Colors.orange.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
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
                      const Text(
                        '💰',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${gameService.state.money}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '🛍️ Welcome to the Shop!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      ShopCategoryCard(
                        emoji: '🌱',
                        title: 'Seeds Shop',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ShopScreen(gameService: gameService),
                          ),
                        ),
                      ),
                      ShopCategoryCard(
                        emoji: '👨‍🌾',
                        title: 'Hire Workers',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkersShopScreen(gameService: gameService),
                          ),
                        ),
                      ),
                      ShopCategoryCard(
                        emoji: '🛠️',
                        title: 'Tools Shop',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ToolsShopScreen(gameService: gameService),
                          ),
                        ),
                      ),
                      ShopCategoryCard(
                        emoji: '🏞️',
                        title: 'Land Shop',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LandShopScreen(gameService: gameService),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShopCategoryCard extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback onTap;

  const ShopCategoryCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white.withValues(alpha: 0.9),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
