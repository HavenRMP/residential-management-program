class EstadoCargo {
  static const String pendiente = 'Pendiente';
  static const String parcial = 'Parcial';
  static const String pagado = 'Pagado';
  static const String cancelado = 'Cancelado';

  static const List<String> todos = [
    pendiente,
    parcial,
    pagado,
    cancelado,
  ];
}

class EstadoPago {
  static const String pendienteConfirmacion = 'PendienteConfirmacion';
  static const String confirmado = 'Confirmado';
  static const String rechazado = 'Rechazado';
  static const String anulado = 'Anulado';

  static const List<String> todos = [
    pendienteConfirmacion,
    confirmado,
    rechazado,
    anulado,
  ];
}

class MetodoPago {
  static const String efectivo = 'Efectivo';
  static const String transferencia = 'Transferencia';
  static const String deposito = 'Deposito';
  static const String otro = 'Otro';

  static const List<String> todos = [
    efectivo,
    transferencia,
    deposito,
    otro,
  ];
}

class TipoCargo {
  static const String renta = 'Renta';
  static const String mantenimiento = 'Mantenimiento';
  static const String servicio = 'Servicio';
  static const String multa = 'Multa';
  static const String otro = 'Otro';

  static const List<String> todos = [
    mantenimiento,
    servicio,
    renta,
    multa,
    otro,
  ];
}

class TipoMovimientoSaldo {
  static const String abono = 'Abono';
  static const String aplicacion = 'Aplicacion';
  static const String reversoAbono = 'ReversoAbono';
  static const String reversoAplicacion = 'ReversoAplicacion';

  static const List<String> todos = [
    abono,
    aplicacion,
    reversoAbono,
    reversoAplicacion,
  ];
}

class ResponsablePago {
  static const String propietario = 'Propietario';
  static const String residente = 'Residente';

  static const List<String> todos = [
    propietario,
    residente,
  ];
}

class OrigenPago {
  static const String admin = 'Admin';
  static const String inquilino = 'Inquilino';

  static const List<String> todos = [
    admin,
    inquilino,
  ];
}

/// Respuesta de subida y optimización de comprobante
class ComprobanteUploadResponse {
  final String ruta;
  final String hash;
  final int tamanoBytes;
  final String contentType;

  const ComprobanteUploadResponse({
    required this.ruta,
    required this.hash,
    required this.tamanoBytes,
    required this.contentType,
  });

  factory ComprobanteUploadResponse.fromJson(Map<String, dynamic> json) {
    return ComprobanteUploadResponse(
      ruta: json['ruta']?.toString() ?? '',
      hash: json['hash']?.toString() ?? '',
      tamanoBytes: (json['tamanoBytes'] as num?)?.toInt() ?? 0,
      contentType: json['contentType']?.toString() ?? 'image/jpeg',
    );
  }

  Map<String, dynamic> toJson() => {
        'ruta': ruta,
        'hash': hash,
        'tamanoBytes': tamanoBytes,
        'contentType': contentType,
      };
}

/// Pago asociado a un cargo
class PagoAsociadoModel {
  final String pagoId;
  final double monto;
  final DateTime? fechaPago;
  final String metodo;
  final String estado;

  const PagoAsociadoModel({
    required this.pagoId,
    required this.monto,
    this.fechaPago,
    required this.metodo,
    required this.estado,
  });

  factory PagoAsociadoModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedFecha;
    if (json['fechaPago'] != null) {
      parsedFecha = DateTime.tryParse(json['fechaPago'].toString());
    }
    return PagoAsociadoModel(
      pagoId: json['pagoId']?.toString() ?? '',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      fechaPago: parsedFecha,
      metodo: json['metodo']?.toString() ?? MetodoPago.otro,
      estado: json['estado']?.toString() ?? EstadoPago.pendienteConfirmacion,
    );
  }

  Map<String, dynamic> toJson() => {
        'pagoId': pagoId,
        'monto': monto,
        'fechaPago': fechaPago?.toIso8601String(),
        'metodo': metodo,
        'estado': estado,
      };
}

/// Cargo o deuda asignada a una vivienda
class CargoModel {
  final String id;
  final int viviendaId;
  final String? numeroCasa;
  final String tipo;
  final String concepto;
  final double monto;
  final double montoPagado;
  final double saldoPendiente;
  final String estado;
  final String? fechaVencimiento;
  final String? periodo;
  final String? notas;
  final List<PagoAsociadoModel> pagosAsociados;

  const CargoModel({
    required this.id,
    required this.viviendaId,
    this.numeroCasa,
    required this.tipo,
    required this.concepto,
    required this.monto,
    this.montoPagado = 0.0,
    required this.saldoPendiente,
    required this.estado,
    this.fechaVencimiento,
    this.periodo,
    this.notas,
    this.pagosAsociados = const [],
  });

