import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:invitation_edit_send/utils/common.dart';

/// Bounding box of pixels that differ from pure white.
({int left, int top, int width, int height})? inkBox(img.Image image) {
  int? minX, minY, maxX, maxY;
  for (final px in image) {
    if (px.r < 230 || px.g < 230 || px.b < 230) {
      minX = minX == null || px.x < minX ? px.x : minX;
      minY = minY == null || px.y < minY ? px.y : minY;
      maxX = maxX == null || px.x > maxX ? px.x : maxX;
      maxY = maxY == null || px.y > maxY ? px.y : maxY;
    }
  }
  if (minX == null) return null;
  return (
    left: minX,
    top: minY!,
    width: maxX! - minX + 1,
    height: maxY! - minY + 1
  );
}

Future<void> loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}

DecodedCard whiteCard(int w, int h) {
  final image = img.Image(width: w, height: h, numChannels: 4)
    ..clear(img.ColorRgba8(255, 255, 255, 255));
  return DecodedCard(w, h, image.getBytes(order: img.ChannelOrder.rgba));
}

const red = ui.Color(0xFFFF0000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadFont('PlaywriteIN', 'fonts/PlaywriteIN-VariableFont_wght.ttf');
    await loadFont('NotoSerif', 'fonts/NotoSerifGujarati-VariableFont_wght.ttf');
  });

  group('safePdfName (task 3.4, F-9)', () {
    test('keeps an ordinary name as typed', () {
      expect(safePdfName('Asha Patel', {}), 'Asha Patel');
    });
    test('strips path separators and illegal characters', () {
      expect(safePdfName('A/B\\C:D*E?"F<G>H|', {}), 'ABCDEFGH');
      expect(safePdfName('../../etc', {}), 'etc');
    });
    test('falls back to "invitation" when nothing is left', () {
      expect(safePdfName('', {}), 'invitation');
      expect(safePdfName('  //  ', {}), 'invitation');
    });
    test('caps length at 80', () {
      expect(safePdfName('x' * 300, {}).length, 80);
    });
    test('de-duplicates as "name (2)", case-insensitively', () {
      expect(safePdfName('Ravi', {'ravi'}), 'Ravi (2)');
      expect(safePdfName('Ravi', {'Ravi', 'Ravi (2)'}), 'Ravi (3)');
    });
    test('keeps Gujarati', () {
      expect(safePdfName('આશા પટેલ', {}), 'આશા પટેલ');
    });
  });

  group('fitImageOnPage (task 3.5, F-18)', () {
    const a4 = ui.Size(595, 842);
    test('wide image fills the width and is centred vertically', () {
      final r = fitImageOnPage(const ui.Size(2000, 1000), a4, 10);
      expect(r.width, closeTo(575, 1e-9));
      expect(r.top, closeTo((842 - 287.5) / 2, 1e-9));
    });
    test('tall image fits the page height and is not clipped', () {
      final r = fitImageOnPage(const ui.Size(1000, 3000), a4, 10);
      expect(r.height, closeTo(822, 1e-9));
      expect(r.top, closeTo(10, 1e-9));
      expect(r.bottom, lessThanOrEqualTo(832 + 1e-9));
    });
  });

  test('buildPdfBytesSync: one page, starts with %PDF, tall image ok', () {
    final png = img.encodePng(img.Image(width: 300, height: 1200));
    final bytes = buildPdfBytesSync(png);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });

  group('rendering with Flutter text (task 3.9)', () {
    test('Latin text lands at the scaled editor position', () async {
      // Preview 400x300 -> output 800x600: scale 2.
      final out = await renderCard(
        whiteCard(800, 600),
        const [
          FieldPaint(
              text: 'Hello', topLeft: ui.Offset(50, 40), scale: 2, color: red)
        ],
        const ui.Size(400, 300),
      );
      final box = inkBox(img.decodePng(out.png!)!)!;
      // Ink starts close to (100, 80); script glyphs may lean a little left.
      expect(box.left, inInclusiveRange(90, 115));
      expect(box.top, inInclusiveRange(76, 110));
    });

    test('Gujarati produces ink (it used to render as nothing)', () async {
      final out = await renderCard(
        whiteCard(400, 300),
        const [
          FieldPaint(
              text: 'આશા પટેલ', topLeft: ui.Offset(10, 10), scale: 3, color: red)
        ],
        const ui.Size(400, 300),
      );
      final box = inkBox(img.decodePng(out.png!)!);
      expect(box, isNotNull);
      expect(box!.width, greaterThan(20));
    });

    test('text height follows 8 * scale * pixelScale like the editor', () async {
      Future<int> heightAt(double scale) async {
        final out = await renderCard(
          whiteCard(800, 600),
          [
            FieldPaint(
                text: 'HHHH',
                topLeft: const ui.Offset(10, 10),
                scale: scale,
                color: red)
          ],
          const ui.Size(400, 300),
        );
        return inkBox(img.decodePng(out.png!)!)!.height;
      }

      final h1 = await heightAt(1);
      final h3 = await heightAt(3);
      expect(h3 / h1, closeTo(3, 0.6));
    });

    test('colour is the field colour', () async {
      final out = await renderCard(
        whiteCard(200, 100),
        const [
          FieldPaint(
              text: 'IIII',
              topLeft: ui.Offset(10, 10),
              scale: 4,
              color: ui.Color(0xFF0000FF))
        ],
        const ui.Size(200, 100),
      );
      final image = img.decodePng(out.png!)!;
      final bluish = image.where((p) => p.b > 200 && p.r < 60 && p.g < 60);
      expect(bluish, isNotEmpty);
      expect(image.where((p) => p.r > 200 && p.g < 60 && p.b < 60), isEmpty);
    });

    test('empty text draws nothing; PDF can be produced in the isolate',
        () async {
      final out = await renderCard(
        whiteCard(200, 100),
        const [
          FieldPaint(text: '', topLeft: ui.Offset(1, 1), scale: 1, color: red)
        ],
        const ui.Size(200, 100),
        png: true,
        pdf: true,
      );
      expect(inkBox(img.decodePng(out.png!)!), isNull);
      expect(String.fromCharCodes(out.pdf!.take(5)), '%PDF-');
    });
  });

  test('decodeCardBytes: corrupt input returns null, downscale works', () {
    expect(decodeCardBytes(Uint8List.fromList([1, 2, 3])), isNull);
    final jpg = img.encodeJpg(img.Image(width: 2000, height: 1000));
    final card = decodeCardBytes(jpg, maxWidth: 500)!;
    expect(card.width, 500);
    expect(card.height, 250);
    expect(card.rgba.length, 500 * 250 * 4);
  });

  test('writePdf never overwrites', () async {
    final dir = await Directory.systemTemp.createTemp('pdfout');
    addTearDown(() => dir.delete(recursive: true));
    final bytes = Uint8List.fromList([37, 80, 68, 70]);
    final a = await writePdf(bytes, 'Asha', dir: dir);
    final b = await writePdf(bytes, 'asha', dir: dir);
    expect(a, endsWith('/Asha.pdf'));
    expect(b, endsWith('/asha (2).pdf'));
  });

  test('persistPickedImage copies into documents/cards', () async {
    final docs = await Directory.systemTemp.createTemp('docs');
    final cache = await Directory.systemTemp.createTemp('cache');
    addTearDown(() async {
      await docs.delete(recursive: true);
      await cache.delete(recursive: true);
    });
    final src = File('${cache.path}/picked.jpg')..writeAsBytesSync([1, 2, 3]);
    final stored = await persistPickedImage(src.path, documentsDir: docs);
    expect(stored, startsWith('${docs.path}/cards/'));
    expect(stored, endsWith('.jpg'));
    src.deleteSync();
    expect(File(stored).readAsBytesSync(), [1, 2, 3]);
    expect(await persistPickedImage(stored, documentsDir: docs), stored);
  });
}
