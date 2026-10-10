import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';
import '../Models/paquete_model.dart';
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
}
