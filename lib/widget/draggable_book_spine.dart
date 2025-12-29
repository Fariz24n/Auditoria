import 'package:flutter/material.dart' hide Theme;
import 'package:flutter/material.dart' as material show Theme;
import '../drift/app_database.dart';
import 'book_spine.dart';

class DraggableBookSpine extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  final int index;
  final Function(int) onAccept;

  const DraggableBookSpine({
    super.key,
    required this.book,
    required this.width,
    required this.height,
    required this.index,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, cand, rej) {
        final hovering = cand.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: LongPressDraggable<int>(
            data: index,
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(6),
              child: Opacity(
                opacity: 0.8,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: BookSpine(book: book, width: width, height: height),
                ),
              ),
            ),
            childWhenDragging: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                  width: 2,
                ),
                color: Colors.grey.withValues(alpha: 0.1),
              ),
              child: const Center(child: Icon(Icons.drag_handle)),
            ),
            child: Stack(
              children: [
                BookSpine(book: book, width: width, height: height),
                if (hovering)
                  Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: material.Theme.of(context).primaryColor,
                        width: 3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
