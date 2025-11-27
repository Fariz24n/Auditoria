import 'package:flutter/material.dart';
import '../drift/app_database.dart';
import '../widget/draggable_book_spine.dart';

class ShelfRow extends StatelessWidget {
  final List<Book> books;
  final double bookWidth;
  final double bookHeight;
  final int booksPerShelf;
  final AppDatabase db;
  final Function(int, int) onBookReorder;

  const ShelfRow({
    super.key,
    required this.books,
    required this.bookWidth,
    required this.bookHeight,
    required this.booksPerShelf,
    required this.db,
    required this.onBookReorder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[850]!.withValues(alpha: 0.3)
                  : Colors.brown[50]!.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < booksPerShelf; i++)
                  if (i < books.length)
                    DraggableBookSpine(
                      key: ValueKey('book_${books[i].id}'),
                      book: books[i],
                      width: bookWidth,
                      height: bookHeight,
                      index: i,
                      onAccept: (dragged) => onBookReorder(dragged, i),
                    )
                  else
                    SizedBox(width: bookWidth + 12),
              ],
            ),
          ),

          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.grey[800]!, Colors.grey[900]!]
                    : [Colors.brown[300]!, Colors.brown[400]!],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
