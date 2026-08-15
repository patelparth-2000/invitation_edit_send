import 'dart:io';

import 'package:flutter/material.dart';
import 'package:invitation_edit_send/services/image_edit_model.dart';

class ImageShow extends StatelessWidget {
  const ImageShow({super.key, required this.image, this.imageEdit});
  final String image;
  final ImageEditModel? imageEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ignore: deprecated_member_use
      backgroundColor: Colors.white.withOpacity(0.9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Edited Image'),
      ),
      body: InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 3.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.file(
              File(image),
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
