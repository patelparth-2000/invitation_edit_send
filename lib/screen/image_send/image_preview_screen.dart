import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../models/card_layout.dart';
import '../../services/image_edit_model.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/widgets/states.dart';
import '../../utils/common.dart';

/// Full-screen preview (plan 5.4). Shows the **real rendered output** from
/// the same engine as the export, at preview resolution: numbered
/// placeholders for the layout, or one guest's [values].
class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({super.key, required this.imageEdit, this.values});
  final ImageEditModel imageEdit;
  final List<String>? values;

  /// Width the background is downscaled to before rendering the preview.
  static const int previewMaxWidth = 1200;

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late final CardLayout layout = CardLayout.fromModel(widget.imageEdit);
  Uint8List? _png;
  String? _error;

  @override
  void initState() {
    super.initState();
    _render();
  }

  List<String> get _labels =>
      widget.values ??
      [for (var i = 0; i < layout.slots.length; i++) '${i + 1}'];

  Future<void> _render() async {
    setState(() {
      _error = null;
      _png = null;
    });
    try {
      final base = await decodeCard(widget.imageEdit.imagePath,
          maxWidth: ImagePreviewScreen.previewMaxWidth);
      final out = await renderCard(
          base, layout.fieldsWith(_labels), layout.previewSize);
      if (!mounted) return;
      setState(() => _png = out.png);
    } catch (e) {
      debugPrint('Preview failed: $e');
      if (mounted) setState(() => _error = 'The preview could not be made.\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.values == null
        ? 'Layout preview'
        : (widget.values!.firstWhere((v) => v.isNotEmpty,
            orElse: () => 'Guest preview'));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _error != null
            ? ErrorState(message: _error!, onRetry: _render)
            : _png == null
                ? const Center(child: CircularProgressIndicator())
                : InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s),
                        child: Image.memory(
                          _png!,
                          fit: BoxFit.contain,
                          semanticLabel: '$title, rendered card',
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
