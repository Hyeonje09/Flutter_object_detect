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
      _image = _image; // 팝업이 열릴 때에만 이미지 할당
      _popupOpen = true; // 팝업이 열림을 나타냄
    });

    await showDialog(
      context: context,
      builder: (BuildContext context) {
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
                    Navigator.of(context).pop();
                    setState(() {
                      _image = null; // 팝업이 닫힐 때 이미지 초기화
                      _popupOpen = false; // 팝업이 닫힘을 나타냄
                    });
                  },
                  child: Text("Close"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OBJECT DETECTOR APP")),
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            !firststate
                ? !message
                ? LoaderState()
                : Text("Select the Camera to Begin Detections")
                : Container(
              width: 416,
              height: 416,
              color: _popupOpen ? Colors.white : null, // 팝업이 열려있을 때는 배경을 흰색으로 설정
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _popupOpen
                        ? Container() // 팝업이 열려있을 때는 이미지를 출력하지 않음
                        : _image != null
                        ? Image.file(
                      _image!,
                      fit: BoxFit.cover,
                    )
                        : Container(),
                  ),
                  Positioned.fill(
                    child: _popupOpen
                        ? Container() // 팝업이 열려있을 때는 이미지를 출력하지 않음
                        : _objectModel.renderBoxesOnImage(
                      _image!,
                      objDetect,
                    ),
                  ),
                  Positioned(
                    // Adjust the position according to your needs
                    top: 20,
                    left: 20,
                    child: Container(
                      width: 100,
                      height: 100,
                      child: _image != null
                          ? Image.file(
                        _image!,
                        fit: BoxFit.cover,
                      )
                          : Container(),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Visibility(
                visible: _imagePrediction != null,
                child: Text("$_imagePrediction"),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                runObjectDetection().then((_) {
                  // Set the prediction result
                  if (objDetect.isNotEmpty) {
                    ResultObjectDetection? highestScorePrediction =
                    objDetect.reduce((a, b) =>
                    a!.score > b!.score ? a : b);
                    if (highestScorePrediction != null) {
                      String prediction =
                          "${highestScorePrediction.className} (${highestScorePrediction.score.toStringAsFixed(2)})";
                      setState(() {
                        _prediction.add(prediction);
                      });
                    }
                  }
                  // Show the image popup
                  showImagePopup();
                });
              },
              child: const Icon(Icons.camera),
            ),
          ],
        ),
      ),
    );
  }
}