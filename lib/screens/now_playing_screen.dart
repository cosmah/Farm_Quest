import 'package:flutter/material.dart';
import 'dart:async';
import '../services/music_player_service.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final MusicPlayerService _musicPlayer = MusicPlayerService();
  StreamSubscription? _playerSubscription;
  double _volume = 0.7;

  @override
  void initState() {
    super.initState();
    _playerSubscription = _musicPlayer.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _musicPlayer.currentSong;
    
    if (currentSong == null) {
      Navigator.pop(context);
      return const SizedBox();
    }

    final fileName = currentSong['file_name'] as String;
    final displayName = _cleanSongName(fileName);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade900,
              Colors.purple.shade700,
              Colors.purple.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button
              _buildHeader(),
              const Spacer(),
              // Large album art
              _buildAlbumArt(),
              const SizedBox(height: 40),
              // Song info
              _buildSongInfo(displayName),
              const SizedBox(height: 40),
              // Playback controls
              _buildControls(),
              const SizedBox(height: 40),
              // Volume control
              _buildVolumeControl(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Now Playing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _musicPlayer.shuffle ? Icons.shuffle_on_rounded : Icons.shuffle,
              color: _musicPlayer.shuffle ? Colors.white : Colors.white60,
            ),
            onPressed: () {
              _musicPlayer.toggleShuffle();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade400,
                Colors.purple.shade700,
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.music_note_rounded,
              size: 120,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(String displayName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            _musicPlayer.isPlaying ? 'Playing' : 'Paused',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Previous button
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 48),
            color: Colors.white,
            onPressed: () => _musicPlayer.previous(),
          ),
          // Play/Pause button (large)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _musicPlayer.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 48,
              ),
              color: Colors.purple.shade700,
              onPressed: () {
                if (_musicPlayer.isPlaying) {
                  _musicPlayer.pause();
                } else {
                  _musicPlayer.play();
                }
              },
            ),
          ),
          // Next button
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 48),
            color: Colors.white,
            onPressed: () => _musicPlayer.next(),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Volume',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: Icon(
                  _musicPlayer.repeat ? Icons.repeat_on_rounded : Icons.repeat,
                  color: _musicPlayer.repeat ? Colors.white : Colors.white60,
                ),
                onPressed: () {
                  _musicPlayer.toggleRepeat();
                  setState(() {});
                },
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                Icons.volume_down_rounded,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) {
                      setState(() => _volume = value);
                      _musicPlayer.setVolume(value);
                    },
                  ),
                ),
              ),
              Icon(
                Icons.volume_up_rounded,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _cleanSongName(String fileName) {
    return fileName
        .replaceAll('.mp3', '')
        .replaceAll('.wav', '')
        .replaceAll('.m4a', '')
        .replaceAll('.flac', '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
  }
}

