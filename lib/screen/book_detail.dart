import 'dart:io';
import 'package:flutter/material.dart' hide Theme; // Hindari konflik nama Theme drift
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../drift/app_database.dart';

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  final AppDatabase db;

  const BookDetailScreen({super.key, required this.bookId, required this.db});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _titleCtrl;
  late TextEditingController _authorCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _seriesCtrl;
  late TextEditingController _tagsCtrl;
  late TextEditingController _shelfCtrl;

  bool _isFavorite = false;
  bool _useShelf = false; // Checkbox logika rak
  String? _coverPath;
  Book? _book;

  // List rak yang sudah ada untuk dropdown
  List<String> _existingShelves = [];

  List<Category> _allCategories = [];
  List<int> _bookCategoryIds = []; // kategori yang dimiliki buku ini
  TextEditingController _newCategoryCtrl = TextEditingController();


  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _authorCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _seriesCtrl = TextEditingController();
    _tagsCtrl = TextEditingController();
    _shelfCtrl = TextEditingController();
    
    _loadBookData();
    _loadCategories(); 
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _descCtrl.dispose();
    _seriesCtrl.dispose();
    _tagsCtrl.dispose();
    _shelfCtrl.dispose();
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookData() async {
    // 1. Ambil Data Buku
    final book = await (widget.db.select(widget.db.books)
          ..where((t) => t.id.equals(widget.bookId)))
        .getSingleOrNull();

    // 2. Ambil Daftar Rak Unik yang sudah ada (untuk dropdown)
    final allBooks = await widget.db.getAllBooks();
    final shelves = allBooks
        .map((b) => b.theme)
        .where((t) => t != null && t.isNotEmpty)
        .toSet() // Hapus duplikat
        .toList();

    if (book != null && mounted) {
      setState(() {
        _book = book;
        _existingShelves = shelves.cast<String>();

        _titleCtrl.text = book.title;
        _authorCtrl.text = book.author ?? '';
        _descCtrl.text = book.description ?? '';
        _seriesCtrl.text = book.series ?? '';
        
        _isFavorite = book.isFavorite;
        _coverPath = book.coverPath;

        // Logika Rak: Jika ada isinya, nyalakan checkbox
        if (book.theme != null && book.theme!.isNotEmpty) {
          _useShelf = true;
          _shelfCtrl.text = book.theme!;
        } else {
          _useShelf = false;
          _shelfCtrl.text = '';
        }
      });
    }
  }

  Future<void> _loadCategories() async {
  // Ambil semua kategori
  final categories = await widget.db.select(widget.db.categories).get();


  // Ambil kategori milik buku ini
  final catOfBook = await widget.db.getCategoriesOfBook(widget.bookId);

  setState(() {
    _allCategories = categories;
    _bookCategoryIds = catOfBook.map((c) => c.id).toList();
  });
  }


  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    // Simpan permanen ke folder app
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory('${appDir.path}/covers');
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final fileName = 'cover_${widget.bookId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImage = await File(pickedFile.path).copy('${coversDir.path}/$fileName');

    setState(() {
      _coverPath = savedImage.path;
    });
  }

  Future<void> _saveChanges() async {
    if (_book == null) return;

    // Tentukan nama rak
    // Jika checkbox mati, rak = null. Jika hidup, ambil teksnya.
    String? finalShelf;
    if (_useShelf && _shelfCtrl.text.trim().isNotEmpty) {
      finalShelf = _shelfCtrl.text.trim();
    } else {
      finalShelf = null;
    }

    await (widget.db.update(widget.db.books)
          ..where((t) => t.id.equals(widget.bookId)))
      .write(
        BooksCompanion(
          title: drift.Value(_titleCtrl.text),
          author: drift.Value(_authorCtrl.text),
          description: drift.Value(_descCtrl.text),
          series: drift.Value(_seriesCtrl.text),
          theme: drift.Value(finalShelf),
          isFavorite: drift.Value(_isFavorite),
          coverPath: drift.Value(_coverPath),
        ),
      );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Info buku berhasil disimpan")),
      );
      context.pop(); // Kembali
    }
  }

  Future<void> _addNewCategory() async {
  final name = _newCategoryCtrl.text.trim();
  if (name.isEmpty) return;

  final id = await widget.db.into(widget.db.categories).insert(
    CategoriesCompanion(
      name: drift.Value(name),
    ),
  );
  await widget.db.assignCategoryToBook(widget.bookId, id);

  _newCategoryCtrl.clear();
  _loadCategories();
 }

 Future<void> _toggleCategory(int categoryId) async {
  final exists = await (widget.db.select(widget.db.bookCategoryMap)
    ..where((m) =>
      m.bookId.equals(widget.bookId) &
      m.categoryId.equals(categoryId)))
    .getSingleOrNull();

  if (exists != null) {
    await (widget.db.delete(widget.db.bookCategoryMap)
      ..where((m) =>
        m.bookId.equals(widget.bookId) &
        m.categoryId.equals(categoryId)))
      .go();
  } else {
    await widget.db.into(widget.db.bookCategoryMap).insert(
      BookCategoryMapCompanion.insert(
        bookId: widget.bookId,
        categoryId: categoryId,
      ),
    );
  }

  _loadCategories();
}



  Future<void> _deleteBook() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Buku?"),
        content: const Text("Buku ini akan dihapus permanen dari perpustakaan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Hapus", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await (widget.db.delete(widget.db.books)
            ..where((t) => t.id.equals(widget.bookId)))
          .go();
      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Styling background agar mirip screenshot dark mode
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark grey bg
      appBar: AppBar(
        title: const Text("Informasi Buku"),
        backgroundColor: const Color(0xFF2C2C2C),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- BAGIAN ATAS (Cover & Info Utama) ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Cover Image (Clickable)
                  GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      width: 110,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black54)],
                        image: (_coverPath != null && File(_coverPath!).existsSync())
                            ? DecorationImage(
                                image: FileImage(File(_coverPath!)), 
                                fit: BoxFit.cover
                              )
                            : null,
                      ),
                      child: _coverPath == null 
                          ? const Center(child: Icon(Icons.add_a_photo, color: Colors.white54))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // 2. Title & Author Inputs
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _titleCtrl,
                          label: "Judul Buku",
                          isBold: true,
                          fontSize: 18,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _authorCtrl,
                          label: "Pengarang Buku",
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        // Tombol Ganti Cover (Explicit Button jika user bingung klik gambar)
                        OutlinedButton(
                          onPressed: _pickCoverImage,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                          ),
                          child: const Text("Pilih Cover"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.white24),

              // --- DESKRIPSI ---
              const SizedBox(height: 16),
              const Text("Deskripsi", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  hintText: "Tulis sinopsis buku...",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                ),
              ),

              const SizedBox(height: 24),

              // --- LOGIKA RAK BUKU & FAVORITE (Complex Part) ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // 1. Favorite Switch
                    Row(
                      children: [
                        Checkbox(
                          value: _isFavorite,
                          activeColor: Colors.blueAccent,
                          onChanged: (v) => setState(() => _isFavorite = v!),
                        ),
                        const Text("Favorite", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    
                    const SizedBox(height: 12),

                    // 2. Shelf Logic (Checkbox + Input + Dropdown)
                    Row(
                      children: [
                        // Checkbox untuk mengaktifkan Rak
                        Checkbox(
                          value: _useShelf,
                          activeColor: Colors.blueAccent,
                          onChanged: (v) {
                            setState(() {
                              _useShelf = v!;
                              if (!_useShelf) _shelfCtrl.clear();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        
                        // Input Field untuk Rak
                        Expanded(
                          child: TextFormField(
                            controller: _shelfCtrl,
                            enabled: _useShelf, // Disable jika checkbox mati
                            style: TextStyle(color: _useShelf ? Colors.white : Colors.grey),
                            decoration: InputDecoration(
                              labelText: "Nama Rak / Kategori",
                              labelStyle: TextStyle(color: Colors.grey[400]),
                              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Dropdown Button (Bulat)
                        PopupMenuButton<String>(
                          enabled: _useShelf,
                          icon: CircleAvatar(
                            backgroundColor: _useShelf ? Colors.grey[700] : Colors.grey[900],
                            radius: 18,
                            child: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          ),
                          onSelected: (String value) {
                            setState(() {
                              _shelfCtrl.text = value; // Isi teks dengan pilihan
                            });
                          },
                          itemBuilder: (BuildContext context) {
                            if (_existingShelves.isEmpty) {
                              return [
                                const PopupMenuItem(enabled: false, child: Text("Belum ada rak tersimpan"))
                              ];
                            }
                            return _existingShelves.map((String shelf) {
                              return PopupMenuItem<String>(
                                value: shelf,
                                child: Text(shelf),
                              );
                            }).toList();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3. Series & Tags
                    _buildUnderlineInput(_seriesCtrl, "Seri"),
                    const SizedBox(height: 8),
                    _buildUnderlineInput(_tagsCtrl, "Tags", icon: Icons.arrow_drop_down_circle_outlined),
                    
                    const SizedBox(height: 16),

// ===================== CATEGORY SECTION =====================
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Kategori Buku",
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allCategories.map((cat) {
                        final isActive = _bookCategoryIds.contains(cat.id);
                        return GestureDetector(
                          onTap: () => _toggleCategory(cat.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.blueAccent : Colors.grey[700],
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(1,2)),
                              ],
                            ),
                            child: Text(
                              cat.name,
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),


                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCategoryCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Buat kategori baru...",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blueAccent)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addNewCategory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Tambah"),
                    ),
                  ],
                ),

const SizedBox(height: 16),
// =================== END CATEGORY SECTION ====================
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- TOMBOL ACTION ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      label: const Text("Hapus Buku", style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _deleteBook,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("Simpan"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16)
                      ),
                      onPressed: _saveChanges,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget untuk Input Field Style
  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    bool isBold = false, 
    double fontSize = 14,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: Colors.white, 
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontSize: fontSize
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
        isDense: true,
        suffixIcon: icon != null ? Icon(icon, color: Colors.grey, size: 20) : null,
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
      ),
    );
  }

  Widget _buildUnderlineInput(TextEditingController ctrl, String label, {IconData? icon}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      ),
    );
  }
}