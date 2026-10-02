import 'package:flutter/services.dart';

class HapticHelper {
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
