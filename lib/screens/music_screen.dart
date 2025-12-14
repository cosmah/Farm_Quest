import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/music_player_service.dart';
import '../services/sound_service.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final MusicPlayerService _musicPlayer = MusicPlayerService();
  final SoundService _soundService = SoundService();
  StreamSubscription? _playerSubscription;
  double _volume = 0.7;

  @override
  void initState() {
    super.initState();
    _musicPlayer.initialize();
    _playerSubscription = _musicPlayer.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _musicPlayer.setVolume(_volume);
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _musicPlayer.currentSong;
    final playlist = _musicPlayer.playlist;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade400,
              Colors.purple.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // Now Playing Card
              if (currentSong != null) _buildNowPlaying(currentSong),
              // Playlist
              Expanded(
                child: _buildPlaylist(playlist),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🎵', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Music Player',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Play your favorite songs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _musicPlayer.shuffle ? Icons.shuffle_on_rounded : Icons.shuffle,
              color: _musicPlayer.shuffle ? Colors.purple : Colors.grey,
            ),
            onPressed: () {
              _soundService.buttonClickSound();
              _musicPlayer.toggleShuffle();
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(
              _musicPlayer.repeat ? Icons.repeat_on_rounded : Icons.repeat,
              color: _musicPlayer.repeat ? Colors.purple : Colors.grey,
            ),
            onPressed: () {
              _soundService.buttonClickSound();
              _musicPlayer.toggleRepeat();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlaying(Map<String, dynamic> song) {
    final fileName = song['file_name'] as String;
    final displayName = fileName.replaceAll('.mp3', '').replaceAll('.wav', '').replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Album art placeholder
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade300, Colors.purple.shade600],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
              child: Text('🎵', style: TextStyle(fontSize: 60)),
            ),
          ),
          const SizedBox(height: 16),
          // Song name
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Now Playing',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 40),
                onPressed: () {
                  _soundService.buttonClickSound();
                  _musicPlayer.previous();
                },
                color: Colors.purple,
              ),
              const SizedBox(width: 20),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.purple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _musicPlayer.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 40,
                  ),
                  onPressed: () {
                    _soundService.buttonClickSound();
                    if (_musicPlayer.isPlaying) {
                      _musicPlayer.pause();
                    } else {
                      _musicPlayer.play();
                    }
                  },
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 40),
                onPressed: () {
                  _soundService.buttonClickSound();
                  _musicPlayer.next();
                },
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Volume control
          Row(
            children: [
              const Icon(Icons.volume_down, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: Colors.purple,
                  onChanged: (value) {
                    setState(() => _volume = value);
                    _musicPlayer.setVolume(value);
                  },
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist(List<Map<String, dynamic>> playlist) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: Column(
        children: [
          // Playlist header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Your Playlist',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${playlist.length} songs',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Playlist items
          Expanded(
            child: playlist.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final song = playlist[index];
                      final isCurrentSong = index == _musicPlayer.currentIndex;
                      return _buildSongItem(song, index, isCurrentSong);
                    },
                  ),
          ),
          // Add songs button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _addSongs,
              icon: const Icon(Icons.add),
              label: const Text('Add Songs from Phone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎵', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          const Text(
            'No songs yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add songs from your phone to listen while farming!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSongItem(Map<String, dynamic> song, int index, bool isCurrent) {
    final fileName = song['file_name'] as String;
    final displayName = fileName.replaceAll('.mp3', '').replaceAll('.wav', '').replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? Colors.purple.shade300.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? Colors.purple : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCurrent ? Colors.purple : Colors.purple.shade100,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              isCurrent ? (_musicPlayer.isPlaying ? '▶️' : '⏸️') : '🎵',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          displayName,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? Colors.white : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isCurrent ? (_musicPlayer.isPlaying ? 'Playing...' : 'Paused') : 'Tap to play',
          style: TextStyle(
            fontSize: 12,
            color: isCurrent ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: isCurrent ? Colors.white : Colors.red,
          ),
          onPressed: () {
            _soundService.buttonClickSound();
            _confirmDelete(song['id'] as int, displayName);
          },
        ),
        onTap: () {
          _soundService.buttonClickSound();
          _musicPlayer.playSongAt(index);
        },
      ),
    );
  }

  Future<void> _addSongs() async {
    _soundService.buttonClickSound();

    // Request permission based on Android version
    PermissionStatus status;
    
    // For Android 13+ (API 33+), request READ_MEDIA_AUDIO
    if (await Permission.audio.status.isDenied) {
      status = await Permission.audio.request();
    } else {
      status = await Permission.audio.status;
    }
    
    // Fallback to storage permission for older Android versions
    if (!status.isGranted && !status.isLimited) {
      status = await Permission.storage.request();
    }
    
    if (!status.isGranted && !status.isLimited) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Audio permission required to add songs'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    // Pick music files
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      for (var file in result.files) {
        if (file.path != null) {
          await _musicPlayer.addSong(file.path!, file.name);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎵 Added ${result.files.length} song(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text('Remove "$name" from your playlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _musicPlayer.removeSong(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Song removed'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

