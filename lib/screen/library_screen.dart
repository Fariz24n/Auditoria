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

  /// ✅ FUNGSI IMPORT (DIPERBAIKI - FILE-BASED)
  Future<void> _handleImportBook(BuildContext context) async {
    // 1. Terima list of file data dari dialog
    final List<SelectedFileData>? selectedFiles = await showDialog<List<SelectedFileData>>(
      context: context,
      builder: (_) => const ImportConfigDialog(),
    );

    // Jika user menekan BATAL
    if (selectedFiles == null || selectedFiles.isEmpty) return;

    // 2. Jalankan import untuk setiap file
    final scanner = FolderScannerService(db);
    int successCount = 0;
    int totalFiles = selectedFiles.length;

    try {
      // Tampilkan indikator loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mengimport $totalFiles file...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Import setiap file
      print('\n🔄 ========== IMPORT LOOP START ==========');
      print('📋 Total files to process: ${selectedFiles.length}');
      for (var i = 0; i < selectedFiles.length; i++) {
        final fileData = selectedFiles[i];
        print('\n🔢 Processing file ${i + 1}/${selectedFiles.length}');
        print('📄 File: ${fileData.name}');
        print('📍 Path: ${fileData.path}');
        print('💾 Bytes: ${fileData.bytes?.length ?? 0}');
        
        // Buat config untuk single file (DENGAN BYTES!)
        final config = ImportConfig(
          fileName: fileData.name,
          filePath: fileData.path,
          fileBytes: fileData.bytes,
          extension: fileData.extension,
          minSizeKb: 1,
          isFavorite: false,
          category: null,
        );
        
        print('⚙️  Calling scanAndImport...');
        final imported = await scanner.scanAndImport(config);
        print('📊 Result: imported=$imported files');
        successCount += imported;
      }
      print('\n🏁 ========== IMPORT LOOP END ==========');
      print('📊 Total success count: $successCount\n');

      final count = successCount;

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0 
              ? '✅ Berhasil import $count file baru' 
              : '⚠️ Tidak ada file baru (Mungkin duplikat atau folder kosong)'
          ),
          backgroundColor: count > 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gagal import: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    final filterFav = state.uri.queryParameters['filter'] == 'favorites';

    String? filterShelf = state.uri.queryParameters['shelf'];
    if (filterShelf != null && filterShelf.trim().isEmpty) {
      filterShelf = null;
    }
    
    String appBarTitle = "Perpustakaan";
    if (filterFav) {
      appBarTitle = "Favorit";
    } else if (filterShelf != null && filterShelf.isNotEmpty) {
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
        onPressed: () => _handleImportBook(context),
      ),
    );
  }

  Widget _emptyState(BuildContext context, String? shelf, bool isFav) {
    String message = "Rak buku Anda masih kosong";
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
              onPressed: () => _handleImportBook(context),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Buku'),
            ),
          ]
        ],
      ),
    );
  }
}
