import 'package:file_picker/file_picker.dart';
import '../drift/app_database.dart';

class MusicImportService {
  final AppDatabase db;
  MusicImportService(this.db);

  Future<void> importMusicForTheme(String theme) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      allowMultiple: true,
    );

    if (result == null) return;

    for (var file in result.files) {
      final path = file.path;
      if (path == null) continue;
      await db.into(db.themeMusic).insert(
        ThemeMusicCompanion.insert(
          theme: theme,
          filePath: path,
        ),
      );
    }
  }
}
