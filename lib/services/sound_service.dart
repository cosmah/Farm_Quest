import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
  }

  // All sound methods now do nothing - user music only
  Future<void> play(String soundName, {String extension = 'wav'}) async {
    // Disabled - user music will be the only audio
  }

  Future<void> playMusic(String musicName, {String extension = 'mp3'}) async {
    // Disabled - user music will be the only audio
  }

  void stopMusic() {
    // Disabled
  }

  // Keep these for backward compatibility but they do nothing
  void plantSound() {}
  void waterSound() {}
  void harvestSound() {}
  void coinSound() {}
  void levelUpSound() {}
  void weedSound() {}
  void pestSound() {}
  void pauseSound() {}
  void resumeSound() {}
  void buttonClickSound() {}
  void errorSound() {}
  void loanApprovedSound() {}
  void loanRepaidSound() {}
  void gameOverSound() {}
  void unlockSound() {}

  void dispose() {
    _player.dispose();
  }
}
