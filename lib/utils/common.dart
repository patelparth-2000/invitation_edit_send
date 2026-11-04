import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Fallback background used when a card has no picked image.
/// The filename is misspelled on purpose (plan trap T-6): it is the real asset name.
const String fallbackCardAsset = 'assets/images/invitetion_card.jpg';

// ---------------------------------------------------------------------------
// Card text style: ONE definition shared by the editor, the previews and the
// exporter, so what the owner designs is what gets burned in (F-4, F-5).
// ---------------------------------------------------------------------------

/// Font family of text on a card. Latin glyphs come from PlaywriteIN; any
/// character it lacks (Gujarati) falls back to the bundled Noto Serif Gujarati.
const String cardFontFamily = 'PlaywriteIN';
const List<String> cardFontFallback = ['NotoSerif'];

/// Editor font size of a field at scale 1, in preview logical pixels.
const double fieldBaseFontSize = 8;

/// Value stored in the `font_type` column for layouts saved by this version.
const String cardFontTypeId = 'flutter:PlaywriteIN+NotoSerif';

/// Style of a field at [scale]. [pixelScale] converts preview pixels to output
/// pixels (1 in the editor; imageWidth / previewWidth when exporting).
TextStyle cardFieldStyle({
  required double scale,
  required Color color,
  double pixelScale = 1,
}) =>
    TextStyle(
      fontFamily: cardFontFamily,
      fontFamilyFallback: cardFontFallback,
      fontWeight: FontWeight.bold,
      fontSize: fieldBaseFontSize * scale * pixelScale,
      color: color,
    );

/// One field to draw, positioned exactly where the editor shows it:
/// [topLeft] is the `Positioned(left:, top:)` of the field's Text widget, in
/// preview logical pixels.
@immutable
class FieldPaint {
  const FieldPaint({
    required this.text,
    required this.topLeft,
    required this.scale,
    required this.color,
  });

  final String text;
  final Offset topLeft;
  final double scale;
  final Color color;
}

/// A decoded card background as raw RGBA, ready to be shipped to an isolate.
@immutable
class DecodedCard {
  const DecodedCard(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final Uint8List rgba;

  img.Image toImage() => img.Image.fromBytes(
        width: width,
        height: height,
        bytes: Uint8List.fromList(rgba).buffer,
        numChannels: 4,
      );
}

/// One rasterised field: straight-alpha RGBA placed at ([x], [y]) in the card.
@immutable
class RasterLayer {
  const RasterLayer(this.rgba, this.width, this.height, this.x, this.y);
  final Uint8List rgba;
  final int width;
  final int height;
  final int x;
  final int y;
}

Future<Uint8List> loadAssetImageAsUint8List(String assetPath) async {
  final ByteData byteData = await rootBundle.load(assetPath);
  return byteData.buffer.asUint8List();
}

Future<Uint8List> loadImageFromFile(String filePath) =>
    File(filePath).readAsBytes();

Future<Uint8List> _loadCardBytes(String? imagePath) =>
    (imagePath != null && imagePath.isNotEmpty)
        ? loadImageFromFile(imagePath)
        : loadAssetImageAsUint8List(fallbackCardAsset);

/// Decodes without throwing (package:image throws on some corrupt input).
img.Image? safeDecode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}

/// Pure: decode [bytes] to RGBA, optionally downscaled so the width is at most
/// [maxWidth]. Runs inside an isolate.
DecodedCard? decodeCardBytes(Uint8List bytes, {int? maxWidth}) {
  var image = safeDecode(bytes);
  if (image == null) return null;
  if (maxWidth != null && image.width > maxWidth) {
    image = img.copyResize(image, width: maxWidth);
  }
  final rgba = image.convert(numChannels: 4, format: img.Format.uint8);
  return DecodedCard(
      rgba.width, rgba.height, rgba.getBytes(order: img.ChannelOrder.rgba));
}

