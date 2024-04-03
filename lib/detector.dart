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

  Uint8List? analyzeImage(img.Image image) {
    //Analyze image and run inference with a returned image with bounding boxes
    // Model requires 320x320 sized image

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

    final scoresTensor = output[0].first as List<double>;
    final boxesTensor = output[1].first as List<List<double>>;

    log('Processing outputs...');

    final List<List<int>> locations = boxesTensor
        .map((box) => box.map((value) => ((value * 300).toInt())).toList())
        .toList();
    final numberOfDetections = output[2].first as double;

    log('Outlining objects...');

    for (var i = 0; i < numberOfDetections; i++) {
      if (scoresTensor[i] > 0.85) {
        // Object
        img.drawRect(
          imageInput,
          x1: locations[i][1],
          y1: locations[i][0],
          x2: locations[i][3],
          y2: locations[i][2],
          color: img.ColorRgb8(0, 255, 0),
          thickness: 3,
        );

        // Label
        img.drawString(
          imageInput,
          'palm: ${scoresTensor[i]}',
          font: img.arial14,
          x: locations[i][1] + 7,
          y: locations[i][0] + 7,
          color: img.ColorRgb8(0, 255, 0),
        );
      }
    }

    log('Done.');
    return img.encodeJpg(imageInput);
  }

  List<List<Object>> _runInference(
      List<List<List<num>>> imageMatrix,
      ) {
    log('Running inference...');

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