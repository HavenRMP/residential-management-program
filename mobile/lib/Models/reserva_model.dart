import 'package:flutter/material.dart';

class ReservaModel {
  final String id;
  final String areaId;
  final String areaNombre;
  final String? condominioId;
  final String? tipo;
  final String estado;
  final DateTime inicio;
  final DateTime fin;
  final String? titularId;
  final String? titularNombre;
  final String? titularApellidos;
  final int? viviendaId;
  final String? numeroCasa;
  final String? solicitanteId;
  final String? solicitanteNombre;
  final String? solicitanteApellidos;
  final String? solicitanteEmail;
  final String? parentesco;
  final String? aprobadorId;
  final String? aprobadorNombre;
  final String? aprobadorApellidos;
  final String? motivo;
  final DateTime? confirmadaEn;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;
  final int noShowsTitular;
  final int noShowsSolicitante;

  ReservaModel({
    required this.id,
    required this.areaId,
    required this.areaNombre,
    this.condominioId,
    this.tipo,
    required this.estado,
    required this.inicio,
    required this.fin,
    this.titularId,
    this.titularNombre,
    this.titularApellidos,
    this.viviendaId,
    this.numeroCasa,
    this.solicitanteId,
    this.solicitanteNombre,
    this.solicitanteApellidos,
    this.solicitanteEmail,
    this.parentesco,
    this.aprobadorId,
    this.aprobadorNombre,
    this.aprobadorApellidos,
    this.motivo,
    this.confirmadaEn,
    this.creadoEn,
    this.actualizadoEn,
    this.noShowsTitular = 0,
    this.noShowsSolicitante = 0,
  });

