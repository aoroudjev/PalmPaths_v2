import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:palm_paths_flutter/detector_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MaterialApp(
    home: MyApp(camera: firstCamera),
  ));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFDAD3C1)),
      ),
      home: MainMenuScreen(camera: camera),  // Pass the camera to MainMenuScreen
    );
  }
}

class MainMenuScreen extends StatelessWidget {

  final CameraDescription camera;

  const MainMenuScreen({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDAD3C1),
      appBar: AppBar(
        title: const Text('Main Menu'),
        backgroundColor: Colors.black.withOpacity(0.5),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/hand_logo_large.png',
              height: 350,
            ),
            const SizedBox(
              height: 50,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => LiveObjectDetection(camera: camera,)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(
                      200, 50), // Set specific width and height
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(fontSize: 30),
                ),
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HistoryScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(200, 50),
                ),
                child: const Text(
                  'History',
                  style: TextStyle(fontSize: 30),
                ),
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () {
                  exit(0);
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(200, 50),
                ),
                child: const Text(
                  'Quit',
                  style: TextStyle(fontSize: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start'),
        backgroundColor: Colors.black.withOpacity(0.5),
      ),
      body: const Center(
        child: Text('Start Screen'),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.black.withOpacity(0.5),
      ),
      body: const Center(
        child: Text('History Screen'),
      ),
    );
  }
}
