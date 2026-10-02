import 'dart:convert';
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

/// Servicio que gestiona la persistencia fuera de línea, caché y cola de sincronización idempotente.
class OfflineSyncService {
  static const String _kKeyVisitasResidente = 'haven_offline_visitas_residente';
  static const String _kKeyVisitasProximas = 'haven_offline_visitas_proximas';
  static const String _kKeyOfflineApprovals = 'haven_offline_approvals_queue';

  static int _idempCounter = 0;

  /// Genera una clave de idempotencia única para la acción.
  static String generateIdempotencyKey(String tipo, String visitaId) {
    _idempCounter++;
    return 'idemp_${tipo}_${visitaId}_${DateTime.now().microsecondsSinceEpoch}_$_idempCounter';
  }

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
          remaining.add(action);
          failed++;
        }
      } catch (e) {
        action.retryCount++;
        remaining.add(action);
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
}}
