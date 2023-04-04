import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite/tflite.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  CameraScreen(this.cameras);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController _controller;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();

    // Initialize camera controller
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    // Load TensorFlow Lite model
    loadModel().then((value) {
      setState(() {});
    });

    // Start camera preview
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});

      // Start streaming camera frames
      _controller.startImageStream((CameraImage image) {
        if (_isDetecting) return;

        // Set flag to prevent duplicate processing
        _isDetecting = true;

        // Process camera frame with TensorFlow Lite model
        processCameraFrame(image).then((value) {
          // Clear flag to enable processing next frame
          _isDetecting = false;
        });
      });
    });
  }

  @override
  void dispose() {
    // Dispose camera controller and TensorFlow Lite interpreter
    _controller?.dispose();
    Tflite.close();

    super.dispose();
  }

  Future loadModel() async {
    // Load pre-trained TensorFlow Lite model
    try {
      String res = await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
      );
      print(res);
    } on PlatformException {
      print("Failed to load model.");
    }
  }

  Future processCameraFrame(CameraImage image) async {
    // Convert camera frame to TensorFlow Lite input format
    var recognitions = await Tflite.runModelOnFrame(
      bytesList: image.planes.map((plane) {
        return plane.bytes;
      }).toList(),
      imageHeight: image.height,
      imageWidth: image.width,
      imageMean: 127.5,
      imageStd: 127.5,
      rotation: 90,
      numResults: 1,
    );

    // Get the top recognition result
    var recognition = recognitions.isNotEmpty ? recognitions[0] : null;

    // Zoom camera to fit detected object
    if (recognition != null && recognition["confidence"] > 0.8) {
      var left = max(0, recognition["rect"]["x"] - 50);
      var top = max(0, recognition["rect"]["y"] - 50);
      var right = min(image.width, recognition["rect"]["x"] + recognition["rect"]["w"] + 50);
      var bottom = min(image.height, recognition["rect"]["y"] + recognition["rect"]["h"] + 50);

      var zoom = 1.0;
      if (right - left > bottom - top) {
        zoom = _controller.value.previewSize.height / (right - left);
      } else {
        zoom = _controller.value.previewSize.width / (bottom - top);
      }
    }}}