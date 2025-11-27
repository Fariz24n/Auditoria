import 'package:flutter/material.dart';
import '../drift/app_database.dart';
import '../service/music_service.dart';

class PlaylistScreen extends StatefulWidget {
  final AppDatabase db;
  final MusicService musicService;

  const PlaylistScreen({super.key, required this.db, required this.musicService});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Library'),
      ),
      body: FutureBuilder<List<Vibe>>(
        future: widget.db.getAllThemes(),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final themes = snap.data!;
          if (themes.isEmpty) return const Center(child: Text('No themes / songs imported yet'));
          return ListView(
            children: themes.map((theme) {
              return ExpansionTile(
                title: Text(theme.name),
                children: [
                  FutureBuilder<List<Song>>(
                    future: widget.db.getSongsByThemeId(theme.name),
                    builder: (c2, snap2) {
                      if (!snap2.hasData) return const SizedBox();
                      final songs = snap2.data!;
                      return Column(
                        children: songs.map((s) {
                          return ListTile(
                            title: Text(s.title ?? 'Untitled'),
                            subtitle: Text(s.filePath, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () {
                                // set playlist to this theme and play this index
                                widget.musicService.setPlaylistByTheme(theme.name, startIndex: songs.indexOf(s));
                                // optionally navigate back or highlight
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
