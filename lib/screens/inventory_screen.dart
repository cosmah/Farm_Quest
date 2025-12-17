import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/game_service.dart';
import '../services/firebase_service.dart';
import '../models/game_state.dart';
import '../models/crop_type.dart';
import '../models/player_profile.dart';
import 'leaderboard_screen.dart';

class InventoryScreen extends StatefulWidget {
  final GameService gameService;

  const InventoryScreen({super.key, required this.gameService});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  StreamSubscription? _stateSubscription;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _stateSubscription = widget.gameService.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.gameService.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 Inventory & Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '🌱 Seeds'),
            Tab(text: '🛠️ Tools'),
            Tab(text: '👨‍🌾 Workers'),
            Tab(text: '👤 Profile'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade300, Colors.teal.shade600],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildSeedsTab(state),
            _buildToolsTab(state),
            _buildWorkersTab(state),
            _buildProfileTab(state),
          ],
        ),
      ),
    );
  }

  // SEEDS TAB
  Widget _buildSeedsTab(GameState state) {
    final bool hasSeeds = state.seedInventory.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '🌱 Seed Inventory',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Types: ${state.seedInventory.length}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!hasSeeds)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('📭', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  Text(
                    'No seeds in inventory',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visit the Seeds Shop to buy some!',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ...CropType.allCrops.map((cropType) {
            final quantity = state.getSeedQuantity(cropType.id);
            if (quantity == 0) return const SizedBox.shrink();
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Text(cropType.emoji, style: const TextStyle(fontSize: 40)),
                title: Text(cropType.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Grows in ${cropType.growthTimeSeconds}s • Sells for \$${cropType.sellPrice}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$quantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // TOOLS TAB
  Widget _buildToolsTab(state) {
    final ownedTools = state.ownedTools;
    final hasTools = ownedTools.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '🛠️ Tools & Equipment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Items: ${ownedTools.length}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!hasTools)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('🔧', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  Text(
                    'No tools owned',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visit the Tools Shop to buy some!',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ...ownedTools.map((tool) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Text(tool.icon, style: const TextStyle(fontSize: 40)),
                title: Text(tool.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tool.description),
                    if (tool.isConsumable)
                      Text(
                        'Consumable • ${tool.quantityOwned} remaining',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      )
                    else
                      const Text(
                        'Permanent Equipment',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                trailing: tool.isConsumable
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: tool.quantityOwned > 0 ? Colors.orange : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${tool.quantityOwned}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_circle, color: Colors.green, size: 32),
              ),
            );
          }).toList(),
      ],
    );
  }

  // WORKERS TAB
  Widget _buildWorkersTab(state) {
    final workers = state.activeWorkers;
    final hasWorkers = workers.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '👨‍🌾 Active Workers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Season ${state.currentSeason} • ${workers.length} workers hired',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Workers are dismissed at season end',
                  style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!hasWorkers)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('🏖️', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  Text(
                    'No workers hired',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visit Shop → Hire Workers to get help!',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ...workers.map((worker) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Text(worker.icon, style: const TextStyle(fontSize: 40)),
                title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker.description),
                    const SizedBox(height: 4),
                    Text(
                      'Cost: \$${worker.cost}/season',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.check_circle, color: Colors.green, size: 32),
              ),
            );
          }).toList(),
      ],
    );
  }

  // PROFILE TAB
  Widget _buildProfileTab(GameState state) {
    final firebaseService = FirebaseService();
    final isSignedIn = firebaseService.isSignedIn;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Account Status Card
        Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSignedIn
                    ? [Colors.green.shade400, Colors.green.shade700]
                    : [Colors.grey.shade400, Colors.grey.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  isSignedIn ? 'Cloud Sync Active' : 'Offline Mode',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSignedIn
                      ? 'Signed in as ${firebaseService.displayName}'
                      : 'Your progress is saved locally only',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Quick Actions
        if (isSignedIn) ...[
          ElevatedButton.icon(
            onPressed: () async {
              // Sync profile
              await firebaseService.updatePlayerProfile(state);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Profile synced to cloud!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Sync Progress to Cloud'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
              );
            },
            icon: const Icon(Icons.leaderboard),
            label: const Text('View Leaderboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out? Make sure to sync your progress first!'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await firebaseService.signOut();
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out successfully')),
                  );
                }
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Why Sign In?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '✅ Save progress to cloud\n'
                    '✅ Compete on global leaderboard\n'
                    '✅ Play across multiple devices\n'
                    '✅ Never lose your farm!',
                    style: TextStyle(fontSize: 14, height: 1.8),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showSignInDialog(context, state),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In / Sign Up'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () async {
                      // Sign in anonymously
                      final user = await firebaseService.signInAnonymously();
                      if (user != null && mounted) {
                        await firebaseService.updatePlayerProfile(state);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Signed in anonymously!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Continue as Guest'),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Game Stats Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 Your Stats',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                _buildStatRow('Level', '${state.level}'),
                _buildStatRow('Money', '\$${state.money}'),
                _buildStatRow('XP', '${state.experience}/${state.experienceToNextLevel}'),
                _buildStatRow('Crops Harvested', '${state.totalCropsHarvested}'),
                _buildStatRow('Plots Unlocked', '${state.unlockedPlots.length}/15'),
                _buildStatRow('Days Played', '${state.daysPlayed}'),
                const Divider(height: 24),
                _buildStatRow(
                  'Your Score',
                  '${PlayerProfile.calculateScore(
                    level: state.level,
                    money: state.money,
                    cropsHarvested: state.totalCropsHarvested,
                    plotsUnlocked: state.unlockedPlots.length,
                  )}',
                  isHighlighted: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isHighlighted ? Colors.blue.shade700 : Colors.grey.shade700,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? Colors.blue.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showSignInDialog(BuildContext context, GameState state) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    bool isSignUp = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isSignUp ? 'Create Account' : 'Sign In'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSignUp)
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                if (isSignUp) const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  isSignUp = !isSignUp;
                });
              },
              child: Text(isSignUp ? 'Have an account? Sign In' : 'Create Account'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final firebaseService = FirebaseService();
                User? user;

                if (isSignUp) {
                  user = await firebaseService.signUpWithEmail(
                    emailController.text.trim(),
                    passwordController.text,
                    nameController.text.trim(),
                  );
                } else {
                  user = await firebaseService.signInWithEmail(
                    emailController.text.trim(),
                    passwordController.text,
                  );
                }

                if (user != null && context.mounted) {
                  await firebaseService.updatePlayerProfile(state);
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${isSignUp ? "Account created" : "Signed in"} successfully!')),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Authentication failed. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(isSignUp ? 'Sign Up' : 'Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

