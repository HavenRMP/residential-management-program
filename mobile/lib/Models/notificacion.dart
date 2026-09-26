class Notificacion {
  final String id;
  final String usuarioId;
  final String usuarioNombre;
  final String usuarioEmail;
  final String tipoEvento;
  final String titulo;
  final String mensaje;
  final String? urlRedireccion;
  final bool leida;
  final DateTime creadoEn;

  Notificacion({
    required this.id,
    this.usuarioId = '',
    this.usuarioNombre = '',
    this.usuarioEmail = '',
    this.tipoEvento = 'general',
    required this.titulo,
    required this.mensaje,
    this.urlRedireccion,
    this.leida = false,
    required this.creadoEn,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    DateTime parsedFecha;
    try {
      final fechaStr = json['creado_en'] ?? json['creadoEn'];
      parsedFecha = fechaStr != null ? DateTime.parse(fechaStr.toString()) : DateTime.now();
    } catch (_) {
      parsedFecha = DateTime.now();
    }

    return Notificacion(
      id: json['id']?.toString() ?? '',
      usuarioId: json['usuario_id']?.toString() ?? json['usuarioId']?.toString() ?? '',
      usuarioNombre: json['usuario_nombre']?.toString() ?? json['usuarioNombre']?.toString() ?? '',
      usuarioEmail: json['usuario_email']?.toString() ?? json['usuarioEmail']?.toString() ?? '',
      tipoEvento: json['tipo_evento']?.toString() ?? json['tipoEvento']?.toString() ?? 'general',
      titulo: json['titulo']?.toString() ?? 'Notificación',
      mensaje: json['mensaje']?.toString() ?? '',
      urlRedireccion: json['url_redireccion']?.toString() ?? json['urlRedireccion']?.toString(),
      leida: json['leida'] == true,
      creadoEn: parsedFecha,
    );
  }

  Notificacion copyWith({
    String? id,
    String? usuarioId,
    String? usuarioNombre,
    String? usuarioEmail,
    String? tipoEvento,
    String? titulo,
    String? mensaje,
    String? urlRedireccion,
    bool? leida,
    DateTime? creadoEn,
  }) {
    return Notificacion(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      usuarioNombre: usuarioNombre ?? this.usuarioNombre,
      usuarioEmail: usuarioEmail ?? this.usuarioEmail,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      urlRedireccion: urlRedireccion ?? this.urlRedireccion,
      leida: leida ?? this.leida,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }
}
