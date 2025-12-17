import 'package:flutter/material.dart';
import '../models/player_profile.dart';
import '../services/firebase_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;
  int _myRank = 0;
  PlayerProfile? _myProfile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyStats() async {
    if (_firebaseService.isSignedIn) {
      final profile = await _firebaseService.getPlayerProfile();
      final rank = await _firebaseService.getPlayerRank();
      setState(() {
        _myProfile = profile;
        _myRank = rank;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Leaderboard'),
        backgroundColor: Colors.amber.shade700,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.leaderboard), text: 'Global Ranking'),
            Tab(icon: Icon(Icons.person), text: 'My Stats'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.amber.shade100,
              Colors.orange.shade50,
            ],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLeaderboardTab(),
            _buildMyStatsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    return StreamBuilder<List<PlayerProfile>>(
      stream: _firebaseService.leaderboardStream(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading leaderboard: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final players = snapshot.data ?? [];

        if (players.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No players yet!\nBe the first on the leaderboard!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            final rank = index + 1;
            final isMe = _firebaseService.isSignedIn && 
                         player.uid == _firebaseService.currentUser!.uid;

            return _buildLeaderboardCard(player, rank, isMe);
          },
        );
      },
    );
  }

  Widget _buildLeaderboardCard(PlayerProfile player, int rank, bool isMe) {
    final rankColor = rank == 1
        ? Colors.amber.shade400
        : rank == 2
            ? Colors.grey.shade400
            : rank == 3
                ? Colors.orange.shade400
                : Colors.blue.shade200;

    final rankIcon = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '$rank';

    return Card(
      elevation: isMe ? 8 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: isMe ? Colors.green.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isMe 
            ? BorderSide(color: Colors.green.shade300, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: rankColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: rankColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                rankIcon,
                style: TextStyle(
                  fontSize: rank <= 3 ? 28 : 18,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Player info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        player.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.green.shade800 : Colors.black87,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Level ${player.level} • ${player.cropsHarvested} crops harvested',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.monetization_on, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '\$${player.totalMoney}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.landscape, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '${player.plotsUnlocked} plots',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'SCORE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${player.score}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.green.shade700 : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyStatsTab() {
    if (!_firebaseService.isSignedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Sign in to track your stats!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your progress will be saved to the cloud',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_myProfile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Rank card
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.purple.shade400, Colors.purple.shade700],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'YOUR GLOBAL RANK',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _myRank > 0 ? '#$_myRank' : '--',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _myProfile!.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5, // Increased for more vertical space
            children: [
              _buildStatCard(
                icon: '⭐',
                label: 'Total Score',
                value: '${_myProfile!.score}',
                color: Colors.amber,
              ),
              _buildStatCard(
                icon: '📊',
                label: 'Level',
                value: '${_myProfile!.level}',
                color: Colors.blue,
              ),
              _buildStatCard(
                icon: '💰',
                label: 'Total Money',
                value: '\$${_myProfile!.totalMoney}',
                color: Colors.green,
              ),
              _buildStatCard(
                icon: '🌾',
                label: 'Crops Harvested',
                value: '${_myProfile!.cropsHarvested}',
                color: Colors.orange,
              ),
              _buildStatCard(
                icon: '🏞️',
                label: 'Plots Unlocked',
                value: '${_myProfile!.plotsUnlocked}',
                color: Colors.teal,
              ),
              _buildStatCard(
                icon: '📅',
                label: 'Days Played',
                value: '${_myProfile!.daysPlayed}',
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Last updated
          Text(
            'Last updated: ${_formatDateTime(_myProfile!.lastUpdated)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.shade300, color.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            // Value
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Label
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

