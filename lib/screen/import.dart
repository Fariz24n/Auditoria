import 'package:flutter/material.dart';
import '../service/file_import_service.dart';
import '../service/music_import.dart'; // tambahkan ini
import '../drift/app_database.dart';

class ImportScreen extends StatefulWidget {
  final AppDatabase db;

  const ImportScreen({super.key, required this.db});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late final FileImportService _fileService;
  late final MusicImportService _musicService;
  List<Book> _books = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fileService = FileImportService(widget.db);
    _musicService = MusicImportService(widget.db);
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await widget.db.getAllBooks();
    if (!mounted) return;
    setState(() => _books = books);
  }

  Future<void> _importBook() async {
    final ctx = context;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _fileService.importBook();
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Buku berhasil diimpor')),
      );
      await _loadBooks();
    } catch (e) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Gagal mengimpor buku: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importMusic() async {
    final ctx = context;
    final theme = await showDialog<String>(
      context: ctx,
      builder: (context) {
        String selected = 'default';
        return AlertDialog(
          title: const Text('Pilih Tema Musik'),
          content: DropdownButtonFormField<String>(
            value: selected,
            items: const [
              DropdownMenuItem(value: 'happy', child: Text('Happy')),
              DropdownMenuItem(value: 'calming', child: Text('Calming')),
              DropdownMenuItem(value: 'thrill', child: Text('Thrill')),
              DropdownMenuItem(value: 'melancholic', child: Text('Melancholic')),
              DropdownMenuItem(value: 'battle', child: Text('Battle')),
              DropdownMenuItem(value: 'default', child: Text('Default')),
            ],
            onChanged: (v) => selected = v!,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(context, selected), child: const Text('OK')),
          ],
        );
      },
    );

    if (theme == null) return;

    try {
      await _musicService.importMusicForTheme(theme);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Musik untuk tema "$theme" berhasil diimpor')),
      );
    } catch (e) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Gagal mengimpor musik: $e')),
      );
    }
  }

  Future<void> _deleteBook(Book book) async {
    final ctx = context;

    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Buku'),
        content: Text('Yakin ingin menghapus "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await widget.db.deleteBook(book.id);
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Buku dihapus')),
    );
    await _loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Buku & Musik')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? const Center(child: Text('Belum ada buku yang diimpor.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.book_outlined),
                        title: Text(book.title),
                        subtitle: Text(book.filePath),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteBook(book),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'import_pdf',
            onPressed: _importBook,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Import PDF'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'import_music',
            onPressed: _importMusic,
            icon: const Icon(Icons.library_music),
            label: const Text('Import Musik'),
          ),
        ],
      ),
    );
  }
}
