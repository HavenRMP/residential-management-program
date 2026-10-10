class CreatePaqueteEsperadoDto {
  final int viviendaId;
  final String destinatarioNombre;
  final int? servicioId;
  final String? servicioNombre;
  final String? numeroGuia;
  final String? descripcion;
  final String? notas;
  final DateTime? fechaEsperadaDesde;
  final DateTime? fechaEsperadaHasta;

  CreatePaqueteEsperadoDto({
    required this.viviendaId,
    required this.destinatarioNombre,
    this.servicioId,
    this.servicioNombre,
    this.numeroGuia,
    this.descripcion,
    this.notas,
    this.fechaEsperadaDesde,
    this.fechaEsperadaHasta,
  });

  Map<String, dynamic> toJson() {
    return {
      'viviendaId': viviendaId,
      'destinatarioNombre': destinatarioNombre,
      if (servicioId != null) 'servicioId': servicioId,
      if (servicioNombre != null && servicioNombre!.trim().isNotEmpty)
        'servicioNombre': servicioNombre!.trim(),
      if (numeroGuia != null && numeroGuia!.trim().isNotEmpty)
        'numeroGuia': numeroGuia!.trim(),
      if (descripcion != null && descripcion!.trim().isNotEmpty)
        'descripcion': descripcion!.trim(),
      if (notas != null && notas!.trim().isNotEmpty)
        'notas': notas!.trim(),
      if (fechaEsperadaDesde != null)
        'fechaEsperadaDesde': fechaEsperadaDesde!.toUtc().toIso8601String(),
      if (fechaEsperadaHasta != null)
        'fechaEsperadaHasta': fechaEsperadaHasta!.toUtc().toIso8601String(),
    };
  }
}

class UpdatePaqueteEsperadoDto {
  final String? destinatarioNombre;
  final int? servicioId;
  final String? servicioNombre;
  final String? numeroGuia;
  final String? descripcion;
  final String? notas;
  final DateTime? fechaEsperadaDesde;
  final DateTime? fechaEsperadaHasta;

  UpdatePaqueteEsperadoDto({
    this.destinatarioNombre,
    this.servicioId,
    this.servicioNombre,
    this.numeroGuia,
    this.descripcion,
    this.notas,
    this.fechaEsperadaDesde,
    this.fechaEsperadaHasta,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (destinatarioNombre != null) map['destinatarioNombre'] = destinatarioNombre;
    if (servicioId != null) map['servicioId'] = servicioId;
    if (servicioNombre != null) map['servicioNombre'] = servicioNombre;
    if (numeroGuia != null) map['numeroGuia'] = numeroGuia;
    if (descripcion != null) map['descripcion'] = descripcion;
    if (notas != null) map['notas'] = notas;
    if (fechaEsperadaDesde != null) {
      map['fechaEsperadaDesde'] = fechaEsperadaDesde!.toUtc().toIso8601String();
    }
    if (fechaEsperadaHasta != null) {
      map['fechaEsperadaHasta'] = fechaEsperadaHasta!.toUtc().toIso8601String();
    }
    return map;
  }
}

class RecibirPaqueteDto {
  final String? paqueteId;
  final int? viviendaId;
  final String? destinatarioNombre;
  final int? servicioId;
  final String? servicioNombre;
  final String? numeroGuia;
  final String? descripcion;
  final String? ubicacionAlmacen;

  RecibirPaqueteDto({
    this.paqueteId,
    this.viviendaId,
    this.destinatarioNombre,
    this.servicioId,
    this.servicioNombre,
    this.numeroGuia,
    this.descripcion,
    this.ubicacionAlmacen,
  });

  Map<String, dynamic> toJson() {
    return {
      if (paqueteId != null && paqueteId!.isNotEmpty) 'paqueteId': paqueteId,
      if (viviendaId != null) 'viviendaId': viviendaId,
      if (destinatarioNombre != null && destinatarioNombre!.trim().isNotEmpty)
        'destinatarioNombre': destinatarioNombre!.trim(),
      if (servicioId != null) 'servicioId': servicioId,
      if (servicioNombre != null && servicioNombre!.trim().isNotEmpty)
        'servicioNombre': servicioNombre!.trim(),
      if (numeroGuia != null && numeroGuia!.trim().isNotEmpty)
        'numeroGuia': numeroGuia!.trim(),
      if (descripcion != null && descripcion!.trim().isNotEmpty)
        'descripcion': descripcion!.trim(),
      if (ubicacionAlmacen != null && ubicacionAlmacen!.trim().isNotEmpty)
        'ubicacionAlmacen': ubicacionAlmacen!.trim(),
    };
  }
}

class EntregarPaqueteDto {
  final String entregadoANombre;

  EntregarPaqueteDto({required this.entregadoANombre});

  Map<String, dynamic> toJson() {
    return {
      'entregadoANombre': entregadoANombre.trim(),
    };
  }
}

class CancelPaqueteDto {
  final String? motivo;

  CancelPaqueteDto({this.motivo});

  Map<String, dynamic> toJson() {
    return {
      if (motivo != null && motivo!.trim().isNotEmpty) 'motivo': motivo!.trim(),
    };
  }
}

class CreateServicioPaqueteriaDto {
  final String nombre;
  final String? iconoUrl;

  CreateServicioPaqueteriaDto({
    required this.nombre,
    this.iconoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre.trim(),
      if (iconoUrl != null && iconoUrl!.trim().isNotEmpty)
        'iconoUrl': iconoUrl!.trim(),
    };
  }
}
