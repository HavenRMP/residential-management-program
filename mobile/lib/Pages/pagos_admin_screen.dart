import 'package:flutter/material.dart';
import '../Models/pagos_models.dart';
import '../Services/pagos_service.dart';
import '../Services/viviendas_service.dart';
import '../Services/app_controller.dart';
import '../Widgets/comprobante_dialog.dart';
import '../Widgets/crear_cargo_modal.dart';
import '../Utils/error_handler.dart';
import '../Utils/haptic_helper.dart';

class PagosAdminScreen extends StatefulWidget {
  final AppController controller;

  const PagosAdminScreen({
    super.key,
    required this.controller,
  });

  @override
  State<PagosAdminScreen> createState() => _PagosAdminScreenState();
}

class _PagosAdminScreenState extends State<PagosAdminScreen>
    with SingleTickerProviderStateMixin {
  late final PagosService _pagosService;
  late final ViviendasService _viviendasService;
  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<PagoModel> _pagosPendientes = [];
  List<CargoModel> _cargos = [];
  List<PagoModel> _historialPagos = [];
  List<dynamic> _viviendas = [];

  String _filtroEstadoCargo = 'Todos';

  @override
  void initState() {
    super.initState();
    _pagosService = PagosService(widget.controller);
    _viviendasService = ViviendasService(widget.controller);
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vivsFuture = _viviendasService.listar();
      final pendientesFuture = _pagosService.getPagos(
        estado: EstadoPago.pendienteConfirmacion,
      );
      final cargosFuture = _pagosService.getCargos();
      final historialFuture = _pagosService.getPagos(tamanoPagina: 50);

      final results = await Future.wait([
        vivsFuture,
        pendientesFuture,
        cargosFuture,
        historialFuture,
      ]);

      if (mounted) {
        setState(() {
          _viviendas = results[0] as List<dynamic>;
          _pagosPendientes =
              (results[1] as PaginatedResponse<PagoModel>).items;
          _cargos = (results[2] as PaginatedResponse<CargoModel>).items;
          _historialPagos =
              (results[3] as PaginatedResponse<PagoModel>).items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorHandler.extractErrorMessage(
            e,
            defaultMessage: 'No fue posible cargar los datos de cobranza.',
          );
        });
      }
    }
  }

  // ==========================================
  // Acciones de Validación de Pagos
  // ==========================================
  Future<void> _confirmarPago(PagoModel pago) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Pago'),
        content: Text(
          '¿Deseas confirmar el pago de \$${pago.monto.toStringAsFixed(2)} recibido mediante ${pago.metodo}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _pagosService.confirmarPago(pago.id);
      final nuevoEstado = res['nuevoEstadoCargo'] ?? 'Actualizado';
      widget.controller.notifyToast('¡Pago confirmado! Estado de cuota: $nuevoEstado', success: true);
      _cargarDatos();
    } catch (e) {
      final err = ErrorHandler.extractErrorMessage(
        e,
        defaultMessage: 'No fue posible confirmar el pago.',
      );
      widget.controller.notifyToast(err, success: false);
    }
  }

  Future<void> _rechazarPago(PagoModel pago) async {
    final motivoCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indica el motivo por el cual se rechaza este reporte de pago (visible para el residente):',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ej. El comprobante adjunto es ilegible o el monto no coincide.',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (motivoCtrl.text.trim().isEmpty) {
                widget.controller.notifyToast('Ingresa un motivo de rechazo.', success: false);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _pagosService.rechazarPago(pago.id, motivoCtrl.text.trim());
      widget.controller.notifyToast('Pago rechazado correctamente.', success: true);
      _cargarDatos();
    } catch (e) {
      final err = ErrorHandler.extractErrorMessage(
        e,
        defaultMessage: 'No fue posible rechazar el pago.',
      );
      widget.controller.notifyToast(err, success: false);
    }
  }

  Future<void> _anularPago(PagoModel pago) async {
    final motivoCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Pago Confirmado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Esta acción revertirá los saldos y marcará el pago como Anulado (ej. cheque rebotado o contracargo bancario):',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Motivo de anulación o reclamo bancario',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (motivoCtrl.text.trim().isEmpty) {
                widget.controller.notifyToast('Ingresa el motivo de anulación.', success: false);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Anular Pago'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _pagosService.anularPago(pago.id, motivoCtrl.text.trim());
      widget.controller.notifyToast('Pago anulado y reversa contable aplicada.', success: true);
      _cargarDatos();
    } catch (e) {
      final err = ErrorHandler.extractErrorMessage(
        e,
        defaultMessage: 'No fue posible anular el pago.',
      );
      widget.controller.notifyToast(err, success: false);
    }
  }

  Future<void> _cancelarCargo(CargoModel cargo) async {
    final motivoCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Cargo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Deseas cancelar el cargo "${cargo.concepto}" de \$${cargo.monto.toStringAsFixed(2)}?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Motivo de cancelación (ej. cálculo erróneo)',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              if (motivoCtrl.text.trim().isEmpty) {
                widget.controller.notifyToast('Ingresa el motivo.', success: false);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Cancelar Cargo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _pagosService.cancelarCargo(cargo.id, motivoCtrl.text.trim());
      widget.controller.notifyToast('Cargo cancelado.', success: true);
      _cargarDatos();
    } catch (e) {
      final err = ErrorHandler.extractErrorMessage(
        e,
        defaultMessage: 'No fue posible cancelar el cargo.',
      );
      widget.controller.notifyToast(err, success: false);
    }
  }

  Future<void> _generarCargosPeriodo() async {
    final now = DateTime.now();
    final defaultPeriodo = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final periodoCtrl = TextEditingController(text: defaultPeriodo);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generar Cuotas del Periodo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción creará automáticamente las cuotas recurrentes para todas las viviendas activas a partir de las plantillas vigentes:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: periodoCtrl,
              decoration: InputDecoration(
                labelText: 'Periodo (YYYY-MM)',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
            child: const Text('Generar Cuotas'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _pagosService.generarCargosPeriodo(periodoCtrl.text.trim());
      final generados = res['cargosGenerados'] ?? 0;
      final total = res['totalMonto'] ?? 0;
      widget.controller.notifyToast(
        '¡$generados cargos generados exitosamente! Total: \$$total',
        success: true,
      );
      _cargarDatos();
    } catch (e) {
      final err = ErrorHandler.extractErrorMessage(
        e,
        defaultMessage: 'No fue posible generar las cuotas del periodo.',
      );
      widget.controller.notifyToast(err, success: false);
    }
  }

  Future<void> _registrarPagoEnVentanilla() async {
    if (_viviendas.isEmpty) {
      widget.controller.notifyToast('No hay viviendas disponibles.', success: false);
      return;
    }

    int? selectedViviendaId = (_viviendas.first['id'] as num).toInt();
    final montoCtrl = TextEditingController();
    final folioCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    String metodo = MetodoPago.efectivo;
    CargoModel? selectedCargo;

    final cargosVivienda = _cargos
        .where((c) =>
            c.viviendaId == selectedViviendaId &&
            c.saldoPendiente > 0 &&
            c.estado != EstadoCargo.cancelado)
        .toList();

    if (cargosVivienda.isNotEmpty) {
      selectedCargo = cargosVivienda.first;
      montoCtrl.text = selectedCargo.saldoPendiente.toStringAsFixed(2);
    }

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final disponibles = _cargos
              .where((c) =>
                  c.viviendaId == selectedViviendaId &&
                  c.saldoPendiente > 0 &&
                  c.estado != EstadoCargo.cancelado)
              .toList();

          return AlertDialog(
            title: const Text('Registrar Pago en Ventanilla'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vivienda', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    initialValue: selectedViviendaId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _viviendas.map((v) {
                      final id = (v['id'] as num).toInt();
                      final casa = v['numeroCasa'] ?? 'S/N';
                      return DropdownMenuItem<int>(value: id, child: Text('Casa #$casa'));
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedViviendaId = val;
                        final sub = _cargos
                            .where((c) =>
                                c.viviendaId == selectedViviendaId &&
                                c.saldoPendiente > 0 &&
                                c.estado != EstadoCargo.cancelado)
                            .toList();
                        selectedCargo = sub.isNotEmpty ? sub.first : null;
                        if (selectedCargo != null) {
                          montoCtrl.text = selectedCargo!.saldoPendiente.toStringAsFixed(2);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text('Cargo a Saladar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (disponibles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Esta vivienda no cuenta con cargos pendientes.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedCargo?.id,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: disponibles.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.concepto} (\$$c.saldoPendiente)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCargo = disponibles.firstWhere((c) => c.id == val);
                          montoCtrl.text = selectedCargo!.saldoPendiente.toStringAsFixed(2);
                        });
                      },
                    ),
                  const SizedBox(height: 12),

                  const Text('Monto (\$)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Método de Pago', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: metodo,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: MetodoPago.todos.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => metodo = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text('Folio / Recibo (opcional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: folioCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ej. REC-00123',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: selectedCargo == null
                    ? null
                    : () {
                        final m = double.tryParse(montoCtrl.text.replaceAll(',', ''));
                        if (m == null || m <= 0) {
                          widget.controller.notifyToast('Ingresa un monto válido.', success: false);
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                child: const Text('Registrar'),
              ),
            ],
          );
        },
      ),
    );

    if (submit != true || selectedCargo == null) return;

    final m = double.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0.0;
    try {
      await _pagosService.registrarPagoAdmin(
        cargoId: selectedCargo!.id,
        monto: m,
        metodo: metodo,
        folioComprobante: folioCtrl.text.trim().isNotEmpty ? folioCtrl.text.trim() : null,
        notas: notasCtrl.text.trim().isNotEmpty ? notasCtrl.text.trim() : 'Recibido en administración',
      );
      widget.controller.notifyToast('Pago en ventanilla registrado y confirmado.', success: true);
      _cargarDatos();
    } catch (e) {
      final err = ErrorHandler.extractErrorMessage(
        e,
        defaultMessage: 'No fue posible registrar el pago.',
      );
      widget.controller.notifyToast(err, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Administración de Cobranza',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF111C99),
              indicatorWeight: 3,
              labelColor: const Color(0xFF111C99),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Por Validar'),
                      if (_pagosPendientes.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_pagosPendientes.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Cargos'),
                const Tab(text: 'Plantillas'),
                const Tab(text: 'Historial'),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF111C99),
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF111C99))),
                    )
                  else if (_errorMessage != null)
                    _buildErrorState()
                  else
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (ctx, _) {
                        switch (_tabController.index) {
                          case 0:
                            return _buildPorValidarTab();
                          case 1:
                            return _buildCargosTab();
                          case 2:
                            return _buildPlantillasTab();
                          case 3:
                          default:
                            return _buildHistorialTab();
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 40),
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Pestaña 1: Pagos por Validar
  // ==========================================
  Widget _buildPorValidarTab() {
    if (_pagosPendientes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 44),
            SizedBox(height: 12),
            Text(
              'Bandeja limpia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 4),
            Text(
              'No hay transferencias ni depósitos pendientes de confirmación.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _pagosPendientes.map((pago) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${pago.monto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Por Validar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Método: ${pago.metodo}${pago.folioComprobante != null ? ' • Folio: ${pago.folioComprobante}' : ''}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
              ),
              if (pago.fechaPago != null)
                Text(
                  'Fecha: ${pago.fechaPago!.toLocal().toString().split(' ').first}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              if (pago.notas != null && pago.notas!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Notas: "${pago.notas}"',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                ),
              ],
              const SizedBox(height: 14),

              // Botones de acción
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticHelper.selection();
                      ComprobanteDialog.show(
                        context,
                        pagoId: pago.id,
                        pagosService: _pagosService,
                      );
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('Comprobante'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => _rechazarPago(pago),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _confirmarPago(pago),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==========================================
  // Pestaña 2: Cargos y Cobranza
  // ==========================================
  Widget _buildCargosTab() {
    final filtrados = _cargos.where((c) {
      if (_filtroEstadoCargo == 'Todos') return true;
      if (_filtroEstadoCargo == 'Vencidos') return c.estaVencido;
      return c.estado.toLowerCase() == _filtroEstadoCargo.toLowerCase();
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Bar
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  HapticHelper.selection();
                  final ok = await CrearCargoModal.show(
                    context,
                    viviendas: _viviendas,
                    pagosService: _pagosService,
                    controller: widget.controller,
                  );
                  if (ok == true) _cargarDatos();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Crear Cargo Manual'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111C99),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filtro Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Todos', 'Pendiente', 'Parcial', 'Pagado', 'Vencidos'].map((filtro) {
              final isSelected = _filtroEstadoCargo == filtro;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filtro),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _filtroEstadoCargo = filtro),
                  selectedColor: const Color(0xFFEEF2FF),
                  checkmarkColor: const Color(0xFF111C99),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF111C99) : const Color(0xFF64748B),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        if (filtrados.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No hay cargos que coincidan con el filtro seleccionado.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          ...filtrados.map((cargo) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cargo.estaVencido ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cargo.concepto,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '\$${cargo.monto.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111C99)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tipo: ${cargo.tipo} • Saldo: \$${cargo.saldoPendiente.toStringAsFixed(2)} • Estado: ${cargo.estado}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (cargo.fechaVencimiento != null)
                    Text(
                      'Vencimiento: ${cargo.fechaVencimiento}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cargo.estaVencido ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                      ),
                    ),
                  if (cargo.estado != EstadoCargo.pagado && cargo.estado != EstadoCargo.cancelado) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _cancelarCargo(cargo),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                          child: const Text('Cancelar Cargo'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // Pestaña 3: Plantillas y Generación
  // ==========================================
  Widget _buildPlantillasTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_mode_rounded, color: Color(0xFF111C99), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Generación Masiva de Cuotas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Ejecuta el disparador para generar automáticamente todos los cargos del periodo activo a partir de las plantillas configuradas.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _generarCargosPeriodo,
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text('Generar Cargos del Periodo'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111C99),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Pestaña 4: Historial / Registro en Ventanilla
  // ==========================================
  Widget _buildHistorialTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _registrarPagoEnVentanilla,
          icon: const Icon(Icons.point_of_sale_rounded, size: 18),
          label: const Text('Registrar Pago en Ventanilla (Efectivo/Directo)'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 16),

        if (_historialPagos.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No hay pagos registrados en el historial.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          ..._historialPagos.map((pago) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${pago.monto.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: pago.estado == EstadoPago.confirmado
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pago.estado,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: pago.estado == EstadoPago.confirmado
                                ? const Color(0xFF059669)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Método: ${pago.metodo} • Origen: ${pago.origen ?? 'N/A'}${pago.folioComprobante != null ? ' • Folio: ${pago.folioComprobante}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (pago.estado == EstadoPago.confirmado)
                        TextButton(
                          onPressed: () => _anularPago(pago),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                          child: const Text('Anular Pago'),
                        ),
                      if (pago.rutaComprobante != null && pago.rutaComprobante!.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () {
                            ComprobanteDialog.show(
                              context,
                              pagoId: pago.id,
                              pagosService: _pagosService,
                            );
                          },
                          icon: const Icon(Icons.receipt_long_rounded, size: 14),
                          label: const Text('Ver Recibo'),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
