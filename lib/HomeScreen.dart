import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:object_detection/LoaderState.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ModelObjectDetection _objectModel;
  String? _imagePrediction;
  List<String> _prediction = [];
  File? _image;
  ImagePicker _picker = ImagePicker();
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];
  bool firststate = false;
  bool message = true;
  bool _popupOpen = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future loadModel() async {
    String pathObjectDetectionModel = "assets/models/yolov5s.torchscript";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
          pathObjectDetectionModel, 80, 640, 640,
          labelPath: "assets/labels/labels.txt");
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
  }

  void handleTimeout() {
    // callback function
    // Do some work.
    setState(() {
      firststate = true;
    });
  }

  Timer scheduleTimeout([int milliseconds = 10000]) =>
      Timer(Duration(milliseconds: milliseconds), handleTimeout);
  //running detections on image
  Future runObjectDetection() async {
    setState(() {
      firststate = false;
      message = false;
    });
    //pick an image
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    objDetect = await _objectModel.getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.1,
        IOUThershold: 0.3);
    objDetect.forEach((element) {
      print({
        "score": element?.score,
        "className": element?.className,
        "class": element?.classIndex,
        "rect": {
          "left": element?.rect.left,
          "top": element?.rect.top,
          "width": element?.rect.width,
          "height": element?.rect.height,
          "right": element?.rect.right,
          "bottom": element?.rect.bottom,
        },
      });
    });
    scheduleTimeout(5 * 1000);
    setState(() {
      _image = File(image.path);
    });
  }

  Future<void> showImagePopup() async {
    setState(() {
      _popupOpen = true;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _image != null
                        ? Image.file(
                      _image!,
                      fit: BoxFit.cover,
                    )
                        : Container(),
                    SizedBox(height: 16),
                    _prediction.isNotEmpty
                        ? Column(
                      children: _prediction.map((prediction) {
                        return Text(
                          "Prediction: $prediction",
                          style: TextStyle(fontSize: 16),
                        );
                      }).toList(),
                    )
                        : Container(),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _popupOpen = false; // Set popup state to false.
                        });
                        Navigator.of(context).pop(); // Close the dialog.
                      },
                      child: Text("OK"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _image = null;
                          _popupOpen = false;
                        });
                        runObjectDetection().then((_) {
                          if (objDetect.isNotEmpty) {
                            ResultObjectDetection? highestScorePrediction =
                            objDetect.reduce((a, b) => a!.score > b!.score ? a : b);
                            if (highestScorePrediction != null) {
                              String prediction =
                                  "${highestScorePrediction.className} (${highestScorePrediction.score.toStringAsFixed(2)})";
                              setState(() {
                                _prediction.add(prediction);
                              });
                            }
                          }
                          showImagePopup();
                        });
                      },
                      child: Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _popupOpen = false; // Close the popup after it's dismissed.
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OBJECT DETECTOR APP")),
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
              child: _image != null
                  ? Image.file(
                _image!,
                fit: BoxFit.contain,
              )
                  : null,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_prediction.isNotEmpty)
                    Text(
                      _prediction.last,
                      style: TextStyle(fontSize: 16),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          runObjectDetection().then((_) {
            if (objDetect.isNotEmpty) {
              ResultObjectDetection? highestScorePrediction =
              objDetect.reduce((a, b) => a!.score > b!.score ? a : b);
              if (highestScorePrediction != null) {
                String prediction =
                    "${highestScorePrediction.className} (${highestScorePrediction.score.toStringAsFixed(2)})";
                setState(() {
                  _prediction.add(prediction);
                });
              }
            }
            showImagePopup();
          });
        },
        child: const Icon(Icons.camera),
      ),
    );
  }
}