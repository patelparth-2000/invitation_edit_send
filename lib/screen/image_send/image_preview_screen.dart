import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/image_edit_model.dart';
import '../../utils/common.dart';
import '../../utils/dimensions.dart';

class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({super.key, required this.imageEdit, this.textData});
  final ImageEditModel imageEdit;
  final List<TextData>? textData;
  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final List<TextData> textDataList = [];
  double imageAspectRatio = 0;
  Size? preImageSize;
  Size? _imageSize;
  Size? _currentImageSize;

  final GlobalKey imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    getTextData();
    imageSizeMethod();
  }

  Future<void> _getImageSize() async {
    try {
      final RenderBox renderBox =
          imageKey.currentContext!.findRenderObject() as RenderBox;
      setState(() {
        _currentImageSize = renderBox.size;
      });
      print(
          'Image size: ${_currentImageSize!.width} x ${_currentImageSize!.height}');
    } catch (e) {
      print('Error fetching RenderBox size: $e');
    }
  }

  void imageSizeMethod() async {
    _imageSize = await getImageSize(widget.imageEdit.imagePath!);
    imageAspectRatio = _imageSize!.width / _imageSize!.height;
    setState(() {});
  }

  void getTextData() {
    List<Map<String, dynamic>> coordinatesList =
        List<Map<String, dynamic>>.from(
            jsonDecode(widget.imageEdit.textCoordinate!));

    Map<String, dynamic> imageSizeMap =
        Map<String, dynamic>.from(jsonDecode(widget.imageEdit.imageSize!));
    preImageSize = Size(double.parse(imageSizeMap["width"].toString()),
        double.parse(imageSizeMap["height"].toString()));

    for (var i = 0; i < coordinatesList.length; i++) {
      textDataList.add(TextData(
          widget.textData != null
              ? widget.textData![i].text.toString()
              : (i + 1).toString(),
          (double.parse(coordinatesList[i]["x"]!.toString()).round())
              .toDouble(),
          (double.parse(coordinatesList[i]["y"]!.toString()).round())
                  .toDouble() +
              2,
          1));
    }

    Future.delayed(Duration(milliseconds: 500)).whenComplete(() {
      _getImageSize();
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Dimensions.screenHeight * .9, // Full screen height
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: Dimensions.screenWidth,
            height: 60,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Image Preview",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        Icons.close,
                        size: 30,
                        color: Colors.black,
                      )),
                ),
              ],
            ),
          ),
          Container(
            width: Dimensions.screenWidth,
            height: 1,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double containerAspectRatio =
                    constraints.maxWidth / constraints.maxHeight;
                return Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              if (_imageSize != null)
                                Image.file(
                                  File(widget.imageEdit.imagePath!),
                                  fit: imageAspectRatio > containerAspectRatio
                                      ? BoxFit.fitWidth
                                      : BoxFit.fitHeight,
                                  key: imageKey,
                                  width: imageAspectRatio > containerAspectRatio
                                      ? constraints.maxWidth
                                      : null,
                                  height:
                                      imageAspectRatio > containerAspectRatio
                                          ? null
                                          : constraints.maxHeight,
                                ),
                              if (_currentImageSize != null)
                                ...textDataList.map(
                                  (textData) {
                                    // Adjust coordinates based on scaling ratio
                                    final scaleX = _currentImageSize!.width /
                                        preImageSize!.width;
                                    final scaleY = _currentImageSize!.height /
                                        preImageSize!.height;
                                    final adjustedX = textData.dx * scaleX;
                                    final adjustedY = textData.dy * scaleY;

                                    return Positioned(
                                      left: adjustedX,
                                      top: adjustedY,
                                      child: GestureDetector(
                                        onScaleUpdate: (details) {
                                          setState(() {
                                            double newScale =
                                                (textData.scale * details.scale)
                                                    .clamp(0.5, 3.0);
                                            textData.scale = newScale;
                                          });
                                        },
                                        child: Text(
                                          textData.text,
                                          style: TextStyle(
                                            fontSize: 8 * textData.scale,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: "PlaywriteIN",
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
