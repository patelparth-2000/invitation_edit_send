import 'dart:convert';
import 'dart:ui' show Color, Offset, Size;

import '../services/image_edit_model.dart';
import '../utils/common.dart' show FieldPaint;

/// One text placeholder on a card layout, exactly as it is stored in the
/// `text_coordinate` column.
///
/// Coordinates are in *editor preview* logical pixels (see [CardLayout.previewSize]).
///
/// The +2/-2 fudge (plan trap T-10) lives here and nowhere else: the editor
/// stores `dy - 2`, screens that place a widget at the slot add the 2 back
/// ([displayY]), and the renderer uses the stored value ([renderY]).
class TextSlot {
  const TextSlot({
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.color,
  });

  /// Builds a slot from a text box's on-screen position in the editor.
  factory TextSlot.fromEditor(double dx, double dy, double scale,
          {int? color}) =>
      TextSlot(x: dx, y: dy - yFudge, scale: scale, color: color);

  static const double yFudge = 2;

  final double x;
  final double y;

  /// Pinch scale set in the editor. Rows written before this field existed
  /// have no `s` key and decode as 1.0.
  final double scale;

  /// Per-field colour as 0xAARRGGBB. Null = use the layout colour
  /// ([CardLayout.color]); every row saved before this existed is null.
  final int? color;

  /// x as every reader has always used it (rounded).
  double get renderX => x.roundToDouble();

  /// y handed to the renderer (`addTextToImage`).
  double get renderY => y.roundToDouble();

  /// y at which a widget is positioned to sit where the editor showed it.
  double get displayY => y.roundToDouble() + yFudge;

  Map<String, num> toJson() =>
      {'x': x, 'y': y, 's': scale, if (color != null) 'c': color!};

  factory TextSlot.fromJson(Map<String, dynamic> json) => TextSlot(
        x: _toDouble(json['x']) ?? 0,
        y: _toDouble(json['y']) ?? 0,
        scale: _toDouble(json['s']) ?? 1.0,
        color: _toDouble(json['c'])?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is TextSlot &&
      other.x == x &&
      other.y == y &&
      other.scale == scale &&
      other.color == color;

  @override
  int get hashCode => Object.hash(x, y, scale, color);

  @override
  String toString() => 'TextSlot(x: $x, y: $y, scale: $scale, color: $color)';
}

/// The decoded form of an `image_edit_table` row's JSON columns.
class CardLayout {
  const CardLayout({
    required this.slots,
    required this.previewSize,
    required this.color,
  });

  final List<TextSlot> slots;

  /// Size of the image widget in the editor when the layout was saved.
  final Size previewSize;

  /// Text colour as 0-255 channels.
  final ({int r, int g, int b}) color;

  Color get flutterColor => Color.fromARGB(255, color.r, color.g, color.b);

  /// Colour of slot [i]: its own colour, else the layout colour.
  Color colorOf(int i) {
    final c = slots[i].color;
    return c != null ? Color(c) : flutterColor;
  }

  /// The fields filled with [values], placed exactly where the editor showed
  /// them (`Positioned(left: renderX, top: displayY)`).
  List<FieldPaint> fieldsWith(List<String> values) => [
        for (var i = 0; i < slots.length; i++)
          FieldPaint(
            text: i < values.length ? values[i] : '',
            topLeft: Offset(slots[i].renderX, slots[i].displayY),
            scale: slots[i].scale,
            color: colorOf(i),
          ),
      ];

  static String encodeSlots(List<TextSlot> slots) =>
      jsonEncode(slots.map((s) => s.toJson()).toList());

  static List<TextSlot> decodeSlots(String? json) {
    if (json == null || json.isEmpty) return const [];
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => TextSlot.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static String encodeSize(Size size) =>
      jsonEncode({'width': size.width, 'height': size.height});

  static Size decodeSize(String? json) {
    if (json == null || json.isEmpty) return Size.zero;
    final m = Map<String, dynamic>.from(jsonDecode(json) as Map);
    return Size(_toDouble(m['width']) ?? 0, _toDouble(m['height']) ?? 0);
  }

  static String encodeColor(int r, int g, int b) =>
      jsonEncode({'r': r, 'g': g, 'b': b});

  static ({int r, int g, int b}) decodeColor(String? json) {
    if (json == null || json.isEmpty) return (r: 255, g: 0, b: 0);
    final m = Map<String, dynamic>.from(jsonDecode(json) as Map);
    int ch(String k) => (_toDouble(m[k]) ?? 0).round().clamp(0, 255);
    return (r: ch('r'), g: ch('g'), b: ch('b'));
  }

  factory CardLayout.fromModel(ImageEditModel model) => CardLayout(
        slots: decodeSlots(model.textCoordinate),
        previewSize: decodeSize(model.imageSize),
        color: decodeColor(model.textColor),
      );
}

double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
