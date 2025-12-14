import 'package:flutter/material.dart';
import 'dart:async';
import '../models/worker.dart';
import '../models/transaction.dart';
import '../services/game_service.dart';

class WorkersShopScreen extends StatefulWidget {
  final GameService gameService;

  const WorkersShopScreen({super.key, required this.gameService});

  @override
  State<WorkersShopScreen> createState() => _WorkersShopScreenState();
}

class _WorkersShopScreenState extends State<WorkersShopScreen> {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍🌾 Hire Workers'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade300, Colors.blue.shade600],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: WorkerType.values.map((type) {
            final unlockLevel = Worker.getUnlockLevel(type);
            final cost = Worker.getCost(type);
            final isLocked = state.level < unlockLevel;
            final canAfford = state.canAfford(cost);
            
            return _buildWorkerCard(type, cost, unlockLevel, isLocked, canAfford);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWorkerCard(WorkerType type, int cost, int unlockLevel, bool isLocked, bool canAfford) {
    final worker = Worker(type: type, hiredAt: DateTime.now(), cost: cost);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(worker.icon, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        worker.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
                  '\$$cost per season',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                if (isLocked)
                  Text('🔒 Level $unlockLevel', style: const TextStyle(color: Colors.red))
                else
                  ElevatedButton(
                    onPressed: canAfford ? () => _hireWorker(worker) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? Colors.blue : Colors.grey,
                    ),
                    child: const Text('Hire'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _hireWorker(Worker worker) {
    final state = widget.gameService.state;
    if (state.spendMoney(
      worker.cost,
      category: TransactionCategory.workerHire,
      description: 'Hired ${worker.name}',
    )) {
      state.hireWorker(worker);
      widget.gameService.saveGame();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${worker.icon} ${worker.name} hired for this season!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    }
  }
}

