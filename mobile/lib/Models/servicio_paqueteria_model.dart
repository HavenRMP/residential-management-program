class ServicioPaqueteriaModel {
  final int id;
  final String? condominioId;
  final String nombre;
  final String? iconoUrl;
  final bool activo;
  final bool esSistema;
  final DateTime? creadoEn;

  ServicioPaqueteriaModel({
    required this.id,
    this.condominioId,
    required this.nombre,
    this.iconoUrl,
    this.activo = true,
    this.esSistema = false,
    this.creadoEn,
  });

  factory ServicioPaqueteriaModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    int parseId(dynamic val) {
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '') ?? 0;
    }

    return ServicioPaqueteriaModel(
      id: parseId(json['id']),
      condominioId: json['condominioId']?.toString() ?? json['condominio_id']?.toString(),
      nombre: (json['nombre'] ?? '').toString(),
      iconoUrl: json['iconoUrl']?.toString() ?? json['icono_url']?.toString(),
      activo: json['activo'] == null || json['activo'] == true,
      esSistema: json['esSistema'] == true || json['es_sistema'] == true,
      creadoEn: parseNullableDate(json['creadoEn'] ?? json['creado_en']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (condominioId != null) 'condominioId': condominioId,
      'nombre': nombre,
      if (iconoUrl != null) 'iconoUrl': iconoUrl,
      'activo': activo,
      'esSistema': esSistema,
      if (creadoEn != null) 'creadoEn': creadoEn?.toUtc().toIso8601String(),
    };
  }

  ServicioPaqueteriaModel copyWith({
    int? id,
    String? condominioId,
    String? nombre,
    String? iconoUrl,
    bool? activo,
    bool? esSistema,
    DateTime? creadoEn,
  }) {
    return ServicioPaqueteriaModel(
      id: id ?? this.id,
      condominioId: condominioId ?? this.condominioId,
      nombre: nombre ?? this.nombre,
      iconoUrl: iconoUrl ?? this.iconoUrl,
      activo: activo ?? this.activo,
      esSistema: esSistema ?? this.esSistema,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }
}
