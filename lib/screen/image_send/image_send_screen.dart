import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:invitation_edit_send/screen/image_edit/image_show.dart';

import '../../services/image_edit_model.dart';
import '../../utils/common.dart';
import 'image_preview_screen.dart';

class ImageSendScreen extends StatefulWidget {
  const ImageSendScreen({super.key, required this.imageEdit});
  final ImageEditModel imageEdit;

  @override
  State<ImageSendScreen> createState() => _ImageSendScreenState();
}

class _ImageSendScreenState extends State<ImageSendScreen> {
  final List<TextData> _textDataList = [];
  final List<TextDataListitem> textDataAllList = [];

  /// True while "Create All" is running. Guards re-entry and drives the progress
  /// affordance — the run is now sequential, so without this the button looks dead.
  bool _isCreatingAll = false;
  int _createdCount = 0;
  double imageAspectRatio = 0;
  Size? preImageSize;
  Size? _imageSize;
  final GlobalKey imageKey = GlobalKey();
  num r = 0;
  num g = 0;
  num b = 0;
  String imagePath = "";

  @override
  void initState() {
    super.initState();

    getTextData();
    imageSizeMethod();
  }

  void imageSizeMethod() async {
    _imageSize = await getImageSize(widget.imageEdit.imagePath!);
    imageAspectRatio = _imageSize!.width / _imageSize!.height;
    setState(() {});
  }

  void getTextData() {
    imagePath = widget.imageEdit.imagePath!;

    Map<String, dynamic> textColorMap =
        Map<String, dynamic>.from(jsonDecode(widget.imageEdit.textColor!));
    r = num.parse(textColorMap["r"].toString());
    g = num.parse(textColorMap["g"].toString());
    b = num.parse(textColorMap["b"].toString());

    Map<String, dynamic> imageSizeMap =
        Map<String, dynamic>.from(jsonDecode(widget.imageEdit.imageSize!));
    preImageSize = Size(double.parse(imageSizeMap["width"].toString()),
        double.parse(imageSizeMap["height"].toString()));

    List<Map<String, dynamic>> coordinatesList =
        List<Map<String, dynamic>>.from(
            jsonDecode(widget.imageEdit.textCoordinate!));

    for (var i = 0; i < coordinatesList.length; i++) {
      _textDataList.add(TextData(
          "",
          (double.parse(coordinatesList[i]["x"]!.toString()).round())
              .toDouble(),
          (double.parse(coordinatesList[i]["y"]!.toString()).round())
                  .toDouble() +
              2,
          1));
    }
    setState(() {});
  }

