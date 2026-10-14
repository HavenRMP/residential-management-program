import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';
import '../Models/area_comun_model.dart';
import '../Models/reserva_model.dart';
import '../Models/bloqueo_model.dart';
import '../Utils/error_handler.dart';

class ReservasService {
  final AppController controller;

  ReservasService(this.controller);

  /// Tiempo de espera para peticiones HTTP del servicio de reservas.
  /// Configurado a 60 segundos para tolerar el arranque en frío (cold start) de instancias de Render.
  static const Duration requestTimeout = Duration(seconds: 60);

  String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL_RESERVAS'];
    if (envUrl != null &&
        envUrl.trim().isNotEmpty &&
        !envUrl.contains('haven.app')) {
      final trimmed = envUrl.trim();
      return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    }
    return 'https://reservas-api-hmos.onrender.com';
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
      var headers = await _getHeaders();
      var response = await controller.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(requestTimeout);

      if (response.statusCode == 401) {
        await controller.forceRefreshSession();
        headers = await _getHeaders();
        response = await controller.httpClient
            .get(Uri.parse(url), headers: headers)
            .timeout(requestTimeout);
      }

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

      // Direct Supabase fallback if backend returns error (such as 403 or 500)
      final fallbackResult = await _getAreasSupabaseFallback(soloActivas);
      if (fallbackResult != null) {
        return fallbackResult;
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudieron consultar las áreas comunes.',
        context: 'ReservasService.getAreas',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.getAreas');
      return {'success': false, 'error': error, 'items': <AreaComunModel>[]};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreas');
      final fallbackResult = await _getAreasSupabaseFallback(soloActivas);
      if (fallbackResult != null) return fallbackResult;
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al consultar áreas comunes.',
        'items': <AreaComunModel>[],
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreas');
      final fallbackResult = await _getAreasSupabaseFallback(soloActivas);
      if (fallbackResult != null) return fallbackResult;
      return {
        'success': false,
        'error': 'Sin conexión a internet al consultar áreas comunes.',
        'items': <AreaComunModel>[],
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreas');
      final fallbackResult = await _getAreasSupabaseFallback(soloActivas);
      if (fallbackResult != null) return fallbackResult;
      return {
        'success': false,
        'error': 'Error de comunicación al consultar áreas comunes.',
        'items': <AreaComunModel>[],
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreas');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al consultar áreas comunes.',
        'items': <AreaComunModel>[],
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreas');
      final fallbackResult = await _getAreasSupabaseFallback(soloActivas);
      if (fallbackResult != null) return fallbackResult;
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de conexión al consultar las áreas comunes.',
          context: 'ReservasService.getAreas',
        ),
        'items': <AreaComunModel>[],
      };
    }
  }

  Future<Map<String, dynamic>?> _getAreasSupabaseFallback(bool soloActivas) async {
    final sb = controller.supabaseClient;
    if (sb == null) return null;
    try {
      dynamic query = sb.from('vw_areas_comunes').select();
      if (soloActivas) {
        query = query.eq('activo', true);
      }
      final data = await query.order('nombre', ascending: true);
      if (data is List && data.isNotEmpty) {
        final areas = data
            .map((j) => AreaComunModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'items': areas,
          'page': 1,
          'pageSize': areas.length,
          'totalCount': areas.length,
          'totalPages': 1,
          'hasNextPage': false,
        };
      }
    } catch (e) {
      debugPrint('[ReservasService] Supabase fallback areas failed: $e');
    }
    return null;
  }

  /// GET /api/areas/{id}
  Future<Map<String, dynamic>> getAreaById(String id) async {
    try {
      final url = '$baseUrl/api/areas/$id';
      final response = await controller.httpClient
          .get(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

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
        context: 'ReservasService.getAreaById',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.getAreaById');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreaById');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al consultar detalle del área común.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreaById');
      return {
        'success': false,
        'error': 'Sin conexión a internet al consultar el área común.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreaById');
      return {
        'success': false,
        'error': 'Error de comunicación de red al consultar el área común.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreaById');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido del área común.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getAreaById');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de conexión al obtener el área común.',
          context: 'ReservasService.getAreaById',
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

      final response = await controller.httpClient
          .post(Uri.parse(url), headers: await _getHeaders(), body: body)
          .timeout(requestTimeout);

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
        context: 'ReservasService.crearArea',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.crearArea');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearArea');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al registrar área común.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearArea');
      return {
        'success': false,
        'error': 'Sin conexión a internet al registrar área común.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearArea');
      return {
        'success': false,
        'error': 'Error de comunicación de red al registrar área común.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearArea');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al crear área común.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearArea');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al registrar área común.',
          context: 'ReservasService.crearArea',
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

      final response = await controller.httpClient
          .patch(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode(bodyMap),
          )
          .timeout(requestTimeout);

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
        context: 'ReservasService.actualizarArea',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.actualizarArea');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.actualizarArea');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al actualizar área común.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.actualizarArea');
      return {
        'success': false,
        'error': 'Sin conexión a internet al actualizar área común.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.actualizarArea');
      return {
        'success': false,
        'error': 'Error de comunicación de red al actualizar área común.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.actualizarArea');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al actualizar área común.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.actualizarArea');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al actualizar área común.',
          context: 'ReservasService.actualizarArea',
        ),
      };
    }
  }

  /// POST /api/areas/{id}/baja (Admin)
  Future<Map<String, dynamic>> bajaArea(String id) async {
    try {
      final url = '$baseUrl/api/areas/$id/baja';
      final response = await controller.httpClient
          .post(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo dar de baja el área común.',
        context: 'ReservasService.bajaArea',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.bajaArea');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.bajaArea');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al dar de baja el área común.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.bajaArea');
      return {
        'success': false,
        'error': 'Sin conexión a internet al dar de baja el área común.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.bajaArea');
      return {
        'success': false,
        'error': 'Error de comunicación de red al dar de baja el área común.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.bajaArea');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al dar de baja el área común.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.bajaArea');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al dar de baja el área común.',
          context: 'ReservasService.bajaArea',
        ),
      };
    }
  }

  /// POST /api/areas/{id}/reactivar (Admin)
  Future<Map<String, dynamic>> reactivarArea(String id) async {
    try {
      final url = '$baseUrl/api/areas/$id/reactivar';
      final response = await controller.httpClient
          .post(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo reactivar el área común.',
        context: 'ReservasService.reactivarArea',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.reactivarArea');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.reactivarArea');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al reactivar el área común.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.reactivarArea');
      return {
        'success': false,
        'error': 'Sin conexión a internet al reactivar el área común.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.reactivarArea');
      return {
        'success': false,
        'error': 'Error de comunicación de red al reactivar el área común.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.reactivarArea');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al reactivar el área común.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.reactivarArea');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al reactivar el área común.',
          context: 'ReservasService.reactivarArea',
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
      var headers = await _getHeaders();
      var response = await controller.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(requestTimeout);

      if (response.statusCode == 401) {
        await controller.forceRefreshSession();
        headers = await _getHeaders();
        response = await controller.httpClient
            .get(Uri.parse(url), headers: headers)
            .timeout(requestTimeout);
      }

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
        context: 'ReservasService.getCalendario',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.getCalendario');
      return {'success': false, 'error': error, 'items': <ReservaModel>[]};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getCalendario');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al consultar el calendario de reservas.',
        'items': <ReservaModel>[],
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getCalendario');
      return {
        'success': false,
        'error': 'Sin conexión a internet al consultar el calendario.',
        'items': <ReservaModel>[],
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getCalendario');
      return {
        'success': false,
        'error': 'Error de comunicación al consultar el calendario.',
        'items': <ReservaModel>[],
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getCalendario');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido del calendario.',
        'items': <ReservaModel>[],
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getCalendario');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al consultar el calendario.',
          context: 'ReservasService.getCalendario',
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
      var headers = await _getHeaders();
      var response = await controller.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(requestTimeout);

      if (response.statusCode == 401) {
        await controller.forceRefreshSession();
        headers = await _getHeaders();
        response = await controller.httpClient
            .get(Uri.parse(url), headers: headers)
            .timeout(requestTimeout);
      }

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
        context: 'ReservasService.getMisReservas',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.getMisReservas');
      return {'success': false, 'error': error, 'items': <ReservaModel>[]};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getMisReservas');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al consultar tus reservas.',
        'items': <ReservaModel>[],
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getMisReservas');
      return {
        'success': false,
        'error': 'Sin conexión a internet al consultar tus reservas.',
        'items': <ReservaModel>[],
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getMisReservas');
      return {
        'success': false,
        'error': 'Error de comunicación de red al consultar tus reservas.',
        'items': <ReservaModel>[],
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getMisReservas');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido de tus reservas.',
        'items': <ReservaModel>[],
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getMisReservas');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al consultar tus reservas.',
          context: 'ReservasService.getMisReservas',
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
      final response = await controller.httpClient
          .get(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

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
        context: 'ReservasService.getPendientesTitular',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.getPendientesTitular');
      return {'success': false, 'error': error, 'items': <ReservaModel>[]};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getPendientesTitular');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al consultar solicitudes por aprobar.',
        'items': <ReservaModel>[],
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getPendientesTitular');
      return {
        'success': false,
        'error': 'Sin conexión a internet al consultar solicitudes pendientes.',
        'items': <ReservaModel>[],
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getPendientesTitular');
      return {
        'success': false,
        'error': 'Error de comunicación al consultar solicitudes de subusuarios.',
        'items': <ReservaModel>[],
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getPendientesTitular');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al consultar solicitudes.',
        'items': <ReservaModel>[],
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getPendientesTitular');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al consultar solicitudes por aprobar.',
          context: 'ReservasService.getPendientesTitular',
        ),
        'items': <ReservaModel>[],
      };
    }
  }

  /// POST /api/reservas
  Future<Map<String, dynamic>> solicitarReserva({
    required String areaId,
    required DateTime inicio,
    required DateTime fin,
  }) async {
    try {
      final url = '$baseUrl/api/reservas';
      final body = jsonEncode({
        'areaId': areaId,
        'inicio': inicio.toUtc().toIso8601String(),
        'fin': fin.toUtc().toIso8601String(),
      });

      final response = await controller.httpClient
          .post(Uri.parse(url), headers: await _getHeaders(), body: body)
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'reserva': ReservaModel.fromJson(decoded as Map<String, dynamic>),
        };
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo crear la reserva.',
        context: 'ReservasService.solicitarReserva',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.solicitarReserva');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.solicitarReserva');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al solicitar la reserva.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.solicitarReserva');
      return {
        'success': false,
        'error': 'Sin conexión a internet al enviar la solicitud de reserva.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.solicitarReserva');
      return {
        'success': false,
        'error': 'Error de comunicación de red al solicitar reserva.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.solicitarReserva');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al procesar solicitud de reserva.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.solicitarReserva');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al solicitar reserva.',
          context: 'ReservasService.solicitarReserva',
        ),
      };
    }
  }

  /// POST /api/reservas/{id}/aprobar-titular
  Future<Map<String, dynamic>> aprobarReservaTitular(String reservaId) async {
    try {
      final url = '$baseUrl/api/reservas/$reservaId/aprobar-titular';
      final response = await controller.httpClient
          .post(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo dar visto bueno a la solicitud.',
        context: 'ReservasService.aprobarReservaTitular',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.aprobarReservaTitular');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaTitular');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al aprobar solicitud de subusuario.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaTitular');
      return {
        'success': false,
        'error': 'Sin conexión a internet al aprobar solicitud.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaTitular');
      return {
        'success': false,
        'error': 'Error de comunicación de red al aprobar solicitud.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaTitular');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al aprobar solicitud.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaTitular');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al aprobar solicitud de subusuario.',
          context: 'ReservasService.aprobarReservaTitular',
        ),
      };
    }
  }

  /// POST /api/reservas/{id}/rechazar-titular
  Future<Map<String, dynamic>> rechazarReservaTitular(
    String reservaId, {
    String? motivo,
  }) async {
    try {
      final url = '$baseUrl/api/reservas/$reservaId/rechazar-titular';
      final response = await controller.httpClient
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode({
              if (motivo != null && motivo.trim().isNotEmpty)
                'motivo': motivo.trim(),
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo rechazar la solicitud.',
        context: 'ReservasService.rechazarReservaTitular',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.rechazarReservaTitular');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaTitular');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al rechazar solicitud.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaTitular');
      return {
        'success': false,
        'error': 'Sin conexión a internet al rechazar solicitud.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaTitular');
      return {
        'success': false,
        'error': 'Error de comunicación al rechazar solicitud.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaTitular');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al rechazar solicitud.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaTitular');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al rechazar solicitud.',
          context: 'ReservasService.rechazarReservaTitular',
        ),
      };
    }
  }

  /// POST /api/reservas/{id}/confirmar
  Future<Map<String, dynamic>> confirmarReserva(String reservaId) async {
    try {
      final url = '$baseUrl/api/reservas/$reservaId/confirmar';
      final response = await controller.httpClient
          .post(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo confirmar la reserva.',
        context: 'ReservasService.confirmarReserva',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.confirmarReserva');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.confirmarReserva');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al confirmar asistencia.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.confirmarReserva');
      return {
        'success': false,
        'error': 'Sin conexión a internet al confirmar asistencia.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.confirmarReserva');
      return {
        'success': false,
        'error': 'Error de comunicación al confirmar asistencia.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.confirmarReserva');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al confirmar reserva.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.confirmarReserva');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al confirmar asistencia.',
          context: 'ReservasService.confirmarReserva',
        ),
      };
    }
  }

  /// POST /api/reservas/{id}/cancelar
  Future<Map<String, dynamic>> cancelarReserva(
    String reservaId, {
    String? motivo,
  }) async {
    try {
      final url = '$baseUrl/api/reservas/$reservaId/cancelar';
      final response = await controller.httpClient
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode({
              if (motivo != null && motivo.trim().isNotEmpty)
                'motivo': motivo.trim(),
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo cancelar la reserva.',
        context: 'ReservasService.cancelarReserva',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.cancelarReserva');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReserva');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al cancelar la reserva.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReserva');
      return {
        'success': false,
        'error': 'Sin conexión a internet al cancelar la reserva.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReserva');
      return {
        'success': false,
        'error': 'Error de comunicación al cancelar la reserva.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReserva');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al cancelar reserva.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReserva');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al cancelar la reserva.',
          context: 'ReservasService.cancelarReserva',
        ),
      };
    }
  }

  /// GET /api/admin/reservas
  Future<Map<String, dynamic>> getReservasAdmin({
    String? estado,
    String? areaId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      var query = 'page=$page&pageSize=$pageSize';
      if (estado != null && estado.isNotEmpty) {
        query += '&estado=${Uri.encodeComponent(estado.toLowerCase())}';
      }
      if (areaId != null && areaId.isNotEmpty) {
        query += '&areaId=${Uri.encodeComponent(areaId)}';
      }
      if (from != null) {
        query += '&from=${Uri.encodeComponent(from.toUtc().toIso8601String())}';
      }
      if (to != null) {
        query += '&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}';
      }

      final url = '$baseUrl/api/admin/reservas?$query';
      final response = await controller.httpClient
          .get(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

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
        defaultMessage: 'No se pudieron consultar las reservas administrativas.',
        context: 'ReservasService.getReservasAdmin',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.getReservasAdmin');
      return {'success': false, 'error': error, 'items': <ReservaModel>[]};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getReservasAdmin');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al consultar reservas administrativas.',
        'items': <ReservaModel>[],
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getReservasAdmin');
      return {
        'success': false,
        'error': 'Sin conexión a internet al consultar reservas administrativas.',
        'items': <ReservaModel>[],
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getReservasAdmin');
      return {
        'success': false,
        'error': 'Error de comunicación al consultar reservas como administrador.',
        'items': <ReservaModel>[],
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getReservasAdmin');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido de reservas administrativas.',
        'items': <ReservaModel>[],
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getReservasAdmin');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al consultar reservas como administrador.',
          context: 'ReservasService.getReservasAdmin',
        ),
        'items': <ReservaModel>[],
      };
    }
  }

  /// GET /api/admin/reservas/no-shows
  Future<Map<String, dynamic>> getNoShows({
    String? titularId,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      var query = 'page=$page&pageSize=$pageSize';
      if (titularId != null && titularId.isNotEmpty) {
        query += '&titularId=${Uri.encodeComponent(titularId)}';
      }

      final url = '$baseUrl/api/admin/reservas/no-shows?$query';
      final response = await controller.httpClient
          .get(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final noShows = itemsRaw
              .map((j) => ReservaModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': noShows,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? noShows.length,
          };
        }
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo consultar el historial de no-shows.',
        context: 'ReservasService.getNoShows',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.getNoShows');
      return {'success': false, 'error': error, 'items': <ReservaModel>[]};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getNoShows');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al consultar no-shows.',
        'items': <ReservaModel>[],
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getNoShows');
      return {
        'success': false,
        'error': 'Sin conexión a internet al consultar no-shows.',
        'items': <ReservaModel>[],
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getNoShows');
      return {
        'success': false,
        'error': 'Error de comunicación al consultar el registro de inasistencias.',
        'items': <ReservaModel>[],
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getNoShows');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido de inasistencias.',
        'items': <ReservaModel>[],
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.getNoShows');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al consultar no-shows.',
          context: 'ReservasService.getNoShows',
        ),
        'items': <ReservaModel>[],
      };
    }
  }

  /// POST /api/admin/reservas/{id}/aprobar
  Future<Map<String, dynamic>> aprobarReservaAdmin(String reservaId) async {
    try {
      final url = '$baseUrl/api/admin/reservas/$reservaId/aprobar';
      final response = await controller.httpClient
          .post(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo aprobar la reserva.',
        context: 'ReservasService.aprobarReservaAdmin',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.aprobarReservaAdmin');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaAdmin');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al aprobar la reserva.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaAdmin');
      return {
        'success': false,
        'error': 'Sin conexión a internet al aprobar la reserva.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaAdmin');
      return {
        'success': false,
        'error': 'Error de comunicación de red al aprobar reserva.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaAdmin');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al aprobar reserva.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.aprobarReservaAdmin');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al aprobar reserva.',
          context: 'ReservasService.aprobarReservaAdmin',
        ),
      };
    }
  }

  /// POST /api/admin/reservas/{id}/rechazar (motivo obligatorio)
  Future<Map<String, dynamic>> rechazarReservaAdmin(
    String reservaId, {
    required String motivo,
  }) async {
    try {
      final url = '$baseUrl/api/admin/reservas/$reservaId/rechazar';
      final response = await controller.httpClient
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode({'motivo': motivo.trim()}),
          )
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo rechazar la reserva.',
        context: 'ReservasService.rechazarReservaAdmin',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.rechazarReservaAdmin');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaAdmin');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al rechazar la reserva.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaAdmin');
      return {
        'success': false,
        'error': 'Sin conexión a internet al rechazar la reserva.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaAdmin');
      return {
        'success': false,
        'error': 'Error de comunicación al rechazar la reserva.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaAdmin');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al rechazar reserva.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.rechazarReservaAdmin');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al rechazar reserva.',
          context: 'ReservasService.rechazarReservaAdmin',
        ),
      };
    }
  }

  /// POST /api/admin/reservas/{id}/cancelar (motivo obligatorio)
  Future<Map<String, dynamic>> cancelarReservaAdmin(
    String reservaId, {
    required String motivo,
  }) async {
    try {
      final url = '$baseUrl/api/admin/reservas/$reservaId/cancelar';
      final response = await controller.httpClient
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: jsonEncode({'motivo': motivo.trim()}),
          )
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo cancelar la reserva.',
        context: 'ReservasService.cancelarReservaAdmin',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.cancelarReservaAdmin');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReservaAdmin');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al cancelar la reserva administrativamente.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReservaAdmin');
      return {
        'success': false,
        'error': 'Sin conexión a internet al cancelar la reserva.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReservaAdmin');
      return {
        'success': false,
        'error': 'Error de comunicación de red al cancelar reserva.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReservaAdmin');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al cancelar reserva.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.cancelarReservaAdmin');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al cancelar reserva.',
          context: 'ReservasService.cancelarReservaAdmin',
        ),
      };
    }
  }

  /// POST /api/admin/reservas/{id}/no-utilizada (solo después de fin)
  Future<Map<String, dynamic>> marcarNoUtilizada(String reservaId) async {
    try {
      final url = '$baseUrl/api/admin/reservas/$reservaId/no-utilizada';
      final response = await controller.httpClient
          .post(Uri.parse(url), headers: await _getHeaders())
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo marcar la inasistencia (no-show).',
        context: 'ReservasService.marcarNoUtilizada',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.marcarNoUtilizada');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.marcarNoUtilizada');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al registrar inasistencia.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.marcarNoUtilizada');
      return {
        'success': false,
        'error': 'Sin conexión a internet al registrar inasistencia.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.marcarNoUtilizada');
      return {
        'success': false,
        'error': 'Error de comunicación al registrar inasistencia.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.marcarNoUtilizada');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al marcar inasistencia.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.marcarNoUtilizada');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al registrar inasistencia.',
          context: 'ReservasService.marcarNoUtilizada',
        ),
      };
    }
  }

  /// POST /api/admin/bloqueos
  Future<Map<String, dynamic>> crearBloqueo({
    required String areaId,
    required DateTime inicio,
    required DateTime fin,
    required String motivo,
  }) async {
    try {
      final url = '$baseUrl/api/admin/bloqueos';
      final body = jsonEncode({
        'areaId': areaId,
        'inicio': inicio.toUtc().toIso8601String(),
        'fin': fin.toUtc().toIso8601String(),
        'motivo': motivo.trim(),
      });

      final response = await controller.httpClient
          .post(Uri.parse(url), headers: await _getHeaders(), body: body)
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'bloqueo': BloqueoModel.fromJson(decoded as Map<String, dynamic>),
          'totalReservasAfectadas': decoded['totalReservasAfectadas'] ??
              decoded['reservas_afectadas'] ??
              0,
        };
      }
      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo crear el bloqueo por mantenimiento.',
        context: 'ReservasService.crearBloqueo',
      );
      ErrorHandler.trackError('HTTP ${response.statusCode}: $error', null, 'ReservasService.crearBloqueo');
      return {'success': false, 'error': error};
    } on TimeoutException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearBloqueo');
      return {
        'success': false,
        'error': 'Tiempo de espera agotado al registrar bloqueo por mantenimiento.',
      };
    } on SocketException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearBloqueo');
      return {
        'success': false,
        'error': 'Sin conexión a internet al registrar bloqueo.',
      };
    } on http.ClientException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearBloqueo');
      return {
        'success': false,
        'error': 'Error de comunicación de red al crear bloqueo.',
      };
    } on FormatException catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearBloqueo');
      return {
        'success': false,
        'error': 'Respuesta con formato no válido al crear bloqueo.',
      };
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasService.crearBloqueo');
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error al registrar bloqueo.',
          context: 'ReservasService.crearBloqueo',
        ),
      };
    }
  }
}
