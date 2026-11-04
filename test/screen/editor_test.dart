import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:invitation_edit_send/models/card_layout.dart';
import 'package:invitation_edit_send/screen/image_edit/image_create_screen.dart';

import '../support/fake_db.dart';
import '../support/harness.dart';

void main() {
  late Directory dir;
  late String imagePath;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('editor');
    imagePath = '${dir.path}/card.png';
    File(imagePath).writeAsBytesSync(
        img.encodePng(img.Image(width: 400, height: 600)));
  });
  tearDownAll(() => dir.delete(recursive: true));

  /// Pumps the editor and lets the real file IO (image measuring) finish.
  Future<void> pumpEditor(WidgetTester tester, FakeDb db,
      {double textScale = 1}) async {
    await tester.pumpWidget(host(
        ImageCreateScreen(imagePath: imagePath, imageName: 'Navchandi', dbService: db),
        textScale: textScale));
    // Image measuring does real file IO and decoding: give it real time.
    for (var i = 0;
        i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'image never finished loading');
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(of: find.text('Save'), matching: find.byType(FilledButton)));

  Future<void> addField(WidgetTester tester, String text) async {
    await tester.tap(find.text('Add field'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
  }

  testWidgets('Save is disabled with zero fields (F-13)', (tester) async {
    await pumpEditor(tester, FakeDb());
    expect(find.text('Add field'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('add selects the field; size, colour, delete + undo',
      (tester) async {
    await pumpEditor(tester, FakeDb());
    await addField(tester, 'Guest name');

    expect(find.text('Guest name'), findsOneWidget);
    // Selected: the toolbar shows field tools.
    expect(find.text('Edit text'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);

    // Size slider mirrors pinch.
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();
    final size = tester.widget<Text>(find.text('Guest name')).style!.fontSize!;
    expect(size, greaterThan(8));

    // Colour.
    await tester.tap(find.text('Colour'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Navy'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('Guest name')).style!.color,
        const Color(0xFF1A237E));

    // Delete with Undo.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Guest name'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Guest name'), findsOneWidget);
  });

  testWidgets('Save stores scale and colour per field (F-3, F-6)',
      (tester) async {
    final db = FakeDb();
    await pumpEditor(tester, db);
    await addField(tester, 'Guest name');
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();
    await tester.tap(find.text('Colour'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Navy'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = db.inserts.single;
    final slot = CardLayout.decodeSlots(saved.textCoordinate).single;
    expect(slot.scale, greaterThan(1));
    expect(slot.color, 0xFF1A237E);
    // T-10: stored y is the on-screen y minus 2.
    expect(slot.y, 48);
    expect(jsonDecode(saved.imageSize!), isA<Map>());
    expect(saved.fileName, 'Navchandi');
    // Save goes on to the guests screen (plan 5.2).
    expect(find.text('No guests yet'), findsOneWidget);
  });

  testWidgets('no overflow at 200 % text', (tester) async {
    await pumpEditor(tester, FakeDb(), textScale: 2);
    await addField(tester, 'Guest name');
    expect(tester.takeException(), isNull);
  });
}
