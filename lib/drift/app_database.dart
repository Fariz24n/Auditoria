import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// ===== Tabel Buku (UPDATED v5) =====
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get filePath => text()();
  TextColumn get coverPath => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  // Nama rak / shelf  
  TextColumn get theme => text().nullable()();

  BoolColumn get fileExists => boolean().withDefault(const Constant(true))();
  IntColumn get lastPageRead => integer().withDefault(const Constant(0))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  // --- Kolom Baru Versi 5 ---
  TextColumn get author => text().nullable()();      
  TextColumn get description => text().nullable()(); 
  TextColumn get series => text().nullable()();      
  TextColumn get tags => text().nullable()();        
}

/// ===== Themes =====
class Themes extends Table {
  TextColumn get name => text()();
  @override
  Set<Column> get primaryKey => {name};
}

/// ===== Book Categories (NEW v6) =====
/// ===== Book Categories =====
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

/// ===== Many-to-Many: Book ↔ Category =====
class BookCategoryMap extends Table {
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();

  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {bookId, categoryId};
}

class BookWithCategories {
  final Book book;
  final List<Category> categories;

  BookWithCategories(this.book, this.categories);
}

Future<BookWithCategories> getBookWithCategories(int bookId) async {
  final book = await (select(books)..where((b) => b.id.equals(bookId))).getSingle();
  final cats = await getCategoriesOfBook(bookId);
  return BookWithCategories(book, cats);
}

/// ===== Songs =====
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get themeName => text()();
  TextColumn get title => text().nullable()();
  TextColumn get filePath => text()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

/// ===== Database =====
@DriftDatabase(tables: [
  Books,
  Themes,
  Songs,
  Categories,        // new
  BookCategoryMap,   // new
])

class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// UPGRADE VERSI KE 5
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // Migrasi v4
          if (from < 4) {
            await m.createTable(themes);
            await m.createTable(songs);
          }

          // Migrasi v5 — Tambah kolom baru
          if (from < 5) {
            await m.addColumn(books, books.author);
            await m.addColumn(books, books.description);
            await m.addColumn(books, books.series);
            await m.addColumn(books, books.tags);
          }
          // Migrasi v6 — kategori buku
          if (from < 6) {
            await m.createTable(categories);
            await m.createTable(bookCategoryMap);
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

  // ===== Music / Playlist DAO =====

  Future<List<Theme>> getAllThemesCore() => select(themes).get();
  Stream<List<Theme>> watchAllThemesCore() => select(themes).watch();

  Future<List<Song>> getSongsByTheme(String themeName) {
    final q = (select(songs)
          ..where((s) => s.themeName.equals(themeName))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]));
    return q.get();
  }

  Stream<List<Song>> watchSongsByThemeCore(String themeName) {
    final q = (select(songs)
          ..where((s) => s.themeName.equals(themeName))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]));
    return q.watch();
  }

  Future<void> addThemeCore(String name) async {
    await into(themes).insert(ThemesCompanion.insert(name: name));
  }

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
            await (select(themes)..where((t) => t.name.equals(themeName))).get();
        if (existing.isEmpty) {
          await into(themes).insert(ThemesCompanion.insert(name: themeName));
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

  Future<int> deleteSongCore(int id) =>
      (delete(songs)..where((tbl) => tbl.id.equals(id))).go();

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

  Future<int> clearSongsForThemeCore(String themeName) =>
      (delete(songs)..where((tbl) => tbl.themeName.equals(themeName))).go();

  // ===== Compatibility Wrappers =====

  Future<List<Theme>> getAllThemes() => getAllThemesCore();
  Stream<List<Theme>> watchAllThemes() => watchAllThemesCore();
  Future<List<Song>> getSongsByThemeId(String themeName) =>
      getSongsByTheme(themeName);
  Stream<List<Song>> watchSongsByThemeId(String themeName) =>
      watchSongsByThemeCore(themeName);

  Future<void> addThemeIfNotExists(String name) async {
    final existing =
        await (select(themes)..where((t) => t.name.equals(name))).get();
    if (existing.isEmpty) {
      await addThemeCore(name);
    }
  }

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

  Future<int> addSongToTheme(String themeName, String filePath,
          {String? title, int? orderIndex}) =>
      addSong(themeName: themeName, filePath: filePath, title: title, orderIndex: orderIndex);

  Future<void> deleteThemeByName(String name) async => deleteTheme(name);

  Future<void> deleteTheme(String name) async {
    await transaction(() async {
      await (delete(songs)..where((s) => s.themeName.equals(name))).go();
      await (delete(themes)..where((t) => t.name.equals(name))).go();
    });
  }

  Future<List<Song>> getSongsByThemeName(String themeName) =>
      getSongsByTheme(themeName);


  Future<List<Category>> getAllCategories() => select(categories).get();

  Stream<List<Category>> watchAllCategories() => select(categories).watch();
  
  Future<int> addCategory(String name) async {
  return into(categories).insert(CategoriesCompanion.insert(name: name));
  }

  Future<int> deleteCategory(int id) {
  return (delete(categories)..where((tbl) => tbl.id.equals(id))).go();
 }

  Future<List<Category>> getCategoriesOfBook(int bookId) {
    final query = select(categories).join([
      innerJoin(
        bookCategoryMap,
        bookCategoryMap.categoryId.equalsExp(categories.id),
      )
    ])
      ..where(bookCategoryMap.bookId.equals(bookId));

    return query.map((row) => row.readTable(categories)).get();
  }

  Future<void> assignCategoryToBook(int bookId, int categoryId) async {
    await into(bookCategoryMap).insert(
      BookCategoryMapCompanion(
        bookId: Value(bookId),
        categoryId: Value(categoryId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> removeCategoryFromBook(int bookId, int categoryId) async {
  await (delete(bookCategoryMap)
        ..where((tbl) =>
            tbl.bookId.equals(bookId) &
            tbl.categoryId.equals(categoryId)))
      .go();
}

  // ===== File Existence Checker =====
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

  Stream<List<String>> watchUniqueThemes() {
    final query = selectOnly(books, distinct: true)
      ..addColumns([books.theme])
      ..where(books.theme.isNotNull() & books.theme.length.isBiggerThanValue(0));

    return query.map((row) => row.read(books.theme)!).watch();
  }

  Stream<List<Book>> watchBooksFiltered({String? shelf, bool onlyFavorites = false}) {
    return (select(books)
          ..where((tbl) {
            if (onlyFavorites) {
              return tbl.isFavorite.equals(true);
            }
            if (shelf != null && shelf.isNotEmpty) {
              return tbl.theme.equals(shelf);
            }
            return const Constant(true);
          })
          ..orderBy([(t) => OrderingTerm(expression: t.displayOrder)]))
        .watch();
  }
}

/// ===== Connection =====
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app_database.sqlite'));
    return NativeDatabase(file);
  });
}
