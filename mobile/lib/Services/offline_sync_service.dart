import 'dart:async';
import 'dart:convert';
import 'dart:io' show InternetAddress, InternetAddressType, NetworkInterface, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../Models/visita_model.dart';
import 'visitas_service.dart';

/// Modelo de acción encolada fuera de línea con clave de idempotencia.
class OfflineApprovalAction {
  final String id; // Clave única de idempotencia
  final String visitaId;
  final String tipo; // 'entrada' | 'salida'
  final String? codigo;
  final String? nombreVisitante;
  final String? numeroCasa;
  final DateTime timestamp;
  int retryCount;

  OfflineApprovalAction({
    required this.id,
    required this.visitaId,
    required this.tipo,
    this.codigo,
    this.nombreVisitante,
    this.numeroCasa,
    DateTime? timestamp,
    this.retryCount = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  String get idempotencyKey => id;

  Map<String, dynamic> toJson() => {
        'id': id,
        'visitaId': visitaId,
        'tipo': tipo,
        'codigo': codigo,
        'nombreVisitante': nombreVisitante,
        'numeroCasa': numeroCasa,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
      };

  factory OfflineApprovalAction.fromJson(Map<String, dynamic> json) =>
      OfflineApprovalAction(
        id: json['id'] as String,
        visitaId: json['visitaId'] as String,
        tipo: json['tipo'] as String,
        codigo: json['codigo'] as String?,
        nombreVisitante: json['nombreVisitante'] as String?,
        numeroCasa: json['numeroCasa'] as String?,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        retryCount: json['retryCount'] as int? ?? 0,
      );
}

/// Servicio central que gestiona la persistencia fuera de línea, caché de todos los endpoints,
/// cola de sincronización y detección estricta de ausencia de conectividad.
class OfflineSyncService {
  // Claves de SharedPreferences para todos los endpoints
  static const String _kKeyVisitasResidente = 'haven_offline_visitas_residente';
  static const String _kKeyVisitasProximas = 'haven_offline_visitas_proximas';
  static const String _kKeyVisitasAdmin = 'haven_offline_visitas_admin';
  static const String _kKeyAvisosVigentes = 'haven_offline_avisos_vigentes';
  static const String _kKeyAvisosHistorico = 'haven_offline_avisos_historico';
  static const String _kKeyViviendas = 'haven_offline_viviendas';
  static const String _kKeyViviendasConResidentes = 'haven_offline_viviendas_con_residentes';
  static const String _kKeyMisViviendas = 'haven_offline_mis_viviendas';
  static const String _kKeyResidentes = 'haven_offline_residentes';
  static const String _kKeySubusuariosPrefix = 'haven_offline_subusuarios_';
  static const String _kKeyMisInvitaciones = 'haven_offline_mis_invitaciones';
  static const String _kKeyNotificaciones = 'haven_offline_notificaciones';
  static const String _kKeyOfflineApprovals = 'haven_offline_approvals_queue';

  /// Número máximo de reintentos para acciones fuera de línea antes de descartarlas
  static const int kMaxOfflineRetries = 5;

  /// Limpia toda la caché offline de la aplicación.
  /// Se ejecuta al cerrar sesión para garantizar la privacidad y prevenir fugas de datos
  /// entre distintos usuarios en dispositivos compartidos.
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = [
        _kKeyVisitasResidente,
        _kKeyVisitasProximas,
        _kKeyVisitasAdmin,
        _kKeyAvisosVigentes,
        _kKeyAvisosHistorico,
        _kKeyViviendas,
        _kKeyViviendasConResidentes,
        _kKeyMisViviendas,
        _kKeyResidentes,
        _kKeyMisInvitaciones,
        _kKeyNotificaciones,
        _kKeyOfflineApprovals,
      ];
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      final allKeys = prefs.getKeys();
      for (final k in allKeys) {
        if (k.startsWith(_kKeySubusuariosPrefix)) {
          await prefs.remove(k);
        }
      }
    } catch (_) {}
  }

  static int _idempCounter = 0;

  /// Permite sobrescribir el estado de conectividad en pruebas automáticas.
  static bool? mockOfflineStatus;

