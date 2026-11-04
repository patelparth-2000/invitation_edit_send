import 'package:flutter/material.dart';

import '../../utils/common.dart';

/// One field as the canvas shows it.
@immutable
class SlotView {
  const SlotView({
    required this.text,
    required this.topLeft,
    required this.scale,
    required this.color,
    this.semanticsLabel,
  });

  final String text;

  /// Position in *design* coordinates (see [CardCanvas.designSize]).
  final Offset topLeft;
  final double scale;
  final Color color;
  final String? semanticsLabel;
}

/// The card image fitted into the available space with its fields on top
/// (plan 4.3). Used by the editor (interactive) and the previews.
///
/// Fit rule (unchanged from the old editor): fill the width when the image is
/// relatively wider than the space, otherwise fill the height.
///
/// Slot positions and sizes are in design coordinates: the size the image
/// had when the layout was designed ([designSize]). When [designSize] is
/// null the canvas's own laid-out size is the design size (the editor).
/// The laid-out size is reported through [onLaidOut] (no GlobalKey + delay).
class CardCanvas extends StatefulWidget {
  const CardCanvas({
    super.key,
    required this.image,
    required this.imageSize,
    required this.slots,
    this.designSize,
    this.selected,
    this.onSelect,
    this.onTransform,
    this.onLaidOut,
    this.imageSemanticsLabel,
  });

  final ImageProvider image;
  final Size imageSize;
  final List<SlotView> slots;
  final Size? designSize;
  final int? selected;

  /// Called with the tapped slot index, or -1 when the background is tapped.
  final ValueChanged<int>? onSelect;

  /// Drag/pinch on a slot: [delta] in design coordinates, [scaleFactor] is the
  /// change since the previous update (multiply the slot scale by it).
  final void Function(int index, Offset delta, double scaleFactor)? onTransform;
  final ValueChanged<Size>? onLaidOut;
  final String? imageSemanticsLabel;

  /// Size the image is shown at inside [constraints].
  static Size fittedSize(Size imageSize, BoxConstraints constraints) {
    if (imageSize.isEmpty ||
        !constraints.hasBoundedWidth ||
        !constraints.hasBoundedHeight) {
      return Size.zero;
    }
    final ar = imageSize.width / imageSize.height;
    final containerAr = constraints.maxWidth / constraints.maxHeight;
    return ar > containerAr
        ? Size(constraints.maxWidth, constraints.maxWidth / ar)
        : Size(constraints.maxHeight * ar, constraints.maxHeight);
  }

  @override
  State<CardCanvas> createState() => _CardCanvasState();
}

class _CardCanvasState extends State<CardCanvas> {
  Size? _reported;
  double _lastScale = 1;

  void _report(Size size) {
    if (widget.onLaidOut == null || size == _reported) return;
    _reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLaidOut!(size);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final shown = CardCanvas.fittedSize(widget.imageSize, constraints);
      if (shown.isEmpty) return const SizedBox.shrink();
      _report(shown);
      final design = widget.designSize ?? shown;
      final k = design.width > 0 ? shown.width / design.width : 1.0;
      final ky = design.height > 0 ? shown.height / design.height : 1.0;
      final primary = Theme.of(context).colorScheme.primary;

      return Center(
        child: SizedBox(
          width: shown.width,
          height: shown.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onSelect == null
                      ? null
                      : () => widget.onSelect!(-1),
                  child: Semantics(
                    image: true,
                    label: widget.imageSemanticsLabel,
                    child: Image(
                      image: widget.image,
                      fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Colors.black12,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < widget.slots.length; i++)
                Positioned(
                  left: widget.slots[i].topLeft.dx * k,
                  top: widget.slots[i].topLeft.dy * ky,
                  child: _slot(i, k, primary),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _slot(int i, double k, Color outline) {
    final slot = widget.slots[i];
    final selected = widget.selected == i;
    Widget child = CustomPaint(
      foregroundPainter: selected ? _DashedRectPainter(outline) : null,
      child: Text(
        slot.text,
        textScaler: TextScaler.noScaling,
        style: cardFieldStyle(
            scale: slot.scale, color: slot.color, pixelScale: k),
      ),
    );
    final interactive = widget.onSelect != null || widget.onTransform != null;
    if (interactive) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect == null ? null : () => widget.onSelect!(i),
        onScaleStart: (_) {
          _lastScale = 1;
          widget.onSelect?.call(i);
        },
        onScaleUpdate: widget.onTransform == null
            ? null
            : (d) {
                final factor = d.scale / _lastScale;
                _lastScale = d.scale;
                widget.onTransform!(i, d.focalPointDelta / k, factor);
              },
        child: child,
      );
    }
    return Semantics(
      label: slot.semanticsLabel ?? 'Field ${i + 1}, ${slot.text}',
      hint: interactive ? 'Double tap to select' : null,
      button: interactive,
      selected: selected,
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rect = (Offset.zero & size).inflate(2);
    const dash = 4.0, gap = 3.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      for (double d = 0; d < total; d += dash + gap) {
        final end = (d + dash).clamp(0, total).toDouble();
        canvas.drawLine(a + dir * d, a + dir * end, paint);
      }
    }

    line(rect.topLeft, rect.topRight);
    line(rect.topRight, rect.bottomRight);
    line(rect.bottomRight, rect.bottomLeft);
    line(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}
