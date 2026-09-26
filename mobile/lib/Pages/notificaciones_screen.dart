import 'package:flutter/material.dart';
import '../Models/notificacion.dart';
import '../Services/app_controller.dart';
import '../Services/notificaciones_service.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late final NotificacionesService _service;
  bool _isLoading = true;
  List<Notificacion> _notificaciones = [];
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _service = NotificacionesService(widget.controller);
    _cargarNotificaciones();
  }

  Future<void> _cargarNotificaciones() async {
    setState(() => _isLoading = true);
    final lista = await _service.getNotificaciones();
    if (mounted) {
      setState(() {
        _notificaciones = lista;
        _isLoading = false;
      });
    }
  }

  int get _noLeidasCount => _notificaciones.where((n) => !n.leida).length;

  Future<void> _marcarComoLeida(Notificacion notif) async {
    if (notif.leida) return;

    // Actualización optimista
    setState(() {
      final index = _notificaciones.indexWhere((n) => n.id == notif.id);
      if (index != -1) {
        _notificaciones[index] = notif.copyWith(leida: true);
      }
    });

    await _service.marcarComoLeida(notif.id);
  }

  Future<void> _marcarTodasComoLeidas() async {
    if (_noLeidasCount == 0 || _isMarkingAll) return;

    setState(() => _isMarkingAll = true);

    // Actualización optimista
    setState(() {
      _notificaciones = _notificaciones.map((n) => n.copyWith(leida: true)).toList();
    });

    final success = await _service.marcarTodasComoLeidas();
    if (mounted) {
      setState(() => _isMarkingAll = false);
      if (success) {
        widget.controller.notifyToast('Todas las notificaciones marcadas como leídas', success: true);
      }
    }
  }

  String _formatTiempoRelativo(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);

    if (diff.inSeconds < 60) {
      return 'Hace un momento';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minuto' : 'minutos'}';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }

  Widget _getIconoPorTipo(String tipo) {
    IconData icon;
    Color bg;
    Color color;

    switch (tipo.toLowerCase()) {
      case 'aviso_urgente':
      case 'urgente':
        icon = Icons.warning_amber_rounded;
        bg = const Color(0xFFFEF2F2);
        color = const Color(0xFFDC2626);
        break;
      case 'aviso':
        icon = Icons.campaign_rounded;
        bg = const Color(0xFFEFF6FF);
        color = const Color(0xFF2563EB);
        break;
      case 'visita':
      case 'acceso':
        icon = Icons.meeting_room_rounded;
        bg = const Color(0xFFECFDF5);
        color = const Color(0xFF059669);
        break;
      case 'pago':
      case 'cuota':
        icon = Icons.receipt_long_rounded;
        bg = const Color(0xFFF0FDFA);
        color = const Color(0xFF0D9488);
        break;
      default:
        icon = Icons.notifications_rounded;
        bg = const Color(0xFFF1F5F9);
        color = const Color(0xFF64748B);
        break;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_noLeidasCount > 0)
            TextButton(
              onPressed: _isMarkingAll ? null : _marcarTodasComoLeidas,
              child: _isMarkingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Marcar leídas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111C99),
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF111C99)))
          : RefreshIndicator(
              color: const Color(0xFF111C99),
              onRefresh: _cargarNotificaciones,
              child: _notificaciones.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _notificaciones.length,
                      itemBuilder: (context, index) {
                        final notif = _notificaciones[index];
                        return _buildNotificacionTile(notif);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: Color(0xFF111C99),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No tienes notificaciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Te avisaremos cuando haya novedades o comunicados importantes en tu condominio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificacionTile(Notificacion notif) {
    return InkWell(
      onTap: () => _marcarComoLeida(notif),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.leida ? Colors.white : const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notif.leida ? const Color(0xFFE2E8F0) : const Color(0xFFC7D2FE),
            width: notif.leida ? 1 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _getIconoPorTipo(notif.tipoEvento),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.titulo,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notif.leida ? FontWeight.w600 : FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (!notif.leida)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF111C99),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.mensaje,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTiempoRelativo(notif.creadoEn),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
