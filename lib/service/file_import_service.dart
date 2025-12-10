import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'; // WAJIB TAMBAH INI DI PUBSPEC
import '../drift/app_database.dart';

class FileImportService {
  final AppDatabase db;
  FileImportService(this.db);

  Future<void> importBook() async {
    // 1. Pick File
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'], // Fokus PDF dulu
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) {
      throw Exception('Tidak ada file yang dipilih');
    }

    final originalFile = File(result.files.single.path!);
    
    // 2. DAPATKAN DIRECTORY PERMANEN APLIKASI
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = p.basename(originalFile.path);
    
    // 3. COPY FILE DARI CACHE KE PERMANENT STORAGE
    // Kita buat folder khusus 'books' biar rapi
    final bookDir = Directory('${appDir.path}/books');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    
    final savedFile = await originalFile.copy('${bookDir.path}/$fileName');

    // 4. SIMPAN PATH PERMANEN KE DATABASE
    final title = p.basenameWithoutExtension(fileName); // Ambil nama file tanpa .pdf

    await db.addBook(BooksCompanion(
      title: Value(title),
      filePath: Value(savedFile.path), // <--- INI KUNCINYA (Path Permanen)
      coverPath: const Value(null),
      lastPageRead: const Value(0),
      isFavorite: const Value(false),
    ));
  }
}