import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:invitation_edit_send/screen/image_send/image_send_screen.dart';
import 'package:invitation_edit_send/services/image_edit_model.dart';

import '../../services/data_base_service.dart';
import '../../services/permission_manager.dart';
import '../image_edit/image_create_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final dbService = DataBaseService.instance;

  bool isAdd = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  List<ImageEditModel> imageEditList = [];
  String fileName = "New file";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..value = 1.0; // Start at the end of the animation (45 degrees).

    _animation = Tween<double>(begin: 0, end: 45 * (3.141592653589793 / 180))
        .animate(_controller);
    getAllImagedata();
  }

  void _toggleAnimation() async {
    setState(() {
      isAdd = !isAdd;
      if (isAdd) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void getAllImagedata() async {
    final all = await dbService.getAllImageEdits();
    // Soft-deleted rows are filtered out HERE, not inside itemBuilder. Returning an
    // empty Container() per deleted row still made ListView.separated allocate the
    // slot and its separator, which is what left visible gaps in the list.
    imageEditList = all.where((e) => e.deleteImage != 1).toList();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Image edit App'),
        actions: [
          IconButton(
            onPressed: () async {
              getAllImagedata();
            },
            icon: Icon(Icons.refresh),
            color: Colors.green,
          ),
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (imageEditList.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(10),
                shrinkWrap: true,
                itemCount: imageEditList.length,
                itemBuilder: (context, index) {
                  var imageData = imageEditList[index];
                  return Container(
                    height: 250,
                    margin: EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10)),
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Stack(
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(imageData.imagePath!),
                                fit: BoxFit.fitWidth,
                                height: 250,
                                width: constraints.maxWidth,
                              ),
                            ),
                          ),
                          Container(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            decoration: BoxDecoration(
                              // ignore: deprecated_member_use
                              color: Colors.black12.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: Row(
                              children: [
                                IconButton(
                                    onPressed: () async {
                                      imageData.fileName =
                                          await _showTextInputDialog(context,
                                              name: imageData.fileName);
                                      dbService.imageEditUpdate(imageData);
                                      setState(() {});
                                    },
                                    icon: Icon(
                                      Icons.edit_note_sharp,
                                      color: Colors.white,
                                    )),
                                InkWell(
                                    onTap: () async {
                                      imageData.deleteImage = 1;
                                      dbService.imageEditUpdate(imageData);
                                      getAllImagedata();
                                      setState(() {});
                                    },
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    )),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            child: Container(
                              width: constraints.maxWidth,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(8)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: constraints.maxWidth,
                                    height: 1,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              imageData.fileName ?? "New File",
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black),
                                            ),
                                            Text(
                                              "No. TextArea : ${imageData.textNumber}",
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                          onPressed: () {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ImageSendScreen(
                                                          imageEdit: imageData),
                                                ));
                                          },
                                          icon: Icon(
                                              Icons.arrow_forward_ios_outlined))
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      );
                    }),
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return SizedBox(
                    height: 10,
                  );
                },
              ),
            ),
          SizedBox(
            height: 50,
          ),
        ],
      ),
      floatingActionButton: Column(
        spacing: 15,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isAdd)
            Column(
              spacing: 15,
              children: [
                Row(
                  spacing: 10,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Camera",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: "tag1",
                      backgroundColor: Colors.blue,
                      shape: CircleBorder(),
                      onPressed: () => selectImage(ImageSource.camera),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 10,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Gallery",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: "tag2",
                      backgroundColor: Colors.blue,
                      shape: CircleBorder(),
                      onPressed: () => selectImage(ImageSource.gallery),
                      child: Icon(
                        Icons.image_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          FloatingActionButton(
            heroTag: "tag3",
            backgroundColor: Colors.blue,
            shape: CircleBorder(),
            onPressed: _toggleAnimation,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animation.value,
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> selectImage(ImageSource source) async {
    bool permissionGranted = false;

    if (source == ImageSource.camera) {
      permissionGranted = await PermissionManager.requestCameraPermission();
    } else if (source == ImageSource.gallery) {
      permissionGranted = await PermissionManager.requestGalleryPermission();
    }

    if (permissionGranted) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        // ignore: use_build_context_synchronously
        await _showTextInputDialog(context, imagePath: pickedFile.path);
      }
    } else {
      showPermissionDeniedDialog();
    }
  }

  void showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blue,
        surfaceTintColor: Colors.blue,
        shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text("Permission Denied"),
        content: const Text(
            "The required permission was not granted. Please allow permissions in app settings."),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: Colors.black, borderRadius: BorderRadius.circular(5)),
              child: const Text(
                "Close",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditor(String imagepath, String imageName) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ImageCreateScreen(
                imagePath: imagepath,
                imageName: imageName,
              )),
    );
  }

  Future<String?> _showTextInputDialog(BuildContext context,
      {String? name, String? imagePath}) async {
    String newName = name ?? fileName;
    return showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Enter File Name'),
          content: TextField(
              onChanged: (value) {
                if (name == null) {
                  fileName = value;
                }
                newName = value;
              },
              controller: TextEditingController(
                text: name ?? fileName,
              ),
              decoration: InputDecoration(
                hintText: "Enter File name",
              )),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(newName);
                if (imagePath != null) {
                  isAdd = false;
                  _controller.forward();
                  setState(() {});
                  _openEditor(imagePath, fileName);
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
