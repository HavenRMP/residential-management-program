class SubusuarioItem {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String parentesco;
  final String estado;
  final String? codigo;
  final DateTime? expiraEn;

  SubusuarioItem({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.parentesco,
    required this.estado,
    this.codigo,
    this.expiraEn,
  });

  bool get isActivo => estado.toLowerCase() == 'activo';
  bool get isPendiente => !isActivo;
  bool get isExpirado => expiraEn != null && DateTime.now().isAfter(expiraEn!);

  factory SubusuarioItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedExpira;
    final expStr = json['expira_en'] ?? json['expiraEn'];
    if (expStr != null) {
      try {
        parsedExpira = DateTime.parse(expStr.toString());
      } catch (_) {}
    }

    return SubusuarioItem(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? 'Sin nombre',
      email: json['email']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      parentesco: json['parentesco']?.toString() ?? 'Familiar',
      estado: json['estado']?.toString() ?? 'Pendiente',
      codigo: json['codigo']?.toString(),
      expiraEn: parsedExpira,
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
      if (codigo != null) 'codigo': codigo,
      if (expiraEn != null) 'expira_en': expiraEn!.toIso8601String(),
    };
  }
}
