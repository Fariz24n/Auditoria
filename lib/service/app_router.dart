import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';
import '../screen/screen_1.dart';
import '../screen/pdf_view_screen.dart';
import '../screen/favorit.dart';
import '../screen/import.dart';

final AppDatabase db = AppDatabase();

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
      ],
    ),
  ],
);
