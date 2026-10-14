import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'haptic_helper.dart';

/// Helper para retroalimentación sonora en el escaneo de accesos y caseta de vigilancia.
class SoundHelper {
  static AudioPlayer? _player;
  static Uint8List? _beepSuccessBytes;
  static Uint8List? _beepErrorBytes;

  static AudioPlayer get _audioPlayer {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Genera un buffer WAV de onda senoidal de corta duración en memoria.
  static Uint8List _generateWavTone({
    required double frequency,
    required double durationSeconds,
    double volume = 0.5,
    int sampleRate = 44100,
  }) {
    final numSamples = (durationSeconds * sampleRate).toInt();
    final dataSize = numSamples * 2; // 16-bit mono = 2 bytes per sample
    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    buffer.setUint8(8, 0x57);  // 'W'
    buffer.setUint8(9, 0x41);  // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size
    buffer.setUint16(20, 1, Endian.little);  // PCM format
    buffer.setUint16(22, 1, Endian.little);  // Mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    buffer.setUint16(32, 2, Endian.little);  // Block align
    buffer.setUint16(34, 16, Endian.little); // Bits per sample

    // data subchunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataSize, Endian.little);

    // PCM samples con atenuación de envolvente suave
    final maxAmp = 32767.0 * volume;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Envolvente de decaimiento suave para evitar clicks acústicos
      final envelope = (i < numSamples * 0.1)
          ? (i / (numSamples * 0.1))
          : (1.0 - (i / numSamples));
      final sample = (math.sin(2 * math.pi * frequency * t) * maxAmp * envelope).toInt();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  /// Beep corto y nítido (880 Hz) para confirmación de detección de código QR en escáner.
  static Future<void> playScannerBeep() async {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticHelper.success();

      _beepSuccessBytes ??= _generateWavTone(
        frequency: 880.0,
        durationSeconds: 0.12,
        volume: 0.65,
      );

      await _audioPlayer.play(BytesSource(_beepSuccessBytes!));
    } catch (e) {
      debugPrint('[SoundHelper] Error reproduciendo scanner beep: $e');
    }
  }

  /// Tono positivo de validación exitosa de pase en caseta (1046 Hz, C6).
  static Future<void> playSuccessBeep() async {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticHelper.success();

      _beepSuccessBytes ??= _generateWavTone(
        frequency: 1046.5,
        durationSeconds: 0.18,
        volume: 0.7,
      );

      await _audioPlayer.play(BytesSource(_beepSuccessBytes!));
    } catch (e) {
      debugPrint('[SoundHelper] Error reproduciendo success beep: $e');
    }
  }

  /// Tono grave de advertencia / pase inválido o expirado (320 Hz).
  static Future<void> playErrorBeep() async {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticHelper.error();

      _beepErrorBytes ??= _generateWavTone(
        frequency: 320.0,
        durationSeconds: 0.25,
        volume: 0.75,
      );

      await _audioPlayer.play(BytesSource(_beepErrorBytes!));
    } catch (e) {
      debugPrint('[SoundHelper] Error reproduciendo error beep: $e');
    }
  }

  /// Libera recursos del reproductor de audio.
  static Future<void> dispose() async {
    try {
      await _player?.dispose();
      _player = null;
    } catch (_) {}
  }
}
