import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../Models/subusuario.dart';
import 'app_controller.dart';

class SubusuariosService {
  final AppController controller;

  static const int maxSubusuarios = 2;

  SubusuariosService(this.controller);

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

  /// Carga los sub-usuarios e invitaciones pendientes de una vivienda
  /// (GET /api/subusuarios/mis-subusuarios?viviendaId={viviendaId})
  Future<List<SubusuarioItem>> getSubusuarios(int viviendaId) async {
    try {
      final url = '$baseUrl/api/subusuarios/mis-subusuarios?viviendaId=$viviendaId';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return [];
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map((item) => SubusuarioItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Genera una invitación para un nuevo sub-usuario
  /// (POST /api/subusuarios/invitar)
  Future<Map<String, dynamic>> invitarSubusuario({
    required int viviendaId,
    required String nombre,
    required String apellidos,
    required String email,
    required String telefono,
    required String parentesco,
  }) async {
    try {
      final url = '$baseUrl/api/subusuarios/invitar';
      final payload = {
        'vivienda_id': viviendaId,
        'nombre': nombre.trim(),
        'apellidos': apellidos.trim(),
        'email': email.trim(),
        'telefono': telefono.trim(),
        'parentesco': parentesco.trim(),
      };

      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return {
            'success': true,
            'item': SubusuarioItem.fromJson(decoded),
          };
        }
        return {'success': true};
      }

      String errorMsg = 'Error al invitar sub-usuario';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] != null) {
          errorMsg = decoded['error'].toString();
        }
      } catch (_) {}

      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Revoca un sub-usuario activo o cancela una invitación pendiente
  /// (DELETE /api/subusuarios/{id}?viviendaId={viviendaId}&isInvitacion={isInvitacion})
  Future<bool> revocarSubusuario(
    String id, {
    required int viviendaId,
    required bool isInvitacion,
  }) async {
    try {
      final url =
          '$baseUrl/api/subusuarios/$id?viviendaId=$viviendaId&isInvitacion=$isInvitacion';
      final response = await controller.httpClient.delete(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}
