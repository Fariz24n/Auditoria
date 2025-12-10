import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';
import '../service/ai/ai_activation.dart';
import 'bookshelf_view.dart';
import '../widget/library_drawer.dart';
import '../service/folder_scanner_service.dart';
import '../screen/import_config_dialog.dart';

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
    // 1. BACA FILTER DARI URL (Router)
    final state = GoRouterState.of(context);
    final filterShelf = state.uri.queryParameters['shelf'];
    final filterFav = state.uri.queryParameters['filter'] == 'favorites';

    // Tentukan Judul AppBar (Wrapped in blocks)
    String appBarTitle = "Perpustakaan";
    if (filterFav) {
      appBarTitle = "Favorit";
    } else if (filterShelf != null) {
      appBarTitle = filterShelf;
    }

    return Scaffold(
      drawer: LibraryDrawer(db: widget.db),

      appBar: AppBar(
        title: Text(appBarTitle),
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
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<List<Book>>(
        stream: db.watchBooksFiltered(
          shelf: filterShelf,
          onlyFavorites: filterFav,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final books = snapshot.data ?? [];
          if (books.isEmpty) {
            return _emptyState(context, filterShelf, filterFav);
          }

          return BookshelfView(books: books, db: db);
        },
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.folder),
        onPressed: () async {
          final ImportDialogResult? result = await showDialog(
            context: context,
            builder: (_) => const ImportConfigDialog(),
          );

          if (result == null) return;

          final scanner = FolderScannerService(db);

          final serviceConfig = ImportConfig(
            selectedPath: result.folderPath,
            allowedExtensions: [
              if (result.scanPdf) '.pdf',
              if (result.scanMp3) '.mp3',
            ],
          );

          await scanner.scanAndImport(serviceConfig);
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context, String? shelf, bool isFav) {
    String message = "Rak buku Anda masih kosong";
    
    // Logic wrapped in blocks
    if (isFav) {
      message = "Belum ada buku Favorit";
    } else if (shelf != null) {
      message = "Rak '$shelf' masih kosong";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w300,
            ),
          ),
          if (!isFav && shelf == null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/import'),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Buku'),
            ),
          ]
        ],
      ),
    );
  }
}