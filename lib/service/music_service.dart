import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../drift/app_database.dart';

class MusicService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AppDatabase db;
  String? _currentTheme;
  String? _currentFilePath;
  bool _wasPlayingBeforeInterruption = false;

  MusicService(this.db) {
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    
    // Handle audio interruptions (phone calls, notifications, etc.)
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.paused && _currentFilePath != null) {
        // Track if we were interrupted vs manually paused
        _wasPlayingBeforeInterruption = true;
      }
    });
  }

  Future<void> playTheme(String theme) async {
    // Ambil daftar musik dari database berdasarkan tema
    final entries = await (db.select(db.themeMusic)
          ..where((tbl) => tbl.theme.equals(theme)))
        .get();

    if (entries.isEmpty) {
      debugPrint('⚠️ Tidak ada musik untuk tema: $theme');
      return;
    }

    // Ambil satu file mp3 secara acak
    final music = (entries..shuffle()).first.filePath;
    debugPrint('🎵 Requested play theme $theme -> $music');

    // If the same file is already loaded, toggle resume instead of restart
    if (_currentFilePath == music) {
      final state = _audioPlayer.state;
      if (state == PlayerState.paused) {
        await _audioPlayer.resume();
      } else if (state == PlayerState.playing) {
        // already playing the requested file, nothing to do
      } else {
        await _audioPlayer.play(DeviceFileSource(music));
      }
      _currentTheme = theme;
      return;
    }

    // New file: stop previous and play
    _currentTheme = theme;
    _currentFilePath = music;
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(music));
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    if (_currentFilePath != null) {
      await _audioPlayer.resume();
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentTheme = null;
    _currentFilePath = null;
  }

  void stopSync() {
    _audioPlayer.stop(); // Don't await - fire and forget
    _currentTheme = null;
    _currentFilePath = null;
  }

  String? get currentTheme => _currentTheme;

  bool get isPlaying => _audioPlayer.state == PlayerState.playing;

  // Streams for UI
  Stream<Duration> get positionStream => _audioPlayer.onPositionChanged;
  Stream<Duration?> get durationStream => _audioPlayer.onDurationChanged;
  Stream<PlayerState> get playerStateStream =>
      _audioPlayer.onPlayerStateChanged;

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }
}
