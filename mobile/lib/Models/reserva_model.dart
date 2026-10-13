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
}
