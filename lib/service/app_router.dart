import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';
import '../screen/library_screen.dart';
import '../screen/pdf_view_screen.dart';
import '../screen/favorit.dart';
import '../screen/playlist_screen.dart';
import '../service/music_service.dart';
import '../screen/book_detail.dart';
import '../screen/import.dart';

// note: reuse db instance and create musicService here or inject from app root
final AppDatabase db = AppDatabase();
final MusicService musicService = MusicService(db);

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return LibraryScreen(db: db);
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'book/:id',
          builder: (BuildContext context, GoRouterState state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) {
              return const Scaffold(
                body: Center(child: Text('Invalid book ID')),
              );
            }
            return PdfViewScreen(bookId: id);
          },
        ),
        GoRoute(
          path: 'edit-book/:id',
          builder: (BuildContext context, GoRouterState state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) {
              return const Scaffold(body: Center(child: Text('Error ID')));
            }
            // Kita arahkan ke layar Edit/Detail
            return BookDetailScreen(bookId: id, db: db);
          },
        ),
        GoRoute(
          path: 'favorit',
          builder: (BuildContext context, GoRouterState state) {
            return const FavoritesScreen();
          },
        ),
        GoRoute(
          path: 'import',
          builder: (BuildContext context, GoRouterState state) {
            return ImportScreen(db: db);
          },
        ),
        GoRoute(
          path: 'music',
          builder: (BuildContext context, GoRouterState state) {
            return PlaylistScreen(db: db, musicService: musicService);
          },
        ),
      ],
    ),
  ],
);

===music_import.dart===
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../drift/app_database.dart';

class MusicImportService {
  final AppDatabase db;
  MusicImportService(this.db);

  /// Import multiple mp3 files and attach them to a theme.
  Future<void> importMusicForTheme(String themeName) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      allowMultiple: true,
    );

    if (result == null) return;

    // ensure theme exists (create if not)
    await db.addThemeIfNotExists(themeName);

    for (var file in result.files) {
      final path = file.path;
      if (path == null) continue;
      
      // 🔥 CEK DUPLIKASI: Cegah import lagu yang sama
      final existingSongs = await (db.select(db.songs)
        ..where((s) => s.filePath.equals(path))).get();
      
      if (existingSongs.isNotEmpty) {
        continue; // Skip lagu yang sudah ada
      }
      
      final title = p.basename(path);
      await db.addSong(
        themeName: themeName,
        filePath: path,
        title: title,
      );
    }
  }
}
