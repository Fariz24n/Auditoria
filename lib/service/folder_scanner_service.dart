import 'dart:io';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../drift/app_database.dart';

class ImportConfig {
  final String fileName;
  final String? filePath;       // null jika SAF
  final List<int>? fileBytes;   // null jika non-SAF
  final String extension;

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

  // =========================================================
  // PUBLIC ENTRY POINT
  // =========================================================

  Future<int> scanAndImport(ImportConfig config) async {
    developer.log('scanAndImport: ${config.fileName}');

    final needsFsAccess = config.fileBytes == null;
    if (needsFsAccess) {
      final granted = await _ensureStoragePermission();
      if (!granted) return 0;
    }

    final ext = config.extension.toLowerCase();
    if (ext != '.pdf' && ext != '.mp3') return 0;

    if (config.fileBytes != null) {
      final sizeKb = config.fileBytes!.length / 1024.0;
      if (sizeKb < config.minSizeKb) return 0;
    }

    try {
      bool imported = false;

      if (ext == '.pdf') {
        final bookDir = await _getBookStorage();
        imported = await _importBookFromData(
          config.fileName,
          config.filePath,
          config.fileBytes,
          bookDir,
          config.isFavorite,
          config.category,
        );
      }

      if (ext == '.mp3') {
        imported = await _importMusicFromData(
          config.fileName,
          config.filePath,
          config.fileBytes,
          config.category ?? 'default',
        );
      }

      return imported ? 1 : 0;
    } catch (e, st) {
      developer.log('Import error: $e\n$st');
      return 0;
    }
  }

  // =========================================================
  // STORAGE HELPERS
  // =========================================================

  Future<Directory> _getBookStorage() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/books');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _getMusicStorage() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/music');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // =========================================================
  // PDF IMPORT
  // =========================================================

  Future<bool> _importBookFromData(
    String fileName,
    String? filePath,
    List<int>? fileBytes,
    Directory storageDir,
    bool isFav,
    String? shelfName,
  ) async {
    try {
      final savedPath = '${storageDir.path}/$fileName';
      final savedFile = File(savedPath);

      if (fileBytes != null) {
        await savedFile.writeAsBytes(fileBytes);
      } else if (filePath != null) {
        await File(filePath).copy(savedPath);
      } else {
        return false;
      }

      final duplicate = await (db.select(db.books)
        ..where((b) => b.filePath.equals(savedFile.path)))
          .get();
      if (duplicate.isNotEmpty) return false;

      final title =
          p.basenameWithoutExtension(fileName).replaceAll('_', ' ');

      await db.into(db.books).insert(
        BooksCompanion(
          title: Value(title),
          filePath: Value(savedFile.path),
          coverPath: const Value(null),
          lastPageRead: const Value(0),
          isFavorite: Value(isFav),
          theme: shelfName != null
              ? Value(shelfName)
              : const Value.absent(),
          author: const Value.absent(),
          description: const Value.absent(),
          series: const Value.absent(),
          fileExists: const Value(true),
          displayOrder: const Value(0),
        ),
      );

      return true;
    } catch (e, st) {
      developer.log('Book import failed: $e\n$st');
      return false;
    }
  }

  // =========================================================
  // MP3 IMPORT (COPY-BASED, FINAL VERSION)
  // =========================================================

  Future<bool> _importMusicFromData(
    String fileName,
    String? filePath,
    List<int>? fileBytes,
    String themeName,
  ) async {
    try {
      final musicDir = await _getMusicStorage();
      final savedPath = '${musicDir.path}/$fileName';
      final savedFile = File(savedPath);

      // SALIN FILE (PERMANEN)
      if (fileBytes != null) {
        await savedFile.writeAsBytes(fileBytes);
      } else if (filePath != null) {
        await File(filePath).copy(savedPath);
      } else {
        return false;
      }

      final theme = themeName.toLowerCase().trim();

      await db.into(db.themes).insert(
        ThemesCompanion.insert(name: theme),
        mode: InsertMode.insertOrIgnore,
      );

      final duplicate = await (db.select(db.songs)
        ..where((s) => s.filePath.equals(savedFile.path)))
          .get();
      if (duplicate.isNotEmpty) return false;

      final title =
          p.basenameWithoutExtension(fileName).replaceAll('_', ' ');

      await db.addSongToTheme(
        theme,
        savedFile.path, // INTERNAL PATH
        title: title,
      );

      return true;
    } catch (e, st) {
      developer.log('Music import failed: $e\n$st');
      return false;
    }
  }

  // =========================================================
  // PERMISSION
  // =========================================================

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      final status = await Permission.storage.request();
      if (status.isGranted) return true;

      if (Platform.isAndroid) {
        final manage = await Permission.manageExternalStorage.request();
        if (manage.isGranted) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
