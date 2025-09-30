import 'package:flutter/material.dart';
import '../model/book.dart';
import '../service/service.dart';
import '../widget/BukuKartu.dart';
import 'pdf_view_screen.dart';
import 'package:reorderables/reorderables.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Book> books = BookService.getBooks();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Perpustakaan")),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('asset/images/shelf.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const minBookWidth = 100; // lebar minimum tiap buku
                int crossAxisCount = (constraints.maxWidth / minBookWidth).floor();

                return ReorderableWrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.start,
                  needsLongPressDraggable: true,
                  children: List.generate(books.length, (index) {
                    final book = books[index];
                    return SizedBox(
                      width: constraints.maxWidth / crossAxisCount - 16, 
                      child: BookCard(
                        key: ValueKey(book.title),
                        title: book.title,
                        coverPath: book.coverPath,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PdfViewScreen(
                                bookPath: book.filePath,
                                bookTitle: book.title,
                              ),
                            ),
                          );
                        },
                        width: 90,
                        height: 140,
                      ),
                    );
                  }),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      final book = books.removeAt(oldIndex);
                      books.insert(newIndex, book);
                    });
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

