import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar autenticación biométrica (Face ID, huella dactilar) y persistencia de preferencias.
class BiometricService {
  static const String keyBiometricEnabled = 'biometric_auth_enabled';

  final LocalAuthentication _localAuth;
  final SharedPreferences? _prefs;

  BiometricService({
    LocalAuthentication? localAuth,
    SharedPreferences? prefs,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Verifica si el hardware del dispositivo soporta biometría.
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verifica si el dispositivo puede evaluar biometría actualmente.
  Future<bool> canCheckBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Lista los tipos de biometría disponibles (huella, rostro, etc.).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Comprueba si el usuario tiene al menos un dato biométrico enrolado en el teléfono.
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final available = await getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Devuelve true si el usuario ha habilitado el inicio biométrico en la app.
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(keyBiometricEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Guarda la preferencia del usuario para habilitar o deshabilitar biometría.
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await _getPrefs();
      return await prefs.setBool(keyBiometricEnabled, enabled);
    } catch (_) {
      return false;
    }
  }

  /// Dispara el diálogo nativo de autenticación biométrica (Face ID / Huella).
  /// Retorna true si la autenticación fue exitosa.
  Future<bool> authenticate({
    String localizedReason = 'Confirma tu identidad para acceder a HAVEN',
  }) async {
    try {
      final canAuth = await canCheckBiometrics();
      if (!canAuth) return false;

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Detiene la autenticación si está en curso.
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (_) {}
  }
}
