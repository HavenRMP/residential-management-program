class AreaComunModel {
  final String id;
  final String? condominioId;
  final String nombre;
  final String? descripcion;
  final String horaApertura;
  final String horaCierre;
  final bool activo;
  final int totalReservasActivas;
  final int totalBloqueosActivos;

  AreaComunModel({
    required this.id,
    this.condominioId,
    required this.nombre,
    this.descripcion,
    required this.horaApertura,
    required this.horaCierre,
    required this.activo,
    this.totalReservasActivas = 0,
    this.totalBloqueosActivos = 0,
  });

  factory AreaComunModel.fromJson(Map<String, dynamic> json) {
    return AreaComunModel(
      id: (json['id'] ?? '').toString(),
      condominioId: json['condominioId']?.toString() ?? json['condominio_id']?.toString(),
      nombre: (json['nombre'] ?? '').toString(),
      descripcion: json['descripcion']?.toString(),
      horaApertura: (json['horaApertura'] ?? json['hora_apertura'] ?? '08:00:00').toString(),
      horaCierre: (json['horaCierre'] ?? json['hora_cierre'] ?? '22:00:00').toString(),
      activo: json['activo'] == true || json['activo'] == 1,
      totalReservasActivas: json['totalReservasActivas'] is num
          ? (json['totalReservasActivas'] as num).toInt()
          : (json['total_reservas_activas'] is num
              ? (json['total_reservas_activas'] as num).toInt()
              : 0),
      totalBloqueosActivos: json['totalBloqueosActivos'] is num
          ? (json['totalBloqueosActivos'] as num).toInt()
          : (json['total_bloqueos_activos'] is num
              ? (json['total_bloqueos_activos'] as num).toInt()
              : 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (condominioId != null) 'condominioId': condominioId,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      'horaApertura': horaApertura,
      'horaCierre': horaCierre,
      'activo': activo,
      'totalReservasActivas': totalReservasActivas,
      'totalBloqueosActivos': totalBloqueosActivos,
    };
  }

  /// Devuelve el horario en formato legible, ej: "08:00 - 22:00"
  String get horarioFormateado {
    final ap = _formatearHoraSimple(horaApertura);
    final ci = _formatearHoraSimple(horaCierre);
    return '$ap - $ci';
  }

  static String _formatearHoraSimple(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw;
  }
}
