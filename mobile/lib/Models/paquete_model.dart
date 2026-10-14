class PaqueteModel {
  final String id;
  final String? condominioId;
  final String? condominioNombre;
  final int viviendaId;
  final String numeroCasa;
  final int? servicioId;
  final String? servicioNombre;
  final String destinatarioNombre;
  final String? numeroGuia;
  final String? descripcion;
  final String? notas;
  final DateTime? fechaEsperadaDesde;
  final DateTime? fechaEsperadaHasta;
  final String estado;
  final bool esInesperado;
  final String? ubicacionAlmacen;
  final DateTime? recibidoEn;
  final String? recibidoPor;
  final String? recibidoPorNombre;
  final DateTime? entregadoEn;
  final String? entregadoANombre;
  final String? entregadoPor;
  final String? entregadoPorNombre;
  final String? creadoPor;
  final String? creadoPorNombre;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  PaqueteModel({
    required this.id,
    this.condominioId,
    this.condominioNombre,
    required this.viviendaId,
    required this.numeroCasa,
    this.servicioId,
    this.servicioNombre,
    required this.destinatarioNombre,
    this.numeroGuia,
    this.descripcion,
    this.notas,
    this.fechaEsperadaDesde,
    this.fechaEsperadaHasta,
    required this.estado,
    this.esInesperado = false,
    this.ubicacionAlmacen,
    this.recibidoEn,
    this.recibidoPor,
    this.recibidoPorNombre,
    this.entregadoEn,
    this.entregadoANombre,
    this.entregadoPor,
    this.entregadoPorNombre,
    this.creadoPor,
    this.creadoPorNombre,
    this.creadoEn,
    this.actualizadoEn,
  });

  bool get isEsperado => estado.toLowerCase() == 'esperado';
  bool get isRecibido => estado.toLowerCase() == 'recibido';
  bool get isEntregado => estado.toLowerCase() == 'entregado';
  bool get isCancelado => estado.toLowerCase() == 'cancelado';
  bool get isVencido => estado.toLowerCase() == 'vencido';
  bool get isDevuelto => estado.toLowerCase() == 'devuelto';

  String get estadoLabel {
    switch (estado.toLowerCase()) {
      case 'esperado':
        return 'Esperado';
      case 'recibido':
        return 'En Caseta';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      case 'vencido':
        return 'Vencido';
      case 'devuelto':
        return 'Devuelto';
      default:
        return estado;
    }
  }

  factory PaqueteModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    int parseViviendaId(dynamic val) {
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '') ?? 0;
    }

    int? parseNullableInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    return PaqueteModel(
      id: (json['id'] ?? '').toString(),
      condominioId: json['condominioId']?.toString() ?? json['condominio_id']?.toString(),
      condominioNombre: json['condominioNombre']?.toString() ?? json['condominio_nombre']?.toString(),
      viviendaId: parseViviendaId(json['viviendaId'] ?? json['vivienda_id']),
      numeroCasa: (json['numeroCasa'] ?? json['numero_casa'] ?? '').toString(),
      servicioId: parseNullableInt(json['servicioId'] ?? json['servicio_id']),
      servicioNombre: json['servicioNombre']?.toString() ?? json['servicio_nombre']?.toString(),
      destinatarioNombre: (json['destinatarioNombre'] ?? json['destinatario_nombre'] ?? '').toString(),
      numeroGuia: json['numeroGuia']?.toString() ?? json['numero_guia']?.toString(),
      descripcion: json['descripcion']?.toString(),
      notas: json['notas']?.toString(),
      fechaEsperadaDesde: parseNullableDate(json['fechaEsperadaDesde'] ?? json['fecha_esperada_desde']),
      fechaEsperadaHasta: parseNullableDate(json['fechaEsperadaHasta'] ?? json['fecha_esperada_hasta']),
      estado: (json['estado'] ?? 'esperado').toString(),
      esInesperado: json['esInesperado'] == true || json['es_inesperado'] == true,
      ubicacionAlmacen: json['ubicacionAlmacen']?.toString() ?? json['ubicacion_almacen']?.toString(),
      recibidoEn: parseNullableDate(json['recibidoEn'] ?? json['recibido_en']),
      recibidoPor: json['recibidoPor']?.toString() ?? json['recibido_por']?.toString(),
      recibidoPorNombre: json['recibidoPorNombre']?.toString() ?? json['recibido_por_nombre']?.toString(),
      entregadoEn: parseNullableDate(json['entregadoEn'] ?? json['entregado_en']),
      entregadoANombre: json['entregadoANombre']?.toString() ?? json['entregado_a_nombre']?.toString(),
      entregadoPor: json['entregadoPor']?.toString() ?? json['entregado_por']?.toString(),
      entregadoPorNombre: json['entregadoPorNombre']?.toString() ?? json['entregado_por_nombre']?.toString(),
      creadoPor: json['creadoPor']?.toString() ?? json['creado_por']?.toString(),
      creadoPorNombre: json['creadoPorNombre']?.toString() ?? json['creado_por_nombre']?.toString(),
      creadoEn: parseNullableDate(json['creadoEn'] ?? json['creado_en']),
      actualizadoEn: parseNullableDate(json['actualizadoEn'] ?? json['actualizado_en']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (condominioId != null) 'condominioId': condominioId,
      if (condominioNombre != null) 'condominioNombre': condominioNombre,
      'viviendaId': viviendaId,
      'numeroCasa': numeroCasa,
      if (servicioId != null) 'servicioId': servicioId,
      if (servicioNombre != null) 'servicioNombre': servicioNombre,
      'destinatarioNombre': destinatarioNombre,
      if (numeroGuia != null) 'numeroGuia': numeroGuia,
      if (descripcion != null) 'descripcion': descripcion,
      if (notas != null) 'notas': notas,
      if (fechaEsperadaDesde != null) 'fechaEsperadaDesde': fechaEsperadaDesde?.toUtc().toIso8601String(),
      if (fechaEsperadaHasta != null) 'fechaEsperadaHasta': fechaEsperadaHasta?.toUtc().toIso8601String(),
      'estado': estado,
      'esInesperado': esInesperado,
      if (ubicacionAlmacen != null) 'ubicacionAlmacen': ubicacionAlmacen,
      if (recibidoEn != null) 'recibidoEn': recibidoEn?.toUtc().toIso8601String(),
      if (recibidoPor != null) 'recibidoPor': recibidoPor,
      if (recibidoPorNombre != null) 'recibidoPorNombre': recibidoPorNombre,
      if (entregadoEn != null) 'entregadoEn': entregadoEn?.toUtc().toIso8601String(),
      if (entregadoANombre != null) 'entregadoANombre': entregadoANombre,
      if (entregadoPor != null) 'entregadoPor': entregadoPor,
      if (entregadoPorNombre != null) 'entregadoPorNombre': entregadoPorNombre,
      if (creadoPor != null) 'creadoPor': creadoPor,
      if (creadoPorNombre != null) 'creadoPorNombre': creadoPorNombre,
      if (creadoEn != null) 'creadoEn': creadoEn?.toUtc().toIso8601String(),
      if (actualizadoEn != null) 'actualizadoEn': actualizadoEn?.toUtc().toIso8601String(),
    };
  }

  PaqueteModel copyWith({
    String? id,
    String? condominioId,
    String? condominioNombre,
    int? viviendaId,
    String? numeroCasa,
    int? servicioId,
    String? servicioNombre,
    String? destinatarioNombre,
    String? numeroGuia,
    String? descripcion,
    String? notas,
    DateTime? fechaEsperadaDesde,
    DateTime? fechaEsperadaHasta,
    String? estado,
    bool? esInesperado,
    String? ubicacionAlmacen,
    DateTime? recibidoEn,
    String? recibidoPor,
    String? recibidoPorNombre,
    DateTime? entregadoEn,
    String? entregadoANombre,
    String? entregadoPor,
    String? entregadoPorNombre,
    String? creadoPor,
    String? creadoPorNombre,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return PaqueteModel(
      id: id ?? this.id,
      condominioId: condominioId ?? this.condominioId,
      condominioNombre: condominioNombre ?? this.condominioNombre,
      viviendaId: viviendaId ?? this.viviendaId,
      numeroCasa: numeroCasa ?? this.numeroCasa,
      servicioId: servicioId ?? this.servicioId,
      servicioNombre: servicioNombre ?? this.servicioNombre,
      destinatarioNombre: destinatarioNombre ?? this.destinatarioNombre,
      numeroGuia: numeroGuia ?? this.numeroGuia,
      descripcion: descripcion ?? this.descripcion,
      notas: notas ?? this.notas,
      fechaEsperadaDesde: fechaEsperadaDesde ?? this.fechaEsperadaDesde,
      fechaEsperadaHasta: fechaEsperadaHasta ?? this.fechaEsperadaHasta,
      estado: estado ?? this.estado,
      esInesperado: esInesperado ?? this.esInesperado,
      ubicacionAlmacen: ubicacionAlmacen ?? this.ubicacionAlmacen,
      recibidoEn: recibidoEn ?? this.recibidoEn,
      recibidoPor: recibidoPor ?? this.recibidoPor,
      recibidoPorNombre: recibidoPorNombre ?? this.recibidoPorNombre,
      entregadoEn: entregadoEn ?? this.entregadoEn,
      entregadoANombre: entregadoANombre ?? this.entregadoANombre,
      entregadoPor: entregadoPor ?? this.entregadoPor,
      entregadoPorNombre: entregadoPorNombre ?? this.entregadoPorNombre,
      creadoPor: creadoPor ?? this.creadoPor,
      creadoPorNombre: creadoPorNombre ?? this.creadoPorNombre,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }
}
