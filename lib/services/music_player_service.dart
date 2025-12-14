import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'database_helper.dart';

class MusicPlayerService {
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  factory MusicPlayerService() => _instance;
  MusicPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final DatabaseHelper _db = DatabaseHelper();

  List<Map<String, dynamic>> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _shuffle = false;
  bool _repeat = false;

  final _stateController = StreamController<PlayerState>.broadcast();
  Stream<PlayerState> get stateStream => _stateController.stream;

  bool get isPlaying => _isPlaying;
  bool get shuffle => _shuffle;
  bool get repeat => _repeat;
  int get currentIndex => _currentIndex;
  List<Map<String, dynamic>> get playlist => _playlist;
  Map<String, dynamic>? get currentSong =>
      _playlist.isEmpty ? null : _playlist[_currentIndex];

  Future<void> initialize() async {
    // Load playlist from database
    _playlist = await _db.getAllSongs();

    // Listen to player state
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      _notifyStateChanged();

      // Auto-play next song when current ends
      if (state == PlayerState.completed) {
        next();
      }
    });

    // Set audio mode
    await _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> loadPlaylist() async {
    _playlist = await _db.getAllSongs();
    _notifyStateChanged();
  }

  Future<void> addSong(String filePath, String fileName) async {
    await _db.addSong(filePath, fileName);
    await loadPlaylist();
  }

  Future<void> removeSong(int id) async {
    await _db.deleteSong(id);
    await loadPlaylist();
    
    // If current song was deleted, stop playing
    if (_playlist.isEmpty) {
      await stop();
    }
  }

  Future<void> playSongAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    final song = _playlist[index];
    final filePath = song['file_path'] as String;

    try {
      await _player.play(DeviceFileSource(filePath));
      _isPlaying = true;
      _notifyStateChanged();
    } catch (e) {
      // File not accessible
      _isPlaying = false;
      _notifyStateChanged();
    }
  }

  Future<void> play() async {
    if (_playlist.isEmpty) return;

    if (_player.state == PlayerState.paused) {
      await _player.resume();
    } else {
      await playSongAt(_currentIndex);
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    _notifyStateChanged();
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _notifyStateChanged();
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;

    if (_shuffle) {
      _currentIndex = (_currentIndex + 1 + DateTime.now().millisecond) % _playlist.length;
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }

    await playSongAt(_currentIndex);
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    await playSongAt(_currentIndex);
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _notifyStateChanged();
  }

  void toggleRepeat() {
    _repeat = !_repeat;
    _player.setReleaseMode(_repeat ? ReleaseMode.loop : ReleaseMode.stop);
    _notifyStateChanged();
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Duration get currentPosition {
    return _player.getDuration() as Duration? ?? Duration.zero;
  }

  Duration get totalDuration {
    return _player.getDuration() as Duration? ?? Duration.zero;
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  void _notifyStateChanged() {
    _stateController.add(PlayerState.playing);
  }

  void dispose() {
    _player.dispose();
    _stateController.close();
  }
}

