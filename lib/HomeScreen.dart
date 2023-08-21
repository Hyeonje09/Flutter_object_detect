import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ModelObjectDetection _objectModel;
  List<String> _prediction = [];
  File? _image;
  ImagePicker _picker = ImagePicker();
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];
  bool firststate = false;
  bool message = true;
  bool _popupOpen = false;
  bool _showImageDetails = false;
  final Map<String, String> labelTranslations = {
    "clock": "시계",
    // 더 많은 라벨에 대한 번역 추가
  };

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
      if (element != null) {
        String englishLabel = element.className ?? "";
        String translatedLabel = labelTranslations[englishLabel] ?? englishLabel;
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
        if (translatedLabel.isNotEmpty) {
          String prediction = "$translatedLabel (${element.score.toStringAsFixed(2)})";
          setState(() {
            _prediction.add(prediction);
          });
        }
      }
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

    // Find the prediction with the highest probability
    String highestProbabilityPrediction = "";
    double highestProbability = 0.0;
    for (String prediction in _prediction) {
      double probability = double.parse(
          prediction.substring(prediction.lastIndexOf("(") + 1, prediction.lastIndexOf(")")));
      if (probability > highestProbability) {
        highestProbability = probability;
        highestProbabilityPrediction = prediction;
      }
    }


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
                    if (highestProbabilityPrediction.isNotEmpty)
                      Text(
                        highestProbabilityPrediction,
                        style: TextStyle(fontSize: 16),
                      ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _popupOpen = false; // 팝업 상태를 닫음.
                        });
                        Navigator.of(context).pop(); // 팝업 닫음.
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
                              String englishLabel = highestScorePrediction.className ?? "";
                              String translatedLabel = labelTranslations[englishLabel] ?? englishLabel;
                              String prediction =
                                  "$translatedLabel (${highestScorePrediction.score.toStringAsFixed(2)})";
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
        _popupOpen = false; // 팝업이 닫힌 후 팝업 상태를 업데이트.
        _showImageDetails = true; // 이미지 및 라벨 표시
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String highestProbabilityLabel = ""; // 초기화
    double highestProbability = 0.0;

    // Find the label with the highest probability in _prediction
    for (String prediction in _prediction) {
      double probability = double.parse(
          prediction.substring(prediction.lastIndexOf("(") + 1, prediction.lastIndexOf(")")));
      if (probability > highestProbability) {
        highestProbability = probability;
        highestProbabilityLabel = prediction;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("OBJECT DETECTOR APP")),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(height: 20), // 이미지 위 간격
          if (_showImageDetails) // 이미지 및 라벨 표시 여부 체크
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    height: 300, // 이미지 높이
                    child: Center(
                      child: _image != null
                          ? Image.file(
                        _image!,
                        fit: BoxFit.contain,
                      )
                          : null,
                    ),
                  ),
                ),
                SizedBox(width: 16), // 이미지와 라벨 간 간격
                Expanded(
                  flex: 1,
                  child: Container(
                    width: double.infinity,
                    height: 300, // 라벨 높이
                    child: Center(
                      child: Text(
                        highestProbabilityLabel,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_showImageDetails)
            SizedBox(height: 16), // 이미지와 텍스트 간 간격
          if (_showImageDetails)
            Container(
              width: double.infinity,
              height: 250, // 텍스트 박스 높이
              margin: EdgeInsets.all(16), // 테두리와의 간격 조정
              padding: EdgeInsets.all(8), // 텍스트와 테두리 간의 간격
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Text(
                "분리배출 방법은 다음과 같습니다. \n"
                    "\t 1. 시계의 배터리를 제거하고, 배터리는 전지류로 분리하여 배출합니다. \n"
                    "\t 2. 시계의 표면이나 뒷면에 재활용표시가 있는 경우, 해당 표시에 따라 플라스틱류나 금속류로 분리하여 배출합니다. \n"
                    "\t 3. 시계의 표면이나 뒷면에 재활용표시가 없는 경우, 소형가전제품으로 분리하여 배출합니다.", // 여기에 분리 배출 방법 텍스트 추가
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
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
                String englishLabel = highestScorePrediction.className ?? "";
                String translatedLabel =
                    labelTranslations[englishLabel] ?? englishLabel;
                String prediction =
                    "$translatedLabel (${highestScorePrediction.score.toStringAsFixed(2)})";
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