import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ===== Tabel Buku =====
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

// ===== Tabel Musik Tema =====
class ThemeMusic extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get theme => text()(); // contoh: "calming", "battle"
  TextColumn get filePath => text()(); // path file mp3 di storage
}

// ===== Database =====
@DriftDatabase(tables: [Books, ThemeMusic])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(books, books.lastPageRead as GeneratedColumn);
          }
          if (from < 3) {
            await m.addColumn(books, books.displayOrder as GeneratedColumn);
          }
        },
      );

  // ===== DAO Buku =====
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
    await (update(books)..where((tbl) => tbl.id.equals(id)))
        .write(BooksCompanion(isFavorite: Value(!currentValue)));
  }

  Future<void> updateLastPage(int bookId, int page) async {
    await (update(books)..where((tbl) => tbl.id.equals(bookId)))
        .write(BooksCompanion(lastPageRead: Value(page)));
  }

  Future<void> updateBookOrder(int bookId, int newOrder) async {
    await (update(books)..where((tbl) => tbl.id.equals(bookId)))
        .write(BooksCompanion(displayOrder: Value(newOrder)));
  }

  Future<void> reorderBooks(List<int> bookIds) async {
    await transaction(() async {
      for (int i = 0; i < bookIds.length; i++) {
        await updateBookOrder(bookIds[i], i);
      }
    });
  }

  // ===== DAO Musik =====
  Future<int> addThemeMusic(ThemeMusicCompanion entry) =>
      into(themeMusic).insert(entry);

  Future<List<ThemeMusicData>> getMusicByTheme(String theme) =>
      (select(themeMusic)..where((tbl) => tbl.theme.equals(theme))).get();

  Future<int> deleteMusic(int id) =>
      (delete(themeMusic)..where((tbl) => tbl.id.equals(id))).go();

  // ===== Validasi File =====
  Future<void> refreshFileExistence() async {
    final allBooks = await select(books).get();
    for (var b in allBooks) {
      final path = b.filePath;
      if (path.isEmpty) continue;

      final exists = File(path).existsSync();
      await (update(books)..where((tbl) => tbl.id.equals(b.id)))
          .write(BooksCompanion(fileExists: Value(exists)));
    }
  }
}

// ===== Connection ke Database =====
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app_database.sqlite'));
    return NativeDatabase(file);
  });
}
