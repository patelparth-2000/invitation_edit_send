import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:invitation_edit_send/models/card_layout.dart';
import 'package:invitation_edit_send/models/guest.dart';
import 'package:invitation_edit_send/services/image_edit_model.dart';

void main() {
  group('TextSlot', () {
    test('fromEditor stores dy - 2 and keeps scale (T-10, F-3)', () {
      final slot = TextSlot.fromEditor(40.4, 60.6, 1.7);
      expect(slot.x, 40.4);
      expect(slot.y, closeTo(58.6, 1e-9));
      expect(slot.scale, 1.7);
    });

    test('display/render y reproduce the historic +2/-2 round trip', () {
      // Old readers: display = round(y) + 2, render = display - 2.
      const slot = TextSlot(x: 10.6, y: 20.4);
      expect(slot.renderX, 11);
      expect(slot.displayY, 22);
      expect(slot.renderY, slot.displayY - TextSlot.yFudge);
    });

    test('encode/decode round trip includes scale', () {
      final slots = [
        const TextSlot(x: 1, y: 2, scale: 1.5),
        const TextSlot(x: 3.25, y: 4.5),
      ];
      final json = CardLayout.encodeSlots(slots);
      expect(jsonDecode(json), [
        {'x': 1, 'y': 2, 's': 1.5},
        {'x': 3.25, 'y': 4.5, 's': 1.0},
      ]);
      expect(CardLayout.decodeSlots(json), slots);
    });

    test('rows saved before scale existed decode with scale 1.0', () {
      final slots = CardLayout.decodeSlots('[{"x":12,"y":"34.5"}]');
      expect(slots.single, const TextSlot(x: 12, y: 34.5, scale: 1.0));
    });

    test('null / empty / malformed coordinates decode to no slots', () {
      expect(CardLayout.decodeSlots(null), isEmpty);
      expect(CardLayout.decodeSlots(''), isEmpty);
      expect(CardLayout.decodeSlots('{}'), isEmpty);
    });
  });

  test('CardLayout.fromModel decodes size and colour', () {
    final layout = CardLayout.fromModel(ImageEditModel(
      textCoordinate: '[{"x":1,"y":2}]',
      imageSize: '{"width":392.5,"height":600}',
      textColor: '{"r":255,"g":"0","b":12}',
    ));
    expect(layout.slots, hasLength(1));
    expect(layout.previewSize, const Size(392.5, 600));
    expect(layout.color, (r: 255, g: 0, b: 12));
    expect(layout.flutterColor, const Color(0xFFFF000C));
  });

  group('per-field colour', () {
    test('is omitted from JSON when unset and round-trips when set', () {
      expect(jsonDecode(CardLayout.encodeSlots([const TextSlot(x: 1, y: 2)])),
          [
            {'x': 1, 'y': 2, 's': 1.0}
          ]);
      const coloured = TextSlot(x: 1, y: 2, color: 0xFF1A237E);
      expect(CardLayout.decodeSlots(CardLayout.encodeSlots([coloured])).single,
          coloured);
    });

    test('colorOf falls back to the layout colour', () {
      final layout = CardLayout.fromModel(ImageEditModel(
        textCoordinate: '[{"x":1,"y":2},{"x":1,"y":2,"c":4278190335}]',
        imageSize: '{"width":10,"height":10}',
        textColor: '{"r":255,"g":0,"b":0}',
      ));
      expect(layout.colorOf(0), const Color(0xFFFF0000));
      expect(layout.colorOf(1), const Color(0xFF0000FF));
    });

    test('fieldsWith places text where the editor showed it', () {
      final layout = CardLayout.fromModel(ImageEditModel(
        textCoordinate: '[{"x":10.4,"y":20.4,"s":2}]',
        imageSize: '{"width":10,"height":10}',
        textColor: '{"r":0,"g":0,"b":0}',
      ));
      final f = layout.fieldsWith(['Ravi', 'extra']).single;
      expect(f.text, 'Ravi');
      expect(f.topLeft, const Offset(10, 22));
      expect(f.scale, 2);
      expect(layout.fieldsWith([]).single.text, '');
    });
  });

  group('Guest', () {
    test('fromMap decodes values, status and pdf path', () {
      final g = Guest.fromMap({
        'id': 3,
        'layout_id': 7,
        'values_json': '["Asha Patel","Surat"]',
        'status': 'created',
        'pdf_path': '/x/Asha Patel.pdf',
      });
      expect(g.id, 3);
      expect(g.layoutId, 7);
      expect(g.values, ['Asha Patel', 'Surat']);
      expect(g.status, GuestStatus.created);
      expect(g.pdfPath, '/x/Asha Patel.pdf');
    });

    test('unknown or missing status reads as not created', () {
      expect(Guest.fromMap({'layout_id': 1, 'values_json': '[]'}).status,
          GuestStatus.notCreated);
      expect(
          Guest.fromMap({'layout_id': 1, 'values_json': '[]', 'status': '?'})
              .status,
          GuestStatus.notCreated);
    });

    test('displayName is the first non-empty value', () {
      expect(const Guest(layoutId: 1, values: ['', ' ', 'Ravi']).displayName,
          'Ravi');
      expect(const Guest(layoutId: 1, values: ['']).displayName, '');
    });

    test('copyWith can clear the pdf path', () {
      const g = Guest(layoutId: 1, values: ['a'], pdfPath: '/p.pdf');
      expect(g.copyWith(pdfPath: () => null).pdfPath, isNull);
      expect(g.copyWith(status: GuestStatus.failed).pdfPath, '/p.pdf');
    });
  });
}
