import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'package:tflite_flutter/tflite_flutter.dart';

class Detector {
  static const _modelPath = 'assets/detect.tflite';

  Interpreter? _interpreter;

  Detector(){
    _loadModel();
    log('Done.');
  }


  Future<void> _loadModel() async {
    log('Loading interpreter options...');
    final interpreterOptions = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      interpreterOptions.addDelegate(XNNPackDelegate());
    }

    // Use Metal Delegate
    if (Platform.isIOS) {
      interpreterOptions.addDelegate(GpuDelegate());
    }

    log('Loading interpreter...');
    _interpreter =
    await Interpreter.fromAsset(_modelPath, options: interpreterOptions);
  }

  Uint8List? analyzeImage(imageData) {
    //Analyze image and run inference with a returned image with bounding boxes
    final image = img.decodeImage(imageData);

    if (image == null) {
      throw Exception("Failed to decode image.");
    }

    final imageInput = img.copyResize(image, width: 320, height: 320);

    final imageMatrix = List.generate(
      imageInput.height,
          (y) => List.generate(
        imageInput.width,
            (x) {
          final pixel = imageInput.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0]; // Normalize values for model input
        },
      ),
    );

    final output = _runInference(imageMatrix);
    return img.encodeJpg(imageInput);
  }

  List<List<Object>> _runInference(
      List<List<List<num>>> imageMatrix,
      ) {
    log('Running inference...');

    // Set input tensor [1, 300, 300, 3]
    final input = [imageMatrix];

    // Set output tensor
    // Scores: [1, 10],
    // Locations: [1, 10, 4],
    // Number of detections: [1],
    // Classes: [1, 10],
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