import 'package:flutter/material.dart';

/// UI typography (plan 5.1). Card *content* fonts live in
/// `lib/utils/common.dart` (`cardFieldStyle`) and are separate from these.
abstract final class AppText {
  static const String uiFamily = 'Nunito';

  /// Registered Gujarati face, so Gujarati in the UI renders.
  static const List<String> uiFallback = ['NotoSerif'];

  static TextTheme apply(TextTheme base) => base.apply(
        fontFamily: uiFamily,
        fontFamilyFallback: uiFallback,
      );
}
