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
}