  /// Determina si una excepción representa ESTRICTAMENTE la ausencia total de conexión (offline),
  /// y NUNCA una conexión débil, latencia o timeout.
  static bool isStrictlyOfflineError(dynamic error) {
    if (error == null) return false;
    if (mockOfflineStatus != null) return mockOfflineStatus!;

    // Si es un TimeoutException, se debe a una conexión débil o lentitud del servidor,
    // NO es una falta absoluta de conexión a la red.
    if (error is TimeoutException) {
      return false;
    }

    final errStr = error.toString().toLowerCase();

    // Descartar explícitamente timeouts en string
    if (errStr.contains('timeout') ||
        errStr.contains('timed out') ||
        errStr.contains('deadline exceeded') ||
        errStr.contains('timeoutexception')) {
      return false;
    }

    // Excepciones de socket por falta de conectividad / interfaces caídas
    if (error is SocketException) {
      final msg = error.message.toLowerCase();
      final osMsg = error.osError?.message.toLowerCase() ?? '';
      if (msg.contains('timed out') || osMsg.contains('timed out')) {
        return false; // Socket timeout != offline
      }
      return true;
    }

    // Errores característicos de ausencia total de red
    return errStr.contains('failed host lookup') ||
        errStr.contains('network is unreachable') ||
        errStr.contains('no address associated with hostname') ||
        errStr.contains('no internet') ||
        errStr.contains('network error') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection reset') ||
        errStr.contains('network_error') ||
        errStr.contains('software caused connection abort') ||
        errStr.contains('clientexception with socketexception');
  }

  /// Verifica activamente si el dispositivo no tiene ninguna conexión a internet activa.
  /// Si hay conexión débil / lenta, retorna false (no activa modo sin conexión).
  static Future<bool> isDeviceOffline() async {
    if (mockOfflineStatus != null) return mockOfflineStatus!;
    if (kIsWeb) return false;

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      ).timeout(const Duration(milliseconds: 1500));

      if (interfaces.isEmpty) {
        return true;
      }

      final hasAddress = interfaces.any((i) => i.addresses.any((a) => !a.isLoopback));
      if (!hasAddress) {
        return true;
      }

