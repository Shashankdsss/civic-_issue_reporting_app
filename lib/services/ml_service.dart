import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class MLService {
  static final MLService instance = MLService._internal();

  factory MLService() {
    return instance;
  }

  MLService._internal();

  Interpreter? _interpreter;
  List<String>? _labels;

  bool get isInterpreterLoaded => _interpreter != null;

  Future<void> loadModel() async {
    try {
      if (_interpreter != null) return;
      _interpreter = await Interpreter.fromAsset('assets/models/civic_issues_model.tflite');
      print('TFLite Model loaded successfully');
      await _loadLabels();
    } catch (e) {
      print('Failed to load TFLite model: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsData.split('\n').where((s) => s.trim().isNotEmpty).toList();
    } catch (e) {
      print('Failed to load labels (using defaults): $e');
      _labels = ['Garbage', 'Pothole', 'Water Leak', 'Other']; 
    }
  }

  Future<String?> classifyImage(File imageFile) async {
    if (_interpreter == null) {
      print("Interpreter not loaded.");
      return null;
    }

    try {
      var imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      // Resize image to 224x224 (Standard for MobileNetV2)
      img.Image resizedImage = img.copyResize(originalImage, width: 224, height: 224);
      
      // Convert to normalized Float32 array
      var input = List.generate(
        1, (i) => List.generate(
          224, (y) => List.generate(
            224, (x) {
              final pixel = resizedImage.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0
              ];
            }
          )
        )
      );

      var outputShape = _interpreter!.getOutputTensor(0).shape; // usually [1, num_classes]
      int numClasses = outputShape[1];
      
      var output = List.generate(1, (i) => List.filled(numClasses, 0.0));

      _interpreter!.run(input, output);

      int maxIndex = 0;
      double maxProb = output[0][0];
      for (int i = 1; i < output[0].length; i++) {
        if (output[0][i] > maxProb) {
          maxProb = output[0][i];
          maxIndex = i;
        }
      }

      String detectedClass = _labels != null && maxIndex < _labels!.length
          ? _labels![maxIndex]
          : 'Class $maxIndex';

      return "$detectedClass (${(maxProb * 100).toStringAsFixed(1)}%)";
    } catch (e) {
      print("Error classifying image: $e");
      return null;
    }
  }
}
