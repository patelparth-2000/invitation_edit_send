import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/guest.dart';
import 'image_edit_model.dart';

const String dbFileName = 'image_edit.db';

/// Schema history:
///   1  image_edit_table
///   2  + guest_table (guest lists used to live only in widget state, F-7)
const int dbVersion = 2;

class DataBaseService {
  /// App-wide instance: file in `getDatabasesPath()`, default sqflite factory.
  static final DataBaseService instance = DataBaseService();

  /// [path] and [factory] are injectable so tests can use `sqflite_common_ffi`
  /// (`inMemoryDatabasePath` or a temp file).
  DataBaseService({this.path, this.factory});

  /// For tests that override every data method and never open a database.
  @visibleForTesting
  DataBaseService.fake()
      : path = null,
        factory = null;

  final String? path;
  final DatabaseFactory? factory;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _opening ??= _open();
    _db = await _opening!;
    return _db!;
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    _opening = null;
    await db?.close();
  }

  Future<Database> _open() async {
    final String dbPath;
    if (path != null) {
      dbPath = path!;
    } else {
      dbPath = join(await getDatabasesPath(), dbFileName);
      try {
        final cacheDir = await getApplicationCacheDirectory();
        await migrateLegacyDb(
            oldPath: join(cacheDir.path, dbFileName), newPath: dbPath);
      } catch (e) {
        // A failed migration must not stop the app from opening.
        debugPrint('Database migration from cache dir failed: $e');
      }
    }
    debugPrint('Database path ==> $dbPath');
    final options = OpenDatabaseOptions(
      version: dbVersion,
      onCreate: (db, version) async {
        await createImageEditTables(db);
        await createGuestTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await createGuestTable(db);
      },
    );
    return (factory ?? databaseFactory).openDatabase(dbPath, options: options);
  }

  /// Versions before this one opened the DB in the app *cache* directory,
  /// which Android may purge (F-1). If the old file exists and the new one does
  /// not, copy it (with any journal files) and then delete the old copy.
  /// Returns true when a migration happened.
  static Future<bool> migrateLegacyDb({
    required String oldPath,
    required String newPath,
  }) async {
    final oldFile = File(oldPath);
    if (await File(newPath).exists() || !await oldFile.exists()) return false;
    await Directory(dirname(newPath)).create(recursive: true);
    await oldFile.copy(newPath);
    const sideSuffixes = ['-journal', '-wal', '-shm'];
    for (final suffix in sideSuffixes) {
      final side = File('$oldPath$suffix');
      if (await side.exists()) await side.copy('$newPath$suffix');
    }
    // Delete the old copy only after everything was copied.
    await oldFile.delete();
    for (final suffix in sideSuffixes) {
      final side = File('$oldPath$suffix');
      if (await side.exists()) await side.delete();
    }
    debugPrint('Database migrated from $oldPath to $newPath');
    return true;
  }

  static Future<void> createImageEditTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS image_edit_table (
        row_number INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT,
        text_number TEXT,
        image_path TEXT,
        font_type TEXT,
        text_coordinate TEXT,
        image_size TEXT,
        text_color TEXT,
        delete_image INTEGER,
        update_date DATE
      )
    ''');
  }

  /// Plan task 2.6 schema, plus `pdf_path` (the last PDF written for the
  /// guest) so a finished run can be shared without re-rendering.
  static Future<void> createGuestTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS guest_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        layout_id INTEGER NOT NULL,
        values_json TEXT NOT NULL,
        status TEXT,
        pdf_path TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS guest_layout_idx ON guest_table(layout_id)');
  }

  Future<int> imageEditInsert(ImageEditModel imageEdit) async {
    final db = await database;
    return ImageEditDatabase(db).insertImageEdit(imageEdit);
  }

  Future<void> imageEditUpdate(ImageEditModel imageEdit) async {
    final db = await database;
    await ImageEditDatabase(db).updateImageEdit(imageEdit.rowNumber!, imageEdit);
  }

  Future<List<ImageEditModel>> getAllImageEdits() async {
    final db = await database;
    return ImageEditDatabase(db).getAllImageEdits();
  }

  Future<ImageEditModel?> getImageEdit(int rowNumber) async {
    final db = await database;
    return ImageEditDatabase(db).getImageEdit(rowNumber);
  }

  // ---- Guests -------------------------------------------------------------

  Future<List<Guest>> getGuests(int layoutId) async {
    final db = await database;
    final rows = await db.query('guest_table',
        where: 'layout_id = ?', whereArgs: [layoutId], orderBy: 'id');
    return rows.map(Guest.fromMap).toList();
  }

  /// Number of guests per layout, for the dashboard subtitle.
  Future<Map<int, int>> guestCounts() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT layout_id, COUNT(*) AS n FROM guest_table GROUP BY layout_id');
    return {
      for (final r in rows) r['layout_id'] as int: (r['n'] as int?) ?? 0,
    };
  }

  /// Inserts or updates [guest] and returns it with its id set.
  Future<Guest> saveGuest(Guest guest) async {
    final db = await database;
    final map = {
      'layout_id': guest.layoutId,
      'values_json': jsonEncode(guest.values),
      'status': guest.status.name,
      'pdf_path': guest.pdfPath,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (guest.id == null) {
      final id = await db.insert('guest_table', map);
      return guest.copyWith(id: id);
    }
    await db.update('guest_table', map, where: 'id = ?', whereArgs: [guest.id]);
    return guest;
  }

  Future<void> deleteGuest(int id) async {
    final db = await database;
    await db.delete('guest_table', where: 'id = ?', whereArgs: [id]);
  }
}
