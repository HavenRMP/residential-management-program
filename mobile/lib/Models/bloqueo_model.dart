class BloqueoModel {
  final String bloqueoId;
  final String areaId;
  final DateTime inicio;
  final DateTime fin;
  final String motivo;
  final int reservasAfectadas;

  final String? areaNombre;
  final String? estado;

  BloqueoModel({
    required this.bloqueoId,
    required this.areaId,
    required this.inicio,
    required this.fin,
    required this.motivo,
    this.reservasAfectadas = 0,
    this.areaNombre,
    this.estado,
  });

  factory BloqueoModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v.toLocal();
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }

    return BloqueoModel(
      bloqueoId: (json['bloqueoId'] ?? json['bloqueo_id'] ?? '').toString(),
      areaId: (json['areaId'] ?? json['area_id'] ?? '').toString(),
      inicio: parseDate(json['inicio']),
      fin: parseDate(json['fin']),
      motivo: (json['motivo'] ?? '').toString(),
      reservasAfectadas: json['reservasAfectadas'] is num
          ? (json['reservasAfectadas'] as num).toInt()
          : (json['totalReservasAfectadas'] is num
              ? (json['totalReservasAfectadas'] as num).toInt()
              : (json['reservas_afectadas'] is num
                  ? (json['reservas_afectadas'] as num).toInt()
                  : 0)),
      areaNombre: json['areaNombre']?.toString() ?? json['area_nombre']?.toString(),
      estado: json['estado']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bloqueoId': bloqueoId,
      'areaId': areaId,
      'inicio': inicio.toUtc().toIso8601String(),
      'fin': fin.toUtc().toIso8601String(),
      'motivo': motivo,
      'totalReservasAfectadas': reservasAfectadas,
    };
  }
}
