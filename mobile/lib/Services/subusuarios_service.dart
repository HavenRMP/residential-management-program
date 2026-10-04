import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../Models/subusuario.dart';
import '../Utils/error_handler.dart';
import 'app_controller.dart';
import 'offline_sync_service.dart';

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
          final items = decoded
              .map((item) => SubusuarioItem.fromJson(item as Map<String, dynamic>))
              .toList();

          // Enriquecer códigos de invitaciones pendientes si vienen nulos
          final pendientesSinCodigo = items.where((i) => i.isPendiente && (i.codigo == null || i.codigo!.isEmpty)).toList();
          final supa = controller.supabaseClient;
          if (pendientesSinCodigo.isNotEmpty && supa != null) {
            try {
              final supaInvitaciones = await supa
                  .from('invitaciones_subusuarios')
                  .select('id, email_invitado, codigo_invitacion')
                  .eq('vivienda_id', viviendaId)
                  .eq('estado', 'pendiente');

              final mapCodes = <String, String>{};
              for (final row in supaInvitaciones) {
                final c = row['codigo_invitacion']?.toString();
                final id = row['id']?.toString();
                final email = row['email_invitado']?.toString().toLowerCase();
                if (c != null && c.isNotEmpty) {
                  if (id != null) mapCodes[id] = c;
                  if (email != null) mapCodes[email] = c;
                }
              }
                for (int i = 0; i < items.length; i++) {
                  if (items[i].isPendiente && (items[i].codigo == null || items[i].codigo!.isEmpty)) {
                    final found = mapCodes[items[i].id] ?? mapCodes[items[i].email.toLowerCase()];
                    if (found != null) {
                      items[i] = items[i].copyWith(codigo: found);
                    }
                  }
                }
            } catch (_) {}
          }

          unawaited(OfflineSyncService.cacheSubusuarios(viviendaId, items.map((i) => i.toJson()).toList()));
          controller.setOffline(false);
          return items;
        }
      }
      return [];
    } catch (e) {
      if (OfflineSyncService.isStrictlyOfflineError(e) || await OfflineSyncService.isDeviceOffline()) {
        final cached = await OfflineSyncService.getCachedSubusuarios(viviendaId);
        if (cached.isNotEmpty) {
          controller.setOffline(true);
          return cached
              .map((c) => SubusuarioItem.fromJson(c as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    }
  }

  /// Envía una invitación a un familiar/co-residente por email
  /// (POST /api/subusuarios/invitar)
  Future<Map<String, dynamic>> invitarSubusuario({
    required int viviendaId,
    required String email,
    required String parentesco,
  }) async {
    try {
      final url = '$baseUrl/api/subusuarios/invitar';
      final payload = {
        'vivienda_id': viviendaId,
        'email': email.trim(),
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
          var item = SubusuarioItem.fromJson(decoded);
          if (item.codigo == null || item.codigo!.isEmpty) {
            final fetched = await _fetchCodigoInvitacion(item.id, viviendaId, email);
            if (fetched != null) {
              item = item.copyWith(codigo: fetched);
            }
          }
          return {
            'success': true,
            'item': item,
            'codigo': item.codigo,
          };
        }
        return {'success': true};
      }

      String defaultError = 'Error al invitar sub-usuario';
      if (response.statusCode == 404) {
        defaultError = 'El correo no está registrado en HAVEN. Tu familiar debe registrarse primero en la app.';
      } else if (response.statusCode == 409) {
        defaultError = 'Límite máximo de 2 sub-usuarios alcanzado o ya tiene una invitación pendiente.';
      }

      final errorMsg = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: defaultError,
      );

      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al invitar sub-usuario.',
        ),
      };
    }
  }

  Future<String?> _fetchCodigoInvitacion(String invitacionId, int viviendaId, String email) async {
    final supa = controller.supabaseClient;
    if (supa == null) return null;
    try {
      final res = await supa
          .from('invitaciones_subusuarios')
          .select('codigo_invitacion')
          .eq('vivienda_id', viviendaId)
          .eq('email_invitado', email.trim().toLowerCase())
          .eq('estado', 'pendiente')
          .order('creado_en', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['codigo_invitacion'] != null) {
        return res['codigo_invitacion'].toString();
      }
    } catch (_) {}
    return null;
  }

  /// Canjea un código de invitación de sub-usuario para vincularse a una vivienda
  /// (POST /api/subusuarios/redimir-codigo o fallback RPC redimir_codigo_subusuario)
  Future<Map<String, dynamic>?> redimirCodigo(String codigo, {String? usuarioId}) async {
    final cleanCode = codigo.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return {'error': 'El código no puede estar vacío'};
    }

    final payload = <String, dynamic>{'codigo': cleanCode};
    if (usuarioId != null && usuarioId.isNotEmpty) {
      payload['usuarioId'] = usuarioId;
    }

    // 1. Intentar endpoint REST de la API de Usuarios
    try {
      final url = '$baseUrl/api/subusuarios/redimir-codigo';
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
      } else if (response.statusCode != 404) {
        return {
          'error': ErrorHandler.extractErrorMessage(
            response.body,
            statusCode: response.statusCode,
            defaultMessage: 'No se pudo canjear el código de invitación.',
          ),
        };
      }
    } catch (_) {
      // Continuar a fallback de RPC Supabase
    }

    // 2. Fallback directo a Supabase RPC redimir_codigo_subusuario
    final supa = controller.supabaseClient;
    if (supa == null) {
      return {'error': 'Cliente de base de datos no disponible'};
    }

    try {
      final rpcParams = <String, dynamic>{'p_codigo': cleanCode};
      if (usuarioId != null && usuarioId.isNotEmpty) {
        rpcParams['p_usuario_id'] = usuarioId;
      }

      final rpcRes = await supa.rpc('redimir_codigo_subusuario', params: rpcParams);

      if (rpcRes == true) {
        return {
          'success': true,
          'message': '¡Código canjeado exitosamente! Ahora eres co-residente de la vivienda.',
        };
      } else {
        return {'error': 'No se pudo redimir el código de sub-usuario'};
      }
    } catch (e) {
      return {
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'No se pudo redimir el código de sub-usuario.',
        ),
      };
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

  /// Obtiene la lista de invitaciones recibidas por el usuario actual
  /// (GET /api/subusuarios/mis-invitaciones)
  Future<List<InvitacionSubusuario>> getMisInvitaciones() async {
    try {
      final url = '$baseUrl/api/subusuarios/mis-invitaciones';
      final response = await controller.httpClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return [];
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final items = decoded
              .map((item) => InvitacionSubusuario.fromJson(item as Map<String, dynamic>))
              .toList();
          unawaited(OfflineSyncService.cacheMisInvitaciones(items.map((i) => i.toJson()).toList()));
          controller.setOffline(false);
          return items;
        }
      }
      return [];
    } catch (e) {
      if (OfflineSyncService.isStrictlyOfflineError(e) || await OfflineSyncService.isDeviceOffline()) {
        final cached = await OfflineSyncService.getCachedMisInvitaciones();
        if (cached.isNotEmpty) {
          controller.setOffline(true);
          return cached
              .map((c) => InvitacionSubusuario.fromJson(c as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    }
  }

  /// Responde (ACEPTADA o RECHAZADA) a una invitación recibida
  /// (POST /api/subusuarios/invitaciones/{id}/responder)
  Future<Map<String, dynamic>> responderInvitacion(
    String id, {
    required bool aceptar,
  }) async {
    try {
      final url = '$baseUrl/api/subusuarios/invitaciones/$id/responder';
      final payload = {
        'respuesta': aceptar ? 'ACEPTADA' : 'RECHAZADA',
      };

      final response = await controller.httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String msg = aceptar ? 'Invitación aceptada' : 'Invitación rechazada';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['message'] != null) {
            msg = decoded['message'].toString();
          }
        } catch (_) {}
        return {'success': true, 'message': msg};
      }

      final errorMsg = ErrorHandler.extractErrorMessage(
        response.body,
        statusCode: response.statusCode,
        defaultMessage: 'No se pudo responder a la invitación.',
      );

      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {
        'success': false,
        'error': ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al responder invitación.',
        ),
      };
    }
  }
}
