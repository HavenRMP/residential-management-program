import 'package:flutter/material.dart';
import '../Models/area_comun_model.dart';
import '../Models/reserva_model.dart';
import '../Services/app_controller.dart';
import '../Services/reservas_service.dart';
import '../Utils/error_handler.dart';
import '../Widgets/solicitar_reserva_modal.dart';

class ReservasResidenteScreen extends StatefulWidget {
  final AppController controller;

  const ReservasResidenteScreen({
    super.key,
    required this.controller,
  });

  @override
  State<ReservasResidenteScreen> createState() => _ReservasResidenteScreenState();
}

class _ReservasResidenteScreenState extends State<ReservasResidenteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ReservasService _reservasService;

  // Tab 1: Mis Reservas
  List<ReservaModel> _misReservas = [];
  bool _isLoadingMisReservas = true;
  String? _errorMisReservas;
  String _filtroEstado = 'todas';

  // Tab 2: Solicitudes de Subusuarios por aprobar (Titular)
  List<ReservaModel> _pendientesTitular = [];
  bool _isLoadingPendientes = true;
  String? _errorPendientes;

  // Tab 3: Áreas Comunes y Calendario
  List<AreaComunModel> _areas = [];
  bool _isLoadingAreas = true;
  String? _errorAreas;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reservasService = ReservasService(widget.controller);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarMisReservas(),
      _cargarPendientesTitular(),
      _cargarAreas(),
    ]);
  }

  Future<void> _cargarMisReservas() async {
    setState(() {
      _isLoadingMisReservas = true;
      _errorMisReservas = null;
    });
    try {
      final estadoParam = _filtroEstado == 'todas' ? null : _filtroEstado;
      final res = await _reservasService.getMisReservas(estado: estadoParam, pageSize: 50);
      if (mounted) {
        setState(() {
          if (res['success'] == true) {
            _misReservas = res['items'] as List<ReservaModel>;
            _errorMisReservas = null;
          } else {
            _errorMisReservas = res['error']?.toString() ?? 'No se pudieron consultar tus reservas.';
          }
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasResidenteScreen._cargarMisReservas');
      if (mounted) {
        setState(() {
          _errorMisReservas = ErrorHandler.parseException(e, defaultMessage: 'Error al consultar reservas.');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMisReservas = false);
      }
    }
  }

  Future<void> _cargarPendientesTitular() async {
    setState(() {
      _isLoadingPendientes = true;
      _errorPendientes = null;
    });
    try {
      final res = await _reservasService.getPendientesTitular(pageSize: 50);
      if (mounted) {
        setState(() {
          if (res['success'] == true) {
            _pendientesTitular = res['items'] as List<ReservaModel>;
            _errorPendientes = null;
          } else {
            _errorPendientes = res['error']?.toString() ?? 'No se pudieron consultar solicitudes pendientes.';
          }
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasResidenteScreen._cargarPendientesTitular');
      if (mounted) {
        setState(() {
          _errorPendientes = ErrorHandler.parseException(e, defaultMessage: 'Error al consultar solicitudes.');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPendientes = false);
      }
    }
  }

  Future<void> _cargarAreas() async {
    setState(() {
      _isLoadingAreas = true;
      _errorAreas = null;
    });
    try {
      final res = await _reservasService.getAreas(soloActivas: true, pageSize: 50);
      if (mounted) {
        setState(() {
          if (res['success'] == true) {
            _areas = res['items'] as List<AreaComunModel>;
            _errorAreas = null;
          } else {
            _errorAreas = res['error']?.toString() ?? 'No se pudieron consultar las áreas comunes.';
          }
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasResidenteScreen._cargarAreas');
      if (mounted) {
        setState(() {
          _errorAreas = ErrorHandler.parseException(e, defaultMessage: 'Error al consultar áreas.');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAreas = false);
      }
    }
  }

  Future<void> _confirmarAsistencia(ReservaModel reserva) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar Asistencia'),
          content: Text(
            '¿Confirmas que harás uso del área "${reserva.areaNombre}" el día ${_formatearFecha(reserva.inicio)} de ${_formatearHora(reserva.inicio)} a ${_formatearHora(reserva.fin)}?\n\n'
            'Recuerda que si confirmas y no asistes, contará como inasistencia (no-show).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              child: const Text('Confirmar Asistencia'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final res = await _reservasService.confirmarReserva(reserva.id);
        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('¡Asistencia confirmada exitosamente!', success: true);
            _cargarMisReservas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudo confirmar.', success: false);
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasResidenteScreen._confirmarAsistencia');
      if (mounted) {
        widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
      }
    }
  }

  Future<void> _cancelarReserva(ReservaModel reserva) async {
    try {
      final motivoCtrl = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelar Reserva'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Estás seguro de cancelar tu reserva para "${reserva.areaNombre}"?'),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo de cancelación (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Cancelar Reserva'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final res = await _reservasService.cancelarReserva(reserva.id, motivo: motivoCtrl.text.trim());
        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('Reserva cancelada correctamente.', success: true);
            _cargarMisReservas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudo cancelar.', success: false);
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasResidenteScreen._cancelarReserva');
      if (mounted) {
        widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
      }
    }
  }

  Future<void> _aprobarComoTitular(ReservaModel reserva) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aprobar Solicitud'),
          content: Text(
            '¿Das el visto bueno a la reserva solicitada por ${reserva.solicitanteCompleto} para "${reserva.areaNombre}"?\n\n'
            'Al aprobarla, se enviará a la administración para su autorización definitiva.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              child: const Text('Aprobar'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final res = await _reservasService.aprobarReservaTitular(reserva.id);
        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('Solicitud aprobada y enviada a administración.', success: true);
            _cargarPendientesTitular();
            _cargarMisReservas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudo aprobar.', success: false);
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasResidenteScreen._aprobarComoTitular');
      if (mounted) {
        widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
      }
    }
  }

  Future<void> _rechazarComoTitular(ReservaModel reserva) async {
    try {
      final motivoCtrl = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechazar Solicitud'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Indica a ${reserva.solicitanteCompleto} el motivo por el cual rechazas su solicitud:'),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final res = await _reservasService.rechazarReservaTitular(reserva.id, motivo: motivoCtrl.text.trim());
        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('Solicitud rechazada.', success: true);
            _cargarPendientesTitular();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudo rechazar.', success: false);
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasResidenteScreen._rechazarComoTitular');
      if (mounted) {
        widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
      }
    }
  }

  void _abrirModalSolicitarReserva({AreaComunModel? preselectedArea}) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SolicitarReservaModal(
        controller: widget.controller,
        preselectedArea: preselectedArea,
      ),
    );

    if (resultado == true) {
      _cargarMisReservas();
    }
  }

  String _formatearFecha(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatearHora(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Reservas de Áreas Comunes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF111C99),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF111C99),
          tabs: [
            const Tab(text: 'Mis Reservas'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Por Aprobar'),
                  if (_pendientesTitular.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Badge(
                      label: Text('${_pendientesTitular.length}'),
                      backgroundColor: const Color(0xFFD97706),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Áreas y Horarios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMisReservasTab(),
          _buildPorAprobarTab(),
          _buildAreasTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirModalSolicitarReserva(),
        backgroundColor: const Color(0xFF111C99),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva Reserva', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: MIS RESERVAS
  // ─────────────────────────────────────────────────────────────
  Widget _buildMisReservasTab() {
    return RefreshIndicator(
      onRefresh: _cargarMisReservas,
      child: Column(
        children: [
          // Filtros por estado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFiltroChip('todas', 'Todas'),
                const SizedBox(width: 8),
                _buildFiltroChip('aprobada', 'Aprobadas'),
                const SizedBox(width: 8),
                _buildFiltroChip('confirmada', 'Confirmadas'),
                const SizedBox(width: 8),
                _buildFiltroChip('pendiente_admin', 'Pendientes'),
                const SizedBox(width: 8),
                _buildFiltroChip('finalizada', 'Finalizadas'),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingMisReservas
                ? const Center(child: CircularProgressIndicator())
                : _errorMisReservas != null && _misReservas.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFDC2626)),
                              const SizedBox(height: 12),
                              Text(
                                _errorMisReservas!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _cargarMisReservas,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                : _misReservas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy_rounded, size: 64, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            const Text(
                              'No tienes reservas en este estado',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Presiona el botón "Nueva Reserva" para apartar un área común.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _misReservas.length,
                        itemBuilder: (ctx, idx) => _buildReservaCard(_misReservas[idx]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String estado, String etiqueta) {
    final selected = _filtroEstado == estado;
    return ChoiceChip(
      label: Text(etiqueta),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _filtroEstado = estado);
          _cargarMisReservas();
        }
      },
      selectedColor: const Color(0xFF111C99),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF334155),
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildReservaCard(ReservaModel reserva) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: reserva.estadoColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(reserva.estadoIcono, color: reserva.estadoColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reserva.areaNombre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: reserva.estadoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: reserva.estadoColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  reserva.estadoEtiqueta,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: reserva.estadoColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                _formatearFecha(reserva.inicio),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                '${_formatearHora(reserva.inicio)} - ${_formatearHora(reserva.fin)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ],
          ),
          if (reserva.motivo != null && reserva.motivo!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Motivo: ${reserva.motivo}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (reserva.esAprobada && !reserva.esConfirmable) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_bottom_rounded, color: Color(0xFF2563EB), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirmación de asistencia obligatoria habilitada entre 7 días y 72 horas antes del evento.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (reserva.esConfirmable || reserva.esCancelable) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (reserva.esCancelable)
                  TextButton.icon(
                    onPressed: () => _cancelarReserva(reserva),
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Cancelar', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                  ),
                if (reserva.esConfirmable) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _confirmarAsistencia(reserva),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Confirmar Asistencia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: POR APROBAR (TITULAR)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPorAprobarTab() {
    return RefreshIndicator(
      onRefresh: _cargarPendientesTitular,
      child: _isLoadingPendientes
          ? const Center(child: CircularProgressIndicator())
          : _errorPendientes != null && _pendientesTitular.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFDC2626)),
                        const SizedBox(height: 12),
                        Text(
                          _errorPendientes!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _cargarPendientesTitular,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
          : _pendientesTitular.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.checklist_rounded, size: 64, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      const Text(
                        'Sin solicitudes pendientes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Cuando algún subusuario o inquilino de tu casa solicite un área común, aparecerá aquí para tu visto bueno.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendientesTitular.length,
                  itemBuilder: (ctx, idx) {
                    final item = _pendientesTitular[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person_pin_rounded, color: Color(0xFFD97706), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.solicitanteCompleto,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      'Parentesco: ${item.parentesco ?? 'Subusuario'}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Área solicitada: ${item.areaNombre}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fecha: ${_formatearFecha(item.inicio)} de ${_formatearHora(item.inicio)} a ${_formatearHora(item.fin)}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _rechazarComoTitular(item),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                                  ),
                                  child: const Text('Rechazar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _aprobarComoTitular(item),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                                  child: const Text('Dar Visto Bueno'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: ÁREAS Y HORARIOS
  // ─────────────────────────────────────────────────────────────
  Widget _buildAreasTab() {
    return RefreshIndicator(
      onRefresh: _cargarAreas,
      child: _isLoadingAreas
          ? const Center(child: CircularProgressIndicator())
          : _errorAreas != null && _areas.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFDC2626)),
                        const SizedBox(height: 12),
                        Text(
                          _errorAreas!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _cargarAreas,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
          : _areas.isEmpty
              ? const Center(child: Text('No hay áreas comunes registradas.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _areas.length,
                  itemBuilder: (ctx, idx) {
                    final area = _areas[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  area.nombre,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Text(
                                  'Disponible',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                ),
                              ),
                            ],
                          ),
                          if (area.descripcion != null && area.descripcion!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              area.descripcion!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF111C99)),
                              const SizedBox(width: 6),
                              Text(
                                'Horario de operación: ${area.horarioFormateado}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                              onPressed: () => _abrirModalSolicitarReserva(preselectedArea: area),
                              icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                              label: const Text('Reservar esta Área', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEEF2FF),
                                foregroundColor: const Color(0xFF111C99),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
