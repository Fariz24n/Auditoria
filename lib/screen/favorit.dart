import 'package:flutter/material.dart';
import '../service/favorit_service.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Book> favorites = FavoriteService.getFavorites();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Books'),
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Text('No favorite books yet 📚'),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final book = favorites[index];
                return ListTile(
                  leading: book.coverPath != null && book.coverPath!.isNotEmpty
                      ? Image.asset(book.coverPath!)
                      : const Icon(Icons.book, size: 40),
                  title: Text(book.title),
                  onTap: () {
                    context.go('/book/${Uri.encodeComponent(book.title)}');
                  },
                );
              },
            ),
    );
  }
}
