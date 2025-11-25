import '../drift/app_database.dart';

class FavoriteService {
  static final List<Book> _favorites = [];

  static List<Book> getFavorites() => _favorites;

  static void toggleFavorite(Book book) {
    if (_favorites.contains(book)) {
      _favorites.remove(book);
    } else {
      _favorites.add(book);
    }
  }

  static bool isFavorite(Book book) {
    return _favorites.contains(book);
  }
}