/// Reads and decodes a card background off the UI isolate.
/// Throws [FormatException] when the image cannot be decoded.
Future<DecodedCard> decodeCard(String? imagePath, {int? maxWidth}) async {
  final bytes = await _loadCardBytes(imagePath);
  final card =
      await Isolate.run(() => decodeCardBytes(bytes, maxWidth: maxWidth));
  if (card == null) {
    throw const FormatException('The card image could not be opened.');
  }
  return card;
}

Future<Size?> getImageSize(String imagePath) async {
  final Uint8List imageBytes = await loadImageFromFile(imagePath);
  final dims = await Isolate.run(() {
    final image = safeDecode(imageBytes);
    return image == null ? null : (image.width, image.height);
  });
  if (dims == null) return null;
  return Size(dims.$1.toDouble(), dims.$2.toDouble());
}

/// Rasterises [fields] with Flutter's text engine (any font, any script),
/// scaled from [previewSize] to an output of [outWidth] x [outHeight].
/// Must run on the root isolate (`dart:ui` painting).
Future<List<RasterLayer>> rasteriseFields(
  List<FieldPaint> fields,
  Size previewSize,
  int outWidth,
  int outHeight,
) async {
  if (previewSize.width <= 0 || previewSize.height <= 0) return const [];
  final double sx = outWidth / previewSize.width;
  final double sy = outHeight / previewSize.height;
  final layers = <RasterLayer>[];
  for (final f in fields) {
    if (f.text.isEmpty) continue;
    final painter = TextPainter(
      text: TextSpan(
          text: f.text,
          style: cardFieldStyle(scale: f.scale, color: f.color, pixelScale: sx)),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    // Script fonts draw outside their line box; pad so nothing is clipped.
    final int pad = (painter.preferredLineHeight * 0.5).ceil();
    final int w = painter.width.ceil() + 2 * pad;
    final int h = painter.height.ceil() + 2 * pad;
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), Offset(pad.toDouble(), pad.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    image.dispose();
    picture.dispose();
    painter.dispose();
    if (data == null) continue;
    layers.add(RasterLayer(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      w,
      h,
      (f.topLeft.dx * sx).round() - pad,
      (f.topLeft.dy * sy).round() - pad,
    ));
  }
  return layers;
}

/// Pure: composites [layers] onto a copy of [base].
img.Image composeCard(DecodedCard base, List<RasterLayer> layers) {
  final image = base.toImage();
  for (final l in layers) {
    final layer = img.Image.fromBytes(
      width: l.width,
      height: l.height,
      bytes: Uint8List.fromList(l.rgba).buffer,
      numChannels: 4,
    );
    img.compositeImage(image, layer, dstX: l.x, dstY: l.y);
  }
  return image;
}

/// What a render produced. Either may be null if it was not requested.
@immutable
class RenderedCard {
  const RenderedCard({this.png, this.pdf});
  final Uint8List? png;
  final Uint8List? pdf;
}

/// Renders one card: text rasterised here, composite + encode (+ PDF) on a
/// background isolate. Nothing is written to disk.
///
/// [base] can be decoded once and reused for every guest of a run (P-3).
Future<RenderedCard> renderCard(
  DecodedCard base,
  List<FieldPaint> fields,
  Size previewSize, {
  bool png = true,
  bool pdf = false,
}) async {
  final layers =
      await rasteriseFields(fields, previewSize, base.width, base.height);
  return Isolate.run(() {
    final image = composeCard(base, layers);
    // PNG level 6: much smaller than the old uncompressed level 0 (P-2).
    final pngBytes = img.encodePng(image, level: 6);
    return RenderedCard(
      png: png ? pngBytes : null,
      pdf: pdf ? buildPdfBytesSync(pngBytes) : null,
    );
  });
}

/// Copies a picked image into `<documents>/cards/` so it survives the system
/// clearing the app cache, where `image_picker` leaves it (F-2).
Future<String> persistPickedImage(String sourcePath,
    {Directory? documentsDir}) async {
  final docs = documentsDir ?? await getApplicationDocumentsDirectory();
  final cardsDir = Directory(p.join(docs.path, 'cards'));
  await cardsDir.create(recursive: true);
  if (p.isWithin(cardsDir.path, sourcePath)) return sourcePath;
  final ext = p.extension(sourcePath);
  final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
  final copy = await File(sourcePath).copy(p.join(cardsDir.path, name));
  return copy.path;
}

// ---------------------------------------------------------------------------
// PDF
// ---------------------------------------------------------------------------

const int _maxPdfNameLength = 80;

/// Task 3.4 / F-9: a safe, unique PDF base name (no extension).
///
/// Strips `\ / : * ? " < > |` and control characters, trims, caps the length
/// at 80, falls back to `invitation`, and de-duplicates against [taken]
/// (case-insensitive) as `name (2)`, `name (3)`, ... Non-Latin text such as
/// Gujarati is kept.
String safePdfName(String raw, Set<String> taken) {
  var name = raw
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // No leading dots (hidden files, "." and "..").
  name = name.replaceFirst(RegExp(r'^\.+'), '').trim();
  if (name.length > _maxPdfNameLength) {
    name = name.substring(0, _maxPdfNameLength).trim();
  }
  if (name.isEmpty) name = 'invitation';
  final lower = {for (final t in taken) t.toLowerCase()};
  if (!lower.contains(name.toLowerCase())) return name;
  for (var n = 2;; n++) {
    final candidate = '$name ($n)';
    if (!lower.contains(candidate.toLowerCase())) return candidate;
  }
}

/// Where PDFs are written (decision D-4(c)): an app-private folder, shared
/// through the system share sheet. Needs no storage permission on any version.
Future<Directory> pdfOutputDir({Directory? documentsDir}) async {
  final docs = documentsDir ?? await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'invitations'));
  await dir.create(recursive: true);
  return dir;
}

