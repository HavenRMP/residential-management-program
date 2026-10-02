class SubusuarioItem {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String parentesco;
  final String estado;
  final DateTime? creadoEn;
  final String? codigo;

  SubusuarioItem({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.parentesco,
    required this.estado,
    this.creadoEn,
    this.codigo,
  });

  bool get isActivo => estado.toLowerCase() == 'activo';
  bool get isPendiente => !isActivo;

  SubusuarioItem copyWith({
    String? id,
    String? nombre,
    String? email,
    String? telefono,
    String? parentesco,
    String? estado,
    DateTime? creadoEn,
    String? codigo,
  }) {
    return SubusuarioItem(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      parentesco: parentesco ?? this.parentesco,
      estado: estado ?? this.estado,
      creadoEn: creadoEn ?? this.creadoEn,
      codigo: codigo ?? this.codigo,
    );
  }

  factory SubusuarioItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreado;
    final creadoStr = json['creado_en'] ?? json['creadoEn'];
    if (creadoStr != null) {
      try {
        parsedCreado = DateTime.parse(creadoStr.toString());
      } catch (_) {}
    }

    final code = json['codigo']?.toString() ?? json['codigo_invitacion']?.toString();

    return SubusuarioItem(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? 'Pendiente',
      email: json['email']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      parentesco: json['parentesco']?.toString() ?? 'Familiar',
      estado: json['estado']?.toString() ?? 'Pendiente',
      creadoEn: parsedCreado,
      codigo: (code != null && code.isNotEmpty) ? code : null,
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
      if (codigo != null) 'codigo': codigo,
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
  final String? codigo;

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
    this.codigo,
  });

  bool get isPendiente => estado.toUpperCase() == 'PENDIENTE';

  InvitacionSubusuario copyWith({
    String? id,
    int? viviendaId,
    String? numeroCasa,
    String? condominioNombre,
    String? titularNombre,
    String? titularId,
    String? parentesco,
    String? estado,
    DateTime? creadoEn,
    String? codigo,
  }) {
    return InvitacionSubusuario(
      id: id ?? this.id,
      viviendaId: viviendaId ?? this.viviendaId,
      numeroCasa: numeroCasa ?? this.numeroCasa,
      condominioNombre: condominioNombre ?? this.condominioNombre,
      titularNombre: titularNombre ?? this.titularNombre,
      titularId: titularId ?? this.titularId,
      parentesco: parentesco ?? this.parentesco,
      estado: estado ?? this.estado,
      creadoEn: creadoEn ?? this.creadoEn,
      codigo: codigo ?? this.codigo,
    );
  }

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

    final code = json['codigo']?.toString() ?? json['codigo_invitacion']?.toString();

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
      codigo: (code != null && code.isNotEmpty) ? code : null,
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
      if (codigo != null) 'codigo': codigo,
    };
  }
}

