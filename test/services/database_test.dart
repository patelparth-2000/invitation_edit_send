import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invitation_edit_send/models/guest.dart';
import 'package:invitation_edit_send/services/data_base_service.dart';
import 'package:invitation_edit_send/services/image_edit_model.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late DataBaseService db;
  setUp(() {
    db = DataBaseService(path: inMemoryDatabasePath, factory: factory);
  });
  tearDown(() => db.close());

  ImageEditModel card(String name) => ImageEditModel(
        fileName: name,
        imagePath: '/cards/$name.jpg',
        textNumber: '1',
        textCoordinate: '[{"x":1,"y":2,"s":1.0}]',
        imageSize: '{"width":100,"height":200}',
        textColor: '{"r":255,"g":0,"b":0}',
        deleteImage: 0,
      );

  group('layouts', () {
    test('insert then getAll returns it', () async {
      final id = await db.imageEditInsert(card('Navchandi'));
      final all = await db.getAllImageEdits();
      expect(all.single.rowNumber, id);
      expect(all.single.fileName, 'Navchandi');
      expect(all.single.updateDate, isNotNull);
    });

    test('update renames without touching other columns', () async {
      final id = await db.imageEditInsert(card('Old'));
      await db.imageEditUpdate(ImageEditModel(rowNumber: id, fileName: 'New'));
      final got = (await db.getImageEdit(id))!;
      expect(got.fileName, 'New');
      expect(got.imagePath, '/cards/Old.jpg');
      expect(got.textCoordinate, '[{"x":1,"y":2,"s":1.0}]');
    });

    test('soft delete sets the flag and keeps the row', () async {
      final id = await db.imageEditInsert(card('Gone'));
      await db.imageEditUpdate(ImageEditModel(rowNumber: id, deleteImage: 1));
      expect((await db.getImageEdit(id))!.deleteImage, 1);
      expect(await db.getAllImageEdits(), hasLength(1));
    });

    test('get by id returns null for a missing row', () async {
      expect(await db.getImageEdit(999), isNull);
    });
  });

  group('guests', () {
    test('insert, update, list per layout, count, delete', () async {
      final a = await db.imageEditInsert(card('A'));
      final b = await db.imageEditInsert(card('B'));
      final g1 =
          await db.saveGuest(Guest(layoutId: a, values: const ['Asha', 'Surat']));
      await db.saveGuest(Guest(layoutId: a, values: const ['Ravi']));
      await db.saveGuest(Guest(layoutId: b, values: const ['Other']));
      expect(g1.id, isNotNull);

      await db.saveGuest(g1.copyWith(
          status: GuestStatus.created, pdfPath: () => '/pdf/Asha.pdf'));
      final listA = await db.getGuests(a);
      expect(listA.map((g) => g.displayName), ['Asha', 'Ravi']);
      expect(listA.first.status, GuestStatus.created);
      expect(listA.first.pdfPath, '/pdf/Asha.pdf');
      expect(listA.first.values, ['Asha', 'Surat']);
      expect(await db.guestCounts(), {a: 2, b: 1});

      await db.deleteGuest(g1.id!);
      expect((await db.getGuests(a)).single.displayName, 'Ravi');
    });
  });

  test('v1 -> v2 upgrade keeps layouts and adds guest_table', () async {
    final dir = await Directory.systemTemp.createTemp('dbup');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, dbFileName);

    // Build a version-1 database exactly as the old app did.
    final v1 = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) => DataBaseService.createImageEditTables(d),
        ));
    await v1.insert('image_edit_table', card('Legacy').toMap());
    await v1.close();

    final upgraded = DataBaseService(path: path, factory: factory);
    addTearDown(upgraded.close);
    final all = await upgraded.getAllImageEdits();
    expect(all.single.fileName, 'Legacy');
    final g = await upgraded
        .saveGuest(Guest(layoutId: all.single.rowNumber!, values: const ['x']));
    expect(g.id, isNotNull);
    expect((await upgraded.database).getVersion(), completion(dbVersion));
  });

  group('migrateLegacyDb (task 2.1, F-1)', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('dbmig'));
    tearDown(() => dir.delete(recursive: true));

    test('copies the cache DB and its journal, then deletes the old files',
        () async {
      final oldPath = p.join(dir.path, 'cache', dbFileName);
      final newPath = p.join(dir.path, 'databases', dbFileName);
      File(oldPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('db');
      File('$oldPath-journal').writeAsStringSync('j');

      expect(await DataBaseService.migrateLegacyDb(
              oldPath: oldPath, newPath: newPath),
          isTrue);
      expect(File(newPath).readAsStringSync(), 'db');
      expect(File('$newPath-journal').readAsStringSync(), 'j');
      expect(File(oldPath).existsSync(), isFalse);
      expect(File('$oldPath-journal').existsSync(), isFalse);
    });

    test('does nothing when the new DB already exists', () async {
      final oldPath = p.join(dir.path, 'old.db');
      final newPath = p.join(dir.path, 'new.db');
      File(oldPath).writeAsStringSync('old');
      File(newPath).writeAsStringSync('new');
      expect(await DataBaseService.migrateLegacyDb(
              oldPath: oldPath, newPath: newPath),
          isFalse);
      expect(File(newPath).readAsStringSync(), 'new');
      expect(File(oldPath).existsSync(), isTrue);
    });

    test('does nothing when there is no old DB', () async {
      expect(await DataBaseService.migrateLegacyDb(
              oldPath: p.join(dir.path, 'nope.db'),
              newPath: p.join(dir.path, 'new.db')),
          isFalse);
    });
  });
}
