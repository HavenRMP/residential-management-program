class SubusuarioItem {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String parentesco;
  final String estado;
  final DateTime? creadoEn;

  SubusuarioItem({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.parentesco,
    required this.estado,
    this.creadoEn,
  });

  bool get isActivo => estado.toLowerCase() == 'activo';
  bool get isPendiente => !isActivo;

  factory SubusuarioItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreado;
    final creadoStr = json['creado_en'] ?? json['creadoEn'];
    if (creadoStr != null) {
      try {
        parsedCreado = DateTime.parse(creadoStr.toString());
      } catch (_) {}
    }

    return SubusuarioItem(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? 'Pendiente',
      email: json['email']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      parentesco: json['parentesco']?.toString() ?? 'Familiar',
      estado: json['estado']?.toString() ?? 'Pendiente',
      creadoEn: parsedCreado,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'parentesco': parentesco,
      'estado': estado,
      if (creadoEn != null) 'creado_en': creadoEn!.toIso8601String(),
    };
  }
}

class InvitacionSubusuario {
  final String id;
  final int viviendaId;
  final String? numeroCasa;
  final String? condominioNombre;
  final String? titularNombre;
  final String? titularId;
  final String parentesco;
  final String estado;
  final DateTime? creadoEn;

  InvitacionSubusuario({
    required this.id,
    required this.viviendaId,
    this.numeroCasa,
    this.condominioNombre,
    this.titularNombre,
    this.titularId,
    required this.parentesco,
    required this.estado,
    this.creadoEn,
  });

  bool get isPendiente => estado.toUpperCase() == 'PENDIENTE';

  factory InvitacionSubusuario.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreado;
    final creadoStr = json['creado_en'] ?? json['creadoEn'];
    if (creadoStr != null) {
      try {
        parsedCreado = DateTime.parse(creadoStr.toString());
      } catch (_) {}
    }

    final vivId = (json['vivienda_id'] is num)
        ? (json['vivienda_id'] as num).toInt()
        : int.tryParse(json['vivienda_id']?.toString() ?? '') ?? 0;

    return InvitacionSubusuario(
      id: json['id']?.toString() ?? '',
      viviendaId: vivId,
      numeroCasa: json['numero_casa']?.toString(),
      condominioNombre: json['condominio_nombre']?.toString(),
      titularNombre: json['titular_nombre']?.toString(),
      titularId: json['titular_id']?.toString(),
      parentesco: json['parentesco']?.toString() ?? 'Familiar',
      estado: json['estado']?.toString() ?? 'PENDIENTE',
      creadoEn: parsedCreado,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vivienda_id': viviendaId,
      'numero_casa': numeroCasa,
      'condominio_nombre': condominioNombre,
      'titular_nombre': titularNombre,
      'titular_id': titularId,
      'parentesco': parentesco,
      'estado': estado,
      if (creadoEn != null) 'creado_en': creadoEn!.toIso8601String(),
    };
  }
}
