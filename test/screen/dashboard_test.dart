import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invitation_edit_send/models/guest.dart';
import 'package:invitation_edit_send/screen/dashboard/dashboard_screen.dart';

import '../support/fake_db.dart';
import '../support/harness.dart';

void main() {
  testWidgets('empty state on a fresh DB (U-1)', (tester) async {
    await tester.pumpWidget(host(DashboardScreen(dbService: FakeDb())));
    await tester.pumpAndSettle();
    expect(find.text('No invitations yet'), findsOneWidget);
    expect(find.text('New invitation'), findsOneWidget);
  });

  testWidgets('error state with Retry', (tester) async {
    final db = FakeDb(failLoad: true);
    await tester.pumpWidget(host(DashboardScreen(dbService: db)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load your invitations'),
        findsOneWidget);
    db.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No invitations yet'), findsOneWidget);
  });

  testWidgets('one card: name, field and guest counts; deleted hidden',
      (tester) async {
    final db = FakeDb(
      cards: [card(row: 1, fields: 2), card(row: 2, name: 'Old')..deleteImage = 1],
      guests: const [
        Guest(id: 1, layoutId: 1, values: ['a']),
        Guest(id: 2, layoutId: 1, values: ['b']),
      ],
    );
    await tester.pumpWidget(host(DashboardScreen(dbService: db)));
    await tester.pumpAndSettle();
    expect(find.text('Navchandi'), findsOneWidget);
    expect(find.text('2 fields · 2 guests'), findsOneWidget);
    expect(find.text('Old'), findsNothing);
  });

  testWidgets('rename: Cancel keeps the name, Rename saves (F-15)',
      (tester) async {
    final db = FakeDb(cards: [card()]);
    await tester.pumpWidget(host(DashboardScreen(dbService: db)));
    await tester.pumpAndSettle();

    Future<void> openRename() async {
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
    }

    await openRename();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(db.updates, isEmpty);

    await openRename();
    await tester.enterText(find.byType(TextField), 'Wedding');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Wedding'), findsOneWidget);
    expect(db.updates.single.fileName, 'Wedding');
  });

  testWidgets('delete asks first and can be undone (F-17)', (tester) async {
    final db = FakeDb(cards: [card()]);
    await tester.pumpWidget(host(DashboardScreen(dbService: db)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete invitation?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No invitations yet'), findsOneWidget);
    expect(db.cards.single.deleteImage, 1);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(db.cards.single.deleteImage, 0);
    expect(find.text('Navchandi'), findsOneWidget);
  });

  for (final cards in [0, 1]) {
    testWidgets('no overflow at 200 % text ($cards cards)', (tester) async {
      await tester.pumpWidget(host(
          DashboardScreen(
              dbService: FakeDb(cards: [if (cards == 1) card()])),
          textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
