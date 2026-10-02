class VisitaModel {
  final String id;
  final int viviendaId;
  final String numeroCasa;
  final String? condominioId;
  final String nombreVisitante;
  final String apellidosVisitante;
  final String? telefonoVisitante;
  final String motivo;
  final int numAcompanantes;
  final String? vehiculoPlacas;
  final String? notas;
  final DateTime fechaLlegadaEsperada;
  final DateTime vigenciaHasta;
  final String estado;
  final DateTime? horaEntrada;
  final DateTime? horaSalida;
  final String? codigo;
  final String? creadoPor;
  final String? creadoPorNombre;
  final DateTime? creadoEn;

  VisitaModel({
    required this.id,
    required this.viviendaId,
    required this.numeroCasa,
    this.condominioId,
    required this.nombreVisitante,
    required this.apellidosVisitante,
    this.telefonoVisitante,
    required this.motivo,
    required this.numAcompanantes,
    this.vehiculoPlacas,
    this.notas,
    required this.fechaLlegadaEsperada,
    required this.vigenciaHasta,
    required this.estado,
    this.horaEntrada,
    this.horaSalida,
    this.codigo,
    this.creadoPor,
    this.creadoPorNombre,
    this.creadoEn,
  });

  String get nombreCompletoVisitante => '$nombreVisitante $apellidosVisitante'.trim();

  bool get isProgramada => estado.toLowerCase() == 'programada';
  bool get isEnCurso => estado.toLowerCase() == 'en_curso';
  bool get isFinalizada => estado.toLowerCase() == 'finalizada';
  bool get isCancelada => estado.toLowerCase() == 'cancelada';
  bool get isExpirada => estado.toLowerCase() == 'expirada';

  factory VisitaModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val == null) return fallback ?? DateTime.now();
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return fallback ?? DateTime.now();
      }
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    return VisitaModel(
      id: (json['id'] ?? '').toString(),
      viviendaId: (json['viviendaId'] ?? json['vivienda_id'] ?? 0) is num
          ? (json['viviendaId'] ?? json['vivienda_id'] as num).toInt()
          : int.tryParse((json['viviendaId'] ?? json['vivienda_id'])?.toString() ?? '') ?? 0,
      numeroCasa: (json['numeroCasa'] ?? json['numero_casa'] ?? '').toString(),
      condominioId: json['condominioId']?.toString() ?? json['condominio_id']?.toString(),
      nombreVisitante: (json['nombreVisitante'] ?? json['nombre_visitante'] ?? '').toString(),
      apellidosVisitante: (json['apellidosVisitante'] ?? json['apellidos_visitante'] ?? '').toString(),
      telefonoVisitante: json['telefonoVisitante']?.toString() ?? json['telefono_visitante']?.toString(),
      motivo: (json['motivo'] ?? 'personal').toString(),
      numAcompanantes: (json['numAcompanantes'] ?? json['num_acompanantes'] ?? 0) is num
          ? (json['numAcompanantes'] ?? json['num_acompanantes'] as num).toInt()
          : int.tryParse((json['numAcompanantes'] ?? json['num_acompanantes'])?.toString() ?? '') ?? 0,
      vehiculoPlacas: json['vehiculoPlacas']?.toString() ?? json['vehiculo_placas']?.toString(),
      notas: json['notas']?.toString(),
      fechaLlegadaEsperada: parseDate(json['fechaLlegadaEsperada'] ?? json['fecha_llegada_esperada']),
      vigenciaHasta: parseDate(json['vigenciaHasta'] ?? json['vigencia_hasta']),
      estado: (json['estado'] ?? 'programada').toString(),
      horaEntrada: parseNullableDate(json['horaEntrada'] ?? json['hora_entrada']),
      horaSalida: parseNullableDate(json['horaSalida'] ?? json['hora_salida']),
      codigo: json['codigo']?.toString(),
      creadoPor: json['creadoPor']?.toString() ?? json['creado_por']?.toString(),
      creadoPorNombre: json['creadoPorNombre']?.toString() ?? json['creado_por_nombre']?.toString(),
      creadoEn: parseNullableDate(json['creadoEn'] ?? json['creado_en']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'viviendaId': viviendaId,
      'numeroCasa': numeroCasa,
      'condominioId': condominioId,
      'nombreVisitante': nombreVisitante,
      'apellidosVisitante': apellidosVisitante,
      'telefonoVisitante': telefonoVisitante,
      'motivo': motivo,
      'numAcompanantes': numAcompanantes,
      'vehiculoPlacas': vehiculoPlacas,
      'notas': notas,
      'fechaLlegadaEsperada': fechaLlegadaEsperada.toUtc().toIso8601String(),
      'vigenciaHasta': vigenciaHasta.toUtc().toIso8601String(),
      'estado': estado,
      'horaEntrada': horaEntrada?.toUtc().toIso8601String(),
      'horaSalida': horaSalida?.toUtc().toIso8601String(),
      'codigo': codigo,
      'creadoPor': creadoPor,
      'creadoPorNombre': creadoPorNombre,
      'creadoEn': creadoEn?.toUtc().toIso8601String(),
    };
  }

  VisitaModel copyWith({
    String? id,
    int? viviendaId,
    String? numeroCasa,
    String? condominioId,
    String? nombreVisitante,
    String? apellidosVisitante,
    String? telefonoVisitante,
    String? motivo,
    int? numAcompanantes,
    String? vehiculoPlacas,
    String? notas,
    DateTime? fechaLlegadaEsperada,
    DateTime? vigenciaHasta,
    String? estado,
    DateTime? horaEntrada,
    DateTime? horaSalida,
    String? codigo,
    String? creadoPor,
    String? creadoPorNombre,
    DateTime? creadoEn,
  }) {
    return VisitaModel(
      id: id ?? this.id,
      viviendaId: viviendaId ?? this.viviendaId,
      numeroCasa: numeroCasa ?? this.numeroCasa,
      condominioId: condominioId ?? this.condominioId,
      nombreVisitante: nombreVisitante ?? this.nombreVisitante,
      apellidosVisitante: apellidosVisitante ?? this.apellidosVisitante,
      telefonoVisitante: telefonoVisitante ?? this.telefonoVisitante,
      motivo: motivo ?? this.motivo,
      numAcompanantes: numAcompanantes ?? this.numAcompanantes,
      vehiculoPlacas: vehiculoPlacas ?? this.vehiculoPlacas,
      notas: notas ?? this.notas,
      fechaLlegadaEsperada: fechaLlegadaEsperada ?? this.fechaLlegadaEsperada,
      vigenciaHasta: vigenciaHasta ?? this.vigenciaHasta,
      estado: estado ?? this.estado,
      horaEntrada: horaEntrada ?? this.horaEntrada,
      horaSalida: horaSalida ?? this.horaSalida,
      codigo: codigo ?? this.codigo,
      creadoPor: creadoPor ?? this.creadoPor,
      creadoPorNombre: creadoPorNombre ?? this.creadoPorNombre,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }
}
