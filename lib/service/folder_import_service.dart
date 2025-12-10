import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../drift/app_database.dart';

class FolderImportService {
  final AppDatabase db;
  FolderImportService(this.db);

  Future<void> importFromFolder({
    required String folderPath,
    required bool scanPdf,
    required bool scanMp3,
  }) async {
    final dir = Directory(folderPath);

    if (!await dir.exists()) {
      throw Exception('Folder tidak ditemukan');
    }

    final files = dir.listSync(recursive: true);

    final appDir = await getApplicationDocumentsDirectory();

    for (final entity in files) {
      if (entity is! File) continue;

      final ext = p.extension(entity.path).toLowerCase();

      // === PDF IMPORT ===
      if (scanPdf && ext == '.pdf') {
        await _importPdf(entity, appDir);
      }

      // === MP3 IMPORT ===
      if (scanMp3 && ext == '.mp3') {
        await _importMp3(entity, appDir);
      }
    }
  }

  Future<void> _importPdf(File source, Directory appDir) async {
    final fileName = p.basename(source.path);
    final title = p.basenameWithoutExtension(fileName);

    final targetDir = Directory('${appDir.path}/books');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final saved = await source.copy('${targetDir.path}/$fileName');

    await db.addBook(BooksCompanion(
      title: Value(title),
      filePath: Value(saved.path),
      coverPath: const Value(null),
      lastPageRead: const Value(0),
      isFavorite: const Value(false),
    ));
  }

  Future<void> _importMp3(File source, Directory appDir) async {
    final fileName = p.basename(source.path);
    final title = p.basenameWithoutExtension(fileName);

    final targetDir = Directory('${appDir.path}/music');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final saved = await source.copy('${targetDir.path}/$fileName');

    await db.addSong(
      themeName: 'imported', // WAJIB
      filePath: saved.path,
      title: title,
  );
  }
}
