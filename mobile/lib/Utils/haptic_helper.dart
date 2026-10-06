import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Utilidad para proporcionar retroalimentación háptica consistente y confiable en la app.
class HapticHelper {
  static DateTime _lastLightTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Vibración estándar con mayor intensidad para pulsaciones de botones comunes, chips, etc.
  static Future<void> light() async {
    final now = DateTime.now();
    if (now.difference(_lastLightTime).inMilliseconds < 40) return;
    _lastLightTime = now;

    try {
      if (kIsWeb) return;
      if (Platform.isAndroid) {
        // En Android, HapticFeedback.vibrate() invoca HapticFeedbackConstants.LONG_PRESS,
        // lo que produce un pulso háptico firme, nítido y universalmente compatible en todos los
        // fabricantes (Samsung, Xiaomi, Pixel), proporcionando mayor intensidad que KEYBOARD_TAP.
        await HapticFeedback.vibrate();
      } else {
        // En iOS, mediumImpact genera una respuesta de Taptic Engine firme y perceptible,
        // con mayor presencia e impacto que lightImpact.
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Vibración de confirmación para acciones exitosas (escaneo QR exitoso, código copiado, guardado).
  static Future<void> success() async {
    try {
      if (kIsWeb) return;
      if (Platform.isAndroid) {
        // Doble pulso táctil para sensación de confirmación ("ba-bump")
        await HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 90));
        await HapticFeedback.vibrate();
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  /// Vibración fuerte de alerta para indicar advertencias o errores (patrón triple o doble).
  static Future<void> error() async {
    try {
      if (kIsWeb) return;
      if (Platform.isAndroid) {
        await HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 70));
        await HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 70));
        await HapticFeedback.vibrate();
      } else {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 70));
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  /// Clic de selección táctil al cambiar de pestaña o alternar filtros/switches.
  static Future<void> selection() async {
    try {
      if (kIsWeb) return;
      if (Platform.isAndroid) {
        // En Android usamos mediumImpact (KEYBOARD_TAP) para un tacto sutil pero perceptible al alternar tabs.
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }
}
