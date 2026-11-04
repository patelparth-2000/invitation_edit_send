import 'package:flutter/material.dart';

/// Brand seeds only (plan 5.1). Screens take every colour from
/// `Theme.of(context).colorScheme`, never from here directly.
abstract final class AppColors {
  /// Deep maroon.
  static const Color brandSeed = Color(0xFF8E1B3A);

  /// Marigold; becomes `colorScheme.tertiary`.
  static const Color accent = Color(0xFFE39B16);

  static const Color success = Color(0xFF2E7D32);

  /// Swatches offered for card text in the editor.
  static const List<Color> cardTextSwatches = [
    Color(0xFFD50000), // red (the historic default)
    Color(0xFF8E1B3A), // maroon
    Color(0xFFE39B16), // marigold
    Color(0xFFB8860B), // dark gold
    Color(0xFF1A237E), // navy
    Color(0xFF1B5E20), // green
    Color(0xFF000000), // black
    Color(0xFFFFFFFF), // white
  ];
}
