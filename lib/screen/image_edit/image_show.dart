import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../ui/theme/app_spacing.dart';

/// "Card ready": the finished card with Share and Done (plan 5.3, R1).
class ImageShow extends StatelessWidget {
  const ImageShow({
    super.key,
    required this.imageBytes,
    this.pdfPath,
    this.title,
  });

  final Uint8List imageBytes;
  final String? pdfPath;
  final String? title;

  Future<void> _share(BuildContext context) async {
    final path = pdfPath;
    if (path == null || !File(path).existsSync()) return;
    try {
      await SharePlus.instance.share(ShareParams(
          files: [XFile(path, mimeType: 'application/pdf')]));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title == null || title!.isEmpty
          ? 'Card ready'
          : 'Card ready: $title')),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.memory(imageBytes,
              fit: BoxFit.contain, semanticLabel: 'Finished card'),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: pdfPath == null ? null : () => _share(context),
                  icon: const Icon(Icons.share),
                  label: const Text('Share PDF'),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
