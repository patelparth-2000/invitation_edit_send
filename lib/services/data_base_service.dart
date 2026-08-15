// ignore_for_file: avoid_print

// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'image_edit_model.dart';

class DataBaseService {
  static Database? _db;
  static final DataBaseService instance = DataBaseService._constructor();

  DataBaseService._constructor();

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getApplicationCacheDirectory();
    final databasePath = join(databaseDirPath.path, "image_edit.db");
    print("Database path ==> $databasePath");

    final database = await openDatabase(databasePath, version: 1,
        onCreate: (db, version) async {
      createImageEditTables(db);
    });

    return database;
  }

  Future<void> createImageEditTables(Database db) async {
    // List of all SQL CREATE TABLE statements
    const tableCreationQueries = '''
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
    ''';

    await db.execute(tableCreationQueries);
  }

  Future<int> imageEditInsert(ImageEditModel imageEdit) async {
    final db = await database;
    final imageDb = ImageEditDatabase(db);

    final newImage = imageEdit;

    print("New Image Edit added!");
    return await imageDb.insertImageEdit(newImage);
  }

  void imageEditUpdate(ImageEditModel imageEdit) async {
    final db = await database;
    final imageDb = ImageEditDatabase(db);
    final updateFields = imageEdit;

    await imageDb.updateImageEdit(imageEdit.rowNumber!, updateFields);
    print("Image Edit updated!");
  }

  Future<List<ImageEditModel>> getAllImageEdits() async {
    final db = await database;
    final imageDb = ImageEditDatabase(db);
    final image = await imageDb.getAllImageEdits();
    return image;
  }

  Future<ImageEditModel?> getImageEdit(int rowNumber) async {
    final db = await database;
    final imageDb = ImageEditDatabase(db);
    final image = await imageDb.getImageEdit(rowNumber);
    return image;
  }
}
