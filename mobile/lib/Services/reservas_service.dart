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

  /// POST /api/areas (Admin)
  Future<Map<String, dynamic>> crearArea({
    required String nombre,
    String? descripcion,
    required String horaApertura,
    required String horaCierre,
  }) async {
    try {
      final url = '$baseUrl/api/areas';
      final body = jsonEncode({
        'nombre': nombre.trim(),
        if (descripcion != null && descripcion.trim().isNotEmpty)
          'descripcion': descripcion.trim(),
        'horaApertura': horaApertura,
        'horaCierre': horaCierre,
      });

      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: body,
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
        defaultMessage: 'No se pudo crear el área común.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al registrar área común.',
        ),
      };
    }
  }

  /// PATCH /api/areas/{id} (Admin)
  Future<Map<String, dynamic>> actualizarArea(
    String id, {
    String? nombre,
    String? descripcion,
    String? horaApertura,
    String? horaCierre,
  }) async {
    try {
      final url = '$baseUrl/api/areas/$id';
      final bodyMap = <String, dynamic>{};
      if (nombre != null) bodyMap['nombre'] = nombre.trim();
      if (descripcion != null) bodyMap['descripcion'] = descripcion.trim();
      if (horaApertura != null) bodyMap['horaApertura'] = horaApertura;
      if (horaCierre != null) bodyMap['horaCierre'] = horaCierre;

      final response = await controller.httpClient.patch(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(bodyMap),
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
        defaultMessage: 'No se pudo actualizar el área común.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al actualizar área común.',
        ),
      };
    }
  }

  /// POST /api/areas/{id}/baja (Admin)
  Future<Map<String, dynamic>> bajaArea(String id) async {
    try {
      final url = '$baseUrl/api/areas/$id/baja';
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo dar de baja el área común.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al dar de baja el área común.',
        ),
      };
    }
  }

  /// POST /api/areas/{id}/reactivar (Admin)
  Future<Map<String, dynamic>> reactivarArea(String id) async {
    try {
      final url = '$baseUrl/api/areas/$id/reactivar';
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo reactivar el área común.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al reactivar el área común.',
        ),
      };
    }
  }

  /// GET /api/reservas/calendario
  Future<Map<String, dynamic>> getCalendario({
    required DateTime from,
    required DateTime to,
    String? areaId,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final fromIso = Uri.encodeComponent(from.toUtc().toIso8601String());
      final toIso = Uri.encodeComponent(to.toUtc().toIso8601String());
      var query = 'from=$fromIso&to=$toIso&page=$page&pageSize=$pageSize';
      if (areaId != null && areaId.isNotEmpty) {
        query += '&areaId=${Uri.encodeComponent(areaId)}';
      }

      final url = '$baseUrl/api/reservas/calendario?$query';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final reservas = itemsRaw
              .map((j) => ReservaModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': reservas,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? reservas.length,
          };
        }
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo cargar el calendario.',
      );
      return {'success': false, 'error': error, 'items': <ReservaModel>[]};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al consultar el calendario.',
        ),
        'items': <ReservaModel>[],
      };
    }
  }

  /// GET /api/reservas/mias
  Future<Map<String, dynamic>> getMisReservas({
    String? estado,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      var query = 'page=$page&pageSize=$pageSize';
      if (estado != null && estado.isNotEmpty) {
        query += '&estado=${Uri.encodeComponent(estado.toLowerCase())}';
      }

      final url = '$baseUrl/api/reservas/mias?$query';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final reservas = itemsRaw
              .map((j) => ReservaModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': reservas,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? reservas.length,
            'totalPages': decoded['totalPages'] ?? 1,
            'hasNextPage': decoded['hasNextPage'] ?? false,
          };
        }
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudieron consultar tus reservas.',
      );
      return {'success': false, 'error': error, 'items': <ReservaModel>[]};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al consultar tus reservas.',
        ),
        'items': <ReservaModel>[],
      };
    }
  }

  /// GET /api/reservas/por-aprobar-titular
  Future<Map<String, dynamic>> getPendientesTitular({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = 'page=$page&pageSize=$pageSize';
      final url = '$baseUrl/api/reservas/por-aprobar-titular?$query';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final reservas = itemsRaw
              .map((j) => ReservaModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': reservas,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? reservas.length,
            'totalPages': decoded['totalPages'] ?? 1,
          };
        }
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudieron consultar solicitudes pendientes.',
      );
      return {'success': false, 'error': error, 'items': <ReservaModel>[]};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al consultar solicitudes por aprobar.',
        ),
        'items': <ReservaModel>[],
      };
    }
  }
}
