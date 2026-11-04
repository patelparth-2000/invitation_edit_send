import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invitation_edit_send/models/card_layout.dart';
import 'package:invitation_edit_send/models/guest.dart';
import 'package:invitation_edit_send/screen/image_send/image_send_screen.dart';
import 'package:invitation_edit_send/services/image_edit_model.dart';

import '../support/fake_db.dart';
import '../support/harness.dart';

/// Renderer stub: fails for guests whose first value is in [failFor].
class FakeRenderer implements GuestRenderer {
  FakeRenderer({this.failFor = const {}});
  final Set<String> failFor;
  final List<String> rendered = [];
  int begins = 0;

  @override
  Future<void> begin(ImageEditModel card) async => begins++;

  @override
  Future<({Uint8List? png, String pdfPath})> render(
      CardLayout layout, Guest guest,
      {bool png = false}) async {
    if (failFor.contains(guest.displayName)) throw StateError('bad guest');
    rendered.add(guest.displayName);
    return (png: png ? tinyPng : null, pdfPath: '/pdf/${guest.displayName}.pdf');
  }

  @override
  void end() {}
}

Widget screen(FakeDb db, {FakeRenderer? renderer, int fields = 2, double textScale = 1}) =>
    host(
        ImageSendScreen(
            imageEdit: card(fields: fields),
            dbService: db,
            renderer: renderer ?? FakeRenderer()),
        textScale: textScale);

void main() {
  testWidgets('empty state, then saved guests load (F-7)', (tester) async {
    await tester.pumpWidget(screen(FakeDb()));
    await tester.pumpAndSettle();
    expect(find.text('No guests yet'), findsOneWidget);

    final db = FakeDb(guests: const [
      Guest(id: 1, layoutId: 1, values: ['Asha', 'Surat']),
      Guest(id: 2, layoutId: 99, values: ['Other card']),
    ]);
    await tester.pumpWidget(Container());
    await tester.pumpWidget(screen(db));
    await tester.pumpAndSettle();
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Surat'), findsOneWidget);
    expect(find.text('Other card'), findsNothing);
    expect(find.text('Not created'), findsOneWidget);
    expect(find.text('Create all (1)'), findsOneWidget);
  });

  testWidgets('add: field 1 required; Save and add another keeps the sheet',
      (tester) async {
    final db = FakeDb();
    await tester.pumpWidget(screen(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add guest'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Field 1 is required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Ravi');
    await tester.tap(find.text('Save and add another'));
    await tester.pumpAndSettle();
    expect(find.text('1 added'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Mira');
    await tester.enterText(find.byType(TextFormField).at(1), 'Vadodara');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(db.guests.map((g) => g.values), [
      ['Ravi', ''],
      ['Mira', 'Vadodara'],
    ]);
    expect(find.text('Ravi'), findsOneWidget);
    expect(find.text('Mira'), findsOneWidget);
  });

  testWidgets('edit then dismiss neither throws nor changes (F-8)',
      (tester) async {
    final db = FakeDb(guests: const [
      Guest(id: 1, layoutId: 1, values: ['Asha', 'Surat']),
    ]);
    await tester.pumpWidget(screen(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Asha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Changed');
    // Dismiss the sheet without saving.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Asha'), findsOneWidget);
    expect(db.guests.single.values, ['Asha', 'Surat']);

    await tester.tap(find.text('Asha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Asha Patel');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Asha Patel'), findsOneWidget);
    expect(db.guests.single.values, ['Asha Patel', 'Surat']);
  });

  testWidgets('Create all: continues past a failure, records status, summary',
      (tester) async {
    final db = FakeDb(guests: const [
      Guest(id: 1, layoutId: 1, values: ['Asha']),
      Guest(id: 2, layoutId: 1, values: ['Bad']),
      Guest(id: 3, layoutId: 1, values: ['Ravi']),
    ]);
    final renderer = FakeRenderer(failFor: {'Bad'});
    await tester.pumpWidget(screen(db, renderer: renderer));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create all (3)'));
    await tester.pumpAndSettle();

    expect(renderer.rendered, ['Asha', 'Ravi']);
    expect(renderer.begins, 1); // background prepared once per run (P-3)
    expect(find.text('2 created, 1 failed'), findsOneWidget);
    expect(find.text('Retry failed (1)'), findsOneWidget);
    expect(find.text('Share all (2)'), findsOneWidget);
    expect(db.guests.map((g) => g.status), [
      GuestStatus.created,
      GuestStatus.failed,
      GuestStatus.created,
    ]);
    expect(db.guests.first.pdfPath, '/pdf/Asha.pdf');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Created'), findsNWidgets(2));
    expect(find.text('Failed'), findsOneWidget);
  });

  testWidgets('delete a guest can be undone', (tester) async {
    final db = FakeDb(guests: const [
      Guest(id: 1, layoutId: 1, values: ['Asha']),
    ]);
    await tester.pumpWidget(screen(db));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(db.guests, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(db.guests.single.values, ['Asha']);
    expect(find.text('Asha'), findsOneWidget);
  });

  testWidgets('a card with zero fields cannot take guests (F-13)',
      (tester) async {
    await tester.pumpWidget(screen(FakeDb(), fields: 0));
    await tester.pumpAndSettle();
    expect(find.text('This card has no fields'), findsOneWidget);
    expect(find.text('Add guest'), findsNothing);
  });

  testWidgets('no overflow at 200 % text', (tester) async {
    final db = FakeDb(guests: const [
      Guest(id: 1, layoutId: 1, values: ['Asha Patel', 'Surat, Gujarat']),
    ]);
    await tester.pumpWidget(screen(db, textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
