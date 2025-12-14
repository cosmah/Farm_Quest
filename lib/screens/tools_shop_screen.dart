import 'package:flutter/material.dart';
import 'dart:async';
import '../models/tool.dart';
import '../models/transaction.dart';
import '../services/game_service.dart';

class ToolsShopScreen extends StatefulWidget {
  final GameService gameService;

  const ToolsShopScreen({super.key, required this.gameService});

  @override
  State<ToolsShopScreen> createState() => _ToolsShopScreenState();
}

class _ToolsShopScreenState extends State<ToolsShopScreen> {
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _stateSubscription = widget.gameService.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.gameService.state;

    final consumables = ToolType.values.where((t) => Tool.isConsumableType(t)).toList();
    final equipment = ToolType.values.where((t) => !Tool.isConsumableType(t)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠️ Tools Shop'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade300, Colors.purple.shade600],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '💧 Consumables',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ...consumables.map((type) => _buildToolCard(type, state)),
            const SizedBox(height: 24),
            const Text(
              '⚙️ Equipment',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ...equipment.map((type) => _buildToolCard(type, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(ToolType type, state) {
    final tool = Tool(type: type, isConsumable: Tool.isConsumableType(type));
    final cost = Tool.getCost(type);
    final unlockLevel = Tool.getUnlockLevel(type);
    final isLocked = state.level < unlockLevel;
    final canAfford = state.canAfford(cost);
    final owned = state.getToolQuantity(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tool.icon, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tool.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (owned > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Owned: $owned',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        tool.description,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$$cost',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                if (isLocked)
                  Text('🔒 Level $unlockLevel', style: const TextStyle(color: Colors.red))
                else
                  ElevatedButton(
                    onPressed: canAfford ? () => _buyTool(tool, cost) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? Colors.purple : Colors.grey,
                    ),
                    child: const Text('Buy'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _buyTool(Tool tool, int cost) {
    final state = widget.gameService.state;
    if (state.spendMoney(
      cost,
      category: TransactionCategory.toolPurchase,
      description: 'Bought ${tool.name}',
    )) {
      state.buyTool(tool);
      widget.gameService.saveGame();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tool.icon} ${tool.name} purchased!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    }
  }
}