      try {
        final lookup = await InternetAddress.lookup('dns.google')
            .timeout(const Duration(milliseconds: 2000));
        if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
          return false;
        }
      } on SocketException {
        // Fallback secundario a Cloudflare antes de declarar offline
        try {
          final fallback = await InternetAddress.lookup('one.one.one.one')
              .timeout(const Duration(milliseconds: 2000));
          return fallback.isEmpty || fallback[0].rawAddress.isEmpty;
        } on SocketException {
          return true;
        } on TimeoutException {
          return false;
        }
      } on TimeoutException {
        // Conexión lenta o débil: NO se considera modo sin conexión
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Genera una clave de idempotencia única para la acción.
  static String generateIdempotencyKey(String tipo, String visitaId) {
    _idempCounter++;
    return 'idemp_${tipo}_${visitaId}_${DateTime.now().microsecondsSinceEpoch}_$_idempCounter';
  }

  // -------------------------------------------------------------
  // VISITAS: Caché residente, vigilancia (próximas) y administrador
  // -------------------------------------------------------------

  /// Guarda en caché la lista de visitas del residente.
  static Future<void> cacheVisitasResidente(List<VisitaModel> visitas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(visitas.map((v) => v.toJson()).toList());
      await prefs.setString(_kKeyVisitasResidente, encoded);
    } catch (_) {}
  }

  /// Recupera las visitas en caché del residente.
  static Future<List<VisitaModel>> getCachedVisitasResidente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyVisitasResidente);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str) as List<dynamic>;
        return list
            .map((item) => VisitaModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Guarda en caché las visitas próximas para vigilancia.
  static Future<void> cacheVisitasProximas(List<VisitaModel> visitas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(visitas.map((v) => v.toJson()).toList());
      await prefs.setString(_kKeyVisitasProximas, encoded);
    } catch (_) {}
  }

  /// Recupera las visitas próximas en caché para vigilancia.
  static Future<List<VisitaModel>> getCachedVisitasProximas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyVisitasProximas);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str) as List<dynamic>;
        return list
            .map((item) => VisitaModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Guarda en caché el histórico de visitas para el administrador.
  static Future<void> cacheVisitasAdmin(List<VisitaModel> visitas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(visitas.map((v) => v.toJson()).toList());
      await prefs.setString(_kKeyVisitasAdmin, encoded);
    } catch (_) {}
  }

  /// Recupera el histórico de visitas en caché para el administrador.
  static Future<List<VisitaModel>> getCachedVisitasAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyVisitasAdmin);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str) as List<dynamic>;
        return list
            .map((item) => VisitaModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // -------------------------------------------------------------
  // AVISOS: Vigentes e histórico
  // -------------------------------------------------------------

  static Future<void> cacheAvisosVigentes(List<dynamic> avisos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKeyAvisosVigentes, jsonEncode(avisos));
    } catch (_) {}
  }

  static Future<List<dynamic>> getCachedAvisosVigentes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyAvisosVigentes);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  static Future<void> cacheAvisosHistorico(List<dynamic> avisos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKeyAvisosHistorico, jsonEncode(avisos));
    } catch (_) {}
  }

  static Future<List<dynamic>> getCachedAvisosHistorico() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyAvisosHistorico);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // -------------------------------------------------------------
  // VIVIENDAS Y RESIDENTES
  // -------------------------------------------------------------

  static Future<void> cacheViviendas(List<dynamic> viviendas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKeyViviendas, jsonEncode(viviendas));
    } catch (_) {}
  }

  static Future<List<dynamic>> getCachedViviendas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyViviendas);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  static Future<void> cacheViviendasConResidentes(List<dynamic> viviendas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKeyViviendasConResidentes, jsonEncode(viviendas));
    } catch (_) {}
  }

  static Future<List<dynamic>> getCachedViviendasConResidentes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyViviendasConResidentes);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  static Future<void> cacheMisViviendas(List<Map<String, dynamic>> viviendas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKeyMisViviendas, jsonEncode(viviendas));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getCachedMisViviendas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyMisViviendas);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str) as List<dynamic>;
        return decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> cacheResidentes(List<dynamic> residentes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKeyResidentes, jsonEncode(residentes));
    } catch (_) {}
  }

  static Future<List<dynamic>> getCachedResidentes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyResidentes);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // -------------------------------------------------------------
  // SUBUSUARIOS E INVITACIONES
  // -------------------------------------------------------------

  static Future<void> cacheSubusuarios(int viviendaId, List<dynamic> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_kKeySubusuariosPrefix$viviendaId', jsonEncode(items));
    } catch (_) {}
  }

  static Future<List<dynamic>> getCachedSubusuarios(int viviendaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_kKeySubusuariosPrefix$viviendaId');
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  static Future<void> cacheMisInvitaciones(List<dynamic> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKeyMisInvitaciones, jsonEncode(items));
    } catch (_) {}
  }

  static Future<List<dynamic>> getCachedMisInvitaciones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyMisInvitaciones);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // -------------------------------------------------------------
  // NOTIFICACIONES
  // -------------------------------------------------------------

  static Future<void> cacheNotificaciones(List<dynamic> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKeyNotificaciones, jsonEncode(items));
    } catch (_) {}
  }

  static Future<List<dynamic>> getCachedNotificaciones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyNotificaciones);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // -------------------------------------------------------------
  // VALIDACIÓN DE APROBACIÓN POR VIGILANTE SIN CONEXIÓN
  // -------------------------------------------------------------

  /// Valida si una visita es elegible para ser aprobada fuera de línea por el vigilante.
  /// REGLA ESTRICTA: SOLAMENTE visitas que ya fueron descargadas en caché y cuyo estado sea 'esperada' o 'programada'.
  static Future<Map<String, dynamic>> canApproveOffline(String visitaId) async {
    final cachedList = await getCachedVisitasProximas();
    final index = cachedList.indexWhere((v) => v.id == visitaId);

    if (index < 0) {
      return {
        'allowed': false,
        'reason': 'Esta visita no fue descargada previamente. En modo sin conexión solo se pueden aprobar visitas descargadas.',
      };
    }

    final visita = cachedList[index];
    final estado = visita.estado.trim().toLowerCase();
    final esEsperada = visita.isProgramada || estado == 'programada' || estado == 'esperada';

    if (!esEsperada) {
      return {
        'allowed': false,
        'reason': 'La visita no está en estado "esperada" (estado actual: ${visita.estado}). En modo sin conexión solo se pueden aprobar visitas esperadas.',
        'visita': visita,
      };
    }

    // Validación estricta de vigencia temporal
    if (DateTime.now().isAfter(visita.vigenciaHasta)) {
      return {
        'allowed': false,
        'reason': 'La vigencia de esta visita ha expirado (${visita.vigenciaHasta}). En modo sin conexión no se permite aprobar visitas vencidas.',
        'visita': visita,
      };
    }

    return {
      'allowed': true,
      'visita': visita,
    };
  }

  // -------------------------------------------------------------
  // ENCOLAMIENTO Y SINCRONIZACIÓN DE ACCIONES
  // -------------------------------------------------------------

  /// Encola una acción de entrada o salida con clave de idempotencia única.
  /// Si la acción ya estaba encolada para la misma visita y tipo, no la duplica.
  static Future<OfflineApprovalAction> queueOfflineApproval({
    required String visitaId,
    required String tipo,
    String? codigo,
    String? nombreVisitante,
    String? numeroCasa,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getPendingApprovals();

    // Verificación de idempotencia local: si ya existe acción pendiente para esta visita y tipo, la reutiliza
    final existingIndex = queue.indexWhere(
        (a) => a.visitaId == visitaId && a.tipo.toLowerCase() == tipo.toLowerCase());

    if (existingIndex >= 0) {
      return queue[existingIndex];
    }

    final idUnica = generateIdempotencyKey(tipo, visitaId);
    final action = OfflineApprovalAction(
      id: idUnica,
      visitaId: visitaId,
      tipo: tipo,
      codigo: codigo,
      nombreVisitante: nombreVisitante,
      numeroCasa: numeroCasa,
    );

    queue.add(action);
    final encoded = jsonEncode(queue.map((a) => a.toJson()).toList());
    await prefs.setString(_kKeyOfflineApprovals, encoded);

    // Actualiza localmente el estado de la visita en caché para reflejar el cambio inmediato en la UI
    await _actualizarEstadoVisitaEnCache(visitaId, tipo);

    return action;
  }

  /// Obtiene la lista de acciones pendientes de sincronización.
  static Future<List<OfflineApprovalAction>> getPendingApprovals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyOfflineApprovals);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str) as List<dynamic>;
        return list
            .map((item) => OfflineApprovalAction.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Sincroniza todas las acciones pendientes contra el backend.
  /// Retorna un mapa con el conteo de sincronizados exitosos y errores.
  static Future<Map<String, int>> syncPendingApprovals(VisitasService service) async {
    final queue = await getPendingApprovals();
    if (queue.isEmpty) {
      return {'synced': 0, 'failed': 0};
    }

    int synced = 0;
    int failed = 0;
    final List<OfflineApprovalAction> remaining = [];

    for (final action in queue) {
      try {
        Map<String, dynamic> res;
        if (action.tipo.toLowerCase() == 'salida') {
          res = await service.registrarSalida(action.visitaId);
        } else {
          res = await service.registrarEntrada(action.visitaId);
        }

        // Si tuvo éxito o si el servidor indica que ya fue procesada (idempotencia del backend)
        final success = res['success'] == true;
        final errorMsg = (res['error'] ?? '').toString().toLowerCase();
        final alreadyProcessed = errorMsg.contains('ya ingresó') ||
            errorMsg.contains('ya registrada') ||
            errorMsg.contains('already');

        if (success || alreadyProcessed) {
          synced++;
        } else {
          action.retryCount++;
          if (action.retryCount < kMaxOfflineRetries) {
            remaining.add(action);
          }
          failed++;
        }
      } catch (e) {
        action.retryCount++;
        if (action.retryCount < kMaxOfflineRetries) {
          remaining.add(action);
        }
        failed++;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(remaining.map((a) => a.toJson()).toList());
    await prefs.setString(_kKeyOfflineApprovals, encoded);

    return {'synced': synced, 'failed': failed};
  }

  static Future<void> _actualizarEstadoVisitaEnCache(String visitaId, String tipo) async {
    try {
      final proximas = await getCachedVisitasProximas();
      bool modified = false;
      for (int i = 0; i < proximas.length; i++) {
        if (proximas[i].id == visitaId) {
          proximas[i] = proximas[i].copyWith(
            estado: tipo.toLowerCase() == 'salida' ? 'completada' : 'ingresada',
            horaEntrada: tipo.toLowerCase() == 'entrada' ? DateTime.now() : proximas[i].horaEntrada,
            horaSalida: tipo.toLowerCase() == 'salida' ? DateTime.now() : proximas[i].horaSalida,
          );
          modified = true;
          break;
        }
      }
      if (modified) {
        await cacheVisitasProximas(proximas);
      }
    } catch (_) {}
  }
}