  bool get estaVencido {
    if (fechaVencimiento == null || fechaVencimiento!.isEmpty) return false;
    final parsed = DateTime.tryParse(fechaVencimiento!);
    if (parsed == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(parsed.year, parsed.month, parsed.day);
    return due.isBefore(today) && estado != EstadoCargo.pagado && estado != EstadoCargo.cancelado;
  }

  factory CargoModel.fromJson(Map<String, dynamic> json) {
    final pagosRaw = json['pagosAsociados'] as List<dynamic>? ?? [];
    return CargoModel(
      id: json['id']?.toString() ?? '',
      viviendaId: (json['viviendaId'] as num?)?.toInt() ?? 0,
      numeroCasa: json['numeroCasa']?.toString(),
      tipo: json['tipo']?.toString() ?? TipoCargo.mantenimiento,
      concepto: json['concepto']?.toString() ?? 'Cargo',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      montoPagado: (json['montoPagado'] as num?)?.toDouble() ?? 0.0,
      saldoPendiente: (json['saldoPendiente'] as num?)?.toDouble() ??
          ((json['monto'] as num?)?.toDouble() ?? 0.0) -
              ((json['montoPagado'] as num?)?.toDouble() ?? 0.0),
      estado: json['estado']?.toString() ?? EstadoCargo.pendiente,
      fechaVencimiento: json['fechaVencimiento']?.toString(),
      periodo: json['periodo']?.toString(),
      notas: json['notas']?.toString(),
      pagosAsociados: pagosRaw
          .whereType<Map<String, dynamic>>()
          .map((p) => PagoAsociadoModel.fromJson(p))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'viviendaId': viviendaId,
        'numeroCasa': numeroCasa,
        'tipo': tipo,
        'concepto': concepto,
        'monto': monto,
        'montoPagado': montoPagado,
        'saldoPendiente': saldoPendiente,
        'estado': estado,
        'fechaVencimiento': fechaVencimiento,
        'periodo': periodo,
        'notas': notas,
        'pagosAsociados': pagosAsociados.map((p) => p.toJson()).toList(),
      };
}

/// Transacción de pago
class PagoModel {
  final String id;
  final String? cargoId;
  final int? viviendaId;
  final String? numeroCasa;
  final String? conceptoCargo;
  final double monto;
  final String metodo;
  final DateTime? fechaPago;
  final String? folioComprobante;
  final String? rutaComprobante;
  final String? notas;
  final String estado;
  final String? origen;
  final String? motivoRechazo;
  final DateTime? fechaRegistro;

  const PagoModel({
    required this.id,
    this.cargoId,
    this.viviendaId,
    this.numeroCasa,
    this.conceptoCargo,
    required this.monto,
    required this.metodo,
    this.fechaPago,
    this.folioComprobante,
    this.rutaComprobante,
    this.notas,
    required this.estado,
    this.origen,
    this.motivoRechazo,
    this.fechaRegistro,
  });

  factory PagoModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedFechaPago;
    if (json['fechaPago'] != null) {
      parsedFechaPago = DateTime.tryParse(json['fechaPago'].toString());
    }
    DateTime? parsedFechaRegistro;
    if (json['fechaRegistro'] != null) {
      parsedFechaRegistro = DateTime.tryParse(json['fechaRegistro'].toString());
    }

    return PagoModel(
      id: json['id']?.toString() ?? json['pagoId']?.toString() ?? '',
      cargoId: json['cargoId']?.toString(),
      viviendaId: (json['viviendaId'] as num?)?.toInt(),
      numeroCasa: json['numeroCasa']?.toString(),
      conceptoCargo: json['conceptoCargo']?.toString(),
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      metodo: json['metodo']?.toString() ?? MetodoPago.otro,
      fechaPago: parsedFechaPago,
      folioComprobante: json['folioComprobante']?.toString(),
      rutaComprobante: json['rutaComprobante']?.toString(),
      notas: json['notas']?.toString(),
      estado: json['estado']?.toString() ?? EstadoPago.pendienteConfirmacion,
      origen: json['origen']?.toString() ?? OrigenPago.inquilino,
      motivoRechazo: json['motivoRechazo']?.toString() ?? json['motivo']?.toString(),
      fechaRegistro: parsedFechaRegistro,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cargoId': cargoId,
        'viviendaId': viviendaId,
        'numeroCasa': numeroCasa,
        'conceptoCargo': conceptoCargo,
        'monto': monto,
        'metodo': metodo,
        'fechaPago': fechaPago?.toIso8601String(),
        'folioComprobante': folioComprobante,
        'rutaComprobante': rutaComprobante,
        'notas': notas,
        'estado': estado,
        'origen': origen,
        'motivoRechazo': motivoRechazo,
        'fechaRegistro': fechaRegistro?.toIso8601String(),
      };
}

/// Resumen de saldo por vivienda
class SaldoViviendaResumen {
  final int viviendaId;
  final String numeroCasa;
  final double totalPendiente;
  final double totalVencido;
  final int totalCargosAbiertos;
  final double saldoAFavor;

  const SaldoViviendaResumen({
    required this.viviendaId,
    required this.numeroCasa,
    this.totalPendiente = 0.0,
    this.totalVencido = 0.0,
    this.totalCargosAbiertos = 0,
    this.saldoAFavor = 0.0,
  });

  factory SaldoViviendaResumen.fromJson(Map<String, dynamic> json) {
    return SaldoViviendaResumen(
      viviendaId: (json['viviendaId'] as num?)?.toInt() ?? 0,
      numeroCasa: json['numeroCasa']?.toString() ?? '',
      totalPendiente: (json['totalPendiente'] as num?)?.toDouble() ?? 0.0,
      totalVencido: (json['totalVencido'] as num?)?.toDouble() ?? 0.0,
      totalCargosAbiertos: (json['totalCargosAbiertos'] as num?)?.toInt() ?? 0,
      saldoAFavor: (json['saldoAFavor'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'viviendaId': viviendaId,
        'numeroCasa': numeroCasa,
        'totalPendiente': totalPendiente,
        'totalVencido': totalVencido,
        'totalCargosAbiertos': totalCargosAbiertos,
        'saldoAFavor': saldoAFavor,
      };
}

/// Respuesta de `GET /api/saldos/mi-saldo`
class MiSaldoResponse {
  final double totalPendiente;
  final double totalVencido;
  final int totalCargosAbiertos;
  final double saldoAFavor;
  final List<SaldoViviendaResumen> viviendas;

  const MiSaldoResponse({
    this.totalPendiente = 0.0,
    this.totalVencido = 0.0,
    this.totalCargosAbiertos = 0,
    this.saldoAFavor = 0.0,
    this.viviendas = const [],
  });

  factory MiSaldoResponse.fromJson(Map<String, dynamic> json) {
    final vivsRaw = json['viviendas'] as List<dynamic>? ?? [];
    return MiSaldoResponse(
      totalPendiente: (json['totalPendiente'] as num?)?.toDouble() ?? 0.0,
      totalVencido: (json['totalVencido'] as num?)?.toDouble() ?? 0.0,
      totalCargosAbiertos: (json['totalCargosAbiertos'] as num?)?.toInt() ?? 0,
      saldoAFavor: (json['saldoAFavor'] as num?)?.toDouble() ?? 0.0,
      viviendas: vivsRaw
          .whereType<Map<String, dynamic>>()
          .map((v) => SaldoViviendaResumen.fromJson(v))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalPendiente': totalPendiente,
        'totalVencido': totalVencido,
        'totalCargosAbiertos': totalCargosAbiertos,
        'saldoAFavor': saldoAFavor,
        'viviendas': viviendas.map((v) => v.toJson()).toList(),
      };
}

/// Movimiento de la bolsa de saldo a favor
class MovimientoSaldoModel {
  final String id;
  final int viviendaId;
  final String tipo;
  final double monto;
  final double saldoAnterior;
  final double saldoNuevo;
  final DateTime? fecha;
  final String? concepto;
  final String? referenciaId;

  const MovimientoSaldoModel({
    required this.id,
    required this.viviendaId,
    required this.tipo,
    required this.monto,
    this.saldoAnterior = 0.0,
    this.saldoNuevo = 0.0,
    this.fecha,
    this.concepto,
    this.referenciaId,
  });

  factory MovimientoSaldoModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedFecha;
    if (json['fecha'] != null) {
      parsedFecha = DateTime.tryParse(json['fecha'].toString());
    }
    return MovimientoSaldoModel(
      id: json['id']?.toString() ?? '',
      viviendaId: (json['viviendaId'] as num?)?.toInt() ?? 0,
      tipo: json['tipo']?.toString() ?? TipoMovimientoSaldo.abono,
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      saldoAnterior: (json['saldoAnterior'] as num?)?.toDouble() ?? 0.0,
      saldoNuevo: (json['saldoNuevo'] as num?)?.toDouble() ?? 0.0,
      fecha: parsedFecha,
      concepto: json['concepto']?.toString(),
      referenciaId: json['referenciaId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'viviendaId': viviendaId,
        'tipo': tipo,
        'monto': monto,
        'saldoAnterior': saldoAnterior,
        'saldoNuevo': saldoNuevo,
        'fecha': fecha?.toIso8601String(),
        'concepto': concepto,
        'referenciaId': referenciaId,
      };
}

/// Envoltorio de paginación estándar
class PaginatedResponse<T> {
  final int pagina;
  final int tamanoPagina;
  final int total;
  final List<T> items;

  const PaginatedResponse({
    required this.pagina,
    required this.tamanoPagina,
    required this.total,
    required this.items,
  });

  bool get hasMore => pagina * tamanoPagina < total;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFactory,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PaginatedResponse<T>(
      pagina: (json['pagina'] as num?)?.toInt() ?? 1,
      tamanoPagina: (json['tamanoPagina'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? rawItems.length,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => itemFactory(item))
          .toList(),
    );
  }
}
