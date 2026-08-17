// Smoke test for the invitation editor's root widget.
//
// This file previously held the untouched `flutter create` counter template — it
// asserted `find.text('0')` and tapped `Icons.add`, neither of which exists in this
// app. It had failed since the project was created and told you nothing about the
// invitation flow. Real coverage here is still effectively zero; this at least
// asserts something true about real code.
//
// The screens below the root all reach for SQLite, the file system or the camera,
// so they cannot be pumped without a harness. Testing those properly means
// injecting `DataBaseService` rather than constructing it inside each screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:invitation_edit_send/main.dart';

void main() {
  testWidgets('MyApp builds a GetMaterialApp with the expected configuration',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    final appFinder = find.byType(GetMaterialApp);
    expect(appFinder, findsOneWidget);

    final app = tester.widget<GetMaterialApp>(appFinder);
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.home, isNotNull);
    expect(app.theme?.useMaterial3, isTrue);
  });
}
