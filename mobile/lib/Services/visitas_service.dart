import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';
import '../Models/visita_model.dart';
import 'offline_sync_service.dart';

class VisitasService {
  final AppController controller;

  VisitasService(this.controller);

  String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL_VISITAS'];
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

  // --- RESIDENTES ---

  /// GET /api/visitas/mis-visitas
  Future<Map<String, dynamic>> getMisVisitas({
    int page = 1,
    int pageSize = 10,
    String? estado,
  }) async {
    try {
      var query = 'page=$page&pageSize=$pageSize';
      if (estado != null && estado.isNotEmpty) {
        query += '&estado=${Uri.encodeComponent(estado.toLowerCase())}';
      }

      final url = '$baseUrl/api/visitas/mis-visitas?$query';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final visitas = itemsRaw.map((j) => VisitaModel.fromJson(j as Map<String, dynamic>)).toList();
          if (page == 1 && (estado == null || estado.isEmpty)) {
            unawaited(OfflineSyncService.cacheVisitasResidente(visitas));
          }
          controller.setOffline(false);
          return {
            'success': true,
            'items': visitas,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? visitas.length,
          };
        }
      }
      final error = _extractErrorMessage(response.body);
      return {'success': false, 'error': error, 'items': <VisitaModel>[]};
    } catch (e) {
      if (OfflineSyncService.isStrictlyOfflineError(e) || await OfflineSyncService.isDeviceOffline()) {
        final cached = await OfflineSyncService.getCachedVisitasResidente();
        if (cached.isNotEmpty) {
          controller.setOffline(true);
          final filtered = (estado != null && estado.isNotEmpty)
              ? cached.where((v) => v.estado.toLowerCase() == estado.toLowerCase()).toList()
              : cached;
          return {
            'success': true,
            'items': filtered,
            'page': 1,
            'pageSize': filtered.length,
            'totalCount': filtered.length,
            'isOffline': true,
          };
        }
      }
      return {
        'success': false,
        'error': e is TimeoutException ? 'Conexión débil o lenta. Tiempo de espera agotado.' : e.toString(),
        'items': <VisitaModel>[],
      };
    }
  }

  /// POST /api/visitas
  Future<Map<String, dynamic>> programarVisita({
    required int viviendaId,
    required String nombreVisitante,
    required String apellidosVisitante,
    String? telefonoVisitante,
    required String motivo,
    int numAcompanantes = 0,
    String? vehiculoPlacas,
    String? notas,
    required DateTime fechaLlegadaEsperada,
    int horasVigencia = 24,
  }) async {
    try {
      final url = '$baseUrl/api/visitas';
      final body = jsonEncode({
        'viviendaId': viviendaId,
        'nombreVisitante': nombreVisitante.trim(),
        'apellidosVisitante': apellidosVisitante.trim(),
        if (telefonoVisitante != null && telefonoVisitante.trim().isNotEmpty)
          'telefonoVisitante': telefonoVisitante.trim(),
        'motivo': motivo,
        'numAcompanantes': numAcompanantes,
        if (vehiculoPlacas != null && vehiculoPlacas.trim().isNotEmpty)
          'vehiculoPlacas': vehiculoPlacas.trim(),
        if (notas != null && notas.trim().isNotEmpty) 'notas': notas.trim(),
        'fechaLlegadaEsperada': fechaLlegadaEsperada.toUtc().toIso8601String(),
        'horasVigencia': horasVigencia,
      });

      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: body,
      );

      if (response.statusCode == 201 || (response.statusCode >= 200 && response.statusCode < 300)) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'visita': VisitaModel.fromJson(decoded as Map<String, dynamic>),
        };
      }

      return {
        'success': false,
        'error': _extractErrorMessage(response.body),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// PUT /api/visitas/{id}
  Future<Map<String, dynamic>> editarVisita(
    String visitaId, {
    String? nombreVisitante,
    String? apellidosVisitante,
    String? telefonoVisitante,
    String? motivo,
    int? numAcompanantes,
    String? vehiculoPlacas,
    String? notas,
    DateTime? fechaLlegadaEsperada,
    int? horasVigencia,
  }) async {
    try {
      final url = '$baseUrl/api/visitas/$visitaId';
      final Map<String, dynamic> bodyMap = {};
      if (nombreVisitante != null) bodyMap['nombreVisitante'] = nombreVisitante.trim();
      if (apellidosVisitante != null) bodyMap['apellidosVisitante'] = apellidosVisitante.trim();
      if (telefonoVisitante != null) bodyMap['telefonoVisitante'] = telefonoVisitante.trim();
      if (motivo != null) bodyMap['motivo'] = motivo;
      if (numAcompanantes != null) bodyMap['numAcompanantes'] = numAcompanantes;
      if (vehiculoPlacas != null) bodyMap['vehiculoPlacas'] = vehiculoPlacas.trim();
      if (notas != null) bodyMap['notas'] = notas.trim();
      if (fechaLlegadaEsperada != null) {
        bodyMap['fechaLlegadaEsperada'] = fechaLlegadaEsperada.toUtc().toIso8601String();
      }
      if (horasVigencia != null) bodyMap['horasVigencia'] = horasVigencia;

      final response = await controller.httpClient.put(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(bodyMap),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'visita': VisitaModel.fromJson(decoded as Map<String, dynamic>),
        };
      }

      return {
        'success': false,
        'error': _extractErrorMessage(response.body),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// POST /api/visitas/{id}/cancelar
  Future<Map<String, dynamic>> cancelarVisita(String visitaId) async {
    try {
      final url = '$baseUrl/api/visitas/$visitaId/cancelar';
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 204 || (response.statusCode >= 200 && response.statusCode < 300)) {
        return {'success': true};
      }

      return {
        'success': false,
        'error': _extractErrorMessage(response.body),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- VIGILANCIA & ADMIN ---

  /// GET /api/visitas/proximas
  Future<Map<String, dynamic>> getVisitasProximas({
    int page = 1,
    int pageSize = 20,
    String? busqueda,
  }) async {
    try {
      var query = 'page=$page&pageSize=$pageSize';
      if (busqueda != null && busqueda.trim().isNotEmpty) {
        query += '&busqueda=${Uri.encodeComponent(busqueda.trim())}';
      }

      final url = '$baseUrl/api/visitas/proximas?$query';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final visitas = itemsRaw.map((j) => VisitaModel.fromJson(j as Map<String, dynamic>)).toList();
          if (page == 1 && (busqueda == null || busqueda.trim().isEmpty)) {
            unawaited(OfflineSyncService.cacheVisitasProximas(visitas));
          }
          controller.setOffline(false);
          return {
            'success': true,
            'items': visitas,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? visitas.length,
          };
        }
      }

      return {
        'success': false,
        'error': _extractErrorMessage(response.body),
        'items': <VisitaModel>[],
      };
    } catch (e) {
      if (OfflineSyncService.isStrictlyOfflineError(e) || await OfflineSyncService.isDeviceOffline()) {
        final cached = await OfflineSyncService.getCachedVisitasProximas();
        if (cached.isNotEmpty) {
          controller.setOffline(true);
          final q = (busqueda ?? '').trim().toLowerCase();
          final filtered = q.isEmpty
              ? cached
              : cached.where((v) =>
                  v.nombreCompletoVisitante.toLowerCase().contains(q) ||
                  (v.codigo != null && v.codigo!.toLowerCase().contains(q)) ||
                  v.numeroCasa.toLowerCase().contains(q)).toList();
          return {
            'success': true,
            'items': filtered,
            'page': 1,
            'pageSize': filtered.length,
            'totalCount': filtered.length,
            'isOffline': true,
          };
        }
      }
      return {
        'success': false,
        'error': e is TimeoutException ? 'Conexión débil o lenta. Tiempo de espera agotado.' : e.toString(),
        'items': <VisitaModel>[],
      };
    }
  }

  /// GET /api/visitas/codigo/{codigo}
  Future<Map<String, dynamic>> validarCodigo(String codigo) async {
    try {
      final clean = codigo.trim();
      final url = '$baseUrl/api/visitas/codigo/${Uri.encodeComponent(clean)}';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        controller.setOffline(false);
        return {
          'success': true,
          'visita': VisitaModel.fromJson(decoded as Map<String, dynamic>),
        };
      }

      return {
        'success': false,
        'error': _extractErrorMessage(response.body, defaultMsg: 'Código inválido o expirado'),
      };
    } catch (e) {
      if (OfflineSyncService.isStrictlyOfflineError(e) || await OfflineSyncService.isDeviceOffline()) {
        final cached = await OfflineSyncService.getCachedVisitasProximas();
        final match = cached.where((v) => v.codigo?.trim().toUpperCase() == codigo.trim().toUpperCase()).toList();
        if (match.isNotEmpty) {
          controller.setOffline(true);
          return {
            'success': true,
            'visita': match.first,
            'isOffline': true,
          };
        }
      }
      return {
        'success': false,
        'error': e is TimeoutException ? 'Conexión débil o lenta. Tiempo de espera agotado.' : e.toString(),
      };
    }
  }

  /// POST /api/visitas/{id}/entrada
  Future<Map<String, dynamic>> registrarEntrada(String visitaId) async {
    try {
      final url = '$baseUrl/api/visitas/$visitaId/entrada';
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'visita': VisitaModel.fromJson(decoded as Map<String, dynamic>),
        };
      }

      return {
        'success': false,
        'error': _extractErrorMessage(response.body, defaultMsg: 'Error al registrar entrada'),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// POST /api/visitas/{id}/salida
  Future<Map<String, dynamic>> registrarSalida(String visitaId) async {
    try {
      final url = '$baseUrl/api/visitas/$visitaId/salida';
      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'visita': VisitaModel.fromJson(decoded as Map<String, dynamic>),
        };
      }

      return {
        'success': false,
        'error': _extractErrorMessage(response.body, defaultMsg: 'Error al registrar salida'),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- ADMINISTRADOR ---

  /// GET /api/visitas/historico
  Future<Map<String, dynamic>> getHistorico({
    int page = 1,
    int pageSize = 20,
    DateTime? desde,
    DateTime? hasta,
    int? viviendaId,
    String? estado,
  }) async {
    try {
      final params = <String>[
        'page=$page',
        'pageSize=$pageSize',
      ];
      if (desde != null) {
        params.add('desde=${Uri.encodeComponent(desde.toUtc().toIso8601String())}');
      }
      if (hasta != null) {
        params.add('hasta=${Uri.encodeComponent(hasta.toUtc().toIso8601String())}');
      }
      if (viviendaId != null && viviendaId > 0) {
        params.add('viviendaId=$viviendaId');
      }
      if (estado != null && estado.isNotEmpty) {
        params.add('estado=${Uri.encodeComponent(estado.toLowerCase())}');
      }

      final url = '$baseUrl/api/visitas/historico?${params.join('&')}';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final itemsRaw = decoded['items'] as List<dynamic>? ?? [];
          final visitas = itemsRaw.map((j) => VisitaModel.fromJson(j as Map<String, dynamic>)).toList();
          if (page == 1 && desde == null && hasta == null && viviendaId == null && estado == null) {
            unawaited(OfflineSyncService.cacheVisitasAdmin(visitas));
          }
          controller.setOffline(false);
          return {
            'success': true,
            'items': visitas,
            'page': decoded['page'] ?? page,
            'pageSize': decoded['pageSize'] ?? pageSize,
            'totalCount': decoded['totalCount'] ?? visitas.length,
          };
        }
      }

      return {
        'success': false,
        'error': _extractErrorMessage(response.body),
        'items': <VisitaModel>[],
      };
    } catch (e) {
      if (OfflineSyncService.isStrictlyOfflineError(e) || await OfflineSyncService.isDeviceOffline()) {
        final cached = await OfflineSyncService.getCachedVisitasAdmin();
        if (cached.isNotEmpty) {
          controller.setOffline(true);
          return {
            'success': true,
            'items': cached,
            'page': 1,
            'pageSize': cached.length,
            'totalCount': cached.length,
            'isOffline': true,
          };
        }
      }
      return {
        'success': false,
        'error': e is TimeoutException ? 'Conexión débil o lenta. Tiempo de espera agotado.' : e.toString(),
        'items': <VisitaModel>[],
      };
    }
  }

  /// GET /api/visitas/historico para visitas programadas activas
  Future<Map<String, dynamic>> getVisitasProgramadas({
    int page = 1,
    int pageSize = 20,
    int? viviendaId,
  }) async {
    return getHistorico(
      page: page,
      pageSize: pageSize,
      viviendaId: viviendaId,
      estado: 'programada',
    );
  }

  /// GET /api/visitas/historico para todas las visitas del historial
  Future<Map<String, dynamic>> getVisitasPasadas({
    int page = 1,
    int pageSize = 20,
    String? estado,
    int? viviendaId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    return getHistorico(
      page: page,
      pageSize: pageSize,
      hasta: hasta,
      desde: desde,
      viviendaId: viviendaId,
      estado: estado,
    );
  }

  String _extractErrorMessage(String responseBody, {String defaultMsg = 'Ocurrió un error inesperado'}) {
    try {
      if (responseBody.isEmpty) return defaultMsg;
      final parsed = jsonDecode(responseBody);
      if (parsed is Map<String, dynamic>) {
        if (parsed.containsKey('error')) return parsed['error'].toString();
        if (parsed.containsKey('message')) return parsed['message'].toString();
        if (parsed.containsKey('title')) return parsed['title'].toString();
      }
      return defaultMsg;
    } catch (_) {
      return defaultMsg;
    }
  }
}
