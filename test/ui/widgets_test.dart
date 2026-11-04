import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invitation_edit_send/ui/theme/app_theme.dart';
import 'package:invitation_edit_send/ui/widgets/busy_button.dart';
import 'package:invitation_edit_send/ui/widgets/card_canvas.dart';
import 'package:invitation_edit_send/ui/widgets/dialogs.dart';
import 'package:invitation_edit_send/ui/widgets/states.dart';

import '../support/harness.dart';

void main() {
  test('AppTheme: M3, light and dark, maroon seed, marigold tertiary', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    expect(light.useMaterial3, isTrue);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.tertiary, const Color(0xFFE39B16));
    expect(light.appBarTheme.centerTitle, isFalse);
  });

  testWidgets('EmptyState shows title, message and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(Scaffold(
      body: EmptyState(
        icon: Icons.mail_outline,
        title: 'No invitations yet',
        message: 'Start here.',
        actionLabel: 'New invitation',
        onAction: () => tapped = true,
      ),
    )));
    expect(find.text('No invitations yet'), findsOneWidget);
    expect(find.text('Start here.'), findsOneWidget);
    await tester.tap(find.text('New invitation'));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorState retries', (tester) async {
    var retried = 0;
    await tester.pumpWidget(host(Scaffold(
        body: ErrorState(message: 'Boom', onRetry: () => retried++))));
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('ConfirmDialog resolves true/false', (tester) async {
    bool? result;
    await tester.pumpWidget(host(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => result = await ConfirmDialog.show(context,
              title: 'Delete?', message: 'Sure?', confirmLabel: 'Delete',
              destructive: true),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('TextPromptDialog: OK disabled when empty, Cancel -> null',
      (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(host(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => result =
              await TextPromptDialog.show(context, title: 'Name', initial: ''),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final ok = find.widgetWithText(FilledButton, 'OK');
    expect(tester.widget<FilledButton>(ok).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  Ravi  ');
    await tester.pump();
    expect(tester.widget<FilledButton>(ok).onPressed, isNotNull);
    await tester.tap(ok);
    await tester.pumpAndSettle();
    expect(result, 'Ravi');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('BusyButton disables itself while running (F-12)',
      (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(host(Scaffold(
      body: BusyButton(
        label: 'Save',
        busyLabel: 'Saving…',
        onPressed: () {
          calls++;
          return gate.future;
        },
      ),
    )));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    await tester.tap(find.text('Saving…'));
    await tester.pump();
    expect(calls, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
  });

  group('CardCanvas (task 4.3)', () {
    Widget canvas({
      Size? designSize,
      ValueChanged<Size>? onLaidOut,
      ValueChanged<int>? onSelect,
      double scale = 1,
    }) =>
        host(Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: CardCanvas(
                image: MemoryImage(tinyPng),
                imageSize: const Size(200, 100), // 2:1 -> shown 400x200
                designSize: designSize,
                slots: [
                  SlotView(
                      text: 'Ravi',
                      topLeft: const Offset(20, 10),
                      scale: scale,
                      color: Colors.red),
                ],
                onLaidOut: onLaidOut,
                onSelect: onSelect,
              ),
            ),
          ),
        ));

    testWidgets('reports its fitted size', (tester) async {
      Size? reported;
      await tester.pumpWidget(canvas(onLaidOut: (s) => reported = s));
      await tester.pump();
      expect(reported, const Size(400, 200));
    });

    testWidgets('positions and sizes slots in design coordinates',
        (tester) async {
      // Designed at 200x100, shown at 400x200 -> everything doubles.
      await tester.pumpWidget(canvas(designSize: const Size(200, 100)));
      final canvasBox = tester.getTopLeft(find.byType(CardCanvas));
      final shownLeft = canvasBox.dx; // width fills the 400 box
      final shownTop = canvasBox.dy + 100; // centred vertically
      final text = tester.getTopLeft(find.text('Ravi'));
      expect(text.dx - shownLeft, closeTo(40, 0.5));
      expect(text.dy - shownTop, closeTo(20, 0.5));
      final style = tester.widget<Text>(find.text('Ravi')).style!;
      expect(style.fontSize, closeTo(8 * 2, 1e-9));
      expect(style.color, Colors.red);
    });

    testWidgets('font size follows the slot scale', (tester) async {
      await tester.pumpWidget(canvas(scale: 2.5));
      expect(tester.widget<Text>(find.text('Ravi')).style!.fontSize,
          closeTo(20, 1e-9));
    });

    testWidgets('tapping a slot selects it, the background clears',
        (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(canvas(onSelect: taps.add));
      await tester.tap(find.text('Ravi'));
      await tester.tapAt(tester.getBottomRight(find.byType(CardCanvas)) -
          const Offset(5, 105));
      expect(taps, [0, -1]);
    });
  });
}
