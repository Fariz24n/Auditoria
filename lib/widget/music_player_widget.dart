import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:drift/drift.dart' as drift;

import '../service/music_service.dart';
import '../drift/app_database.dart' hide Theme;

// ============================================================================
// MUSIC PLAYER WIDGET
// ============================================================================

class MusicPlayerWidget extends StatelessWidget {
  final MusicService musicService;
  final Stream<String> themeStream;

  const MusicPlayerWidget({
    super.key,
    required this.musicService,
    required this.themeStream,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 6),
            _buildProgressBar(context),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.folder_open_rounded,
            size: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'Atur Musik',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => MusicManagerSheet(musicService: musicService),
            );
          },
        ),
        const SizedBox(width: 8),

        Expanded(
          child: StreamBuilder<String>(
            stream: themeStream,
            initialData: 'default',
            builder: (context, themeSnap) {
              final theme = themeSnap.data ?? 'default';
              final themeColor = _getThemeColor(theme);

              return StreamBuilder<List<MusicFile>>(
                stream: musicService.playlistStream,
                initialData: const [],
                builder: (context, listSnap) {
                  final playlist = listSnap.data ?? [];

                  return StreamBuilder<int>(
                    stream: musicService.currentIndexStream,
                    initialData: -1,
                    builder: (context, indexSnap) {
                      final idx = indexSnap.data ?? -1;
                      final title = (idx >= 0 && idx < playlist.length)
                          ? playlist[idx].title
                          : 'Siap memutar';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(_getThemeIcon(theme), size: 18, color: themeColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    theme.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: themeColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(width: 8),
        _buildControls(context),
      ],
    );
  }

  // --------------------------------------------------------------------------

  Widget _buildControls(BuildContext context) {
    return StreamBuilder<String>(
      stream: themeStream,
      initialData: 'default',
      builder: (context, themeSnap) {
        final themeColor = _getThemeColor(themeSnap.data ?? 'default');

        return StreamBuilder<PlayerState>(
          stream: musicService.playerStateStream,
          initialData: PlayerState.stopped,
          builder: (context, stateSnap) {
            final isPlaying = stateSnap.data == PlayerState.playing;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _btn(Icons.skip_previous_rounded, musicService.previous, 24),
                _btn(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  () => isPlaying ? musicService.pause() : musicService.resume(),
                  36,
                  color: themeColor,
                ),
                _btn(Icons.skip_next_rounded, musicService.next, 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, double size, {Color? color}) {
    return IconButton(
      icon: Icon(icon),
      iconSize: size,
      color: color,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onTap,
    );
  }

  // --------------------------------------------------------------------------

  Widget _buildProgressBar(BuildContext context) {
    return StreamBuilder<String>(
      stream: themeStream,
      initialData: 'default',
      builder: (context, themeSnap) {
        final themeColor = _getThemeColor(themeSnap.data ?? 'default');

        return StreamBuilder<Duration>(
          stream: musicService.positionStream,
          initialData: Duration.zero,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;

            return StreamBuilder<Duration?>(
              stream: musicService.durationStream,
              initialData: Duration.zero,
              builder: (context, durSnap) {
                final dur = durSnap.data ?? Duration.zero;
                final max = dur.inMilliseconds > 0 ? dur.inMilliseconds : 1;
                final cur = pos.inMilliseconds.clamp(0, max).toDouble();

                return Row(
                  children: [
                    _time(_fmt(pos)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbColor: themeColor,
                          activeTrackColor: themeColor,
                          inactiveTrackColor: themeColor.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: cur,
                          max: max.toDouble(),
                          onChanged: (_) {},
                          onChangeEnd: (v) =>
                              musicService.seek(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                    ),
                    _time(_fmt(dur)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _time(String t) => SizedBox(
        width: 36,
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      );

  static String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  // --------------------------------------------------------------------------
  // THEME HELPERS (VERSI 1 DIPERTAHANKAN)
  // --------------------------------------------------------------------------

  static Color _getThemeColor(String theme) {
    switch (theme.toLowerCase()) {
      case 'happy': return Colors.amber;
      case 'calming': return Colors.blue;
      case 'thrill': return Colors.red;
      case 'tense': return Colors.purple;
      case 'battle': return Colors.deepOrange;
      case 'default': return Colors.grey;
      default:
        return Colors.primaries[theme.hashCode % Colors.primaries.length];
    }
  }

  static IconData _getThemeIcon(String theme) {
    switch (theme.toLowerCase()) {
      case 'happy': return Icons.sentiment_very_satisfied;
      case 'calming': return Icons.spa;
      case 'thrill': return Icons.flash_on;
      case 'tense': return Icons.visibility;
      case 'battle': return Icons.whatshot;
      default: return Icons.music_note;
    }
  }
}

// ============================================================================
// MUSIC MANAGER SHEET (INLINE, LANGSUNG DB)
// ============================================================================

class MusicManagerSheet extends StatefulWidget {
  final MusicService musicService;
  const MusicManagerSheet({super.key, required this.musicService});

  @override
  State<MusicManagerSheet> createState() => _MusicManagerSheetState();
}

class _MusicManagerSheetState extends State<MusicManagerSheet> {
  String _filter = 'uncategorized';
  String _target = 'happy';
  final Set<int> _selected = {};

  final _themes = ['happy', 'calming', 'tense', 'battle', 'thrill'];
  final _filters = ['uncategorized', 'happy', 'calming', 'tense', 'battle', 'thrill'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Atur Musik', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),

          Row(
            children: [
              const Text('Tampilkan:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filter,
                items: _filters
                    .map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() {
                  _filter = v!;
                  _selected.clear();
                }),
              ),
            ],
          ),

          Expanded(
            child: FutureBuilder<List<Song>>(
              future: _fetchSongs(),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final songs = snap.data!;
                if (songs.isEmpty) return const Center(child: Text('Kosong'));

                return ListView(
                  children: songs.map((s) {
                    final sel = _selected.contains(s.id);
                    return CheckboxListTile(
                      value: sel,
                      title: Text(s.title ?? _basename(s.filePath)),
                      subtitle: Text(_basename(s.filePath)),
                      onChanged: (v) => setState(() {
                        v == true ? _selected.add(s.id) : _selected.remove(s.id);
                      }),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          Row(
            children: [
              DropdownButton<String>(
                value: _target,
                items: _themes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _target = v!),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _selected.isEmpty ? null : _move,
                child: const Text('PINDAH'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<Song>> _fetchSongs() {
    final db = widget.musicService.db;
    // When filtering 'uncategorized', show both 'uncategorized' and 'default' themes
    if (_filter == 'uncategorized') {
      return (db.select(db.songs)
        ..where((s) => s.themeName.equals('uncategorized') | s.themeName.equals('default')))
        .get();
    }
    return (db.select(db.songs)..where((s) => s.themeName.equals(_filter))).get();
  }

  Future<void> _move() async {
    final db = widget.musicService.db;
    await db.addThemeIfNotExists(_target);

    for (final id in _selected) {
      await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
        SongsCompanion(themeName: drift.Value(_target)),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dipindahkan ke $_target')),
      );
      setState(() => _selected.clear());
    }
  }

  String _basename(String p) => p.split('/').last;
}
