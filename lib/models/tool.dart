enum ToolType {
  // Consumables (one-time use)
  waterCan,      // 💧 Water 1 plot
  pesticide,     // 🧪 Kill pests instantly
  weedKiller,    // 🧴 Remove weeds fast
  fertilizer,    // 🌸 50% faster growth
  
  // Equipment (permanent)
  sprinkler,     // 💦 Auto-water 1 plot
  waterTank,     // 🛢️ Store 50 water uses
  pestTrap,      // 🪤 50% less pests on 1 plot
  compostBin,    // 🪴 Better soil quality
  rainBarrel,    // 🏺 Collect free water
  labKit,        // ⚗️ Better crop quality
  thermometer,   // 🌡️ Weather warnings
  microscope,    // 🔬 Detect diseases early
}

class Tool {
  final ToolType type;
  final bool isConsumable;
  final int? assignedPlotIndex; // For equipment installed on specific plot
  final DateTime? purchasedAt;
  final int quantityOwned; // For consumables

  Tool({
    required this.type,
    required this.isConsumable,
    this.assignedPlotIndex,
    this.purchasedAt,
    this.quantityOwned = 1,
  });

  Tool copyWith({
    ToolType? type,
    bool? isConsumable,
    int? assignedPlotIndex,
    DateTime? purchasedAt,
    int? quantityOwned,
  }) {
    return Tool(
      type: type ?? this.type,
      isConsumable: isConsumable ?? this.isConsumable,
      assignedPlotIndex: assignedPlotIndex ?? this.assignedPlotIndex,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      quantityOwned: quantityOwned ?? this.quantityOwned,
    );
  }

  String get icon {
    switch (type) {
      case ToolType.waterCan:
        return '💧';
      case ToolType.pesticide:
        return '🧪';
      case ToolType.weedKiller:
        return '🧴';
      case ToolType.fertilizer:
        return '🌸';
      case ToolType.sprinkler:
        return '💦';
      case ToolType.waterTank:
        return '🛢️';
      case ToolType.pestTrap:
        return '🪤';
      case ToolType.compostBin:
        return '🪴';
      case ToolType.rainBarrel:
        return '🏺';
      case ToolType.labKit:
        return '⚗️';
      case ToolType.thermometer:
        return '🌡️';
      case ToolType.microscope:
        return '🔬';
    }
  }

  String get name {
    switch (type) {
      case ToolType.waterCan:
        return 'Water Can';
      case ToolType.pesticide:
        return 'Pesticide';
      case ToolType.weedKiller:
        return 'Weed Killer';
      case ToolType.fertilizer:
        return 'Fertilizer';
      case ToolType.sprinkler:
        return 'Sprinkler';
      case ToolType.waterTank:
        return 'Water Tank';
      case ToolType.pestTrap:
        return 'Pest Trap';
      case ToolType.compostBin:
        return 'Compost Bin';
      case ToolType.rainBarrel:
        return 'Rain Barrel';
      case ToolType.labKit:
        return 'Lab Kit';
      case ToolType.thermometer:
        return 'Thermometer';
      case ToolType.microscope:
        return 'Microscope';
    }
  }

  String get description {
    switch (type) {
      case ToolType.waterCan:
        return 'Water 1 plot manually';
      case ToolType.pesticide:
        return 'Kill pests instantly';
      case ToolType.weedKiller:
        return 'Remove weeds fast';
      case ToolType.fertilizer:
        return 'Grow 50% faster (1 use)';
      case ToolType.sprinkler:
        return 'Auto-water 1 plot forever';
      case ToolType.waterTank:
        return 'Store 50 water uses';
      case ToolType.pestTrap:
        return '50% less pests on plot';
      case ToolType.compostBin:
        return 'Better soil quality';
      case ToolType.rainBarrel:
        return 'Collect free water';
      case ToolType.labKit:
        return 'Better crop quality (+20% value)';
      case ToolType.thermometer:
        return 'Get weather warnings';
      case ToolType.microscope:
        return 'Detect diseases early';
    }
  }

  static int getCost(ToolType type) {
    switch (type) {
      case ToolType.waterCan:
        return 10;
      case ToolType.pesticide:
        return 20;
      case ToolType.weedKiller:
        return 15;
      case ToolType.fertilizer:
        return 50;
      case ToolType.sprinkler:
        return 500;
      case ToolType.waterTank:
        return 300;
      case ToolType.pestTrap:
        return 400;
      case ToolType.compostBin:
        return 350;
      case ToolType.rainBarrel:
        return 250;
      case ToolType.labKit:
        return 600;
      case ToolType.thermometer:
        return 150;
      case ToolType.microscope:
        return 700;
    }
  }

  static int getUnlockLevel(ToolType type) {
    switch (type) {
      case ToolType.waterCan:
      case ToolType.pesticide:
      case ToolType.weedKiller:
        return 1; // Available from start
      case ToolType.fertilizer:
      case ToolType.waterTank:
        return 3;
      case ToolType.sprinkler:
      case ToolType.pestTrap:
        return 5;
      case ToolType.compostBin:
      case ToolType.rainBarrel:
        return 7;
      case ToolType.labKit:
      case ToolType.thermometer:
        return 10;
      case ToolType.microscope:
        return 12;
    }
  }

  static bool isConsumableType(ToolType type) {
    return type == ToolType.waterCan ||
        type == ToolType.pesticide ||
        type == ToolType.weedKiller ||
        type == ToolType.fertilizer;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'isConsumable': isConsumable,
      'assignedPlotIndex': assignedPlotIndex,
      'purchasedAt': purchasedAt?.toIso8601String(),
      'quantityOwned': quantityOwned,
    };
  }

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      type: ToolType.values[json['type']],
      isConsumable: json['isConsumable'],
      assignedPlotIndex: json['assignedPlotIndex'],
      purchasedAt: json['purchasedAt'] != null
          ? DateTime.parse(json['purchasedAt'])
          : null,
      quantityOwned: json['quantityOwned'] ?? 1,
    );
  }

  // Check if tool is installed on a specific plot
  bool isInstalledOnPlot(int plotIndex) {
    return !isConsumable && assignedPlotIndex == plotIndex;
  }
}

