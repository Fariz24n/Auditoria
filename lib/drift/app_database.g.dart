// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverPathMeta =
      const VerificationMeta('coverPath');
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
      'cover_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
      'theme', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileExistsMeta =
      const VerificationMeta('fileExists');
  @override
  late final GeneratedColumn<bool> fileExists = GeneratedColumn<bool>(
      'file_exists', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("file_exists" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _lastPageReadMeta =
      const VerificationMeta('lastPageRead');
  @override
  late final GeneratedColumn<int> lastPageRead = GeneratedColumn<int>(
      'last_page_read', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _displayOrderMeta =
      const VerificationMeta('displayOrder');
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
      'display_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        filePath,
        coverPath,
        isFavorite,
        theme,
        fileExists,
        lastPageRead,
        displayOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(Insertable<Book> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(_coverPathMeta,
          coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('theme')) {
      context.handle(
          _themeMeta, theme.isAcceptableOrUnknown(data['theme']!, _themeMeta));
    }
    if (data.containsKey('file_exists')) {
      context.handle(
          _fileExistsMeta,
          fileExists.isAcceptableOrUnknown(
              data['file_exists']!, _fileExistsMeta));
    }
    if (data.containsKey('last_page_read')) {
      context.handle(
          _lastPageReadMeta,
          lastPageRead.isAcceptableOrUnknown(
              data['last_page_read']!, _lastPageReadMeta));
    }
    if (data.containsKey('display_order')) {
      context.handle(
          _displayOrderMeta,
          displayOrder.isAcceptableOrUnknown(
              data['display_order']!, _displayOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      coverPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_path']),
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      theme: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}theme']),
      fileExists: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}file_exists'])!,
      lastPageRead: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_page_read'])!,
      displayOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}display_order'])!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final int id;
  final String title;
  final String filePath;
  final String? coverPath;
  final bool isFavorite;
  final String? theme;
  final bool fileExists;
  final int lastPageRead;
  final int displayOrder;
  const Book(
      {required this.id,
      required this.title,
      required this.filePath,
      this.coverPath,
      required this.isFavorite,
      this.theme,
      required this.fileExists,
      required this.lastPageRead,
      required this.displayOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || theme != null) {
      map['theme'] = Variable<String>(theme);
    }
    map['file_exists'] = Variable<bool>(fileExists);
    map['last_page_read'] = Variable<int>(lastPageRead);
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      filePath: Value(filePath),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      isFavorite: Value(isFavorite),
      theme:
          theme == null && nullToAbsent ? const Value.absent() : Value(theme),
      fileExists: Value(fileExists),
      lastPageRead: Value(lastPageRead),
      displayOrder: Value(displayOrder),
    );
  }

  factory Book.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      filePath: serializer.fromJson<String>(json['filePath']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      theme: serializer.fromJson<String?>(json['theme']),
      fileExists: serializer.fromJson<bool>(json['fileExists']),
      lastPageRead: serializer.fromJson<int>(json['lastPageRead']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'filePath': serializer.toJson<String>(filePath),
      'coverPath': serializer.toJson<String?>(coverPath),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'theme': serializer.toJson<String?>(theme),
      'fileExists': serializer.toJson<bool>(fileExists),
      'lastPageRead': serializer.toJson<int>(lastPageRead),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  Book copyWith(
          {int? id,
          String? title,
          String? filePath,
          Value<String?> coverPath = const Value.absent(),
          bool? isFavorite,
          Value<String?> theme = const Value.absent(),
          bool? fileExists,
          int? lastPageRead,
          int? displayOrder}) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        filePath: filePath ?? this.filePath,
        coverPath: coverPath.present ? coverPath.value : this.coverPath,
        isFavorite: isFavorite ?? this.isFavorite,
        theme: theme.present ? theme.value : this.theme,
        fileExists: fileExists ?? this.fileExists,
        lastPageRead: lastPageRead ?? this.lastPageRead,
        displayOrder: displayOrder ?? this.displayOrder,
      );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      theme: data.theme.present ? data.theme.value : this.theme,
      fileExists:
          data.fileExists.present ? data.fileExists.value : this.fileExists,
      lastPageRead: data.lastPageRead.present
          ? data.lastPageRead.value
          : this.lastPageRead,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('filePath: $filePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('theme: $theme, ')
          ..write('fileExists: $fileExists, ')
          ..write('lastPageRead: $lastPageRead, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, filePath, coverPath, isFavorite,
      theme, fileExists, lastPageRead, displayOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.filePath == this.filePath &&
          other.coverPath == this.coverPath &&
          other.isFavorite == this.isFavorite &&
          other.theme == this.theme &&
          other.fileExists == this.fileExists &&
          other.lastPageRead == this.lastPageRead &&
          other.displayOrder == this.displayOrder);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> filePath;
  final Value<String?> coverPath;
  final Value<bool> isFavorite;
  final Value<String?> theme;
  final Value<bool> fileExists;
  final Value<int> lastPageRead;
  final Value<int> displayOrder;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.filePath = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.theme = const Value.absent(),
    this.fileExists = const Value.absent(),
    this.lastPageRead = const Value.absent(),
    this.displayOrder = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String filePath,
    this.coverPath = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.theme = const Value.absent(),
    this.fileExists = const Value.absent(),
    this.lastPageRead = const Value.absent(),
    this.displayOrder = const Value.absent(),
  })  : title = Value(title),
        filePath = Value(filePath);
  static Insertable<Book> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? filePath,
    Expression<String>? coverPath,
    Expression<bool>? isFavorite,
    Expression<String>? theme,
    Expression<bool>? fileExists,
    Expression<int>? lastPageRead,
    Expression<int>? displayOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (filePath != null) 'file_path': filePath,
      if (coverPath != null) 'cover_path': coverPath,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (theme != null) 'theme': theme,
      if (fileExists != null) 'file_exists': fileExists,
      if (lastPageRead != null) 'last_page_read': lastPageRead,
      if (displayOrder != null) 'display_order': displayOrder,
    });
  }

  BooksCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String>? filePath,
      Value<String?>? coverPath,
      Value<bool>? isFavorite,
      Value<String?>? theme,
      Value<bool>? fileExists,
      Value<int>? lastPageRead,
      Value<int>? displayOrder}) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      isFavorite: isFavorite ?? this.isFavorite,
      theme: theme ?? this.theme,
      fileExists: fileExists ?? this.fileExists,
      lastPageRead: lastPageRead ?? this.lastPageRead,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (fileExists.present) {
      map['file_exists'] = Variable<bool>(fileExists.value);
    }
    if (lastPageRead.present) {
      map['last_page_read'] = Variable<int>(lastPageRead.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('filePath: $filePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('theme: $theme, ')
          ..write('fileExists: $fileExists, ')
          ..write('lastPageRead: $lastPageRead, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }
}

class $ThemeMusicTable extends ThemeMusic
    with TableInfo<$ThemeMusicTable, ThemeMusicData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThemeMusicTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
      'theme', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, theme, filePath];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'theme_music';
  @override
  VerificationContext validateIntegrity(Insertable<ThemeMusicData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('theme')) {
      context.handle(
          _themeMeta, theme.isAcceptableOrUnknown(data['theme']!, _themeMeta));
    } else if (isInserting) {
      context.missing(_themeMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ThemeMusicData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThemeMusicData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      theme: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}theme'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
    );
  }

  @override
  $ThemeMusicTable createAlias(String alias) {
    return $ThemeMusicTable(attachedDatabase, alias);
  }
}

