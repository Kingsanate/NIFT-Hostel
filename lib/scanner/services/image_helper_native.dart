import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_editor/image_editor.dart';

/// Native (Android / iOS) implementation of face crop.
/// Uses Google ML Kit for face detection and image_editor (C++) for fast crop.
Future<String?> cropFaceNative(String imagePath) async {
  try {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.1,
      ),
    );

    final faces = await faceDetector.processImage(inputImage);
    faceDetector.close();

    if (faces.isEmpty) {
      debugPrint('No face detected for auto-crop.');
      return null;
    }

    faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
        .compareTo(a.boundingBox.width * a.boundingBox.height));
    final bbox = faces.first.boundingBox;

    // Add padding around the face
    final padX = bbox.width * 0.25;
    final padY = bbox.height * 0.25;

    final double x = (bbox.left - padX) > 0 ? (bbox.left - padX) : 0;
    final double y = (bbox.top - padY) > 0 ? (bbox.top - padY) : 0;
    final double w = bbox.width + (padX * 2);
    final double h = bbox.height + (padY * 2);

    final ImageEditorOption option = ImageEditorOption();
    option.addOption(ClipOption(
      x: x,
      y: y,
      width: w,
      height: h,
    ));
    option.addOption(ScaleOption(200, 200));

    // Native C++ memory-safe cropping (no Dart ui.Image decoding)
    final Uint8List? croppedBytes = await ImageEditor.editFileImage(
      file: File(imagePath),
      imageEditorOption: option,
    );

    if (croppedBytes != null) {
      return base64Encode(croppedBytes);
    }

    return null;
  } catch (e) {
    debugPrint('Native crop error: $e');
    return null;
  }
}
