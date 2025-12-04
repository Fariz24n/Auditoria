import 'package:flutter/material.dart';
import '../drift/app_database.dart';
import 'shelf_row.dart';

class BookshelfView extends StatefulWidget {
  final List<Book> books;
  final AppDatabase db;

  const BookshelfView({super.key, required this.books, required this.db});

  @override
  State<BookshelfView> createState() => _BookshelfViewState();
}

class _BookshelfViewState extends State<BookshelfView> {
  List<Book> _currentBooks = [];

  @override
  void initState() {
    super.initState();
    _currentBooks = List.from(widget.books);
  }

  @override
  void didUpdateWidget(BookshelfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.books != oldWidget.books) {
      _currentBooks = List.from(widget.books);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final screenWidth = c.maxWidth;
        final booksPerShelf = _calcBooksPerShelf(screenWidth);
        final bookWidth = (screenWidth - 48) / booksPerShelf - 16;
        final bookHeight = bookWidth * 1.45;

        final shelves = _groupBooks(_currentBooks, booksPerShelf);

        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          physics: const BouncingScrollPhysics(),
          itemCount: shelves.length,
          onReorder: (_, __) {},
          itemBuilder: (context, shelfIndex) {
            return ShelfRow(
              key: ValueKey('shelf_$shelfIndex'),
              books: shelves[shelfIndex],
              bookWidth: bookWidth,
              bookHeight: bookHeight,
              booksPerShelf: booksPerShelf,
              db: widget.db,
              onBookReorder: (oldIndex, newIndex) {
                _reorder(shelfIndex, oldIndex, newIndex, booksPerShelf);
              },
            );
          },
        );
      },
    );
  }

  void _reorder(int shelfIndex, int oldShelfIdx, int newShelfIdx, int perShelf) {
    setState(() {
      final oldGlobal = shelfIndex * perShelf + oldShelfIdx;
      final newGlobal = shelfIndex * perShelf + newShelfIdx;

      if (oldGlobal < _currentBooks.length &&
          newGlobal < _currentBooks.length) {
        final book = _currentBooks.removeAt(oldGlobal);
        _currentBooks.insert(newGlobal, book);
      }
    });

    widget.db.reorderBooks(_currentBooks.map((b) => b.id).toList());
  }

  int _calcBooksPerShelf(double w) {
    if (w > 1200) return 7;
    if (w > 900) return 6;
    if (w > 700) return 5;
    if (w > 500) return 4;
    return 3;
  }

  List<List<Book>> _groupBooks(List<Book> b, int perShelf) {
    final shelves = <List<Book>>[];
    for (int i = 0; i < b.length; i += perShelf) {
      shelves.add(b.sublist(i, i + perShelf > b.length ? b.length : i + perShelf));
    }
    return shelves;
  }
}
