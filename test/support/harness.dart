import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:invitation_edit_send/services/image_edit_model.dart';
import 'package:invitation_edit_send/ui/theme/app_theme.dart';

/// Wraps [child] in the app theme. [textScale] for the 200 % checks (5.4).
Widget host(Widget child, {double textScale = 1}) => MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    );

ImageEditModel card(
        {int row = 1, String name = 'Navchandi', int fields = 2}) =>
    ImageEditModel(
      rowNumber: row,
      fileName: name,
      imagePath: '/nonexistent/card.jpg',
      textNumber: '$fields',
      textCoordinate:
          '[${List.generate(fields, (i) => '{"x":10,"y":${10 + i * 20},"s":1.0}').join(',')}]',
      imageSize: '{"width":400,"height":600}',
      textColor: '{"r":255,"g":0,"b":0}',
      deleteImage: 0,
      updateDate: '2026-11-0${row % 9 + 1}',
    );

/// A valid 1x1 transparent PNG.
final Uint8List tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
