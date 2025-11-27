import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';
import '../service/ai/ai_activation.dart';
import 'bookshelf_view.dart';

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

    _aiEnabled = AiActivationService.instance.isActive;
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
          IconButton(
            icon: Icon(
              _aiEnabled ? Icons.memory : Icons.memory_outlined,
              color: _aiEnabled ? Colors.amber : null,
            ),
            onPressed: () {
              AiActivationService.instance.toggle();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AiActivationService.instance.isActive
                        ? 'Mode AI diaktifkan.'
                        : 'Mode AI dimatikan.',
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<List<Book>>(
        stream: db.watchAllBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final books = snapshot.data ?? [];
          if (books.isEmpty) {
            return _emptyState(context);
          }

          return BookshelfView(books: books, db: db);
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/import'),
        tooltip: 'Import Buku',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined, size: 64, color: Colors.grey[400]),
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
          ),
        ],
      ),
    );
  }
}
