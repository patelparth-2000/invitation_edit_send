import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/data_base_service.dart';
import '../../services/image_edit_model.dart';
import '../../utils/common.dart';
import 'image_show.dart';

class ImageCreateScreen extends StatefulWidget {
  const ImageCreateScreen(
      {super.key, required this.imagePath, required this.imageName});
  final String imagePath;
  final String imageName;

  @override
  State<ImageCreateScreen> createState() => _ImageCreateScreenState();
}

class _ImageCreateScreenState extends State<ImageCreateScreen> {
  final List<TextData> textDataList = [];
  final GlobalKey imageKey = GlobalKey();
  final dbService = DataBaseService.instance;
  String inputText = "Enter text";
  double textFontSize = 8;
  double textScale = 1.0;
  String? imagePath;
  Size? _imageSize;
  bool isLoading = false;
  double imageAspectRatio = 0;
  num r = 255;
  num g = 0;
  num b = 0;

  Future<File?> cropImage(String imagePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square crop
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          hideBottomControls: true,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (croppedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final newPath = '${appDir.path}/${croppedFile.path.split('/').last}';
      final savedFile = await File(croppedFile.path).copy(newPath);
      return savedFile; // Returns the saved file in the app directory
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    imageSizeMethod();
  }

  void imageSizeMethod() async {
    setState(() {
      isLoading = true;
    });
    imagePath = widget.imagePath;
    if (imagePath != "") {
      _imageSize = await getImageSize(imagePath!);
      imageAspectRatio = _imageSize!.width / _imageSize!.height;
    }
    setState(() {
      isLoading = false;
    });
  }

  void editImage() async {
    int intexNumber = -1;
    ImageEditModel imageEdit = ImageEditModel();
    String fileName = "";
    final RenderBox renderBox =
        imageKey.currentContext!.findRenderObject() as RenderBox;
    Size imageSize = renderBox.size;
    List<Map<String, num>> coordinatesList = [];
    List<TextData> newTextData = [];

    for (var i = 0; i < textDataList.length; i++) {
      fileName = textDataList[0].text;
      newTextData.add(TextData(textDataList[i].text, textDataList[i].dx,
          textDataList[i].dy - 2, textDataList[i].scale));
      coordinatesList
          .add({'x': textDataList[i].dx, 'y': textDataList[i].dy - 2});
    }

    String image =
        await addTextToImage(imagePath, newTextData, imageSize, r, g, b);

    createPdf(image, fileName);

    if (imagePath != null && imagePath!.isNotEmpty) {
      String textCoordinateJson = jsonEncode(coordinatesList);
      String textColorJson = jsonEncode({'r': r, 'g': g, 'b': b});
      String imageSizeJson =
          jsonEncode({'width': imageSize.width, 'height': imageSize.height});

      imageEdit = ImageEditModel(
          deleteImage: 0,
          fontType: "fonts/font_zip/PlaywriteIN-VariableFont_wght.ttf (2).zip",
          imagePath: imagePath,
          textNumber: textDataList.length.toString(),
          textCoordinate: textCoordinateJson,
          textColor: textColorJson,
          fileName: widget.imageName,
          imageSize: imageSizeJson);
      intexNumber = await dbService.imageEditInsert(imageEdit);
    }

    if (intexNumber != -1) {
      imageEdit.rowNumber = intexNumber;
    }

    // ignore: use_build_context_synchronously
    Navigator.of(context)
      ..pop()
      ..push(
        MaterialPageRoute(
          builder: (context) => ImageShow(image: image, imageEdit: imageEdit),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ignore: deprecated_member_use
      backgroundColor: Colors.white.withOpacity(0.9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Image Text Editor'),
        actions: [
          if (imagePath != "")
            IconButton(
              onPressed: () async {
                File? file = await cropImage(imagePath!);
                if (file != null) {
                  imagePath = file.path;
                  setState(() {});
                }
              },
              icon: Icon(Icons.crop),
              color: Colors.green,
            ),
          IconButton(
            onPressed: () async {
              editImage();
            },
            icon: Icon(Icons.check_circle),
            color: Colors.green,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : LayoutBuilder(
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
                              if (imagePath != null &&
                                  imagePath != "" &&
                                  _imageSize != null)
                                Image.file(
                                  File(imagePath!),
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
                                )
                              else
                                Image.asset(
                                  'assets/images/invitetion_card.jpg',
                                  fit: BoxFit.fitWidth,
                                  key: imageKey,
                                  width: constraints.maxWidth,
                                ),
                              ...textDataList.map((textData) => Positioned(
                                    left: textData.dx,
                                    top: textData.dy,
                                    child: GestureDetector(
                                      onLongPress: () async {
                                        String? newText =
                                            await _showTextInputDialog(context,
                                                name: textData.text);
                                        if (newText != null) {
                                          setState(() {
                                            textData.text = newText;
                                          });
                                        }
                                      },
                                      onScaleUpdate: (details) {
                                        setState(() {
                                          double newScale =
                                              (textData.scale * details.scale)
                                                  .clamp(0.5, 3.0);
                                          if (newScale == textData.scale) {
                                            textData.dx +=
                                                details.focalPointDelta.dx /
                                                    details.scale;
                                            textData.dy +=
                                                details.focalPointDelta.dy /
                                                    details.scale;
                                          } else {
                                            textData.dx +=
                                                details.focalPointDelta.dx;
                                            textData.dy +=
                                                details.focalPointDelta.dy;
                                          }
                                          textData.scale = newScale;
                                        });
                                      },
                                      child: Text(
                                        textData.text,
                                        style: TextStyle(
                                            fontSize:
                                                textFontSize * textData.scale,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: "PlaywriteIN"),
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: "tag4",
        backgroundColor: Colors.blue,
        shape: CircleBorder(),
        onPressed: () async {
          String? newText = await _showTextInputDialog(context);
          if (newText != null) {
            setState(() {
              textDataList.add(TextData(newText, 50, 50, 1.0));
            });
          }
        },
        child: Icon(
          Icons.add,
          size: 35,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<String?> _showTextInputDialog(BuildContext context,
      {String? name}) async {
    String newText = name ?? inputText;
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Edit Text'),
          content: TextField(
              onChanged: (value) {
                newText = value;
              },
              controller: TextEditingController(
                text: name ?? "",
              ),
              decoration: InputDecoration(
                hintText: inputText,
              )),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(newText);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
