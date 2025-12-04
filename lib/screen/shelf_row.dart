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


// === shelf_row.dart ===
@override
Widget build(BuildContext context) {
  // 1. Warna Papan Rak (Lebih elegan untuk Dark Mode)
  final shelfColor = Colors.grey[800]; 
  final shadowColor = Colors.black.withValues(alpha: 0.5);

  return Container(
    // Beri jarak antar rak lebih lega
    margin: const EdgeInsets.only(bottom: 40), 
    child: Column(
      children: [
        // --- A. AREA BUKU (Tanpa Background Box) ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), // Padding kiri-kanan agar tidak mepet layar
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Agar buku tersebar rapi
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
                  // Placeholder transparan untuk menjaga grid tetap rapi
                  SizedBox(width: bookWidth),
            ],
          ),
        ),

        // --- B. PAPAN RAK (Alas Pijakan) ---
        // Kita buat efek 3D sederhana: Bagian atas papan & bagian depan papan
        Column(
          children: [
            // 1. Permukaan atas papan (tempat buku berdiri)
            Container(
              height: 12, 
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: shelfColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                boxShadow: [
                  // Bayangan di bawah pantat buku (Ambient Occlusion)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
            // 2. Ketebalan papan (Sisi depan)
            Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900], // Lebih gelap untuk efek 3D
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                boxShadow: [
                  // Bayangan rak ke lantai/rak bawahnya
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
}
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 32),
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//             decoration: BoxDecoration(
//               color: isDark
//                   ? Colors.grey[850]!.withValues(alpha: 0.3)
//                   : Colors.brown[50]!.withValues(alpha: 0.5),
//               borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
//             ),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 for (int i = 0; i < booksPerShelf; i++)
//                   if (i < books.length)
//                     DraggableBookSpine(
//                       key: ValueKey('book_${books[i].id}'),
//                       book: books[i],
//                       width: bookWidth,
//                       height: bookHeight,
//                       index: i,
//                       onAccept: (dragged) => onBookReorder(dragged, i),
//                     )
//                   else
//                     SizedBox(width: bookWidth + 12),
//               ],
//             ),
//           ),

//           Container(
//             height: 8,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: isDark
//                     ? [Colors.grey[800]!, Colors.grey[900]!]
//                     : [Colors.brown[300]!, Colors.brown[400]!],
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withValues(alpha: 0.2),
//                   blurRadius: 8,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//           ),

//           Container(
//             height: 2,
//             margin: const EdgeInsets.symmetric(horizontal: 8),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   Colors.transparent,
//                   Colors.black.withValues(alpha: 0.1),
//                   Colors.transparent,
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }