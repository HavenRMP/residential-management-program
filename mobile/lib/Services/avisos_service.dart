import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';

class AvisosService {
  final AppController controller;

  AvisosService(this.controller);

  String get baseUrl => dotenv.env['API_BASE_URL_AVISOS'] ?? 'https://avisos-api-qg5b.onrender.com';

  Future<Map<String, String>> _getHeaders() async {
    final token = await controller.getValidAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>?> getAvisosVigentes({int page = 1, int pageSize = 10}) async {
    try {
      final url = '$baseUrl/api/avisos?page=$page&pageSize=$pageSize';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Error de conexión con el servicio de avisos.');
    }
  }

  Future<Map<String, dynamic>?> getAvisosHistorico({int page = 1, int pageSize = 10}) async {
    try {
      final url = '$baseUrl/api/avisos/historico?page=$page&pageSize=$pageSize';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Error de conexión con el servicio de avisos.');
    }
  }

  Future<Map<String, dynamic>?> createAviso(String titulo, String contenido, {int duracionDias = 7}) async {
    try {
      final url = '$baseUrl/api/avisos';
      final payload = {
        'titulo': titulo,
        'contenido': contenido,
        'duracionDias': duracionDias,
      };

      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      throw Exception('Error de conexión al crear aviso.');
    }
  }

  Future<Map<String, dynamic>?> updateAviso(String id, String titulo, String contenido) async {
    try {
      final url = '$baseUrl/api/avisos/$id';
      final payload = {
        'titulo': titulo,
        'contenido': contenido,
      };

      final response = await controller.httpClient.put(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      throw Exception('Error de conexión al actualizar aviso.');
    }
  }

  Future<bool> deleteAviso(String id) async {
    try {
      final url = '$baseUrl/api/avisos/$id';
      final response = await controller.httpClient.delete(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      throw Exception('Error de conexión al eliminar aviso.');
    }
  }
}
