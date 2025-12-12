import 'crop.dart';

/// Represents a farm plot that can hold a crop
class Plot {
  final String id;
  Crop? crop;
  bool isUnlocked;
  final int unlockCost;

  Plot({
    required this.id,
    this.crop,
    this.isUnlocked = false,
    required this.unlockCost,
  });

  bool get isEmpty => crop == null;
  bool get hasLiveCrop => crop != null && !crop!.isDead && !crop!.isHarvested;
  bool get hasReadyCrop => crop != null && crop!.state == CropState.ready;
  bool get hasDeadCrop => crop != null && crop!.isDead;

  void plantCrop(Crop newCrop) {
    crop = newCrop;
  }

  void clearCrop() {
    crop = null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'crop': crop?.toJson(),
        'isUnlocked': isUnlocked,
        'unlockCost': unlockCost,
      };

  factory Plot.fromJson(Map<String, dynamic> json) {
    return Plot(
      id: json['id'],
      crop: json['crop'] != null ? Crop.fromJson(json['crop']) : null,
      isUnlocked: json['isUnlocked'] ?? false,
      unlockCost: json['unlockCost'] ?? 100,
    );
  }
}

