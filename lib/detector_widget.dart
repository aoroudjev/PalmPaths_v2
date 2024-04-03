import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';


class LiveObjectDetection extends StatefulWidget {
  final CameraDescription camera;

  const LiveObjectDetection({super.key, required this.camera});

  @override
  _LiveObjectDetectionState createState() => _LiveObjectDetectionState();
}

class _LiveObjectDetectionState extends State<LiveObjectDetection> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller!.initialize().then((_) {
      // Start the image stream after the controller is initialized
      if (!mounted) {
        return;
      }
      setState(() {});

      _controller!.startImageStream((CameraImage image) async {
      //   Process Image here
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
      appBar: AppBar(title: Text('Live Object Detection')),
      // Wait until the controller is initialized before displaying the camera preview
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller!);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}