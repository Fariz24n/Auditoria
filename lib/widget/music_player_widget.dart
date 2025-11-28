// lib/widget/music_player_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../service/music_service.dart';

class MusicPlayerWidget extends StatefulWidget {
  final MusicService musicService;
  final Stream<String> themeStream;

  const MusicPlayerWidget({
    super.key,
    required this.musicService,
    required this.themeStream,
  });

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  // StreamSubscriptions
  late StreamSubscription<String> _themeSub;
  late StreamSubscription<PlayerState> _stateSub;
  late StreamSubscription<List<MusicFile>> _playlistSub;
  late StreamSubscription<int> _indexSub;

  // State Variables
  String _currentTheme = 'default';
  bool _isPlaying = false;
  List<MusicFile> _playlist = [];
  int _currentIndex = -1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // 1. Theme Listener (Debounced)
    _themeSub = widget.themeStream.listen((theme) {
      if (!mounted) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _currentTheme = theme);
      });
    });

    // 2. Player State Listener
    _stateSub = widget.musicService.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    // 3. Playlist Listener
    _playlistSub = widget.musicService.playlistStream.listen((list) {
      if (!mounted) return;
      setState(() => _playlist = list);
    });

    // 4. Index Listener
    _indexSub = widget.musicService.currentIndexStream.listen((idx) {
      if (!mounted) return;
      setState(() => _currentIndex = idx);
    });

    // CATATAN: Kami MENGHAPUS _posSub dan _durSub dari sini
    // untuk mencegah setState() dipanggil 60x per detik yang bikin freeze.
  }

  @override
  void dispose() {
    _themeSub.cancel();
    _stateSub.cancel();
    _playlistSub.cancel();
    _indexSub.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getThemeColor();
    final currentTitle = (_currentIndex >= 0 && _currentIndex < _playlist.length)
        ? _playlist[_currentIndex].title
        : 'Select Theme / Play Music';

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER: Theme Info & Controls ---
            Row(
              children: [
                // Theme Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(_getThemeIcon(), size: 16, color: themeColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentTheme.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                            Text(
                              currentTitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: themeColor.withValues(alpha: 0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Controls
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => widget.musicService.previous(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  onPressed: _togglePlayPause,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 32, // Play button lebih besar
                  color: themeColor,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => widget.musicService.next(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
              ],
            ),

            const SizedBox(height: 4),

            // --- PROGRESS BAR (OPTIMIZED) ---
            // Menggunakan StreamBuilder agar hanya bagian Slider yang rebuild
            StreamBuilder<Duration>(
              stream: widget.musicService.positionStream,
              builder: (context, snapshotPos) {
                final position = snapshotPos.data ?? Duration.zero;
                
                return StreamBuilder<Duration?>(
                  stream: widget.musicService.durationStream,
                  builder: (context, snapshotDur) {
                    final duration = snapshotDur.data ?? Duration.zero;
                    final totalMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
                    final currentMs = position.inMilliseconds.clamp(0, totalMs).toDouble();

                    return Row(
                      children: [
                        Text(_formatDuration(position), 
                             style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            ),
                            child: Slider(
                              value: currentMs,
                              max: totalMs.toDouble(),
                              activeColor: themeColor,
                              inactiveColor: themeColor.withValues(alpha: 0.2),
                              onChanged: (v) {
                                // Opsional: Implementasi seek preview
                              },
                              onChangeEnd: (v) {
                                widget.musicService.seek(Duration(milliseconds: v.toInt()));
                              },
                            ),
                          ),
                        ),
                        Text(_formatDuration(duration), 
                             style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    );
                  }
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Color _getThemeColor() {
    switch (_currentTheme) {
      case 'happy': return Colors.amber;
      case 'calming': return Colors.blue;
      case 'thrill': return Colors.red;
      case 'melancholic': return Colors.indigo;
      case 'battle': return Colors.deepOrange;
      default: return Colors.grey;
    }
  }

  IconData _getThemeIcon() {
    switch (_currentTheme) {
      case 'happy': return Icons.sentiment_very_satisfied;
      case 'calming': return Icons.spa;
      case 'thrill': return Icons.flash_on;
      case 'melancholic': return Icons.cloud;
      case 'battle': return Icons.whatshot;
      default: return Icons.music_note;
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await widget.musicService.pause();
    } else {
      await widget.musicService.resume();
    }
  }
}