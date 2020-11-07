// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

final Map<String, Item> _items = <String, Item>{};
Item _itemForMessage(Map<String, dynamic> message) {
  final dynamic data = message['data'] ?? message;
  final String itemId = data['id'];
  final Item item = _items.putIfAbsent(itemId, () => Item(itemId: itemId))
    ..status = data['status'];
  return item;
}

class Item {
  Item({this.itemId});
  final String itemId;

  StreamController<Item> _controller = StreamController<Item>.broadcast();
  Stream<Item> get onChanged => _controller.stream;

  String _status;
  String get status => _status;
  set status(String value) {
    _status = value;
    _controller.add(this);
  }

  static final Map<String, Route<void>> routes = <String, Route<void>>{};
  Route<void> get route {
    final String routeName = '/detail/$itemId';
    return routes.putIfAbsent(
      routeName,
      () => MaterialPageRoute<void>(
        settings: RouteSettings(name: routeName),
        builder: (BuildContext context) => DetailPage(itemId),
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  DetailPage(this.itemId);
  final String itemId;
  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Item _item;
  StreamSubscription<Item> _subscription;

  @override
  void initState() {
    super.initState();
    _item = _items[widget.itemId];
    _subscription = _item.onChanged.listen((Item item) {
      if (!mounted) {
        _subscription.cancel();
      } else {
        setState(() {
          _item = item;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Item ${_item.itemId}"),
      ),
      body: Material(
        child: Center(child: Text("Item status: ${_item.status}")),
      ),
    );
  }
}

class PushMessagingExample extends StatefulWidget {
  @override
  _PushMessagingExampleState createState() => _PushMessagingExampleState();
}

class _PushMessagingExampleState extends State<PushMessagingExample> {
  String _homeScreenText = "Waiting for token...";
  bool _topicButtonsDisabled = false;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  final TextEditingController _topicController =
      TextEditingController(text: 'topic');

  Widget _buildDialog(BuildContext context, Item item) {
    return AlertDialog(
      content: Text("Item ${item.itemId} has been updated"),
      actions: <Widget>[
        FlatButton(
          child: const Text('CLOSE'),
          onPressed: () {
            Navigator.pop(context, false);
          },
        ),
        FlatButton(
          child: const Text('SHOW'),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ],
    );
  }

  void _showItemDialog(Map<String, dynamic> message) {
    showDialog<bool>(
      context: context,
      builder: (_) => _buildDialog(context, _itemForMessage(message)),
    ).then((bool shouldNavigate) {
      if (shouldNavigate == true) {
        _navigateToItemDetail(message);
      }
    });
  }

  void _navigateToItemDetail(Map<String, dynamic> message) {
    final Item item = _itemForMessage(message);
    // Clear away dialogs
    Navigator.popUntil(context, (Route<dynamic> route) => route is PageRoute);
    if (!item.route.isCurrent) {
      Navigator.push(context, item.route);
    }
  }

  @override
  void initState() {
    super.initState();
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        _showItemDialog(message);
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        _navigateToItemDetail(message);
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
        _navigateToItemDetail(message);
      },
    );
    _firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(
            sound: true, badge: true, alert: true, provisional: true));
    _firebaseMessaging.onIosSettingsRegistered
        .listen((IosNotificationSettings settings) {
      print("Settings registered: $settings");
    });
    _firebaseMessaging.getToken().then((String token) {
      assert(token != null);
      setState(() {
        _homeScreenText = "Push Messaging token: $token";
      });
      print(_homeScreenText);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Push Messaging Demo'),
        ),
        // For testing -- simulate a message being received
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showItemDialog(<String, dynamic>{
            "data": <String, String>{
              "id": "2",
              "status": "out of stock",
            },
          }),
          tooltip: 'Simulate Message',
          child: const Icon(Icons.message),
        ),
        body: Material(
          child: Column(
            children: <Widget>[
              Center(
                child: Text(_homeScreenText),
              ),
              Row(children: <Widget>[
                Expanded(
                  child: TextField(
                      controller: _topicController,
                      onChanged: (String v) {
                        setState(() {
                          _topicButtonsDisabled = v.isEmpty;
                        });
                      }),
                ),
                FlatButton(
                  child: const Text("subscribe"),
                  onPressed: _topicButtonsDisabled
                      ? null
                      : () {
                          _firebaseMessaging
                              .subscribeToTopic(_topicController.text);
                          _clearTopicText();
                        },
                ),
                FlatButton(
                  child: const Text("unsubscribe"),
                  onPressed: _topicButtonsDisabled
                      ? null
                      : () {
                          _firebaseMessaging
                              .unsubscribeFromTopic(_topicController.text);
                          _clearTopicText();
                        },
                ),
              ])
            ],
          ),
        ));
  }

  void _clearTopicText() {
    setState(() {
      _topicController.text = "";
      _topicButtonsDisabled = true;
    });
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PushMessagingExample(),
    );
  }
}

// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';

// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:qrscan/qrscan.dart' as scanner;

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatefulWidget {
//   @override
//   _MyAppState createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   Uint8List bytes = Uint8List(0);
//   TextEditingController _inputController;
//   TextEditingController _outputController;

//   @override
//   initState() {
//     super.initState();
//     this._inputController = new TextEditingController();
//     this._outputController = new TextEditingController();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         backgroundColor: Colors.grey[300],
//         body: Builder(
//           builder: (BuildContext context) {
//             return ListView(
//               children: <Widget>[
//                 _qrCodeWidget(this.bytes, context),
//                 Container(
//                   color: Colors.white,
//                   child: Column(
//                     children: <Widget>[
//                       TextField(
//                         controller: this._inputController,
//                         keyboardType: TextInputType.url,
//                         textInputAction: TextInputAction.go,
//                         onSubmitted: (value) => _generateBarCode(value),
//                         decoration: InputDecoration(
//                           prefixIcon: Icon(Icons.text_fields),
//                           helperText: 'Please input your code to generage qrcode image.',
//                           hintText: 'Please Input Your Code',
//                           hintStyle: TextStyle(fontSize: 15),
//                           contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 15),
//                         ),
//                       ),
//                       SizedBox(height: 20),
//                       TextField(
//                         controller: this._outputController,
//                         readOnly: true,
//                         maxLines: 2,
//                         decoration: InputDecoration(
//                           prefixIcon: Icon(Icons.wrap_text),
//                           helperText: 'The barcode or qrcode you scan will be displayed in this area.',
//                           hintText: 'The barcode or qrcode you scan will be displayed in this area.',
//                           hintStyle: TextStyle(fontSize: 15),
//                           contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 15),
//                         ),
//                       ),
//                       SizedBox(height: 20),
//                       this._buttonGroup(),
//                       SizedBox(height: 70),
//                     ],
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//         floatingActionButton: FloatingActionButton(
//           onPressed: () => _scanBytes(),
//           tooltip: 'Take a Photo',
//           child: const Icon(Icons.camera_alt),
//         ),
//       ),
//     );
//   }

//   Widget _qrCodeWidget(Uint8List bytes, BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.all(20),
//       child: Card(
//         elevation: 6,
//         child: Column(
//           children: <Widget>[
//             Container(
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: <Widget>[
//                   Icon(Icons.verified_user, size: 18, color: Colors.green),
//                   Text('  Generate Qrcode', style: TextStyle(fontSize: 15)),
//                   Spacer(),
//                   Icon(Icons.more_vert, size: 18, color: Colors.black54),
//                 ],
//               ),
//               padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
//               decoration: BoxDecoration(
//                 color: Colors.black12,
//                 borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
//               ),
//             ),
//             Padding(
//               padding: EdgeInsets.only(left: 40, right: 40, top: 30, bottom: 10),
//               child: Column(
//                 children: <Widget>[
//                   SizedBox(
//                     height: 190,
//                     child: bytes.isEmpty
//                         ? Center(
//                             child: Text('Empty code ... ', style: TextStyle(color: Colors.black38)),
//                           )
//                         : Image.memory(bytes),
//                   ),
//                   Padding(
//                     padding: EdgeInsets.only(top: 7, left: 25, right: 25),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceAround,
//                       children: <Widget>[
//                         Expanded(
//                           flex: 5,
//                           child: GestureDetector(
//                             child: Text(
//                               'remove',
//                               style: TextStyle(fontSize: 15, color: Colors.blue),
//                               textAlign: TextAlign.left,
//                             ),
//                             onTap: () => this.setState(() => this.bytes = Uint8List(0)),
//                           ),
//                         ),
//                         Text('|', style: TextStyle(fontSize: 15, color: Colors.black26)),
//                         Expanded(
//                           flex: 5,
//                           child: GestureDetector(
//                             onTap: () async {
//                               final success = await ImageGallerySaver.saveImage(this.bytes);
//                               SnackBar snackBar;
//                               if (success) {
//                                 snackBar = new SnackBar(content: new Text('Successful Preservation!'));
//                                 Scaffold.of(context).showSnackBar(snackBar);
//                               } else {
//                                 snackBar = new SnackBar(content: new Text('Save failed!'));
//                               }
//                             },
//                             child: Text(
//                               'save',
//                               style: TextStyle(fontSize: 15, color: Colors.blue),
//                               textAlign: TextAlign.right,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 ],
//               ),
//             ),
//             Divider(height: 2, color: Colors.black26),
//             Container(
//               child: Row(
//                 children: <Widget>[
//                   Icon(Icons.history, size: 16, color: Colors.black38),
//                   Text('  Generate History', style: TextStyle(fontSize: 14, color: Colors.black38)),
//                   Spacer(),
//                   Icon(Icons.chevron_right, size: 16, color: Colors.black38),
//                 ],
//               ),
//               padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
//             )
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buttonGroup() {
//     return Row(
//       children: <Widget>[
//         Expanded(
//           flex: 1,
//           child: SizedBox(
//             height: 120,
//             child: InkWell(
//               onTap: () => _generateBarCode(this._inputController.text),
//               child: Card(
//                 child: Column(
//                   children: <Widget>[
//                     Expanded(
//                       flex: 2,
//                       child: Image.asset('images/generate_qrcode.png'),
//                     ),
//                     Divider(height: 20),
//                     Expanded(flex: 1, child: Text("Generate")),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//         Expanded(
//           flex: 1,
//           child: SizedBox(
//             height: 120,
//             child: InkWell(
//               onTap: _scan,
//               child: Card(
//                 child: Column(
//                   children: <Widget>[
//                     Expanded(
//                       flex: 2,
//                       child: Image.asset('images/scanner.png'),
//                     ),
//                     Divider(height: 20),
//                     Expanded(flex: 1, child: Text("Scan")),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//         Expanded(
//           flex: 1,
//           child: SizedBox(
//             height: 120,
//             child: InkWell(
//               onTap: _scanPhoto,
//               child: Card(
//                 child: Column(
//                   children: <Widget>[
//                     Expanded(
//                       flex: 2,
//                       child: Image.asset('images/albums.png'),
//                     ),
//                     Divider(height: 20),
//                     Expanded(flex: 1, child: Text("Scan Photo")),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Future _scan() async {
//     String barcode = await scanner.scan();
//     this._outputController.text = barcode;
//   }

//   Future _scanPhoto() async {
//     String barcode = await scanner.scanPhoto();
//     this._outputController.text = barcode;
//   }

//   Future _scanPath(String path) async {
//     String barcode = await scanner.scanPath(path);
//     this._outputController.text = barcode;
//   }

//   Future _scanBytes() async {
//     File file = await ImagePicker.pickImage(source: ImageSource.camera);
//     Uint8List bytes = file.readAsBytesSync();
//     String barcode = await scanner.scanBytes(bytes);
//     this._outputController.text = barcode;
//   }

//   Future _generateBarCode(String inputCode) async {
//     Uint8List result = await scanner.generateBarCode(inputCode);
//     this.setState(() => this.bytes = result);
//   }
// }
