enum WorkerType {
  farmhand,      // 🚿 Auto-waters
  pestController, // ⚡ Auto-removes pests
  gardener,      // 🧹 Auto-removes weeds
  supervisor,    // 📋 Manages 1 plot completely
  masterFarmer,  // 🏆 Manages up to 5 plots
}

class Worker {
  final WorkerType type;
  final DateTime hiredAt;
  final int cost;
  final List<int>? assignedPlotIndices; // For supervisor/master farmer

  Worker({
    required this.type,
    required this.hiredAt,
    required this.cost,
    this.assignedPlotIndices,
  });

  String get icon {
    switch (type) {
      case WorkerType.farmhand:
        return '💼';
      case WorkerType.pestController:
        return '🦺';
      case WorkerType.gardener:
        return '🧑‍🌾';
      case WorkerType.supervisor:
        return '👔';
      case WorkerType.masterFarmer:
        return '🎓';
    }
  }

  String get name {
    switch (type) {
      case WorkerType.farmhand:
        return 'Farmhand';
      case WorkerType.pestController:
        return 'Pest Controller';
      case WorkerType.gardener:
        return 'Gardener';
      case WorkerType.supervisor:
        return 'Supervisor';
      case WorkerType.masterFarmer:
        return 'Master Farmer';
    }
  }

  String get description {
    switch (type) {
      case WorkerType.farmhand:
        return 'Auto-waters all plots';
      case WorkerType.pestController:
        return 'Auto-removes pests from all plots';
      case WorkerType.gardener:
        return 'Auto-removes weeds from all plots';
      case WorkerType.supervisor:
        return 'Manages 1 plot completely';
      case WorkerType.masterFarmer:
        return 'Manages up to 5 plots completely';
    }
  }

  static int getCost(WorkerType type) {
    switch (type) {
      case WorkerType.farmhand:
        return 200;
      case WorkerType.pestController:
        return 300;
      case WorkerType.gardener:
        return 250;
      case WorkerType.supervisor:
        return 500;
      case WorkerType.masterFarmer:
        return 1500;
    }
  }

  static int getUnlockLevel(WorkerType type) {
    switch (type) {
      case WorkerType.farmhand:
      case WorkerType.pestController:
      case WorkerType.gardener:
        return 5;
      case WorkerType.supervisor:
        return 10;
      case WorkerType.masterFarmer:
        return 15;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'hiredAt': hiredAt.toIso8601String(),
      'cost': cost,
      'assignedPlotIndices': assignedPlotIndices,
    };
  }

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      type: WorkerType.values[json['type']],
      hiredAt: DateTime.parse(json['hiredAt']),
      cost: json['cost'],
      assignedPlotIndices: json['assignedPlotIndices'] != null
          ? List<int>.from(json['assignedPlotIndices'])
          : null,
    );
  }

  // Check if worker manages a specific plot
  bool managesPlot(int plotIndex) {
    if (type == WorkerType.farmhand ||
        type == WorkerType.pestController ||
        type == WorkerType.gardener) {
      return true; // These workers manage all plots
    }
    return assignedPlotIndices?.contains(plotIndex) ?? false;
  }
}

