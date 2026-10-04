import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';
import '../Utils/error_handler.dart';
import 'offline_sync_service.dart';

class ViviendasService {
  final AppController controller;

  ViviendasService(this.controller);

  String get baseUrl => dotenv.env['API_BASE_URL_VIVIENDAS'] ?? 'https://viviendas-api.onrender.com';

  Future<Map<String, String>> _getHeaders() async {
    final token = await controller.getValidAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<List<dynamic>> listar() async {
    try {
      final url = '$baseUrl/api/Viviendas';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        List<dynamic> items = [];
        if (decoded is Map && decoded['items'] is List) {
          items = decoded['items'];
        } else if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          items = decoded['data'];
        }

        if (items.isNotEmpty) {
          unawaited(OfflineSyncService.cacheViviendas(items));
          controller.setOffline(false);
          return items;
        }
      }
      return [];
    } catch (e) {
      if (OfflineSyncService.isStrictlyOfflineError(e) || await OfflineSyncService.isDeviceOffline()) {
        final cached = await OfflineSyncService.getCachedViviendas();
        if (cached.isNotEmpty) {
          controller.setOffline(true);
          return cached;
        }
      }
      return [];
    }
  }

  Future<List<dynamic>> listarConResidentes({int page = 1, int pageSize = 100}) async {
    try {
      final url = '$baseUrl/api/Viviendas/con-residentes?page=$page&pageSize=$pageSize';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        List<dynamic> items = [];
        if (decoded is Map && decoded['items'] is List) {
          items = decoded['items'];
        } else if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          items = decoded['data'];
        }
        if (items.isNotEmpty) {
          unawaited(OfflineSyncService.cacheViviendasConResidentes(items));
          controller.setOffline(false);
          return items;
        }
      }
    } catch (e) {
      if (OfflineSyncService.isStrictlyOfflineError(e) || await OfflineSyncService.isDeviceOffline()) {
        final cached = await OfflineSyncService.getCachedViviendasConResidentes();
        if (cached.isNotEmpty) {
          controller.setOffline(true);
          return cached;
        }
      }
    }

    final list = await listar();
    if (list.isNotEmpty) {
      try {
        final asignaciones = await Future.wait(
          list.map(
            (v) => (v is Map && v['id'] != null)
                ? obtenerResidentesVivienda(v['id']).catchError((_) => <dynamic>[])
                : Future.value(<dynamic>[]),
          ),
        );
        for (int i = 0; i < list.length; i++) {
          final res = asignaciones[i];
          if (list[i] is Map) {
            list[i]['residentes'] = res;
            list[i]['totalResidentes'] = res.length;
            list[i]['estaOcupada'] = res.isNotEmpty;
          }
        }
      } catch (_) {}
    }
    return list;
  }


  Future<Map<String, dynamic>?> crear({required String numeroCasa, String? tipo}) async {
    try {
      final url = '$baseUrl/api/Viviendas';
      final payload = {'numeroCasa': numeroCasa, 'tipo': tipo};
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'success': true, 'data': decoded};
      }
      return {
        'error': ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No se pudo crear la vivienda.',
        ),
      };
    } catch (e) {
      return {
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al crear vivienda.',
        ),
      };
    }
  }

  Future<Map<String, dynamic>?> actualizar(int id, {required String numeroCasa, String? tipo}) async {
    try {
      final url = '$baseUrl/api/Viviendas/$id';
      final payload = {'numeroCasa': numeroCasa, 'tipo': tipo};
      final response = await controller.httpClient.put(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'success': true, 'data': decoded};
      }
      return {
        'error': ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No se pudo actualizar la vivienda.',
        ),
      };
    } catch (e) {
      return {
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al actualizar la vivienda.',
        ),
      };
    }
  }

  Future<bool> eliminar(int id) async {
    try {
      final url = '$baseUrl/api/Viviendas/$id';
      final response = await controller.httpClient.delete(
        Uri.parse(url),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
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

  Future<Map<String, dynamic>?> generarCodigo(int viviendaId, {int? minutosVigencia}) async {
    try {
      final url = '$baseUrl/api/viviendas/$viviendaId/codigo';
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
          defaultMessage: 'No se pudo generar el código para la vivienda.',
        ),
      };
    } catch (e) {
      return {
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al generar el código.',
        ),
      };
    }
  }

  Future<Map<String, dynamic>?> redimirCodigo(String codigo, {String? usuarioId}) async {
    final url = '$baseUrl/api/codigos/vivienda/redimir';
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
            defaultMessage: 'No se pudo canjear el código de vivienda.',
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
