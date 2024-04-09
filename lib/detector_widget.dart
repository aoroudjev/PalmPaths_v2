import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:palm_paths_flutter/detector_service.dart';
import 'package:palm_paths_flutter/recognition.dart';
import 'package:palm_paths_flutter/screen_params.dart';


class DetectorWidget extends StatefulWidget {
  const DetectorWidget({super.key});

  @override
  State<DetectorWidget> createState() => _DetectorWidgetState();
}

class _DetectorWidgetState extends State<DetectorWidget> with WidgetsBindingObserver {

  late List<CameraDescription> cameras;

  CameraController? _cameraController;

  get _controller => _cameraController;

  /// Object Detector is running on a background [Isolate]. This is nullable
  /// because acquiring a [Detector] is an asynchronous operation. This
  /// value is `null` until the detector is initialized.
  Detector? _detector;
  StreamSubscription? _subscription;

  /// Results to draw bounding boxes
  List<Recognition>? results;

  /// Realtime stats
  Map<String, String>? stats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initStateAsync();
  }

  void _initStateAsync(){
    // initialize preview and CameraImage stream
    _initializeCamera();

  }

  void _initializeCamera() async {
    cameras = await availableCameras();

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    )..initialize().then((_) async {
      await _controller.startImageStream(onLatestImageAvailable);
      setState(() {
        ScreenParams.previewSize = _controller.value.previewSize!;
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    // Return empty container while the camera is not initialized
    if (_cameraController == null || !_controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    var aspect = 1 / _controller.value.aspectRatio;

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: aspect,
          child: CameraPreview(_controller),
        ),
        // Stats
        _statsWidget(),
        // Bounding boxes
        AspectRatio(
          aspectRatio: aspect,
          child: _boundingBoxes(),
        ),
      ],
    );
  }

  Widget _statsWidget() => (stats != null)
      ? Align(
    alignment: Alignment.bottomCenter,
    child: Container(
      color: Colors.white.withAlpha(150),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: stats!.entries
              .map((e) => StatsWidget(e.key, e.value))
              .toList(),
        ),
      ),
    ),
  )
      : const SizedBox.shrink();
}