class ThemeMusicData extends DataClass implements Insertable<ThemeMusicData> {
  final int id;
  final String theme;
  final String filePath;
  const ThemeMusicData(
      {required this.id, required this.theme, required this.filePath});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme'] = Variable<String>(theme);
    map['file_path'] = Variable<String>(filePath);
    return map;
  }

  ThemeMusicCompanion toCompanion(bool nullToAbsent) {
    return ThemeMusicCompanion(
      id: Value(id),
      theme: Value(theme),
      filePath: Value(filePath),
    );
  }

  factory ThemeMusicData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThemeMusicData(
      id: serializer.fromJson<int>(json['id']),
      theme: serializer.fromJson<String>(json['theme']),
      filePath: serializer.fromJson<String>(json['filePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'theme': serializer.toJson<String>(theme),
      'filePath': serializer.toJson<String>(filePath),
    };
  }

  ThemeMusicData copyWith({int? id, String? theme, String? filePath}) =>
      ThemeMusicData(
        id: id ?? this.id,
        theme: theme ?? this.theme,
        filePath: filePath ?? this.filePath,
      );
  ThemeMusicData copyWithCompanion(ThemeMusicCompanion data) {
    return ThemeMusicData(
      id: data.id.present ? data.id.value : this.id,
      theme: data.theme.present ? data.theme.value : this.theme,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThemeMusicData(')
          ..write('id: $id, ')
          ..write('theme: $theme, ')
          ..write('filePath: $filePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, theme, filePath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThemeMusicData &&
          other.id == this.id &&
          other.theme == this.theme &&
          other.filePath == this.filePath);
}

class ThemeMusicCompanion extends UpdateCompanion<ThemeMusicData> {
  final Value<int> id;
  final Value<String> theme;
  final Value<String> filePath;
  const ThemeMusicCompanion({
    this.id = const Value.absent(),
    this.theme = const Value.absent(),
    this.filePath = const Value.absent(),
  });
  ThemeMusicCompanion.insert({
    this.id = const Value.absent(),
    required String theme,
    required String filePath,
  })  : theme = Value(theme),
        filePath = Value(filePath);
  static Insertable<ThemeMusicData> custom({
    Expression<int>? id,
    Expression<String>? theme,
    Expression<String>? filePath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (theme != null) 'theme': theme,
      if (filePath != null) 'file_path': filePath,
    });
  }

  ThemeMusicCompanion copyWith(
      {Value<int>? id, Value<String>? theme, Value<String>? filePath}) {
    return ThemeMusicCompanion(
      id: id ?? this.id,
      theme: theme ?? this.theme,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThemeMusicCompanion(')
          ..write('id: $id, ')
          ..write('theme: $theme, ')
          ..write('filePath: $filePath')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ThemeMusicTable themeMusic = $ThemeMusicTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [books, themeMusic];
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  required String title,
  required String filePath,
  Value<String?> coverPath,
  Value<bool> isFavorite,
  Value<String?> theme,
  Value<bool> fileExists,
  Value<int> lastPageRead,
  Value<int> displayOrder,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> filePath,
  Value<String?> coverPath,
  Value<bool> isFavorite,
  Value<String?> theme,
  Value<bool> fileExists,
  Value<int> lastPageRead,
  Value<int> displayOrder,
});

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverPath => $composableBuilder(
      column: $table.coverPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get theme => $composableBuilder(
      column: $table.theme, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get fileExists => $composableBuilder(
      column: $table.fileExists, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastPageRead => $composableBuilder(
      column: $table.lastPageRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get displayOrder => $composableBuilder(
      column: $table.displayOrder, builder: (column) => ColumnFilters(column));
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverPath => $composableBuilder(
      column: $table.coverPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get theme => $composableBuilder(
      column: $table.theme, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get fileExists => $composableBuilder(
      column: $table.fileExists, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastPageRead => $composableBuilder(
      column: $table.lastPageRead,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get displayOrder => $composableBuilder(
      column: $table.displayOrder,
      builder: (column) => ColumnOrderings(column));
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<bool> get fileExists => $composableBuilder(
      column: $table.fileExists, builder: (column) => column);

  GeneratedColumn<int> get lastPageRead => $composableBuilder(
      column: $table.lastPageRead, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
      column: $table.displayOrder, builder: (column) => column);
}

class $$BooksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BooksTable,
    Book,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
    Book,
    PrefetchHooks Function()> {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String?> coverPath = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<String?> theme = const Value.absent(),
            Value<bool> fileExists = const Value.absent(),
            Value<int> lastPageRead = const Value.absent(),
            Value<int> displayOrder = const Value.absent(),
          }) =>
              BooksCompanion(
            id: id,
            title: title,
            filePath: filePath,
            coverPath: coverPath,
            isFavorite: isFavorite,
            theme: theme,
            fileExists: fileExists,
            lastPageRead: lastPageRead,
            displayOrder: displayOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            required String filePath,
            Value<String?> coverPath = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<String?> theme = const Value.absent(),
            Value<bool> fileExists = const Value.absent(),
            Value<int> lastPageRead = const Value.absent(),
            Value<int> displayOrder = const Value.absent(),
          }) =>
              BooksCompanion.insert(
            id: id,
            title: title,
            filePath: filePath,
            coverPath: coverPath,
            isFavorite: isFavorite,
            theme: theme,
            fileExists: fileExists,
            lastPageRead: lastPageRead,
            displayOrder: displayOrder,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BooksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BooksTable,
    Book,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
    Book,
    PrefetchHooks Function()>;
typedef $$ThemeMusicTableCreateCompanionBuilder = ThemeMusicCompanion Function({
  Value<int> id,
  required String theme,
  required String filePath,
});
typedef $$ThemeMusicTableUpdateCompanionBuilder = ThemeMusicCompanion Function({
  Value<int> id,
  Value<String> theme,
  Value<String> filePath,
});

class $$ThemeMusicTableFilterComposer
    extends Composer<_$AppDatabase, $ThemeMusicTable> {
  $$ThemeMusicTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get theme => $composableBuilder(
      column: $table.theme, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));
}

class $$ThemeMusicTableOrderingComposer
    extends Composer<_$AppDatabase, $ThemeMusicTable> {
  $$ThemeMusicTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get theme => $composableBuilder(
      column: $table.theme, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));
}

class $$ThemeMusicTableAnnotationComposer
    extends Composer<_$AppDatabase, $ThemeMusicTable> {
  $$ThemeMusicTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);
}

class $$ThemeMusicTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ThemeMusicTable,
    ThemeMusicData,
    $$ThemeMusicTableFilterComposer,
    $$ThemeMusicTableOrderingComposer,
    $$ThemeMusicTableAnnotationComposer,
    $$ThemeMusicTableCreateCompanionBuilder,
    $$ThemeMusicTableUpdateCompanionBuilder,
    (
      ThemeMusicData,
      BaseReferences<_$AppDatabase, $ThemeMusicTable, ThemeMusicData>
    ),
    ThemeMusicData,
    PrefetchHooks Function()> {
  $$ThemeMusicTableTableManager(_$AppDatabase db, $ThemeMusicTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThemeMusicTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThemeMusicTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThemeMusicTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> theme = const Value.absent(),
            Value<String> filePath = const Value.absent(),
          }) =>
              ThemeMusicCompanion(
            id: id,
            theme: theme,
            filePath: filePath,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String theme,
            required String filePath,
          }) =>
              ThemeMusicCompanion.insert(
            id: id,
            theme: theme,
            filePath: filePath,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ThemeMusicTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ThemeMusicTable,
    ThemeMusicData,
    $$ThemeMusicTableFilterComposer,
    $$ThemeMusicTableOrderingComposer,
    $$ThemeMusicTableAnnotationComposer,
    $$ThemeMusicTableCreateCompanionBuilder,
    $$ThemeMusicTableUpdateCompanionBuilder,
    (
      ThemeMusicData,
      BaseReferences<_$AppDatabase, $ThemeMusicTable, ThemeMusicData>
    ),
    ThemeMusicData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ThemeMusicTableTableManager get themeMusic =>
      $$ThemeMusicTableTableManager(_db, _db.themeMusic);
}
