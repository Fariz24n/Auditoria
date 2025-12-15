import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'package:permission_handler/permission_handler.dart';

import '../drift/app_database.dart';

class ImportConfig {
  // NEW APPROACH: File data bisa dari bytes (Android SAF) atau path (Desktop/iOS)
  final String fileName;        // Nama file (e.g., "mybuku.pdf")
  final String? filePath;       // Path file (bisa null di Android)
  final List<int>? fileBytes;   // Bytes data (untuk Android SAF)
  final String extension;       // Extension (e.g., ".pdf")
  
  final double minSizeKb;
  final bool isFavorite;
  final String? category;

  const ImportConfig({
    required this.fileName,
    this.filePath,
    this.fileBytes,
    required this.extension,
    this.minSizeKb = 1,
    this.isFavorite = false,
    this.category,
  });
}

class FolderScannerService {
  final AppDatabase db;
  FolderScannerService(this.db);

  /// Main entry: Import single file (using bytes or path).
  /// Returns number of successfully imported items (0 or 1).
  Future<int> scanAndImport(ImportConfig config) async {
    print('\n🟢 ========== scanAndImport START ==========');
    print('📄 FileName: ${config.fileName}');
    print('📍 FilePath: ${config.filePath ?? "NULL (using bytes)"}');
    print('💾 FileBytes: ${config.fileBytes?.length ?? 0} bytes');
    print('📎 Extension: ${config.extension}');
    print('📏 MinSizeKb: ${config.minSizeKb}');
    developer.log('=== scanAndImport START ===');
    developer.log('FileName: ${config.fileName}');
    developer.log('FilePath: ${config.filePath}');
    developer.log('FileBytes length: ${config.fileBytes?.length}');

    // Request storage permission before trying to read filesystem
    print('🔐 Checking storage permission...');
    final hasPermission = await _ensureStoragePermission();
    print('🔐 Permission result: $hasPermission');
    if (!hasPermission) {
      print('❌ Storage permission DENIED!');
      developer.log('Storage permission denied.');
      return 0;
    }
    print('✅ Storage permission GRANTED');

    // Validate extension
    final ext = config.extension.toLowerCase();
    if (ext != '.pdf' && ext != '.mp3') {
      print('❌ Unsupported extension: $ext');
      return 0;
    }
    print('✅ Extension valid: $ext');

    // Size check (if we have bytes)
    if (config.fileBytes != null) {
      final sizeKb = config.fileBytes!.length / 1024.0;
      print('📊 File size: ${sizeKb.toStringAsFixed(2)} KB');
      if (sizeKb < config.minSizeKb) {
        print('⏭️  File too small: ${sizeKb.toStringAsFixed(2)} KB');
        return 0;
      }
      print('✅ Size OK');
    }

    // Ensure app storage folder exists (for PDFs)
    Directory? bookStorage;
    if (ext == '.pdf') {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        bookStorage = Directory('${appDir.path}/books');
        if (!await bookStorage.exists()) {
          await bookStorage.create(recursive: true);
        }
        print('📁 Book storage ready: ${bookStorage.path}');
      } catch (e) {
        print('❌ Failed creating book storage: $e');
        developer.log('Failed creating/accessing app book storage: $e');
        return 0;
      }
    }

