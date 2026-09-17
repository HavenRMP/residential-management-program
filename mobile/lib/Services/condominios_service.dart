import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';

class CondominiosService {
  final AppController controller;

  CondominiosService(this.controller);

  String get baseUrl => dotenv.env['API_BASE_URL_CONDOMINIOS'] ?? 'https://condominios-api-vv32.onrender.com';

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

  Future<Map<String, dynamic>?> redimirCodigo(String codigo, {String? usuarioId}) async {
    final url = '$baseUrl/api/codigos/condominio/redimir';
    final payload = {'codigo': codigo};
    if (usuarioId != null) payload['usuarioId'] = usuarioId;
    
    try {
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {'success': true};
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (!decoded.containsKey('success')) decoded['success'] = true;
          return decoded;
        }
        return {'success': true, 'data': decoded};
      } else {
        try {
          final errDecoded = jsonDecode(response.body);
          if (errDecoded is Map && errDecoded['error'] != null) {
            return {'error': errDecoded['error']};
          }
        } catch (_) {}
        return {'error': 'Error HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
