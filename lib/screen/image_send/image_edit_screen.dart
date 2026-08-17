import 'package:flutter/material.dart';

import '../../services/image_edit_model.dart';

class ImageEditScreen extends StatefulWidget {
  const ImageEditScreen({super.key, required this.imageEdit});
  final ImageEditModel imageEdit;

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}