import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:palm_paths_flutter/image_utils.dart';

import 'detector.dart';


class LiveObjectDetection extends StatefulWidget {
  final CameraDescription camera;

  const LiveObjectDetection({super.key, required this.camera});

  @override
  _LiveObjectDetectionState createState() => _LiveObjectDetectionState();
}

class _LiveObjectDetectionState extends State<LiveObjectDetection> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  Uint8List? processedImageData;
  bool isProcessing = false;
  final detector = Detector();

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.low,
    );

    _initializeControllerFuture = _controller!.initialize().then((_) {
      // Start the image stream after the controller is initialized
      if (!mounted) {
        return;
      }
      setState(() {});

      _controller!.startImageStream((CameraImage image) async {
        if (isProcessing) return;

        isProcessing = true;

        try {
          // Analyze image frame
          final image_lib.Image? convertedImage = await convertCameraImageToImage(image);
          final Uint8List? processedImage = detector.analyzeImage(convertedImage!);

          setState(() {
            processedImageData = processedImage;
          });
        } catch(e) {
          if (kDebugMode) {
            print(e);
          }
        } finally {
          isProcessing = false;
        }
      });
    });
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Object Detection')),
      // Wait until the controller is initialized before displaying the camera preview
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return Stack(
              children: [
                CameraPreview(_controller!),
                if (processedImageData != null)
                  Positioned.fill(
                    child: Image.memory(processedImageData!, fit: BoxFit.cover),
                  ),
                // You can add more widgets here to overlay additional information
              ],
            );
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}