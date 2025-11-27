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
  late StreamSubscription<String> _themeSub;
  late StreamSubscription<Duration> _posSub;
  late StreamSubscription<Duration?> _durSub;
  late StreamSubscription<PlayerState> _stateSub;
  late StreamSubscription<List<MusicFile>> _playlistSub;
  late StreamSubscription<int> _indexSub;

  String _currentTheme = 'default';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  List<MusicFile> _playlist = [];
  int _currentIndex = -1;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _themeSub = widget.themeStream.listen((theme) {
      if (!mounted) return;

      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _currentTheme = theme);
        });
      });

    _posSub = widget.musicService.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });

    _durSub = widget.musicService.durationStream.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur ?? Duration.zero);
    });

    _stateSub = widget.musicService.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _playlistSub = widget.musicService.playlistStream.listen((list) {
      if (!mounted) return;
      setState(() => _playlist = list);
    });

    _indexSub = widget.musicService.currentIndexStream.listen((idx) {
      if (!mounted) return;
      setState(() => _currentIndex = idx);
    });
  }

  @override
  void dispose() {
    _themeSub.cancel();
    _posSub.cancel();
    _durSub.cancel();
    _stateSub.cancel();
    _playlistSub.cancel();
    _indexSub.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getThemeColor();
    final totalMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final currentTitle = (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex].title : '—';

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
            Row(
              children: [
                // Theme badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              _currentTheme,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: themeColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentTitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: themeColor.withValues(alpha: 0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: _previous,
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: _next,
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stop,
                ),
              ],
            ),

            // Slider
            Row(
              children: [
                Text(_formatDuration(_position),
                    style: const TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value:
                        _position.inMilliseconds.clamp(0, totalMs).toDouble(),
                    max: totalMs.toDouble(),
                    onChanged: (v) {
                      setState(() {
                        _position = Duration(milliseconds: v.toInt());
                      });
                    },
                    onChangeEnd: (v) async {
                      await widget.musicService
                          .seek(Duration(milliseconds: v.toInt()));
                    },
                  ),
                ),
                Text(_formatDuration(_duration),
                    style: const TextStyle(fontSize: 11)),
              ],
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
      case 'happy':
        return Colors.amber;
      case 'calming':
        return Colors.blue;
      case 'thrill':
        return Colors.red;
      case 'melancholic':
        return Colors.indigo;
      case 'battle':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  IconData _getThemeIcon() {
    switch (_currentTheme) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'calming':
        return Icons.spa;
      case 'thrill':
        return Icons.flash_on;
      case 'melancholic':
        return Icons.cloud;
      case 'battle':
        return Icons.whatshot;
      default:
        return Icons.music_note;
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await widget.musicService.pause();
    } else {
      // resume current
      await widget.musicService.resume();
    }
  }

  Future<void> _stop() async {
    await widget.musicService.stop();
  }

  Future<void> _next() async {
    await widget.musicService.next();
  }

  Future<void> _previous() async {
    await widget.musicService.previous();
  }
}
