import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:translator/translator.dart';

Future<Uint8List> loadAssetImageAsUint8List(String assetPath) async {
  ByteData byteData = await rootBundle.load(assetPath);
  return byteData.buffer.asUint8List();
}

Future<Uint8List> loadImageFromFile(String filePath) async {
  File file = File(filePath);
  return await file.readAsBytes();
}

Future<Uint8List> loadNetworkImageAsUint8List(String url) async {
  http.Response response = await http.get(Uri.parse(url));
  return response.bodyBytes;
}

class TextData {
  String text;
  double dx;
  double dy;
  double scale;

  TextData(this.text, this.dx, this.dy, this.scale);
}

Future<img.BitmapFont> loadBitmapFont(String fntPath, String imagePath) async {
  // Load the .fnt file as a string
  String fntData = await rootBundle.loadString(fntPath);

  // Load the font image as a Uint8List
  Uint8List imageBytes = await rootBundle
      .load(imagePath)
      .then((data) => data.buffer.asUint8List());
  img.Image fontImage = img.decodeImage(imageBytes)!;

  // Create a BitmapFont from the fnt data and image
  return img.BitmapFont.fromFnt(fntData, fontImage);
}

Future<img.BitmapFont> loadBitmapFontFromZip(String zipPath) async {
  // Load the zip file as bytes
  final ByteData data = await rootBundle.load(zipPath);
  final List<int> bytes = data.buffer.asUint8List();

  // Load the BitmapFont from the zip bytes
  img.BitmapFont font = img.BitmapFont.fromZip(bytes);
  return font;
}

/// The bitmap font every export is rendered with.
///
/// KNOWN LIMITATION — Gujarati cannot be burned into a card.
/// This is a **Latin-only** bitmap font. `img.BitmapFont.fromZip` consumes a
/// pre-rasterised ZIP, not a TTF, so `fonts/NotoSerifGujarati-VariableFont_wght.ttf`
/// cannot be used here — it is registered in pubspec.yaml and therefore applies to
/// Flutter *widgets* only. Every character outside this font's atlas renders as
/// nothing in the exported image and PDF.
///
/// That matters because this app ships Gujarati fonts, a `translator` dependency and
/// a drafted Gujarati greeting, so it was plainly built for a Gujarati event — and
/// the export path is the one place that cannot serve it.
///
/// Two ways out, neither a small edit:
///   1. Rasterise NotoSerifGujarati into a bitmap-font ZIP (BMFont/Hiero) and load it
///      here. Cheapest, but one fixed size and one script per atlas.
///   2. Stop using `img.drawString` and render text with Flutter's own engine
///      (`ui.ParagraphBuilder` + `ui.Canvas` -> `ui.Image`), then composite that.
///      Handles any TTF, any size and complex scripts properly. This is the real fix.
Future<ByteData> loadAssetFont() async {
  ByteData imageData = await rootBundle
      .load("fonts/font_zip/PlaywriteIN-VariableFont_wght.ttf (2).zip");
  return imageData;
}

Future<String> translateText(String locale, String text) async {
  String translatorText = "";
  final translator = GoogleTranslator();
  await translator.translate(text, to: locale).then((value) {
    translatorText = value.text;
  });
  return translatorText;
}

Future<Size?> getImageSize(String imagePath) async {
  Uint8List imageBytes = await loadImageFromFile(imagePath);

  var image = img.decodeImage(imageBytes);
  if (image == null) return null;

  // Actual image dimensions
  int actualImageWidth = image.width;
  int actualImageHeight = image.height;
  return Size(actualImageWidth.toDouble(), actualImageHeight.toDouble());
}

