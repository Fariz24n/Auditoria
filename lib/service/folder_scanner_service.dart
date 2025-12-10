import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../drift/app_database.dart';
import 'dart:developer' as developer;


class ImportConfig {
  /// Path folder yang discan
  final String selectedPath;

  /// Ekstensi file yang diizinkan (contoh: ['.pdf', '.epub', '.mp3'])
  final List<String> allowedExtensions;

  /// Ukuran minimum file (KB) agar tidak import file rusak
  final double minSizeKb;

  /// Default favorite untuk buku
  final bool isFavorite;

  /// Kategori / rak / theme
  /// - Untuk buku → masuk ke Books.theme
  /// - Untuk musik → jadi themeName
  final String? category;

  const ImportConfig({
    required this.selectedPath,
    required this.allowedExtensions,
    this.minSizeKb = 1, // default 1 KB
    this.isFavorite = false,
    this.category,
  });
}

class FolderScannerService {
  final AppDatabase db;
  FolderScannerService(this.db);

  /// Fungsi utama yang dipanggil UI
  Future<int> scanAndImport(ImportConfig config) async {
    final dir = Directory(config.selectedPath);
    if (!dir.existsSync()) return 0;

    // 1. Scan file (Non-recursive agar cepat, atau ubah true jika perlu)
    List<FileSystemEntity> entities = [];
    try {
      entities = dir.listSync(recursive: false); 
    } catch (e) {
      throw Exception("Gagal membaca folder: $e");
    }

    int successCount = 0;
    
    // Siapkan direktori penyimpanan internal App
    final appDir = await getApplicationDocumentsDirectory();
    final bookStorage = Directory('${appDir.path}/books');
    if (!await bookStorage.exists()) await bookStorage.create(recursive: true);

    for (var entity in entities) {
      if (entity is File) {
        // A. Cek Ekstensi
        final ext = p.extension(entity.path).toLowerCase();
        if (!config.allowedExtensions.contains(ext)) continue;

        // B. Cek Ukuran File
        try {
          final stat = await entity.stat();
          final sizeKb = stat.size / 1024;
          if (sizeKb < config.minSizeKb) continue;
        } catch (e) {
          continue; // Skip jika gagal baca stat
        }

        try {
          // LOGIKA PEMISAHAN JENIS FILE BERDASARKAN DATABASE ANDA
          
          // === KASUS 1: BUKU (PDF, EPUB, DOCX) ===
          if (ext == '.pdf' || ext == '.mp3') {
            await _importBook(
              entity, 
              bookStorage, 
              config.isFavorite,
              config.category // Masukkan kategori panel sebagai 'Rak Buku'
            );
            successCount++;
          } 
          
          // === KASUS 2: MUSIK (MP3) ===
          else if (ext == '.mp3') {
            // Default ke 'default' jika kategori null
            final themeName = config.category ?? 'default';
            await _importMusic(entity, themeName);
            successCount++;
          }
        } catch (e) {
          developer.log(
            'Error importing ${entity.path}',
            error: e,
            name: 'ImportService',
          );
        }
      }
    }
    
    return successCount;
  }

  // --- PRIVATE HELPERS ---

  Future<void> _importBook(
    File originalFile, 
    Directory storageDir, 
    bool isFav,
    String? shelfName // Ini akan masuk ke kolom 'theme' di tabel Books
  ) async {
    final fileName = p.basename(originalFile.path);
    
    // Copy file ke internal storage
    final savedFile = await originalFile.copy('${storageDir.path}/$fileName');
    
    // Bersihkan nama file untuk jadi Judul
    final title = p.basenameWithoutExtension(fileName).replaceAll('_', ' ');

    // Gunakan DAO addBook dari AppDatabase
    await db.addBook(BooksCompanion(
      title: Value(title),
      filePath: Value(savedFile.path),
      coverPath: const Value(null),
      lastPageRead: const Value(0),
      isFavorite: Value(isFav),
      // Sinkronisasi dengan kolom 'theme' di tabel Books Anda
      theme: shelfName != null ? Value(shelfName) : const Value.absent(),
      // Kolom baru V5 (biarkan null dulu karena auto-detect sulit)
      author: const Value.absent(),
      description: const Value.absent(), 
      series: const Value.absent(),
      tags: const Value.absent(),
      // Default values
      fileExists: const Value(true),
      displayOrder: const Value(0),
    ));
  }

  Future<void> _importMusic(File originalFile, String themeName) async {
    // Memastikan tema ada (menggunakan helper dari database Anda)
    await db.addThemeIfNotExists(themeName);
    
    final title = p.basenameWithoutExtension(originalFile.path).replaceAll('_', ' ');

    // Menggunakan helper addSong dari database Anda
    await db.addSong(
      themeName: themeName,
      filePath: originalFile.path, // Musik biasanya pakai path asli (hemat storage)
      title: title,
      orderIndex: 0, // Default urutan
    );
  }
}