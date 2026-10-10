import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';
import '../Models/paquete_model.dart';
import '../Models/servicio_paqueteria_model.dart';
import '../Models/paquete_dtos.dart';
import '../Utils/error_handler.dart';

class PaqueteriaService {
  final AppController controller;

  PaqueteriaService(this.controller);

  String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL_PAQUETERIA'] ?? dotenv.env['API_BASE_URL_VISITAS'];
    if (envUrl != null &&
        envUrl.trim().isNotEmpty &&
        !envUrl.contains('haven.app')) {
      return envUrl.trim();
    }
    return 'https://visitas-api-r66s.onrender.com';
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await controller.getValidAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // --- ENDPOINTS PARA EL RESIDENTE ---

  /// GET /api/paqueteria/mis-paquetes
  /// Lista el historial de paquetes del residente logueado.
  Future<Map<String, dynamic>> getMisPaquetes({
    int page = 1,
    int pageSize = 10,
    String? estado,
    int? viviendaId,
  }) async {
    try {
      final queryParams = <String>[
        'page=$page',
        'pageSize=$pageSize',
      ];
      if (estado != null && estado.trim().isNotEmpty) {
        queryParams.add('estado=${Uri.encodeComponent(estado.trim().toLowerCase())}');
      }
      if (viviendaId != null && viviendaId > 0) {
        queryParams.add('viviendaId=$viviendaId');
      }

      final url = '$baseUrl/api/paqueteria/mis-paquetes?${queryParams.join('&')}';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final items = itemsRaw
              .map((j) => PaqueteModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': items,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? items.length,
          };
        } else if (decoded is List) {
          final items = decoded
              .map((j) => PaqueteModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': items,
            'page': page,
            'pageSize': pageSize,
            'totalCount': items.length,
          };
        }
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudieron consultar los paquetes.',
      );
      return {'success': false, 'error': error, 'items': <PaqueteModel>[]};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al consultar paquetes.',
        ),
        'items': <PaqueteModel>[],
      };
    }
  }

  /// POST /api/paqueteria
  /// Registra un paquete esperado por parte del residente.
  Future<Map<String, dynamic>> createPaqueteEsperado(CreatePaqueteEsperadoDto dto) async {
    try {
      final url = '$baseUrl/api/paqueteria';
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(dto.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final paquete = PaqueteModel.fromJson(decoded as Map<String, dynamic>);
        return {'success': true, 'data': paquete};
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo registrar el paquete esperado.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al registrar paquete esperado.',
        ),
      };
    }
  }

  /// PUT /api/paqueteria/{id}
  /// Modifica los datos de un paquete esperado. Falla con 409 si ya fue recibido en caseta.
  Future<Map<String, dynamic>> updatePaqueteEsperado(
    String id,
    UpdatePaqueteEsperadoDto dto,
  ) async {
    try {
      final url = '$baseUrl/api/paqueteria/$id';
      final response = await controller.httpClient.put(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(dto.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final paquete = PaqueteModel.fromJson(decoded as Map<String, dynamic>);
        return {'success': true, 'data': paquete};
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo actualizar el paquete esperado.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al actualizar paquete esperado.',
        ),
      };
    }
  }

  /// POST /api/paqueteria/{id}/cancelar
  /// Cancela un paquete esperado antes de su recepción física.
  Future<Map<String, dynamic>> cancelarPaqueteEsperado(
    String id, {
    String? motivo,
  }) async {
    try {
      final url = '$baseUrl/api/paqueteria/$id/cancelar';
      final body = CancelPaqueteDto(motivo: motivo).toJson();
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo cancelar el paquete esperado.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al cancelar paquete esperado.',
        ),
      };
    }
  }

  // --- ENDPOINTS PARA LA CASETA (VIGILANCIA / ADMIN) ---

  /// GET /api/paqueteria/esperados
  /// Lista los paquetes esperados para la caseta.
  Future<Map<String, dynamic>> getPaquetesEsperadosCaseta({
    int page = 1,
    int pageSize = 10,
    int? viviendaId,
  }) async {
    try {
      final queryParams = <String>[
        'page=$page',
        'pageSize=$pageSize',
      ];
      if (viviendaId != null && viviendaId > 0) {
        queryParams.add('viviendaId=$viviendaId');
      }

      final url = '$baseUrl/api/paqueteria/esperados?${queryParams.join('&')}';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final items = itemsRaw
              .map((j) => PaqueteModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': items,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? items.length,
          };
        } else if (decoded is List) {
          final items = decoded
              .map((j) => PaqueteModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': items,
            'page': page,
            'pageSize': pageSize,
            'totalCount': items.length,
          };
        }
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudieron consultar los paquetes esperados en caseta.',
      );
      return {'success': false, 'error': error, 'items': <PaqueteModel>[]};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al consultar paquetes esperados.',
        ),
        'items': <PaqueteModel>[],
      };
    }
  }

  /// GET /api/paqueteria/inventario
  /// Lista los paquetes en caseta en estado recibido.
  Future<Map<String, dynamic>> getInventarioCaseta({
    int page = 1,
    int pageSize = 10,
    int? viviendaId,
  }) async {
    try {
      final queryParams = <String>[
        'page=$page',
        'pageSize=$pageSize',
      ];
      if (viviendaId != null && viviendaId > 0) {
        queryParams.add('viviendaId=$viviendaId');
      }

      final url = '$baseUrl/api/paqueteria/inventario?${queryParams.join('&')}';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final items = itemsRaw
              .map((j) => PaqueteModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': items,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? items.length,
          };
        } else if (decoded is List) {
          final items = decoded
              .map((j) => PaqueteModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': items,
            'page': page,
            'pageSize': pageSize,
            'totalCount': items.length,
          };
        }
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo consultar el inventario de caseta.',
      );
      return {'success': false, 'error': error, 'items': <PaqueteModel>[]};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al consultar inventario de caseta.',
        ),
        'items': <PaqueteModel>[],
      };
    }
  }

  /// POST /api/paqueteria/recepcion
  /// Registra la recepción física del paquete en caseta (detona Push Notification).
  Future<Map<String, dynamic>> recibirPaquete(RecibirPaqueteDto dto) async {
    try {
      final url = '$baseUrl/api/paqueteria/recepcion';
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(dto.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final paquete = PaqueteModel.fromJson(decoded as Map<String, dynamic>);
        return {'success': true, 'data': paquete};
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo registrar la recepción del paquete.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al recibir paquete.',
        ),
      };
    }
  }

  /// POST /api/paqueteria/{id}/entrega
  /// Registra la entrega en mano del paquete al residente.
  Future<Map<String, dynamic>> entregarPaquete(
    String id,
    String entregadoANombre,
  ) async {
    try {
      final url = '$baseUrl/api/paqueteria/$id/entrega';
      final body = EntregarPaqueteDto(entregadoANombre: entregadoANombre).toJson();
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final paquete = PaqueteModel.fromJson(decoded as Map<String, dynamic>);
        return {'success': true, 'data': paquete};
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo registrar la entrega del paquete.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al registrar entrega del paquete.',
        ),
      };
    }
  }

  /// GET /api/paqueteria/historico
  /// Pantalla de auditoría e historial general para caseta/admin.
  Future<Map<String, dynamic>> getHistoricoCaseta({
    DateTime? desde,
    DateTime? hasta,
    int? viviendaId,
    String? estado,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final queryParams = <String>[
        'page=$page',
        'pageSize=$pageSize',
      ];
      if (desde != null) {
        queryParams.add('desde=${Uri.encodeComponent(desde.toUtc().toIso8601String())}');
      }
      if (hasta != null) {
        queryParams.add('hasta=${Uri.encodeComponent(hasta.toUtc().toIso8601String())}');
      }
      if (viviendaId != null && viviendaId > 0) {
        queryParams.add('viviendaId=$viviendaId');
      }
      if (estado != null && estado.trim().isNotEmpty) {
        queryParams.add('estado=${Uri.encodeComponent(estado.trim().toLowerCase())}');
      }

      final url = '$baseUrl/api/paqueteria/historico?${queryParams.join('&')}';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final items = itemsRaw
              .map((j) => PaqueteModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': items,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? items.length,
          };
        } else if (decoded is List) {
          final items = decoded
              .map((j) => PaqueteModel.fromJson(j as Map<String, dynamic>))
              .toList();
          return {
            'success': true,
            'items': items,
            'page': page,
            'pageSize': pageSize,
            'totalCount': items.length,
          };
        }
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo consultar el histórico de paquetería.',
      );
      return {'success': false, 'error': error, 'items': <PaqueteModel>[]};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al consultar histórico de paquetería.',
        ),
        'items': <PaqueteModel>[],
      };
    }
  }

  // --- CATÁLOGO DE SERVICIOS ---

  /// GET /api/paqueteria/servicios
  /// Retorna las empresas de paquetería disponibles.
  Future<List<ServicioPaqueteriaModel>> getServicios() async {
    try {
      final url = '$baseUrl/api/paqueteria/servicios';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map((j) => ServicioPaqueteriaModel.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      }
      return <ServicioPaqueteriaModel>[];
    } catch (_) {
      return <ServicioPaqueteriaModel>[];
    }
  }

  /// POST /api/paqueteria/servicios
  /// Crea un nuevo servicio en el catálogo (solo Admin).
  Future<Map<String, dynamic>> createServicio(CreateServicioPaqueteriaDto dto) async {
    try {
      final url = '$baseUrl/api/paqueteria/servicios';
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(dto.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final servicio = ServicioPaqueteriaModel.fromJson(decoded as Map<String, dynamic>);
        return {'success': true, 'data': servicio};
      }

      final error = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo crear el servicio de paquetería.',
      );
      return {'success': false, 'error': error};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al crear servicio de paquetería.',
        ),
      };
    }
  }

  /// DELETE /api/paqueteria/servicios/{id}
  /// Elimina un servicio del catálogo (solo Admin).
  Future<bool> deleteServicio(int id) async {
    try {
      final url = '$baseUrl/api/paqueteria/servicios/$id';
      final response = await controller.httpClient.delete(
        Uri.parse(url),
        headers: await _getHeaders(),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
