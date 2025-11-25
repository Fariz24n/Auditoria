import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';
import '../service/ai/ai_activation.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;


class LibraryScreen extends StatefulWidget {
  final AppDatabase db;
  const LibraryScreen({super.key, required this.db});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late AppDatabase db;
  late StreamSubscription<bool> _aiSub;
  bool _aiEnabled = false;

  @override
  void initState() {
    super.initState();
    db = widget.db;

    // Ambil status AI saat ini
    _aiEnabled = AiActivationService.instance.isActive;

    // Dengarkan perubahan status AI
    _aiSub = AiActivationService.instance.onActivationChanged.listen((v) {
      if (!mounted) return;
      setState(() => _aiEnabled = v);
    });
  }

  @override
  void dispose() {
    _aiSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perpustakaan"),
        actions: [
          // Tombol mode AI global
          IconButton(
            icon: Icon(
              _aiEnabled ? Icons.memory : Icons.memory_outlined,
              color: _aiEnabled ? Colors.amber : null,
            ),
            tooltip: _aiEnabled ? 'AI Aktif' : 'Aktifkan AI',
            onPressed: () {
              AiActivationService.instance.toggle();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AiActivationService.instance.isActive
                        ? 'Mode AI diaktifkan. Buku akan dianalisis saat dibuka.'
                        : 'Mode AI dimatikan.',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),

      // ====== BODY ======
      body: StreamBuilder<List<Book>>(
        stream: db.watchAllBooks(),
        builder: (context, snapshot) {
          // Show loading only on first load
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final books = snapshot.data ?? [];
          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "Rak buku Anda masih kosong",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/import'),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Buku'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return _BookshelfView(books: books, db: db);
        },
      ),

      // Floating Action Button untuk import
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/import'),
        tooltip: 'Import Buku',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================
// BOOKSHELF VIEW - Modern 2.5D Library Layout with Drag & Drop
// ============================================================
class _BookshelfView extends StatefulWidget {
  final List<Book> books;
  final AppDatabase db;

  const _BookshelfView({required this.books, required this.db});

  @override
  State<_BookshelfView> createState() => _BookshelfViewState();
}

class _BookshelfViewState extends State<_BookshelfView> {
  List<Book> _currentBooks = [];

  @override
  void initState() {
    super.initState();
    _currentBooks = List.from(widget.books);
  }

  @override
  void didUpdateWidget(_BookshelfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.books != oldWidget.books) {
      _currentBooks = List.from(widget.books);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive book sizing
        final screenWidth = constraints.maxWidth;
        final booksPerShelf = _calculateBooksPerShelf(screenWidth);
        final bookWidth = (screenWidth - 48) / booksPerShelf - 12;
        final bookHeight = bookWidth * 1.5;

        // Group books into shelves
        final shelves = _groupBooksIntoShelves(_currentBooks, booksPerShelf);

        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          physics: const BouncingScrollPhysics(),
          itemCount: shelves.length,
          onReorder: (oldIndex, newIndex) {
            // This won't be called for the shelves themselves
          },
          itemBuilder: (context, shelfIndex) {
            return _ShelfRow(
              key: ValueKey('shelf_$shelfIndex'),
              books: shelves[shelfIndex],
              bookWidth: bookWidth,
              bookHeight: bookHeight,
              booksPerShelf: booksPerShelf,
              db: widget.db,
              onBookReorder: (int bookIndex, int targetIndex) {
                _onBookReorder(
                    shelfIndex, bookIndex, targetIndex, booksPerShelf);
              },
            );
          },
        );
      },
    );
  }

  void _onBookReorder(int shelfIndex, int bookIndexInShelf,
      int targetIndexInShelf, int booksPerShelf) {
    setState(() {
      final oldGlobalIndex = shelfIndex * booksPerShelf + bookIndexInShelf;
      final newGlobalIndex = shelfIndex * booksPerShelf + targetIndexInShelf;

      if (oldGlobalIndex < _currentBooks.length &&
          newGlobalIndex < _currentBooks.length) {
        final book = _currentBooks.removeAt(oldGlobalIndex);
        _currentBooks.insert(newGlobalIndex, book);
      }
    });

    // Save to database
    _saveOrder();
  }

  Future<void> _saveOrder() async {
    final bookIds = _currentBooks.map((b) => b.id).toList();
    await widget.db.reorderBooks(bookIds);
  }

  int _calculateBooksPerShelf(double screenWidth) {
    if (screenWidth > 1200) return 7;
    if (screenWidth > 900) return 6;
    if (screenWidth > 700) return 5;
    if (screenWidth > 500) return 4;
    return 3;
  }

  List<List<Book>> _groupBooksIntoShelves(List<Book> books, int perShelf) {
    final shelves = <List<Book>>[];
    for (int i = 0; i < books.length; i += perShelf) {
      shelves.add(books.sublist(
          i, i + perShelf > books.length ? books.length : i + perShelf));
    }
    return shelves;
  }
}

class _ShelfRow extends StatelessWidget {
  final List<Book> books;
  final double bookWidth;
  final double bookHeight;
  final int booksPerShelf;
  final AppDatabase db;
  final Function(int oldIndex, int newIndex) onBookReorder;

