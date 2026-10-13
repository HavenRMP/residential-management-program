import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';
import '../Models/area_comun_model.dart';
import '../Models/reserva_model.dart';
import '../Models/bloqueo_model.dart';
import '../Utils/error_handler.dart';

class ReservasService {
  final AppController controller;

  ReservasService(this.controller);

  String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL_RESERVAS'];
    if (envUrl != null &&
        envUrl.trim().isNotEmpty &&
        !envUrl.contains('haven.app')) {
      return envUrl.trim();
    }
    return 'https://reservas-api.onrender.com';
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await controller.getValidAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// GET /api/areas
  Future<Map<String, dynamic>> getAreas({
    bool soloActivas = true,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final query = 'soloActivas=$soloActivas&page=$page&pageSize=$pageSize';
      final url = '$baseUrl/api/areas?$query';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final areas = itemsRaw
              .map((j) => AreaComunModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': areas,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? areas.length,
            'totalPages': decoded['totalPages'] ?? 1,
            'hasNextPage': decoded['hasNextPage'] ?? false,
          };
        }
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudieron consultar las áreas comunes.',
      );
      return {'success': false, 'error': error, 'items': <AreaComunModel>[]};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de conexión al consultar las áreas comunes.',
        ),
        'items': <AreaComunModel>[],
      };
    }
  }

  /// GET /api/areas/{id}
  Future<Map<String, dynamic>> getAreaById(String id) async {
    try {
      final url = '$baseUrl/api/areas/$id';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'area': AreaComunModel.fromJson(decoded as Map<String, dynamic>),
        };
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'Área común no encontrada.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de conexión al obtener el área común.',
        ),
      };
    }
  }
}
