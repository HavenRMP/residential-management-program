import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';

class ViviendasService {
  final AppController controller;

  ViviendasService(this.controller);

  String get baseUrl => dotenv.env['API_BASE_URL_VIVIENDAS'] ?? '';

  Future<Map<String, String>> _getHeaders() async {
    final token = await controller.getValidAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<List<dynamic>> listar() async {
    final url = '$baseUrl/api/Viviendas';
    final response = await controller.httpClient.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['data'] is List) return decoded['data'];
    }
    return [];
  }

  Future<Map<String, dynamic>?> crear({required String numeroCasa, String? tipo}) async {
    final url = '$baseUrl/api/Viviendas';
    final payload = {'numeroCasa': numeroCasa, 'tipo': tipo};
    final response = await controller.httpClient.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> actualizar(int id, {required String numeroCasa, String? tipo}) async {
    final url = '$baseUrl/api/Viviendas/$id';
    final payload = {'numeroCasa': numeroCasa, 'tipo': tipo};
    final response = await controller.httpClient.put(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<bool> eliminar(int id) async {
    final url = '$baseUrl/api/Viviendas/$id';
    final response = await controller.httpClient.delete(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  Future<List<dynamic>> obtenerResidentesVivienda(int viviendaId) async {
    final url = '$baseUrl/api/Viviendas/$viviendaId/residentes';
    final response = await controller.httpClient.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['data'] is List) return decoded['data'];
    }
    return [];
  }

  Future<bool> vincularResidente(int viviendaId, String usuarioId) async {
    final url = '$baseUrl/api/Viviendas/$viviendaId/residentes';
    final response = await controller.httpClient.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode({'usuarioId': usuarioId}),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<bool> desvincularResidente(int viviendaId, String usuarioId) async {
    final url = '$baseUrl/api/Viviendas/$viviendaId/residentes/$usuarioId';
    final response = await controller.httpClient.delete(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
