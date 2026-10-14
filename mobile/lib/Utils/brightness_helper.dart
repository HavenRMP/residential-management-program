import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Helper para gestionar el brillo de pantalla temporalmente al mostrar códigos QR.
class BrightnessHelper {
  static double? _previousBrightness;
  static bool _isMaximized = false;

  /// Eleva el brillo de la pantalla de la aplicación al 100% para facilitar el escaneo en caseta o garita.
  static Future<void> setMaxBrightness() async {
    if (kIsWeb) return;
    try {
      _previousBrightness = await ScreenBrightness().application;
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
      _isMaximized = true;
    } on PlatformException catch (e) {
      debugPrint('[BrightnessHelper] Error ajustando brillo máximo: $e');
    } catch (e) {
      debugPrint('[BrightnessHelper] Error inesperado en setMaxBrightness: $e');
    }
  }

  /// Restaura el brillo previo del dispositivo o restablece el brillo del sistema.
  static Future<void> resetBrightness() async {
    if (kIsWeb || !_isMaximized) return;
    try {
      if (_previousBrightness != null) {
        await ScreenBrightness().setApplicationScreenBrightness(_previousBrightness!);
      } else {
        await ScreenBrightness().resetApplicationScreenBrightness();
      }
    } on PlatformException catch (e) {
      debugPrint('[BrightnessHelper] Error restaurando brillo: $e');
    } catch (e) {
      debugPrint('[BrightnessHelper] Error inesperado en resetBrightness: $e');
    } finally {
      _isMaximized = false;
      _previousBrightness = null;
    }
  }
}
