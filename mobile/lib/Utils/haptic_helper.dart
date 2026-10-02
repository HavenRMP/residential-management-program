import 'package:flutter/services.dart';

/// Utilidad para proporcionar retroalimentación háptica consistente en la app.
class HapticHelper {
  /// Vibración muy ligera para pulsaciones de botones comunes o chips.
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Vibración media para confirmar acciones exitosas (escaneo QR exitoso, código copiado, guardado).
  static Future<void> success() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Vibración fuerte o patrón para indicar advertencias o errores.
  static Future<void> error() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Clic de selección táctil al cambiar de pestaña o alternar filtros/switches.
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
