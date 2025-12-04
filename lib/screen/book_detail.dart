// lib/screen/book_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart' hide Theme;
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../drift/app_database.dart';
import 'package:flutter/material.dart' as material show Theme;

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  final AppDatabase db;

  const BookDetailScreen({super.key, required this.bookId, required this.db});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleCtrl;
  late TextEditingController _shelfCtrl; 
  bool _isFavorite = false;
  String? _coverPath;
  Book? _book;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _shelfCtrl = TextEditingController();
    _loadBook();
  }

  Future<void> _loadBook() async {
    final book = await (widget.db.select(widget.db.books)..where((t) => t.id.equals(widget.bookId))).getSingleOrNull();
    if (book != null) {
      setState(() {
        _book = book;
        _titleCtrl.text = book.title;
        _shelfCtrl.text = book.theme ?? ''; // Ini Nama Rak (misal: Drama)
        _isFavorite = book.isFavorite;
        _coverPath = book.coverPath;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_book == null) return;
    
    await widget.db.updateBook(
      BooksCompanion(
        id: drift.Value(widget.bookId),
        title: drift.Value(_titleCtrl.text),
        theme: drift.Value(_shelfCtrl.text.isEmpty ? null : _shelfCtrl.text), // Simpan Nama Rak
        isFavorite: drift.Value(_isFavorite),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Info buku disimpan")));
      context.pop(); // Kembali ke library
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_book == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Informasi Buku")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Bagian Header (Cover & Judul)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Image
                  Container(
                    width: 100,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      image: (_coverPath != null && File(_coverPath!).existsSync())
                          ? DecorationImage(image: FileImage(File(_coverPath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _coverPath == null ? const Icon(Icons.book, size: 40) : null,
                  ),
                  const SizedBox(width: 16),
                  // Judul & Penulis Input
                  Expanded(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(labelText: "Judul Buku", border: OutlineInputBorder()),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        // Input Nama Rak (Kategori)
                        TextFormField(
                          controller: _shelfCtrl,
                          decoration: const InputDecoration(
                            labelText: "Nama Rak / Kategori",
                            hintText: "Contoh: Drama, Action...",
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.shelves),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // 2. Tombol Favorite & Dropdown Rak (Seperti Referensi)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: material.Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Checkbox Favorite
                    SwitchListTile(
                      title: const Text("Tandai sebagai Favorit"),
                      subtitle: const Text("Buku akan muncul di filter Favorit"),
                      value: _isFavorite,
                      activeThumbColor: Colors.blueAccent,
                      secondary: Icon(Icons.star, color: _isFavorite ? Colors.amber : Colors.grey),
                      onChanged: (val) => setState(() => _isFavorite = val),
                    ),
                    
                    const Divider(),
                    
                    // Tombol Aksi
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text("Hapus Buku", style: TextStyle(color: Colors.red)),
                            onPressed: () {
                              // Logika hapus buku
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text("Simpan"),
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}