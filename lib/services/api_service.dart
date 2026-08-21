import 'dart:math';
import 'package:flutter/foundation.dart';

class ApiService {
  static Future<bool> uploadImage(String path) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Simulate random success/failure
    // 70% success rate to demonstrate retries
    final random = Random().nextDouble();
    if (random < 0.7) {
      debugPrint("Upload success: $path");
      return true;
    } else {
      debugPrint("Upload failed: $path");
      return false;
    }
  }
}
