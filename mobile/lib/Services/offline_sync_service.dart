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
