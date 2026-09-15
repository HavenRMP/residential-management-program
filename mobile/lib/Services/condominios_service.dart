import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';

class CondominiosService {
  final AppController controller;

  CondominiosService(this.controller);

  String get baseUrl => dotenv.env['API_BASE_URL_USUARIOS'] ?? ''; // Condominios is usually tied to Usuarios base url in this project based on earlier grep

  Future<Map<String, String>> _getHeaders() async {
    final token = await controller.getValidAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>?> generarCodigo(String condominioId, {int? minutosVigencia}) async {
    final url = '$baseUrl/api/condominios/$condominioId/codigo';
    final payload = minutosVigencia != null ? {'minutosVigencia': minutosVigencia} : {};
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

  Future<Map<String, dynamic>?> redimirCodigo(String codigo) async {
    final url = '$baseUrl/api/codigos/condominio/redimir';
    final payload = {'codigo': codigo};
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
}
