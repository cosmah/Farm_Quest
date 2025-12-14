import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../services/sound_service.dart';
import 'intro_screen.dart';
import 'main_game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final SoundService _soundService = SoundService();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _hasExistingGame = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Animation setup
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    
    _animController.forward();
    
    // Check for existing game
    _checkExistingGame();
    
    // Start background music
    _soundService.playMusic('menu');
  }

  Future<void> _checkExistingGame() async {
    final gameService = GameService();
    final hasPlayed = await gameService.hasPlayedBefore();
    setState(() {
      _hasExistingGame = hasPlayed;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade700,
              Colors.green.shade300,
              Colors.yellow.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Game logo/title
                          const Spacer(),
                          _buildLogo(),
                          const SizedBox(height: 40),
                          _buildTitle(),
                          const SizedBox(height: 20),
                          _buildSubtitle(),
                          const Spacer(),
                          // Menu buttons
                          _buildMenuButtons(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(
            'assets/icon/logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Text(
          'FARM QUEST',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black45,
                offset: Offset(3, 3),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'The Farm Fun Game',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Build Your Farm Empire',
        style: TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMenuButtons() {
    return Column(
      children: [
        if (_hasExistingGame)
          _MenuButton(
            icon: '▶️',
            label: 'Continue Game',
            color: Colors.green,
            onPressed: () async {
              _soundService.buttonClickSound();
              _soundService.stopMusic();
              final gameService = GameService();
              await gameService.loadGame();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainGameScreen(gameService: gameService),
                  ),
                );
              }
            },
          ),
        const SizedBox(height: 16),
        _MenuButton(
          icon: '🎮',
          label: _hasExistingGame ? 'New Game' : 'Start Game',
          color: Colors.blue,
          onPressed: () {
            _soundService.buttonClickSound();
            _soundService.stopMusic();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const IntroScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        _MenuButton(
          icon: 'ℹ️',
          label: 'How to Play',
          color: Colors.orange,
          onPressed: () {
            _soundService.buttonClickSound();
            _showHowToPlay();
          },
        ),
      ],
    );
  }

  void _showHowToPlay() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('📖'),
            SizedBox(width: 12),
            Text('How to Play'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HowToPlayItem(
                icon: '🏦',
                title: 'Take a Loan',
                description: 'Start by getting a loan from the bank',
              ),
              _HowToPlayItem(
                icon: '🌱',
                title: 'Plant Seeds',
                description: 'Buy seeds and plant them on your farm',
              ),
              _HowToPlayItem(
                icon: '💧',
                title: 'Water & Care',
                description: 'Water crops regularly and remove weeds/pests',
              ),
              _HowToPlayItem(
                icon: '🌾',
                title: 'Harvest & Sell',
                description: 'Harvest ready crops to earn money',
              ),
              _HowToPlayItem(
                icon: '💵',
                title: 'Repay Loan',
                description: 'Repay before deadline or lose everything!',
              ),
              _HowToPlayItem(
                icon: '⏸️',
                title: 'Pause Anytime',
                description: 'Use pause button to stop the game',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _soundService.buttonClickSound();
              Navigator.pop(context);
            },
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToPlayItem extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const _HowToPlayItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

