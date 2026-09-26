import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../Models/notificacion.dart';
import 'app_controller.dart';

class NotificacionesService {
  final AppController controller;

  NotificacionesService(this.controller);

  String get baseUrl =>
      dotenv.env['API_BASE_URL_USUARIOS'] ??
      'https://usuarios-api-n1qi.onrender.com';

  Future<Map<String, String>> _getHeaders() async {
    final token = await controller.getValidAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Carga la lista de notificaciones del usuario (GET /api/notificaciones)
  Future<List<Notificacion>> getNotificaciones() async {
    try {
      final url = '$baseUrl/api/notificaciones';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return [];
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map((item) => Notificacion.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Carga el conteo de notificaciones no leídas (GET /api/notificaciones/contador-no-leidas)
  Future<int> getContadorNoLeidas() async {
    try {
      final url = '$baseUrl/api/notificaciones/contador-no-leidas';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return 0;
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return (decoded['count'] as num?)?.toInt() ?? 0;
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Marca una notificación como leída (PATCH /api/notificaciones/{id}/leer)
  Future<bool> marcarComoLeida(String id) async {
    try {
      final url = '$baseUrl/api/notificaciones/$id/leer';
      final response = await controller.httpClient.patch(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({}),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// Marca todas las notificaciones como leídas (POST /api/notificaciones/marcar-todas)
  Future<bool> marcarTodasComoLeidas() async {
    try {
      final url = '$baseUrl/api/notificaciones/marcar-todas';
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({}),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}
