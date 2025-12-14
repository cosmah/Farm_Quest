import 'package:flutter/material.dart';
import 'dart:async';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../models/crop_type.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
}

