// lib/service/file_import_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart';
import '../drift/app_database.dart';


const bool debugBypassFilePicker = false;

class FileImportService {
  final AppDatabase db;
  FileImportService(this.db);

Future<void> importBook() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf, mp3'],
    allowMultiple: false,
  );

  if (result == null) {
    throw Exception('Tidak ada file yang dipilih');
  }

  final path = result.files.single.path;
  if (path == null) {
    throw Exception('File tidak valid');
  }

  final file = File(path);
  final title = file.uri.pathSegments.last.split('.').first;

  await db.addBook(BooksCompanion(
    title: Value(title),
    filePath: Value(file.path),
    coverPath: const Value(null),
  ));
}
}