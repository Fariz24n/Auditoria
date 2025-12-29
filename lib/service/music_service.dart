import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../drift/app_database.dart';

class MusicFile {
  final int? id;
  final String title;
  final String path;

  MusicFile({this.id, required this.title, required this.path});
}

class MusicService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AppDatabase db;

  List<MusicFile> _playlist = [];
  int _currentIndex = -1;
  String? _currentActiveTheme; // Menyimpan tema yang sedang aktif

  bool _isShuffling = false;
  bool _repeatOne = false;
  bool _repeatAll = false;

  final _playlistCtl = StreamController<List<MusicFile>>.broadcast();
  final _indexCtl = StreamController<int>.broadcast();
  final _stateCtl = StreamController<PlayerState>.broadcast();

  MusicService(this.db) {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.onPlayerStateChanged.listen((state) => _stateCtl.add(state));
    _audioPlayer.onPlayerComplete.listen((_) async => await _handleComplete());
    
    // Initialize with default theme so manual controls work
    _initializeDefaultPlaylist();
  }
  
  Future<void> _initializeDefaultPlaylist() async {
    final songs = await db.getSongsByTheme('default');
    if (songs.isNotEmpty) {
      _currentActiveTheme = 'default';
      _playlist = songs.map((s) => MusicFile(
        id: s.id,
        title: s.title ?? 'Untitled',
        path: s.filePath,
      )).toList();
      _playlistCtl.add(_playlist);
    }
  }

  // PUBLIC STREAMS & GETTERS
  Stream<List<MusicFile>> get playlistStream => _playlistCtl.stream;
  Stream<int> get currentIndexStream => _indexCtl.stream;
  Stream<PlayerState> get playerStateStream => _stateCtl.stream;
  Stream<Duration> get positionStream => _audioPlayer.onPositionChanged;
  Stream<Duration?> get durationStream => _audioPlayer.onDurationChanged;
  
  bool get isPlaying => _audioPlayer.state == PlayerState.playing;
  String? get activeTheme => _currentActiveTheme;

  // ================================================================
  // CORE LOGIC: SET PLAYLIST BY THEME (AI SYNCHRONIZED)
  // ================================================================
  
  Future<void> setPlaylistByTheme(String theme, {int startIndex = 0}) async {
    final cleanTheme = theme.toLowerCase().trim();

    // CEK: Jika tema yang diminta sudah aktif dan sedang berputar, jangan interupsi.
    if (_currentActiveTheme == cleanTheme && isPlaying) {
      debugPrint("MusicService: Tema '$cleanTheme' sudah aktif. Melanjutkan pemutaran...");
      return;
    }

    debugPrint("MusicService: Memuat lagu untuk tema '$cleanTheme'...");
    final songs = await db.getSongsByTheme(cleanTheme);

    if (songs.isEmpty) {
      if (cleanTheme != 'default') {
        debugPrint("MusicService: Tema '$cleanTheme' kosong, lari ke 'default'...");
        return setPlaylistByTheme('default');
      }
      debugPrint("MusicService: Tema default kosong. Player berhenti.");
      await stop();
      return;
    }

    _currentActiveTheme = cleanTheme;
    _playlist = songs.map((s) => MusicFile(
      id: s.id,
      title: s.title ?? 'Untitled',
      path: s.filePath,
    )).toList();

    _playlistCtl.add(_playlist);
    
    // Putar lagu pertama (atau acak jika shuffle aktif)
    final idx = _isShuffling ? Random().nextInt(_playlist.length) : startIndex;
    await playAtIndex(idx.clamp(0, _playlist.length - 1));
  }

  // ================================================================
  // PLAYBACK CONTROLS
  // ================================================================

  Future<void> playAtIndex(int index) async {
    if (_playlist.isEmpty || index < 0 || index >= _playlist.length) return;

    final file = _playlist[index];
    
    // VALIDASI FISIK: Pastikan file benar-benar ada di storage internal
    if (!await File(file.path).exists()) {
      debugPrint("MusicService: ERROR! File tidak ditemukan di ${file.path}");
      return;
    }

    _currentIndex = index;
    _indexCtl.add(_currentIndex);

    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(file.path));
  }

  Future<void> pause() async => await _audioPlayer.pause();
  Future<void> resume() async => await _audioPlayer.resume();
  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentIndex = -1;
    _currentActiveTheme = null;
    _indexCtl.add(_currentIndex);
  }

  Future<void> seek(Duration position) async => await _audioPlayer.seek(position);

Future<void> next() async {
  if (_playlist.isEmpty) {
    if (_currentActiveTheme != null) {
      await setPlaylistByTheme(_currentActiveTheme!);
      return;
    }
    return;
  }

  int nextIndex = _isShuffling
      ? Random().nextInt(_playlist.length)
      : _currentIndex + 1;

  if (nextIndex >= _playlist.length) {
    if (_repeatAll) {
      nextIndex = 0;
    } else {
      return;
    }
  }
  await playAtIndex(nextIndex);
}


Future<void> previous() async {
  if (_playlist.isEmpty) {
    if (_currentActiveTheme != null) {
      await setPlaylistByTheme(_currentActiveTheme!);
      return;
    }
    return;
  }

  int prevIndex = _currentIndex - 1;

  if (prevIndex < 0) {
    if (_repeatAll) {
      prevIndex = _playlist.length - 1;
    } else {
      return;
    }
  }

  await playAtIndex(prevIndex);
}


  // ================================================================
  // SETTINGS & DISPOSE
  // ================================================================

  void toggleShuffle() => _isShuffling = !_isShuffling;
  
  void toggleRepeatOne() {
    _repeatOne = !_repeatOne;
    if (_repeatOne) _repeatAll = false;
  }

  void toggleRepeatAll() {
    _repeatAll = !_repeatAll;
    if (_repeatAll) _repeatOne = false;
  }

  Future<void> _handleComplete() async {
    if (_repeatOne) {
      await playAtIndex(_currentIndex);
    } else {
      await next();
    }
  }

  void dispose() {
    _playlistCtl.close();
    _indexCtl.close();
    _stateCtl.close();
    _audioPlayer.dispose();
  }
}