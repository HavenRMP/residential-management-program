import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Utilidad para proporcionar retroalimentación háptica consistente y confiable en la app.
class HapticHelper {
  static DateTime _lastLightTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Vibración ligera para pulsaciones de botones comunes, chips, etc.
  static Future<void> light() async {
    final now = DateTime.now();
    if (now.difference(_lastLightTime).inMilliseconds < 40) return;
    _lastLightTime = now;

    try {
      if (kIsWeb) return;
      if (Platform.isAndroid) {
        // En Android, HapticFeedback.lightImpact() mapea a VIRTUAL_KEY, el cual es ignorado
        // por la gran mayoría de capas OEM (Xiaomi/MIUI/HyperOS, Samsung, Pixel) cuando
        // la navegación por gestos está activa.
        // HapticFeedback.mediumImpact() utiliza KEYBOARD_TAP, que es exactamente la vibración
        // háptica que sí responde en el teclado del sistema.
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Vibración media para confirmar acciones exitosas (escaneo QR exitoso, código copiado, guardado).
  static Future<void> success() async {
    try {
      if (kIsWeb) return;
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Vibración fuerte o de alerta para indicar advertencias o errores.
  static Future<void> error() async {
    try {
      if (kIsWeb) return;
      // heavyImpact en Android usa CONTEXT_CLICK (no produce vibración en teléfonos).
      // HapticFeedback.vibrate() activa la vibración háptica de alerta del sistema.
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  /// Clic de selección táctil al cambiar de pestaña o alternar filtros/switches.
  static Future<void> selection() async {
    try {
      if (kIsWeb) return;
      if (Platform.isAndroid) {
        // En Android muchos fabricantes no vibran con CLOCK_TICK (selectionClick).
        // Usamos mediumImpact para garantizar sensación táctil nítida.
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }
}