Future<String> addTextToImage(
  String? imagePath,
  List<TextData> textDataList,
  Size previewSize,
  num r,
  num g,
  num b,
) async {
  String editedImage = "";
  Uint8List imageBytes;
  if (imagePath != null && imagePath != "") {
    imageBytes = await loadImageFromFile(imagePath);
  } else {
    imageBytes =
        await loadAssetImageAsUint8List('assets/images/invitetion_card.jpg');
  }

  ByteData fBitMapFontData = await loadAssetFont();
  img.BitmapFont customFont =
      img.BitmapFont.fromZip(fBitMapFontData.buffer.asUint8List());

  var image = img.decodeImage(imageBytes);
  if (image == null) return "";

  // Actual image dimensions
  int actualImageWidth = image.width;
  int actualImageHeight = image.height;

  // UI image dimensions (previously obtained)
  double uiImageWidth = previewSize.width;
  double uiImageHeight = previewSize.height;

  // Calculate scaling factors
  double scaleX = actualImageWidth / uiImageWidth;
  double scaleY = actualImageHeight / uiImageHeight;

  for (var textData in textDataList) {
    // Scale the positions accurately
    int adjustedX = (textData.dx * scaleX).toInt();
    int adjustedY = (textData.dy * scaleY).toInt();

    // TextData.scale is what the user set by pinch-resizing in the editor
    // (image_create_screen.dart). It used to be ignored entirely here: drawString
    // renders a FIXED-SIZE bitmap font, so every export came out at one size and the
    // PDF never matched the preview.
    //
    // The bitmap font cannot be re-sized directly, so the text is drawn onto its own
    // transparent layer, trimmed to its actual bounds, then composited at
    // scale * scaleX. scaleX is used for both axes so the glyphs keep their aspect
    // ratio — scaleX and scaleY differ whenever the preview box is not exactly the
    // image's aspect ratio, and using each independently would stretch the text.
    final double renderScale = textData.scale * scaleX;

    // Generous layer; trimmed to the real glyph bounds immediately after drawing.
    final int layerW = (textData.text.length + 2) * customFont.lineHeight;
    final int layerH = customFont.lineHeight * 3;

    var textLayer = img.Image(
      width: layerW < 1 ? 1 : layerW,
      height: layerH < 1 ? 1 : layerH,
      numChannels: 4,
    );

    img.drawString(
      textLayer,
      textData.text,
      font: customFont,
      x: 0,
      y: 0,
      color: img.ColorFloat32.rgb(r, g, b),
      maskChannel: img.Channel.red,
    );

    textLayer = img.trim(textLayer, mode: img.TrimMode.transparent);

    final int dstW = (textLayer.width * renderScale).round();
    final int dstH = (textLayer.height * renderScale).round();

    if (dstW > 0 && dstH > 0) {
      img.compositeImage(
        image,
        textLayer,
        dstX: adjustedX,
        dstY: adjustedY,
        dstW: dstW,
        dstH: dstH,
      );
    }
  }

  var editedImageBytes = img.encodePng(image, level: 0);
  editedImage = await convertBackImage(editedImageBytes);
  return editedImage;
}

Future<File> saveImage(Uint8List imageBytes, String filePath) async {
  File file = File(filePath);
  await file.writeAsBytes(imageBytes);
  return file;
}

Future<String> convertBackImage(Uint8List editedImageBytes) async {
  var documentDirectory = await getApplicationDocumentsDirectory();
  String timestamp = "${DateTime.timestamp()}";
  File file = File("");
  // Save as PNG
  file = await saveImage(
      editedImageBytes, '${documentDirectory.path}/${timestamp}_image.png');
  // Or save as JPG
  await saveImage(
      editedImageBytes, '${documentDirectory.path}/${timestamp}_image.jpg');
  return file.path;
}

Future<String> createPdf(String imagePath, String name) async {
  final document = PdfDocument();
  document.pageSettings.setMargins(0);
  // Create a new page without margins (full size)
  final PdfPage page = document.pages.add();

  // Get the page dimensions
  final double pdfWidth = page.getClientSize().width;
  final double pdfHeight = page.getClientSize().height;

  // Load the image
  final File image = File(imagePath);
  final imageBytes = image.readAsBytesSync();
  final PdfBitmap bitmap = PdfBitmap(imageBytes);

  // Image dimensions
  final double imageOriginalWidth = bitmap.width.toDouble();
  final double imageOriginalHeight = bitmap.height.toDouble();

  // Define border margin
  const double borderMargin = 10.0;

  // Scale image to fit full PDF width (minus margins)
  final double scaledImageWidth = pdfWidth - (2 * borderMargin);
  final double scaledImageHeight =
      (imageOriginalHeight / imageOriginalWidth) * scaledImageWidth;

  // Center image vertically
  final double xOffset = borderMargin; // Leave space for left margin
  final double yOffset =
      (pdfHeight - scaledImageHeight - (2 * borderMargin)) / 2;

  // Draw the light blue border rectangle
  page.graphics.drawRectangle(
    bounds: Rect.fromLTWH(
        xOffset - borderMargin,
        yOffset - borderMargin,
        scaledImageWidth + (2 * borderMargin),
        scaledImageHeight + (2 * borderMargin)),
    pen: PdfPen(PdfColor(173, 216, 230)), // Light blue color
  );

  // Draw the image
  page.graphics.drawImage(
    bitmap,
    Rect.fromLTWH(xOffset, yOffset, scaledImageWidth, scaledImageHeight),
  );

  // final outputDir = await getApplicationDocumentsDirectory();
  // Save the PDF
  final file = File(
      "/storage/emulated/0/Download/${name.toLowerCase().replaceAll(" ", "_")}.pdf");
  await file.writeAsBytes(await document.save());
  document.dispose();

  print("PDF saved at ${file.path}");

  return file.path;
}

void saveTextData(
    String text, double x, double y, double width, double height) {}