    // Import the file
    try {
      bool imported = false;
      if (ext == '.pdf') {
        print('📚 Attempting to import PDF...');
        imported = await _importBookFromData(
          config.fileName,
          config.filePath,
          config.fileBytes,
          bookStorage!,
          config.isFavorite,
          config.category,
        );
      } else if (ext == '.mp3') {
        final themeName = config.category ?? 'default';
        print('🎵 Attempting to import MP3 (theme: $themeName)...');
        imported = await _importMusicFromData(
          config.fileName,
          config.filePath,
          themeName,
        );
      }

      if (imported) {
        print('✅ IMPORTED: ${config.fileName}');
        print('🏁 ========== scanAndImport END ==========');
        print('📊 Success Count: 1');
        print('==========================================\n');
        developer.log('=== scanAndImport END — successCount=1 ===');
        return 1;
      } else {
        print('⏭️  SKIPPED (duplicate): ${config.fileName}');
        print('🏁 ========== scanAndImport END ==========');
        print('📊 Success Count: 0');
        print('==========================================\n');
        developer.log('=== scanAndImport END — successCount=0 ===');
        return 0;
      }
    } catch (e, st) {
      print('❌ ERROR importing: $e');
      developer.log('Error importing ${config.fileName}: $e\n$st', name: 'FolderScannerService');
      print('🏁 ========== scanAndImport END ==========');
      print('📊 Success Count: 0 (error)');
      print('==========================================\n');
      return 0;
    }
  }

  // -------------------
  // Helpers
  // -------------------

  /// Import PDF dari data (bytes atau path)
  Future<bool> _importBookFromData(
    String fileName,
    String? filePath,
    List<int>? fileBytes,
    Directory storageDir,
    bool isFav,
    String? shelfName,
  ) async {
    print('\n  📘 _importBookFromData() START');
    print('  📄 FileName: $fileName');
    print('  📍 FilePath: $filePath');
    print('  💾 Bytes: ${fileBytes?.length ?? 0}');
    print('  📁 Storage: ${storageDir.path}');

    try {
      // Tentukan target path
      final savedPath = '${storageDir.path}/$fileName';
      print('  📋 Target: $savedPath');

      // Copy file ke app storage
      final savedFile = File(savedPath);
      
      if (fileBytes != null) {
        // Gunakan bytes (Android SAF)
        print('  💾 Writing from bytes...');
        await savedFile.writeAsBytes(fileBytes);
        print('  ✅ File written from bytes');
      } else if (filePath != null) {
        // Copy dari path (Desktop/iOS)
        print('  📁 Copying from path...');
        final sourceFile = File(filePath);
        await sourceFile.copy(savedPath);
        print('  ✅ File copied from path');
      } else {
        print('  ❌ No source data available!');
        return false;
      }

      // Check duplicate
      print('  🔍 Checking for duplicates...');
      final existingBooks = await (db.select(db.books)
        ..where((b) => b.filePath.equals(savedFile.path))).get();
      print('  📊 Found ${existingBooks.length} duplicates');

      if (existingBooks.isNotEmpty) {
        print('  ⚠️  DUPLICATE detected, skipping');
        print('  📘 _importBookFromData() END - SKIPPED\n');
        return false;
      }
      print('  ✅ No duplicate');

      // Insert to database
      final title = p.basenameWithoutExtension(fileName).replaceAll('_', ' ');
      print('  📝 Title: $title');
      print('  💾 Inserting to database...');

      await db.addBook(BooksCompanion(
        title: Value(title),
        filePath: Value(savedFile.path),
        coverPath: const Value(null),
        lastPageRead: const Value(0),
        isFavorite: Value(isFav),
        theme: shelfName != null ? Value(shelfName) : const Value.absent(),
        author: const Value.absent(),
        description: const Value.absent(),
        series: const Value.absent(),
        tags: const Value.absent(),
        fileExists: const Value(true),
        displayOrder: const Value(0),
      ));

      print('  ✅ Book inserted!');
      print('  📘 _importBookFromData() END - SUCCESS\n');
      return true;
    } catch (e, st) {
      print('  ❌ ERROR: $e');
      developer.log('Failed importing book $fileName: $e\n$st');
      print('  📘 _importBookFromData() END - FAILED\n');
      return false;
    }
  }

  /// Import MP3 dari path (no copy needed for music)
  Future<bool> _importMusicFromData(
    String fileName,
    String? filePath,
    String themeName,
  ) async {
    print('\n  🎵 _importMusicFromData() START');
    print('  📄 FileName: $fileName');
    print('  📍 FilePath: $filePath');
    print('  🎭 Theme: $themeName');

    try {
      // Ensure theme exists
      print('  🔧 Ensuring theme exists...');
      await db.addThemeIfNotExists(themeName);
      print('  ✅ Theme ready');

      // Check duplicate
      print('  🔍 Checking for duplicates...');
      if (filePath != null) {
        final existingSongs = await (db.select(db.songs)
          ..where((s) => s.filePath.equals(filePath))).get();
        print('  📊 Found ${existingSongs.length} duplicates');

        if (existingSongs.isNotEmpty) {
          print('  ⚠️  DUPLICATE detected, skipping');
          print('  🎵 _importMusicFromData() END - SKIPPED\n');
          return false;
        }
      }
      print('  ✅ No duplicate');

      // Insert to database
      final title = p.basenameWithoutExtension(fileName).replaceAll('_', ' ');
      print('  📝 Title: $title');
      print('  💾 Inserting to database...');

      await db.addSong(
        themeName: themeName,
        filePath: filePath ?? '',
        title: title,
        orderIndex: 0,
      );

      print('  ✅ Song inserted!');
      print('  🎵 _importMusicFromData() END - SUCCESS\n');
      return true;
    } catch (e, st) {
      print('  ❌ ERROR: $e');
      developer.log('Failed importing music $fileName: $e\n$st');
      print('  🎵 _importMusicFromData() END - FAILED\n');
      return false;
    }
  }

  Future<bool> _ensureStoragePermission() async {
    // On platforms other than Android/iOS, assume permission is granted (e.g. desktop).
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      // Request normal storage permission first (Android < 11 / iOS)
      final status = await Permission.storage.request();
      if (status.isGranted) return true;

      // On Android 11+ we may need MANAGE_EXTERNAL_STORAGE (special)
      if (Platform.isAndroid) {
        final manageStatus = await Permission.manageExternalStorage.status;
        if (manageStatus.isGranted) return true;

        // Try to request manageExternalStorage if available
        final req = await Permission.manageExternalStorage.request();
        if (req.isGranted) return true;
      }

      return false;
    } catch (e) {
      developer.log('Permission check/request error: $e');
      return false;
    }
  }
}

