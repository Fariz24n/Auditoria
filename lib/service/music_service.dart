import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../drift/app_database.dart';

/// Simple model to present songs to UI (can use SongsData from drift as well)
class MusicFile {
  final int? id;
  final int? themeId;
  final String title;
  final String path;
  final int? durationMs;

  MusicFile({
    this.id,
    this.themeId,
    required this.title,
    required this.path,
    this.durationMs,
  });
}

class MusicService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AppDatabase db;

  List<MusicFile> _playlist = [];
  int _currentIndex = -1;

  bool _isShuffling = false;
  bool _repeatOne = false;
  bool _repeatAll = false;

  // Streams for UI
  final _playlistCtl = StreamController<List<MusicFile>>.broadcast();
  final _indexCtl = StreamController<int>.broadcast();
  final _stateCtl = StreamController<PlayerState>.broadcast();

  MusicService(this.db) {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    // forward audio player state
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _stateCtl.add(state);
    });
    _audioPlayer.onPlayerComplete.listen((_) async {
      // when track completes, advance
      await _handleComplete();
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      // position stream is available via _audioPlayer.onPositionChanged
    });
  }

  // PUBLIC STREAMS
  Stream<List<MusicFile>> get playlistStream => _playlistCtl.stream;
  Stream<int> get currentIndexStream => _indexCtl.stream;
  Stream<PlayerState> get playerStateStream => _stateCtl.stream;

  Stream<Duration> get positionStream => _audioPlayer.onPositionChanged;
  Stream<Duration?> get durationStream => _audioPlayer.onDurationChanged;

  int get currentIndex => _currentIndex;
  MusicFile? get currentFile => (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex] : null;

  bool get isPlaying => _audioPlayer.state == PlayerState.playing;

  // Set playlist based on theme name (fetch from DB)
  Future<void> setPlaylistByTheme(String theme, {int startIndex = 0}) async {
    debugPrint("MusicService: Mencari lagu untuk tema '$theme'...");
    await Future.delayed(const Duration(milliseconds: 50));
    final songs = await db.getSongsByThemeName(theme);

    if (songs.isEmpty) {
      debugPrint('MusicService: Lagu Kosong untuk tema "$theme"');

      if (theme != 'default') {
         debugPrint('MusicService: Mencoba memutar tema "default" sebagai cadangan...');
         return setPlaylistByTheme('default'); // <--- Panggil diri sendiri (Rekursif)
      }

      // Jika tema sudah 'default' dan masih kosong juga, baru kita menyerah.
      debugPrint('MusicService: Tema "default" juga kosong. Player berhenti.');
      _playlist = [];
      _playlistCtl.add(_playlist);
      _currentIndex = -1;
      _indexCtl.add(_currentIndex);
      await stop();
      return;
    }

    // 3. Mapping Data (Hanya jalan kalau lagu ditemukan)
    final files = songs.map((s) => MusicFile(
      id: s.id,
      themeId: null,
      title: s.title ?? 'Untitled',
      path: s.filePath,
      durationMs: null,
    )).toList();

    debugPrint("MusicService: Ditemukan ${files.length} lagu. Memulai player...");

    // (Blok 'if (files.isEmpty)' yang kedua tadi saya hapus karena redundan/tidak perlu.
    // Kalau 'songs' tidak empty, 'files' pasti tidak empty).

    _playlist = files;
    _playlistCtl.add(_playlist);

    // clamp startIndex
    final idx = startIndex.clamp(0, _playlist.length - 1);
    await playAtIndex(idx);
  }

  Future<void> setPlaylist(List<MusicFile> files, {int startIndex = 0}) async {
    if (files.isEmpty) {
      _playlist = [];
      _playlistCtl.add(_playlist);
      _currentIndex = -1;
      _indexCtl.add(_currentIndex);
      await stop();
      return;
    }
    _playlist = List.from(files);
    _playlistCtl.add(_playlist);
    final idx = startIndex.clamp(0, _playlist.length - 1);
    await playAtIndex(idx);
  }

  Future<void> playAtIndex(int index) async {
    if (_playlist.isEmpty) return;
    if (index < 0 || index >= _playlist.length) return;

    final file = _playlist[index];
    _currentIndex = index;
    _indexCtl.add(_currentIndex);

    // If same file, resume if paused
    if (_audioPlayer.state == PlayerState.paused && _audioPlayer.source != null) {
      // if same path resume else reload
      if (_audioPlayer.state == PlayerState.paused) {
        // Attempt to resume (audioplayers handles resume)
        await _audioPlayer.resume();
        return;
      }
    }

    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(file.path));
  }

  Future<void> pause() async => await _audioPlayer.pause();
  Future<void> resume() async => await _audioPlayer.resume();
  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentIndex = -1;
    _indexCtl.add(_currentIndex);
  }

  Future<void> seek(Duration position) async => await _audioPlayer.seek(position);

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    if (_isShuffling) {
      final nextIndex = Random().nextInt(_playlist.length);
      await playAtIndex(nextIndex);
      return;
    }
    var nextIndex = _currentIndex + 1;
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
    if (_playlist.isEmpty) {return;}
    var prev = _currentIndex - 1;
    if (prev < 0) {
      if (_repeatAll) {prev = _playlist.length - 1;}
      else {return;}
    }
    await playAtIndex(prev);
  }

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
      return;
    }
    await next();
  }

  void dispose() {
    _playlistCtl.close();
    _indexCtl.close();
    _stateCtl.close();
    _audioPlayer.dispose();
  }
}
