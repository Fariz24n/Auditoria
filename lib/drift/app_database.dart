import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// ===== Tabel Buku =====
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get filePath => text()();
  TextColumn get coverPath => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get theme => text().nullable()();
  BoolColumn get fileExists => boolean().withDefault(const Constant(true))();
  IntColumn get lastPageRead => integer().withDefault(const Constant(0))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
}

/// ===== New: Themes (playlist categories) =====
/// Example values: 'calming', 'battle', 'happy'
class Themes extends Table {
  TextColumn get name => text()();
  @override
  Set<Column> get primaryKey => {name};
}

/// ===== New: Songs (one-to-many: themeName -> songs) =====
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get themeName => text()();
  TextColumn get title => text().nullable()();
  TextColumn get filePath => text()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

/// ===== Database =====
@DriftDatabase(tables: [Books, Themes, Songs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 4) {
            await m.createTable(vibes);
            await m.createTable(songs);
          }
        },
      );

  // ===== DAO BOOKS =====
  Future<List<Book>> getAllBooks() => (select(books)
        ..orderBy([(t) => OrderingTerm(expression: t.displayOrder)]))
      .get();

  Stream<List<Book>> watchAllBooks() => (select(books)
        ..orderBy([(t) => OrderingTerm(expression: t.displayOrder)]))
      .watch();

  Future<int> addBook(BooksCompanion book) => into(books).insert(book);

  Future<bool> updateBook(BooksCompanion book) => update(books).replace(book);

  Future<int> deleteBook(int id) =>
      (delete(books)..where((tbl) => tbl.id.equals(id))).go();

  Future<void> toggleFavorite(int id, bool currentValue) async {
    await (update(books)..where((tbl) => tbl.id.equals(id))).write(
      BooksCompanion(isFavorite: Value(!currentValue)),
    );
  }

  Future<void> updateLastPage(int bookId, int page) async {
    await (update(books)..where((tbl) => tbl.id.equals(bookId))).write(
      BooksCompanion(lastPageRead: Value(page)),
    );
  }

  Future<void> updateBookOrder(int bookId, int newOrder) async {
    await (update(books)..where((tbl) => tbl.id.equals(bookId))).write(
      BooksCompanion(displayOrder: Value(newOrder)),
    );
  }

  Future<void> reorderBooks(List<int> bookIds) async {
    await transaction(() async {
      for (int i = 0; i < bookIds.length; i++) {
        await updateBookOrder(bookIds[i], i);
      }
    });
  }

  // ===== Playlist / Music DAO (core) =====

  /// Core: get all themes (one-shot)
  Future<List<Vibe>> getAllThemesCore() => select(vibes).get();

  /// Core: watch themes (stream)
  Stream<List<Vibe>> watchAllThemesCore() => select(vibes).watch();

  /// Core: get songs by theme name
  Future<List<Song>> getSongsByTheme(String themeName) {
    final q = (select(songs)..where((s) => s.themeName.equals(themeName))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]));
    return q.get();
  }

  /// Core: watch songs by theme name
  Stream<List<Song>> watchSongsByThemeCore(String themeName) {
    final q = (select(songs)..where((s) => s.themeName.equals(themeName))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]));
    return q.watch();
  }

  /// Core: add theme
  Future<void> addThemeCore(String name) async {
    await into(vibes).insert(ThemesCompanion.insert(name: name));
  }

  /// Core: add song (returns inserted id)
  Future<int> addSongCore({
    required String themeName,
    required String filePath,
    String? title,
    int? orderIndex,
    bool createThemeIfMissing = true,
  }) async {
    return transaction(() async {
      if (createThemeIfMissing) {
        final existing =
            await (select(vibes)..where((t) => t.name.equals(themeName))).get();
        if (existing.isEmpty) {
          await into(vibes).insert(ThemesCompanion.insert(name: themeName));
        }
      }

      final companion = SongsCompanion.insert(
        themeName: themeName,
        filePath: filePath,
      ).copyWith(
        title: title != null ? Value(title) : const Value.absent(),
        orderIndex: orderIndex != null ? Value(orderIndex) : const Value.absent(),
      );

      return into(songs).insert(companion);
    });
  }

  /// Core: delete song by id
  Future<int> deleteSongCore(int id) =>
      (delete(songs)..where((tbl) => tbl.id.equals(id))).go();

  /// Core: reorder songs
  Future<void> reorderSongsCore(String themeName, List<int> orderedIds) async {
    await transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        final id = orderedIds[i];
        await (update(songs)..where((s) => s.id.equals(id))).write(
          SongsCompanion(orderIndex: Value(i)),
        );
      }
    });
  }

  /// Core: clear songs for theme
  Future<int> clearSongsForThemeCore(String themeName) =>
      (delete(songs)..where((tbl) => tbl.themeName.equals(themeName))).go();

  // ===== Compatibility wrappers (names expected by existing code) =====

  /// Compatibility: original callers expecting getAllThemes()
  Future<List<Vibe>> getAllThemes() => getAllThemesCore();

  /// Compatibility: original callers expecting a streaming watcher
  Stream<List<Vibe>> watchAllThemes() => watchAllThemesCore();

  /// Compatibility: provide method name used by older UI code
  /// getSongsByThemeId(String themeName) maps to getSongsByTheme
  Future<List<Song>> getSongsByThemeId(String themeName) =>
      getSongsByTheme(themeName);

  /// Compatibility: provide streaming getter used elsewhere
  Stream<List<Song>> watchSongsByThemeId(String themeName) =>
      watchSongsByThemeCore(themeName);

  /// Compatibility: addThemeIfNotExists(name)
  Future<void> addThemeIfNotExists(String name) async {
    final existing =
        await (select(vibes)..where((t) => t.name.equals(name))).get();
    if (existing.isEmpty) {
      await addThemeCore(name);
    }
  }

  /// Compatibility: addSong(...) used by older import code
  Future<int> addSong({
    required String themeName,
    required String filePath,
    String? title,
    int? orderIndex,
  }) async {
    return addSongCore(
      themeName: themeName,
      filePath: filePath,
      title: title,
      orderIndex: orderIndex,
      createThemeIfMissing: true,
    );
  }

  /// Compatibility alias used in some callers
  Future<int> addSongToTheme(String themeName, String filePath,
          {String? title, int? orderIndex}) =>
      addSong(themeName: themeName, filePath: filePath, title: title, orderIndex: orderIndex);

  /// Compatibility: deleteTheme by name (keeps transactional behavior)
  Future<void> deleteThemeByName(String name) async => deleteTheme(name);

  /// Existing deleteTheme (keeps original name)
  Future<void> deleteTheme(String name) async {
    await transaction(() async {
      await (delete(songs)..where((s) => s.themeName.equals(name))).go();
      await (delete(vibes)..where((t) => t.name.equals(name))).go();
    });
  }

  /// Existing getSongsByTheme kept for backward compatibility
  Future<List<Song>> getSongsByThemeName(String themeName) =>
      getSongsByTheme(themeName);

  // ===== Validasi File (Books) =====
  Future<void> refreshFileExistence() async {
    final allBooks = await select(books).get();
    for (var b in allBooks) {
      final path = b.filePath;
      if (path.isEmpty) continue;

      final exists = File(path).existsSync();
      await (update(books)..where((tbl) => tbl.id.equals(b.id))).write(
        BooksCompanion(fileExists: Value(exists)),
      );
    }
  }
}

//// ===== Connection ke Database =====
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app_database.sqlite'));
    return NativeDatabase(file);
  });
}
