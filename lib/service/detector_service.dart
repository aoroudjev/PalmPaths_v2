import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:palm_paths_flutter/util/image_utils.dart';
import 'package:palm_paths_flutter/util/recognition.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

enum _Codes {
  init,
  busy,
  ready,
  detect,
  result
}

class _Command {
  const _Command(this.code, {this.args});

  final _Codes code;
  final List<Object>? args;
}

class Detector {
  static const _modelPath = 'assets/detect.tflite';
  static const String _labelPath = 'assets/labelmap.txt';


  Detector._(this._isolate, this._interpreter, this._labels);

  final Isolate _isolate;
  late final Interpreter _interpreter;
  late final List<String> _labels;

  // To be used by detector (from UI) to send message to our Service ReceivePort
  late final SendPort _sendPort;

  bool _isReady = false;

  // // Similarly, StreamControllers are stored in a queue so they can be handled
  // // asynchronously and serially.
  final StreamController<Map<String, dynamic>> resultsStream =
    StreamController<Map<String, dynamic>>();


  static Future<Detector> start() async {
    final ReceivePort receivePort = ReceivePort();
    final Isolate isolate = await Isolate.spawn(_DetectorServer._run, receivePort.sendPort);

    final Detector result = Detector._(
      isolate,
      await _loadModel(),
      await _loadLabels(),
    );
    receivePort.listen((message) {
      result._handleCommand(message as _Command);
    });
    return result;
  }

  static Future<Interpreter> _loadModel() async {
    final interpreterOptions = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      interpreterOptions.addDelegate(XNNPackDelegate());
    }

    return Interpreter.fromAsset(
      _modelPath,
      options: interpreterOptions..threads = 4,
    );
  }

  static Future<List<String>> _loadLabels() async {
    return (await rootBundle.loadString(_labelPath)).split('\n');
  }

  /// Starts CameraImage processing
  void processFrame(CameraImage cameraImage) {
    if (_isReady) {
      _sendPort.send(_Command(_Codes.detect, args: [cameraImage]));
    }
  }

  void _handleCommand(_Command command) {
    switch (command.code) {
      case _Codes.init:
        _sendPort = command.args?[0] as SendPort;
        RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
        _sendPort.send(_Command(_Codes.init, args : [
          rootIsolateToken,
          _interpreter.address,
          _labels,
        ]));
      case _Codes.busy:
        _isReady = false;
      case _Codes.ready:
        _isReady = true;
      case _Codes.result:
        _isReady = true;
        resultsStream.add(command.args?[0] as Map<String, dynamic>);
      default:
        debugPrint('Detector unrecognized command: ${command.code}');
    }
  }

  void stop() {
    _isolate.kill();
  }
}

class _DetectorServer {
  static const int mlModelInputSize = 320;

  static const double confidence = 0.5;
  Interpreter? _interpreter;

  _DetectorServer(this._sendPort);
  final SendPort _sendPort;

  static void _run(SendPort sendPort) {
    ReceivePort receivePort = ReceivePort();
    final _DetectorServer server = _DetectorServer(sendPort);
    receivePort.listen((message) async {
      final _Command command = message as _Command;
      await server._handleCommand(command);
    });
  }

  Future<void> _handleCommand(_Command command) async{
    switch (command.code) {
      case _Codes.init:
        RootIsolateToken rootIsolateToken = command.args?[0] as RootIsolateToken;
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
        _interpreter = Interpreter.fromAddress(command.args?[1] as int);
        _sendPort.send(const _Command(_Codes.ready));
      case _Codes.detect:
        _sendPort.send(const _Command(_Codes.busy));
        _convertCameraImage(command.args?[0] as CameraImage);
      default:
        debugPrint('_DetectorService unrecognized command ${command.code}');
    }
  }

  void _convertCameraImage(CameraImage cameraImage) {
    var preConversionTime = DateTime.now().millisecondsSinceEpoch;

    convertCameraImageToImage(cameraImage).then((image) {
      if (image != null) {
        if (Platform.isAndroid){
          image = image_lib.copyRotate(image, angle: 90);
        }

        final results = analyseImage(image, preConversionTime);
        _sendPort.send(_Command(_Codes.result, args: [results]));
      }
    });
  }

  Map<String, dynamic> analyseImage(image_lib.Image? image, int preConversionTime) {
    var conversionElapsedTime = DateTime.now().millisecondsSinceEpoch - preConversionTime;
    var preProcessStart = DateTime.now().millisecondsSinceEpoch;

    final imageInput = image_lib.copyResize(
      image!,
      width: mlModelInputSize,
      height: mlModelInputSize,
    );

    final imageMatrix = List.generate(
      imageInput.height,
      (y) => List.generate(
        imageInput.width,
        (x) {
          final pixel = imageInput.getPixel(x, y);
          return [pixel.r/255, pixel.g/255, pixel.b/255];
        //   TODO: Fix this potential normalization issue
        },
      ),
    );

    var preProcessElapsedTime = DateTime.now().millisecondsSinceEpoch - preProcessStart;
    var inferenceTimeStart = DateTime.now().millisecondsSinceEpoch;

    final output = _runInference(imageMatrix);
    final locationsRaw = output[1].first as List<List<double>>;
    final List<Rect> locations = locationsRaw
        .map((list) => list.map((value) => (value * mlModelInputSize)).toList())
        .map((rect) => Rect.fromLTRB(rect[1], rect[0], rect[3], rect[2]))
        .toList();

    // Omitted Classes since we will be looking at 1 class but this can be re-added for future work
    // final classesRaw = output.elementAt(1).first as List<double>;
    // final classes = classesRaw.map((value) => value.toInt()).toList();


    final scores = output.first.first as List<double>;

    final numberOfDetectionsRaw = output[2].first as double;
    final numberOfDetections = numberOfDetectionsRaw.toInt();

    List<Recognition> recognitions = [];
    for (int i = 0; i < numberOfDetections; i++) {
      // Prediction score
      var score = scores[i];
      // Label string
      var label = 'palm';

      if (score > confidence) {
        recognitions.add(
          Recognition(i, label, score, locations[i]),
        );
      }
    }

    var inferenceElapsedTime =
        DateTime.now().millisecondsSinceEpoch - inferenceTimeStart;

    var totalElapsedTime =
        DateTime.now().millisecondsSinceEpoch - preConversionTime;

    return {
      "recognitions": recognitions,
      "stats": <String, String>{
        'Conversion time:': conversionElapsedTime.toString(),
        'Pre-processing time:': preProcessElapsedTime.toString(),
        'Inference time:': inferenceElapsedTime.toString(),
        'Total prediction time:': totalElapsedTime.toString(),
        'Frame': '${image.width} X ${image.height}',
      },
    };
  }

  List<List<Object>> _runInference(
      List<List<List<num>>> imageMatrix,
      ) {
    // Set input tensor [1, 300, 300, 3]
    final input = [imageMatrix];

    // Set output tensor
    // Scores: [1, 10],
    // Locations: [1, 10, 4],
    // Number of detections: [1],
    // Classes: [1, 10] *not included as we do not use them*,
    final output = {
      0: [List<num>.filled(10, 0)],
      1: [List<List<num>>.filled(10, List<num>.filled(4, 0))],
      2: [0.0],
      3: [List<num>.filled(10, 0)],
    };

    _interpreter!.runForMultipleInputs([input], output);
    return output.values.toList();
  }

}