  /// Renders one card and writes its PDF.
  ///
  /// [showResult] is false during "Create All": pushing a route per guest is what
  /// used to stack N `ImageShow` screens on top of each other.
  Future<void> editImage(TextDataListitem textData,
      {bool showResult = true}) async {
    String fileName = "";
    List<TextData> newTextData = [];

    for (var i = 0; i < textData.textList!.length; i++) {
      fileName = textData.textList![0].text;
      newTextData.add(TextData(
          textData.textList![i].text,
          textData.textList![i].dx,
          textData.textList![i].dy - 2,
          textData.textList![i].scale));
    }

    String image =
        await addTextToImage(imagePath, newTextData, preImageSize!, r, g, b);
    // ignore: unused_local_variable
    String pdfFile = await createPdf(image, fileName);
    // String phoneNumber = textData.number!
    //     .replaceAll("+", ""); // Example number in international format
    // String message = "🙏 નવચંડી પૂજામાં તમારું હાર્દિક સ્વાગત છે. 🙏";
    // sharePdfToWhatsApp(phoneNumber, message, pdfUrl);

    if (!showResult || !mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageShow(
            image: image,
          ),
        ));
  }

  /// Renders every guest's card **one at a time**.
  ///
  /// This used to be a bare `for` loop calling an un-awaited `async void`, so a
  /// 20-guest list decoded 20 full images concurrently, raced on disk and stacked
  /// 20 routes. Sequential is slower per run and is the only version that survives
  /// a real guest list.
  Future<void> createAll() async {
    if (_isCreatingAll || textDataAllList.isEmpty) return;
    setState(() {
      _isCreatingAll = true;
      _createdCount = 0;
    });
    try {
      for (final element in textDataAllList) {
        await editImage(element, showResult: false);
        if (!mounted) return;
        setState(() => _createdCount++);
      }
    } finally {
      if (mounted) setState(() => _isCreatingAll = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Created $_createdCount PDFs in Downloads")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text('Image Send'),
          actions: [
            IconButton(
                onPressed: () {
                  bottomSheet();
                },
                icon: Text(
                  "Preview",
                  style: TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.blueAccent),
                )),
            SizedBox(width: 10)
          ],
        ),
        bottomNavigationBar: InkWell(
          onTap: _isCreatingAll ? null : createAll,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _isCreatingAll ? Colors.blue.shade300 : Colors.blue,
                borderRadius: BorderRadius.circular(40)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isCreatingAll) ...[
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                ],
                Text(
                  _isCreatingAll
                      ? "Creating $_createdCount of ${textDataAllList.length}…"
                      : "Create All",
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      fontSize: 16),
                )
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: "tag5",
          backgroundColor: Colors.blue,
          shape: CircleBorder(),
          onPressed: () async {
            TextDataListitem? newTextList = await _showTextInputDialog(context);
            if (newTextList != null) {
              textDataAllList.add(newTextList);
              setState(() {});
            }
          },
          child: Icon(
            Icons.add,
            size: 35,
            color: Colors.white,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: textDataAllList.length,
                itemBuilder: (context, index) {
                  TextDataListitem texDataList = textDataAllList[index];
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 30),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text("Number: ${texDataList.number}"),
                            for (int i = 0;
                                i < texDataList.textList!.length;
                                i++)
                              Row(
                                children: [
                                  Text("${i + 1}. "),
                                  Text(texDataList.textList![i].text),
                                ],
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 10,
                          children: [
                            Row(
                              spacing: 10,
                              children: [
                                InkWell(
                                    onTap: () {
                                      bottomSheet(
                                          textData: texDataList.textList);
                                    },
                                    child: Icon(
                                      Icons.preview,
                                      color: Colors.blue,
                                    )),
                                InkWell(
                                    onTap: () async {
                                      texDataList = (await _showTextInputDialog(
                                          context,
                                          textDataList: texDataList))!;
                                    },
                                    child: Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    )),
                                InkWell(
                                    onTap: () {
                                      textDataAllList.remove(texDataList);
                                      setState(() {});
                                    },
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    )),
                              ],
                            ),
                            InkWell(
                              onTap: () {
                                editImage(texDataList);
                              },
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 0),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Create",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          fontSize: 16),
                                    )
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (context, index) {
                  return SizedBox(
                    height: 10,
                  );
                },
              ),
            )
          ],
        ));
  }

  Future<TextDataListitem?> _showTextInputDialog(BuildContext context,
      {TextDataListitem? textDataList}) async {
    List<TextData> newList = textDataList != null
        ? List.from(textDataList.textList!)
        : _textDataList
            .map((e) => TextData(e.text, e.dx, e.dy, e.scale))
            .toList();
    List<TextEditingController> controllers = List.generate(
      newList.length,
      (index) => TextEditingController(text: newList[index].text),
    );
    TextEditingController numberController = TextEditingController(
        text: (textDataList != null ? textDataList.number : "") ?? "");
    String countryCode = "+91";

    // List to track selected indices for each dropdown
    List<int?> selectedIndices = List<int?>.filled(newList.length, null);

    return showDialog<TextDataListitem?>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text('Edit Text'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // SizedBox(
                    //   child: IntlPhoneField(
                    //     autovalidateMode: AutovalidateMode.onUserInteraction,
                    //     dropdownIconPosition: IconPosition.trailing,
                    //     controller: numberController,
                    //     cursorColor: Colors.black,
                    //     style:
                    //         const TextStyle(fontSize: 12, color: Colors.black),
                    //     decoration: const InputDecoration(
                    //       counterText: "",
                    //       hintText: "Enter the phone Number",
                    //       contentPadding: EdgeInsets.symmetric(
                    //           vertical: 11, horizontal: 14),
                    //       border: UnderlineInputBorder(),
                    //     ),
                    //     initialCountryCode: 'IN',
                    //     onChanged: (phone) {
                    //       countryCode = phone.countryCode;
                    //     },
                    //   ),
                    // ),
                    ...newList.asMap().entries.map(
                      (entry) {
                        int index = entry.key;
                        TextData textData = entry.value;
                        return Row(
                          children: [
                            Text("${index + 1}."),
                            Expanded(
                              child: TextField(
                                controller: controllers[index],
                                onChanged: (value) {
                                  textData.text = value;
                                },
                                decoration: InputDecoration(
                                  hintText: "Enter the value",
                                ),
                              ),
                            ),
                            if (newList.length > 1)
                              DropdownButton<int>(
                                hint: Text('Select'),
                                value: selectedIndices[index],
                                items:
                                    newList.asMap().entries.map((otherEntry) {
                                  int otherIndex = otherEntry.key;
                                  return DropdownMenuItem<int>(
                                    value: otherIndex,
                                    child: Text("Field ${otherIndex + 1}"),
                                  );
                                }).toList(),
                                onChanged: (selectedIndex) {
                                  if (selectedIndex != null) {
                                    setState(() {
                                      selectedIndices[index] = selectedIndex;
                                      controllers[index].text =
                                          controllers[selectedIndex].text;
                                      textData.text =
                                          controllers[selectedIndex].text;
                                    });
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    TextDataListitem textDataListitem = TextDataListitem();
                    for (int i = 0; i < newList.length; i++) {
                      newList[i].text = controllers[i].text;
                    }
                    textDataListitem = TextDataListitem(
                        number: "$countryCode${numberController.text}",
                        textList: newList);
                    Navigator.of(context).pop(textDataListitem);
                    for (var controller in controllers) {
                      controller.clear();
                    }
                    numberController.clear();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void bottomSheet({final List<TextData>? textData}) {
    Get.bottomSheet(
      backgroundColor: Colors.white,
      isScrollControlled: true, // Allows full-screen bottom sheet
      enableDrag: false, // Disable dragging to close
      ImagePreviewScreen(
        imageEdit: widget.imageEdit,
        textData: textData,
      ),
    );
  }
}

class TextDataListitem {
  String? number;
  List<TextData>? textList;

  TextDataListitem({this.number, this.textList});
}
