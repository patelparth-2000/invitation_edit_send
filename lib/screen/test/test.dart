import 'package:flutter/material.dart';
import 'package:translator/translator.dart';

final translator = GoogleTranslator();
String? _dropDownvalue;
String? translated_text;
TextEditingController myController = TextEditingController();

class TranslatorDemo extends StatefulWidget {
  @override
  _TranslatorDemoState createState() => _TranslatorDemoState();
}

class _TranslatorDemoState extends State<TranslatorDemo> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Scaffold(
            appBar: AppBar(title: Text("Translator App")),
            body: Container(
                margin: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                        width: double.infinity,
                        height: 40,
                        child: TextField(
                            controller: myController,
                            focusNode: FocusNode(canRequestFocus: false),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Enter Text',
                            ))),
                    Container(
                        margin: EdgeInsets.only(top: 20),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: _dropDownvalue == null
                              ? Text('Select language')
                              : Text(_dropDownvalue!,
                                  style: TextStyle(color: Colors.blue)),
                          items: <String>[
                            'English',
                            'Spanish',
                            'Chineese',
                            'German',
                            'Hindi',
                            'Gujarati'
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Container(child: Text(value)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _dropDownvalue = newValue;
                            });

                            if (_dropDownvalue == 'English') {
                              translate_text('en');
                            } else if (_dropDownvalue == 'Spanish') {
                              translate_text('es');
                            } else if (_dropDownvalue == 'Chineese') {
                              translate_text('zh-cn');
                            } else if (_dropDownvalue == 'German') {
                              translate_text('de');
                            } else if (_dropDownvalue == 'Hindi') {
                              translate_text('hi');
                            } else if (_dropDownvalue == 'Gujarati') {
                              translate_text('gu');
                            }
                          },
                        )),
                    Container(
                        margin: EdgeInsets.only(top: 30),
                        child: translated_text != null
                            ? Text(translated_text!,
                                style: TextStyle(
                                    fontSize: 25, fontWeight: FontWeight.bold))
                            : Text('')),
                  ],
                ))));
  }

  void translate_text(String locale) {
    translator.translate(myController.text, to: locale).then((value) {
      setState(() {
        translated_text = value.text;
      });
    });
  }
}
