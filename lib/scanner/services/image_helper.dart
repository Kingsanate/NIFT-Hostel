import 'package:flutter/foundation.dart';

// Conditional import: dart.library.io = mobile/desktop, stub = web
import 'image_helper_stub.dart'
    if (dart.library.io) 'image_helper_native.dart';

class ImageHelper {
  /// Detects a face in the image and crops it to a base64 string.
  ///
  /// On Android / iOS: uses Google ML Kit + image_editor (C++) for fast,
  /// memory-safe cropping.
  ///
  /// On Web: returns null (face detection is native-only). The caller
  /// already handles null gracefully by skipping the face crop step.
  static Future<String?> cropFaceFromImage(String imagePath) async {
    if (kIsWeb) {
      debugPrint('Face crop skipped on web — ML Kit is native-only.');
      return null;
    }
    return cropFaceNative(imagePath);
  }
}
