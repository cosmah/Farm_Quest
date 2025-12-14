import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    if (!enabled) {
      _sfxPlayer.stop();
    }
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      _musicPlayer.stop();
    }
  }

  /// Play a sound effect
  Future<void> play(String soundName, {String extension = 'wav'}) async {
    if (!_soundEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('sounds/$soundName.$extension'));
    } catch (e) {
      // Sound file not found - that's okay, game continues without sound
    }
  }

  /// Play background music
  Future<void> playMusic(String musicName, {String extension = 'mp3'}) async {
    if (!_musicEnabled) return;
    
    try {
      await _musicPlayer.play(
        AssetSource('sounds/$musicName.$extension'),
        volume: 0.3,
      );
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      // Music file not found - that's okay
    }
  }

  /// Stop background music
  void stopMusic() {
    _musicPlayer.stop();
  }

  /// Sound effects list
  // Farm activities - use pop sound
  void plantSound() => play('mixkit-game-blood-pop-slide-2363');
  void waterSound() => play('mixkit-game-blood-pop-slide-2363');
  void weedSound() => play('mixkit-game-blood-pop-slide-2363');
  void pestSound() => play('mixkit-game-blood-pop-slide-2363');
  
  // Progress/achievements - use level up sound
  void harvestSound() => play('mixkit-completion-of-a-level-2063');
  void coinSound() => play('mixkit-completion-of-a-level-2063');
  void levelUpSound() => play('mixkit-completion-of-a-level-2063');
  void unlockSound() => play('mixkit-completion-of-a-level-2063');
  void loanRepaidSound() => play('mixkit-completion-of-a-level-2063');
  
  // UI sounds - use pop sound (more subtle for UI)
  void buttonClickSound() => play('mixkit-game-blood-pop-slide-2363');
  void pauseSound() => play('mixkit-game-blood-pop-slide-2363');
  void resumeSound() => play('mixkit-game-blood-pop-slide-2363');
  
  // Special sounds - can be silent for now or use existing
  void errorSound() => play('error'); // Silent if not exists
  void loanApprovedSound() => play('mixkit-completion-of-a-level-2063');
  void gameOverSound() => play('error'); // Silent if not exists

  void dispose() {
    _sfxPlayer.dispose();
    _musicPlayer.dispose();
  }
}

