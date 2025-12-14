import 'crop_type.dart';

enum CropState {
  growing, // Normal growth
  needsWater, // Needs water soon
  wilting, // Dying from lack of water
  dead, // Completely dead
  ready, // Ready to harvest
}

/// Represents a planted crop instance
class Crop {
  final CropType type;
  DateTime plantedAt;
  DateTime lastWatered;
  double growthProgress; // 0.0 to 1.0
  bool hasWeeds;
  bool hasPests;
  bool isDead;
  bool isHarvested;

  Crop({
    required this.type,
    required this.plantedAt,
    required this.lastWatered,
    this.growthProgress = 0.0,
    this.hasWeeds = false,
    this.hasPests = false,
    this.isDead = false,
    this.isHarvested = false,
  });

  CropState getState(int pausedSeconds) {
    if (isDead) return CropState.dead;
    if (growthProgress >= 1.0 && !isHarvested) return CropState.ready;

    final now = DateTime.now();
    // Subtract paused time from elapsed time
    final secondsSinceWatered = now.difference(lastWatered).inSeconds - pausedSeconds;

    // Check if wilting (10 seconds after needing water)
    if (secondsSinceWatered > type.waterIntervalSeconds + 10) {
      return CropState.wilting;
    }

    // Check if needs water
    if (secondsSinceWatered > type.waterIntervalSeconds) {
      return CropState.needsWater;
    }

    return CropState.growing;
  }
  
  // Backward compatibility - defaults to 0 pause
  CropState get state => getState(0);

  String get emoji {
    if (isDead) return '💀';
    if (growthProgress >= 1.0) return type.emoji;
    if (growthProgress >= 0.66) return '🌾';
    if (growthProgress >= 0.33) return '🌿';
    return '🌱';
  }

  bool get needsAttention {
    return state == CropState.needsWater ||
        state == CropState.wilting ||
        hasWeeds ||
        hasPests;
  }

  Map<String, dynamic> toJson() => {
        'type': type.toJson(),
        'plantedAt': plantedAt.toIso8601String(),
        'lastWatered': lastWatered.toIso8601String(),
        'growthProgress': growthProgress,
        'hasWeeds': hasWeeds,
        'hasPests': hasPests,
        'isDead': isDead,
        'isHarvested': isHarvested,
      };

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      type: CropType.fromJson(json['type']),
      plantedAt: DateTime.parse(json['plantedAt']),
      lastWatered: DateTime.parse(json['lastWatered']),
      growthProgress: json['growthProgress'] ?? 0.0,
      hasWeeds: json['hasWeeds'] ?? false,
      hasPests: json['hasPests'] ?? false,
      isDead: json['isDead'] ?? false,
      isHarvested: json['isHarvested'] ?? false,
    );
  }
}

