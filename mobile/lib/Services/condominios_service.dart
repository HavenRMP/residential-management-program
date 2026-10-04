import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../Utils/error_handler.dart';
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
    try {
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
      return {
        'error': ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No se pudo generar el código del condominio.',
        ),
      };
    } catch (e) {
      return {
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al generar código de condominio.',
        ),
      };
    }
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
        return {
          'error': ErrorHandler.extractErrorMessage(
            response.body,
            statusCode: response.statusCode,
            defaultMessage: 'No se pudo canjear el código del condominio.',
          ),
        };
      }
    } catch (e) {
      return {
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al canjear el código.',
        ),
      };
    }
  }
}
