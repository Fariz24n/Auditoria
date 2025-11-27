import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';
import '../screen/screen_1.dart';
import '../screen/pdf_view_screen.dart';
import '../screen/favorit.dart';
import '../screen/import.dart';
import '../screen/playlist_screen.dart';
import '../service/music_service.dart';

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