/// Base names (without `.pdf`) already present in [dir].
Set<String> existingPdfNames(Directory dir) => {
      for (final f in dir.listSync().whereType<File>())
        if (p.extension(f.path).toLowerCase() == '.pdf')
          p.basenameWithoutExtension(f.path),
    };

/// Largest rect with the image's aspect ratio that fits inside [page] minus
/// [margin] on every side, centred on both axes (F-18).
Rect fitImageOnPage(Size image, Size page, double margin) {
  final double maxW = page.width - 2 * margin;
  final double maxH = page.height - 2 * margin;
  if (image.width <= 0 || image.height <= 0 || maxW <= 0 || maxH <= 0) {
    return Rect.zero;
  }
  final double scale = (maxW / image.width) < (maxH / image.height)
      ? maxW / image.width
      : maxH / image.height;
  final double w = image.width * scale;
  final double h = image.height * scale;
  return Rect.fromLTWH((page.width - w) / 2, (page.height - h) / 2, w, h);
}

/// Pure: one A4 page with [imageBytes] fitted and a light-blue border.
Uint8List buildPdfBytesSync(Uint8List imageBytes) {
  final document = PdfDocument();
  try {
    document.pageSettings.setMargins(0);
    final PdfPage page = document.pages.add();
    final Size pageSize = page.getClientSize();
    final PdfBitmap bitmap = PdfBitmap(imageBytes);
    const double borderMargin = 10.0;
    final Rect imageRect = fitImageOnPage(
      Size(bitmap.width.toDouble(), bitmap.height.toDouble()),
      pageSize,
      borderMargin,
    );
    page.graphics.drawRectangle(
      bounds: imageRect.inflate(borderMargin),
      pen: PdfPen(PdfColor(173, 216, 230)),
    );
    page.graphics.drawImage(bitmap, imageRect);
    return Uint8List.fromList(document.saveSync());
  } finally {
    document.dispose();
  }
}

/// Writes [pdfBytes] as `<safe name>.pdf` in [dir] (the app PDF folder by
/// default) without overwriting anything. Returns the file path.
Future<String> writePdf(Uint8List pdfBytes, String name,
    {Directory? dir}) async {
  final outDir = dir ?? await pdfOutputDir();
  final base = safePdfName(name, existingPdfNames(outDir));
  final file = File(p.join(outDir.path, '$base.pdf'));
  await file.writeAsBytes(pdfBytes, flush: true);
  debugPrint('PDF saved at ${file.path}');
  return file.path;
}