  factory ReservaModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v.toLocal();
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? parseDateOpt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v)?.toLocal();
      }
      return null;
    }

    return ReservaModel(
      id: (json['id'] ?? '').toString(),
      areaId: (json['areaId'] ?? json['area_id'] ?? '').toString(),
      areaNombre: (json['areaNombre'] ?? json['area_nombre'] ?? 'Área Común').toString(),
      condominioId: json['condominioId']?.toString() ?? json['condominio_id']?.toString(),
      tipo: json['tipo']?.toString(),
      estado: (json['estado'] ?? 'PENDIENTE_ADMIN').toString().toUpperCase().trim(),
      inicio: parseDate(json['inicio']),
      fin: parseDate(json['fin']),
      titularId: json['titularId']?.toString() ?? json['titular_id']?.toString(),
      titularNombre: json['titularNombre']?.toString() ?? json['titular_nombre']?.toString(),
      titularApellidos: json['titularApellidos']?.toString() ?? json['titular_apellidos']?.toString(),
      viviendaId: json['viviendaId'] is num
          ? (json['viviendaId'] as num).toInt()
          : (json['vivienda_id'] is num ? (json['vivienda_id'] as num).toInt() : null),
      numeroCasa: json['numeroCasa']?.toString() ?? json['numero_casa']?.toString(),
      solicitanteId: json['solicitanteId']?.toString() ?? json['solicitante_id']?.toString(),
      solicitanteNombre: json['solicitanteNombre']?.toString() ?? json['solicitante_nombre']?.toString(),
      solicitanteApellidos: json['solicitanteApellidos']?.toString() ?? json['solicitante_apellidos']?.toString(),
      solicitanteEmail: json['solicitanteEmail']?.toString() ?? json['solicitante_email']?.toString(),
      parentesco: json['parentesco']?.toString(),
      aprobadorId: json['aprobadorId']?.toString() ?? json['aprobador_id']?.toString(),
      aprobadorNombre: json['aprobadorNombre']?.toString() ?? json['aprobador_nombre']?.toString(),
      aprobadorApellidos: json['aprobadorApellidos']?.toString() ?? json['aprobador_apellidos']?.toString(),
      motivo: json['motivo']?.toString(),
      confirmadaEn: parseDateOpt(json['confirmadaEn'] ?? json['confirmada_en']),
      creadoEn: parseDateOpt(json['creadoEn'] ?? json['creado_en']),
      actualizadoEn: parseDateOpt(json['actualizadoEn'] ?? json['actualizado_en']),
      noShowsTitular: json['noShowsTitular'] is num
          ? (json['noShowsTitular'] as num).toInt()
          : (json['no_shows_titular'] is num ? (json['no_shows_titular'] as num).toInt() : 0),
      noShowsSolicitante: json['noShowsSolicitante'] is num
          ? (json['noShowsSolicitante'] as num).toInt()
          : (json['no_shows_solicitante'] is num ? (json['no_shows_solicitante'] as num).toInt() : 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'areaId': areaId,
      'areaNombre': areaNombre,
      if (condominioId != null) 'condominioId': condominioId,
      if (tipo != null) 'tipo': tipo,
      'estado': estado,
      'inicio': inicio.toUtc().toIso8601String(),
      'fin': fin.toUtc().toIso8601String(),
      if (titularId != null) 'titularId': titularId,
      if (titularNombre != null) 'titularNombre': titularNombre,
      if (titularApellidos != null) 'titularApellidos': titularApellidos,
      if (viviendaId != null) 'viviendaId': viviendaId,
      if (numeroCasa != null) 'numeroCasa': numeroCasa,
      if (solicitanteId != null) 'solicitanteId': solicitanteId,
      if (solicitanteNombre != null) 'solicitanteNombre': solicitanteNombre,
      if (solicitanteApellidos != null) 'solicitanteApellidos': solicitanteApellidos,
      if (solicitanteEmail != null) 'solicitanteEmail': solicitanteEmail,
      if (parentesco != null) 'parentesco': parentesco,
      if (aprobadorId != null) 'aprobadorId': aprobadorId,
      if (aprobadorNombre != null) 'aprobadorNombre': aprobadorNombre,
      if (aprobadorApellidos != null) 'aprobadorApellidos': aprobadorApellidos,
      if (motivo != null) 'motivo': motivo,
      if (confirmadaEn != null) 'confirmadaEn': confirmadaEn!.toUtc().toIso8601String(),
      if (creadoEn != null) 'creadoEn': creadoEn!.toUtc().toIso8601String(),
      if (actualizadoEn != null) 'actualizadoEn': actualizadoEn!.toUtc().toIso8601String(),
      'noShowsTitular': noShowsTitular,
      'noShowsSolicitante': noShowsSolicitante,
    };
  }

  String get solicitanteCompleto {
    final parts = [solicitanteNombre, solicitanteApellidos].where((p) => p != null && p.isNotEmpty).join(' ');
    return parts.isNotEmpty ? parts : 'Solicitante';
  }

  String get titularCompleto {
    final parts = [titularNombre, titularApellidos].where((p) => p != null && p.isNotEmpty).join(' ');
    return parts.isNotEmpty ? parts : 'Titular';
  }

  bool get esPendienteTitular => estado == 'PENDIENTE_TITULAR';
  bool get esPendienteAdmin => estado == 'PENDIENTE_ADMIN';
  bool get esAprobada => estado == 'APROBADA';
  bool get esConfirmada => estado == 'CONFIRMADA';
  bool get esRechazada => estado == 'RECHAZADA_TITULAR' || estado == 'RECHAZADA_ADMIN';
  bool get esCancelada => estado == 'CANCELADA' || estado == 'CANCELADA_ADMIN';
  bool get esNoUtilizada => estado == 'NO_UTILIZADA';
  bool get esFinalizada => estado == 'FINALIZADA';

  /// Regla RE011: Habilitada entre 7 días y 72 horas antes del evento.
  bool get esConfirmable {
    if (!esAprobada) return false;
    final ahora = DateTime.now();
    final diferencia = inicio.difference(ahora);
    return diferencia.inHours >= 72 && diferencia.inDays <= 7;
  }

  /// Indica si la reserva puede cancelarse por el residente (antes de su inicio)
  bool get esCancelable {
    if (DateTime.now().isAfter(inicio)) return false;
    return esPendienteTitular || esPendienteAdmin || esAprobada || esConfirmada;
  }

  /// Indica si el administrador puede marcarla como no utilizada (después de terminar)
  bool get esMarcableNoShow {
    if (DateTime.now().isBefore(fin)) return false;
    return esConfirmada || esAprobada;
  }

  String get estadoEtiqueta {
    switch (estado) {
      case 'PENDIENTE_TITULAR':
        return 'Pendiente Titular';
      case 'PENDIENTE_ADMIN':
        return 'Pendiente Admin';
      case 'APROBADA':
        return 'Aprobada';
      case 'CONFIRMADA':
        return 'Confirmada';
      case 'RECHAZADA_TITULAR':
        return 'Rechazada (Titular)';
      case 'RECHAZADA_ADMIN':
        return 'Rechazada (Admin)';
      case 'CANCELADA':
        return 'Cancelada';
      case 'CANCELADA_ADMIN':
        return 'Cancelada (Admin)';
      case 'NO_UTILIZADA':
        return 'No Utilizada (No-Show)';
      case 'FINALIZADA':
        return 'Finalizada';
      default:
        return estado;
    }
  }

  Color get estadoColor {
    switch (estado) {
      case 'PENDIENTE_TITULAR':
      case 'PENDIENTE_ADMIN':
        return const Color(0xFFD97706); // Amber
      case 'APROBADA':
        return const Color(0xFF2563EB); // Blue
      case 'CONFIRMADA':
        return const Color(0xFF059669); // Emerald
      case 'RECHAZADA_TITULAR':
      case 'RECHAZADA_ADMIN':
      case 'CANCELADA':
      case 'CANCELADA_ADMIN':
        return const Color(0xFFDC2626); // Red
      case 'NO_UTILIZADA':
        return const Color(0xFF7C3AED); // Purple
      case 'FINALIZADA':
        return const Color(0xFF64748B); // Slate
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData get estadoIcono {
    switch (estado) {
      case 'PENDIENTE_TITULAR':
      case 'PENDIENTE_ADMIN':
        return Icons.hourglass_top_rounded;
      case 'APROBADA':
        return Icons.check_circle_outline_rounded;
      case 'CONFIRMADA':
        return Icons.verified_rounded;
      case 'RECHAZADA_TITULAR':
      case 'RECHAZADA_ADMIN':
        return Icons.cancel_outlined;
      case 'CANCELADA':
      case 'CANCELADA_ADMIN':
        return Icons.block_rounded;
      case 'NO_UTILIZADA':
        return Icons.person_off_rounded;
      case 'FINALIZADA':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
