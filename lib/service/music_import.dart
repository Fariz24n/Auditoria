import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../drift/app_database.dart';

class MusicImportService {
  final AppDatabase db;
  MusicImportService(this.db);

  /// Import multiple mp3 files and attach them to a theme.
  Future<void> importMusicForTheme(String themeName) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      allowMultiple: true,
    );

    if (result == null) return;

    // ensure theme exists (create if not)
    await db.addThemeIfNotExists(themeName);

    for (var file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final title = p.basename(path);
      await db.addSong(
        themeName: themeName,
        filePath: path,
        title: title,
      );
    }
  }
}
