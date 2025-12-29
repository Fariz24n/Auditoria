import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// 

/// ===== 1. Tabel Buku (Optimized) =====
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get filePath => text()();
  TextColumn get coverPath => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  // 'theme' di sini berfungsi sebagai nama Rak/Shelf buku
  TextColumn get theme => text().nullable()();

  BoolColumn get fileExists => boolean().withDefault(const Constant(true))();
  IntColumn get lastPageRead => integer().withDefault(const Constant(0))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  // Meta-data Buku
  TextColumn get author => text().nullable()();      
  TextColumn get description => text().nullable()(); 
  TextColumn get series => text().nullable()();      
  // Kolom 'tags' dihapus karena sudah diganti oleh tabel Categories
}

/// ===== 2. Tabel Musik (Themes & Songs) =====
class Themes extends Table {
  TextColumn get name => text()(); // e.g., "happy", "tense"
  @override
  Set<Column> get primaryKey => {name};
}

class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get themeName => text().references(Themes, #name, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  TextColumn get filePath => text()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

/// ===== 3. Tabel Kategori Buku (Many-to-Many) =====
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class BookCategoryMap extends Table {
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryId => integer().references(Categories, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {bookId, categoryId};
}

/// ===== 4. Tabel Chapter Emotion Maps (Phase 2 - Context AI) =====
class ChapterEmotionMaps extends Table {
  TextColumn get chapterId => text()();  // "book_123_chapter_5"
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer()();
  TextColumn get emotionMapJson => text()();  // Serialized ChapterEmotionMapData
  IntColumn get analyzedAt => integer()();
  TextColumn get geminiModel => text().withDefault(const Constant('gemini-1.5-flash'))();
  
  @override
  Set<Column> get primaryKey => {chapterId};
}

@DriftDatabase(tables: [
  Books, Themes, Songs, Categories, BookCategoryMap, ChapterEmotionMaps
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 8; // Naik ke v8 karena perubahan struktur

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 7) {
        await m.createTable(chapterEmotionMaps);
      }
      // Hapus kolom tags jika migrasi dari versi sebelumnya
      if (from < 8) {
        // Drift tidak mendukung penghapusan kolom secara langsung di SQLite 
        // tanpa regenerasi tabel, namun untuk metadata opsional kita bisa mengabaikannya
        // atau melakukan migrasi data ke Categories jika diperlukan.
      }
    },
  );

  // === DAO: BOOKS ===
  Future<List<Book>> getAllBooks() => (select(books)..orderBy([(t) => OrderingTerm(expression: t.displayOrder)])).get();
  
  Future<void> updateLastPage(int bookId, int page) => 
    (update(books)..where((tbl) => tbl.id.equals(bookId))).write(BooksCompanion(lastPageRead: Value(page)));

  Future<void> reorderBooks(List<int> orderedBookIds) async {
  await transaction(() async {
    for (int i = 0; i < orderedBookIds.length; i++) {
      await (update(books)..where((b) => b.id.equals(orderedBookIds[i])))
          .write(BooksCompanion(displayOrder: Value(i)));
    }
  });
}

  // === DAO: CATEGORIES ===
  Future<List<Category>> getCategoriesOfBook(int bookId) {
    final query = select(categories).join([
      innerJoin(bookCategoryMap, bookCategoryMap.categoryId.equalsExp(categories.id))
    ])..where(bookCategoryMap.bookId.equals(bookId));
    return query.map((row) => row.readTable(categories)).get();
  }

  Future<void> assignCategoryToBook(int bookId, int categoryId) =>
    into(bookCategoryMap).insert(
      BookCategoryMapCompanion.insert(
        bookId: bookId,
        categoryId: categoryId,
      ),
      mode: InsertMode.insertOrIgnore,
    );

  // === DAO: MUSIC (Tanpa Redundansi Wrapper) ===
  Future<List<Song>> getSongsByTheme(String themeName) => (select(songs)
    ..where((s) => s.themeName.equals(themeName))
    ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).get();

  Future<void> addSongToTheme(String themeName, String filePath, {String? title}) async {
    await transaction(() async {
      // Pastikan theme ada
      await into(themes).insert(ThemesCompanion.insert(name: themeName), mode: InsertMode.insertOrIgnore);
      await into(songs).insert(SongsCompanion.insert(themeName: themeName, filePath: filePath, title: Value(title)));
    });
  }

  Future<void> addThemeIfNotExists(String themeName) =>
    into(themes).insert(
      ThemesCompanion.insert(name: themeName),
      mode: InsertMode.insertOrIgnore,
    );

  Future<void> addSong({
    required String themeName,
    required String filePath,
    required String title,
    int orderIndex = 0,
  }) async {
    await transaction(() async {
      // Pastikan theme ada
      await addThemeIfNotExists(themeName);
      // Tambah song
      await into(songs).insert(
        SongsCompanion.insert(
          themeName: themeName,
          filePath: filePath,
          title: Value(title),
          orderIndex: Value(orderIndex),
        ),
      );
    });
  }

  // === DAO: WATCH STREAMS (Real-time Updates) ===
  Stream<List<Book>> watchBooksFiltered({
    String? shelf,
    bool onlyFavorites = false,
  }) {
    var query = select(books);
    
    if (shelf != null && shelf.isNotEmpty) {
      query = query..where((b) => b.theme.equals(shelf));
    }
    
    if (onlyFavorites) {
      query = query..where((b) => b.isFavorite.equals(true));
    }
    
    query = query..orderBy([(t) => OrderingTerm(expression: t.displayOrder)]);
    return query.watch();
  }

  Stream<List<String>> watchUniqueThemes() =>
    select(books).watch().map(
      (books) => books
          .map((b) => b.theme)
          .whereType<String>()
          .toSet()
          .toList()
          ..sort(),
    );

  // === DAO: CHAPTER EMOTION MAPS (Integrasi Newreader.dart) ===
  Future<void> saveChapterEmotionMap(String chapterId, int bookId, int chapterIdx, String json) =>
    into(chapterEmotionMaps).insert(
      ChapterEmotionMapsCompanion.insert(
        chapterId: chapterId,
        bookId: bookId,
        chapterIndex: chapterIdx,
        emotionMapJson: json,
        analyzedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrReplace,
    );

  Future<ChapterEmotionMap?> getChapterEmotionMap(String chapterId) =>
    (select(chapterEmotionMaps)..where((t) => t.chapterId.equals(chapterId))).getSingleOrNull();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app_database.sqlite'));
    return NativeDatabase(file);
  });
}