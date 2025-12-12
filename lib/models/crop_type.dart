/// Defines a type of crop that can be planted
class CropType {
  final String id;
  final String name;
  final String emoji;
  final int seedCost; // Cost to buy seed
  final int sellPrice; // Price when harvested
  final int growthTimeSeconds; // Time to fully grow
  final int waterIntervalSeconds; // How often it needs water
  final double weedSpawnChance; // Chance per minute
  final double pestSpawnChance; // Chance per minute

  const CropType({
    required this.id,
    required this.name,
    required this.emoji,
    required this.seedCost,
    required this.sellPrice,
    required this.growthTimeSeconds,
    required this.waterIntervalSeconds,
    required this.weedSpawnChance,
    required this.pestSpawnChance,
  });

  // Available crop types
  static const carrot = CropType(
    id: 'carrot',
    name: 'Carrot',
    emoji: '🥕',
    seedCost: 10,
    sellPrice: 25,
    growthTimeSeconds: 30,
    waterIntervalSeconds: 20,
    weedSpawnChance: 0.3,
    pestSpawnChance: 0.2,
  );

  static const corn = CropType(
    id: 'corn',
    name: 'Corn',
    emoji: '🌽',
    seedCost: 30,
    sellPrice: 80,
    growthTimeSeconds: 60,
    waterIntervalSeconds: 30,
    weedSpawnChance: 0.25,
    pestSpawnChance: 0.15,
  );

  static const tomato = CropType(
    id: 'tomato',
    name: 'Tomato',
    emoji: '🍅',
    seedCost: 50,
    sellPrice: 150,
    growthTimeSeconds: 90,
    waterIntervalSeconds: 40,
    weedSpawnChance: 0.2,
    pestSpawnChance: 0.1,
  );

  static const allCrops = [carrot, corn, tomato];

  static CropType? fromId(String id) {
    try {
      return allCrops.firstWhere((crop) => crop.id == id);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
      };

  factory CropType.fromJson(Map<String, dynamic> json) {
    return fromId(json['id']) ?? carrot;
  }
}

