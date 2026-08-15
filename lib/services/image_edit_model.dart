import 'package:sqflite/sqflite.dart';

class ImageEditModel {
  int? rowNumber;
  String? fileName;
  String? textNumber;
  String? imagePath;
  String? fontType;
  String? textCoordinate;
  String? imageSize;
  String? textColor;
  int? deleteImage;
  String? updateDate;

  ImageEditModel({
    this.rowNumber,
    this.fileName,
    this.textNumber,
    this.imagePath,
    this.fontType,
    this.textCoordinate,
    this.imageSize,
    this.textColor,
    this.deleteImage,
    this.updateDate,
  });

  // Convert model to a Map for database operations
  Map<String, dynamic> toMap({bool forUpdate = false}) {
    final map = {
      'row_number': rowNumber,
      'file_name': fileName,
      'text_number': textNumber,
      'image_path': imagePath,
      'font_type': fontType,
      'text_coordinate': textCoordinate,
      'image_size': imageSize,
      'text_color': textColor,
      'delete_image': deleteImage,
      'update_date': updateDate,
    };

    if (forUpdate) {
      map.removeWhere((key, value) => value == null);
    }

    return map;
  }

  // Create a model instance from a database Map
  factory ImageEditModel.fromMap(Map<String, dynamic> map) {
    return ImageEditModel(
      rowNumber: map['row_number'],
      fileName: map['file_name'],
      textNumber: map['text_number'],
      imagePath: map['image_path'],
      fontType: map['font_type'],
      textCoordinate: map['text_coordinate'],
      imageSize: map['image_size'],
      textColor: map['text_color'],
      deleteImage: map['delete_image'],
      updateDate: map['update_date'],
    );
  }
}

class ImageEditDatabase {
  final Database db;
  ImageEditDatabase(this.db);

  /// Insert new data into the `image_edit_table` table
  Future<int> insertImageEdit(ImageEditModel imageEdit) async {
    imageEdit.updateDate = DateTime.now().toIso8601String(); // Set update_date
    return await db.insert(
      'image_edit_table',
      imageEdit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if exists
    );
  }

  /// Update data in the `image_edit_table` table
  Future<int> updateImageEdit(int rowNumber, ImageEditModel imageEdit) async {
    imageEdit.updateDate = DateTime.now().toIso8601String();
    Map<String, dynamic> updateFields = imageEdit.toMap(forUpdate: true);

    updateFields.removeWhere((key, value) => value == null);
    return await db.update(
      'image_edit_table',
      updateFields,
      where: 'row_number = ?',
      whereArgs: [rowNumber],
    );
  }

  /// Fetch data by `row_number`
  Future<ImageEditModel?> getImageEdit(int rowNumber) async {
    final List<Map<String, dynamic>> result = await db.query(
      'image_edit_table',
      where: 'row_number = ?',
      whereArgs: [rowNumber],
    );

    if (result.isNotEmpty) {
      return ImageEditModel.fromMap(result.first);
    }
    return null;
  }

  /// Fetch all data from `image_edit_table`
  Future<List<ImageEditModel>> getAllImageEdits() async {
    final List<Map<String, dynamic>> result =
        await db.query('image_edit_table');
    return result.map((map) => ImageEditModel.fromMap(map)).toList();
  }
}