  const _ShelfRow({
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
          // Books sitting on the shelf
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[850]?.withValues(alpha: 0.3)
                  : Colors.brown[50]?.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < booksPerShelf; i++)
                  if (i < books.length)
                    _DraggableBookSpine(
                      key: ValueKey('book_${books[i].id}'),
                      book: books[i],
                      width: bookWidth,
                      height: bookHeight,
                      index: i,
                      onAccept: (draggedIndex) {
                        onBookReorder(draggedIndex, i);
                      },
                    )
                  else
                    SizedBox(width: bookWidth + 12), // Empty slot
              ],
            ),
          ),

          // The actual shelf board with 2.5D effect
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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

          // Subtle shelf support/shadow
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

class _BookSpine extends StatefulWidget {
  final Book book;
  final double width;
  final double height;

  const _BookSpine({
    required this.book,
    required this.width,
    required this.height,
  });

  @override
  State<_BookSpine> createState() => _BookSpineState();
}

class _BookSpineState extends State<_BookSpine> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final coverPath = widget.book.coverPath ?? '';

    return GestureDetector(
      onTap: () {
        context.go('/book/${widget.book.id}');
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..translateByVector3(
              Vector3(
                0.0,
                _isHovered ? -8.0 : 0.0,
                0.0,
              ),
            ),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                // Main shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha:_isHovered ? 0.4 : 0.25),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: Offset(0, _isHovered ? 8 : 4),
                ),
                // Depth shadow on right side
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.15),
                  blurRadius: 4,
                  offset: const Offset(3, 0),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Book cover or placeholder - load async with error handling
                  if (coverPath.isNotEmpty)
                    Image.file(
                      File(coverPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return frame != null
                            ? child
                            : Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                      },
                    )
                  else
                    _buildPlaceholder(),

                  // Subtle shine effect (top highlight)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: widget.height * 0.3,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha:0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Spine edge effect (right side)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha:0.3),
                            Colors.black.withValues(alpha:0.1),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Book title overlay (bottom)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      child: Text(
                        widget.book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Hover indicator
                  if (_isHovered)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              Theme.of(context).primaryColor.withValues(alpha:0.6),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    // Generate a subtle color based on book title for variety
    final colorIndex = widget.book.title.hashCode % 6;
    final colors = [
      Colors.indigo[300]!,
      Colors.teal[400]!,
      Colors.amber[700]!,
      Colors.deepOrange[400]!,
      Colors.purple[400]!,
      Colors.green[600]!,
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[colorIndex],
            colors[colorIndex].withValues(alpha:0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.book,
          size: widget.width * 0.4,
          color: Colors.white.withValues(alpha:0.7),
        ),
      ),
    );
  }
}

// ============================================================
// DRAGGABLE BOOK SPINE - Enables drag & drop reordering
// ============================================================
class _DraggableBookSpine extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  final int index;
  final Function(int) onAccept;

  const _DraggableBookSpine({
    required Key key,
    required this.book,
    required this.width,
    required this.height,
    required this.index,
    required this.onAccept,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onAcceptWithDetails: (details) {
        onAccept(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
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
                  child: _BookSpine(
                    book: book,
                    width: width,
                    height: height,
                  ),
                ),
              ),
            ),
            childWhenDragging: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.grey.withValues(alpha:0.3),
                  width: 2,
                  style: BorderStyle.solid,
                ),
                color: Colors.grey.withValues(alpha:0.1),
              ),
              child: const Center(
                child: Icon(Icons.drag_handle, color: Colors.grey),
              ),
            ),
            child: Stack(
              children: [
                _BookSpine(
                  book: book,
                  width: width,
                  height: height,
                ),
                if (isHovering)
                  Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).primaryColor,
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
