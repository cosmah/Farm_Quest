import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/music_player_service.dart';
import '../services/sound_service.dart';
import 'now_playing_screen.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final MusicPlayerService _musicPlayer = MusicPlayerService();
  final SoundService _soundService = SoundService();
  StreamSubscription? _playerSubscription;

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
    final playlist = _musicPlayer.playlist;

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Column(
          children: [
            // Header with add button
            _buildHeader(),
            // Mini Now Playing Bar (tap to expand)
            if (currentSong != null) _buildMiniPlayer(currentSong),
            // Playlist (MAIN FOCUS)
            Expanded(
              child: _buildPlaylist(playlist),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Music Player',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Your library',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          // Add songs button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
            onPressed: _addSongs,
            tooltip: 'Add Songs',
          ),
          // Settings menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.grey.shade800,
            onSelected: (value) {
              if (value == 'shuffle') {
                _musicPlayer.toggleShuffle();
                setState(() {});
              } else if (value == 'repeat') {
                _musicPlayer.toggleRepeat();
                setState(() {});
              } else if (value == 'clear') {
                _confirmClearPlaylist();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'shuffle',
                child: Row(
                  children: [
                    Icon(
                      _musicPlayer.shuffle ? Icons.shuffle_on_rounded : Icons.shuffle,
                      color: _musicPlayer.shuffle ? Colors.purple : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Shuffle',
                      style: TextStyle(
                        color: _musicPlayer.shuffle ? Colors.purple : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'repeat',
                child: Row(
                  children: [
                    Icon(
                      _musicPlayer.repeat ? Icons.repeat_on_rounded : Icons.repeat,
                      color: _musicPlayer.repeat ? Colors.purple : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Repeat',
                      style: TextStyle(
                        color: _musicPlayer.repeat ? Colors.purple : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Clear All', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer(Map<String, dynamic> song) {
    final fileName = song['file_name'] as String;
    final displayName = _cleanSongName(fileName);

    return GestureDetector(
      onTap: () {
        // Open full now playing screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NowPlayingScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade700, Colors.purple.shade900],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Album art thumbnail
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.purple.shade600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.music_note, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _musicPlayer.isPlaying ? 'Playing...' : 'Paused',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Previous button
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 32),
              onPressed: () => _musicPlayer.previous(),
            ),
            // Play/pause button
            IconButton(
              icon: Icon(
                _musicPlayer.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white,
                size: 40,
              ),
              onPressed: () {
                if (_musicPlayer.isPlaying) {
                  _musicPlayer.pause();
                } else {
                  _musicPlayer.play();
                }
              },
            ),
            // Next button
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
              onPressed: () => _musicPlayer.next(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylist(List<Map<String, dynamic>> playlist) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${playlist.length} songs',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final song = playlist[index];
                      final isCurrentSong = index == _musicPlayer.currentIndex;
                      return _buildSongItem(song, index, isCurrentSong);
                    },
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
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.library_music_rounded,
              size: 80,
              color: Colors.purple.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No songs yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add songs from your phone to listen while farming!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _addSongs,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Songs'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongItem(Map<String, dynamic> song, int index, bool isCurrent) {
    final fileName = song['file_name'] as String;
    final displayName = _cleanSongName(fileName);
    final songId = song['id'] as int;

    return Dismissible(
      key: Key('song_$songId'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDeleteSong(displayName);
      },
      onDismissed: (direction) {
        _musicPlayer.removeSong(songId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🗑️ Song removed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.purple.withValues(alpha: 0.3) : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? Colors.purple : Colors.transparent,
            width: 2,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCurrent 
                    ? [Colors.purple, Colors.purple.shade700]
                    : [Colors.grey.shade700, Colors.grey.shade600],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                isCurrent
                    ? (_musicPlayer.isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded)
                    : Icons.music_note_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          title: Text(
            displayName,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            isCurrent ? (_musicPlayer.isPlaying ? 'Now Playing' : 'Paused') : 'Tap to play',
            style: TextStyle(
              fontSize: 12,
              color: isCurrent ? Colors.purple.shade200 : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Delete button (visible)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
                onPressed: () async {
                  final confirm = await _confirmDeleteSong(displayName);
                  if (confirm == true) {
                    _musicPlayer.removeSong(songId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('🗑️ Song removed'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                tooltip: 'Delete',
              ),
            ],
          ),
          onTap: () {
            _musicPlayer.playSongAt(index);
          },
        ),
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

  Future<void> _addSongs() async {
    _soundService.buttonClickSound();

    PermissionStatus status;
    
    if (await Permission.audio.status.isDenied) {
      status = await Permission.audio.request();
    } else {
      status = await Permission.audio.status;
    }
    
    if (!status.isGranted && !status.isLimited) {
      status = await Permission.storage.request();
    }
    
    if (!status.isGranted && !status.isLimited) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Audio permission required to add songs'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<bool?> _confirmDeleteSong(String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Song?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "$name" from your playlist?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmClearPlaylist() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Songs?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove all songs from your playlist. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _musicPlayer.clearPlaylist();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('🗑️ Playlist cleared'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
