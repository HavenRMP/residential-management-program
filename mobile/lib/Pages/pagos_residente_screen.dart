import 'package:flutter/material.dart';
import '../Models/pagos_models.dart';
import '../Services/pagos_service.dart';
import '../Services/app_controller.dart';
import '../Widgets/reportar_pago_modal.dart';
import '../Widgets/comprobante_dialog.dart';
import '../Utils/error_handler.dart';
import '../Utils/haptic_helper.dart';

class PagosResidenteScreen extends StatefulWidget {
  final AppController controller;
  final List<Map<String, dynamic>> misViviendas;

  const PagosResidenteScreen({
    super.key,
    required this.controller,
    required this.misViviendas,
  });

  @override
  State<PagosResidenteScreen> createState() => _PagosResidenteScreenState();
}

class _PagosResidenteScreenState extends State<PagosResidenteScreen>
    with SingleTickerProviderStateMixin {
  late final PagosService _pagosService;
  late final TabController _tabController;

  int? _selectedViviendaId;
  bool _isLoading = true;
  String? _errorMessage;

  MiSaldoResponse? _miSaldo;
  List<CargoModel> _cargos = [];
  List<PagoModel> _pagos = [];
  List<MovimientoSaldoModel> _movimientos = [];

  @override
  void initState() {
    super.initState();
    _pagosService = PagosService(widget.controller);
    _tabController = TabController(length: 3, vsync: this);

    if (widget.misViviendas.isNotEmpty) {
      final first = widget.misViviendas.first;
      if (first['id'] != null) {
        _selectedViviendaId = (first['id'] as num).toInt();
      }
    }

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
      final saldoFuture = _pagosService.getMiSaldo();
      final cargosFuture = _pagosService.getCargos(viviendaId: _selectedViviendaId);
      final pagosFuture = _pagosService.getPagos(viviendaId: _selectedViviendaId);
      final movimientosFuture = _selectedViviendaId != null
          ? _pagosService.getMovimientosSaldo(_selectedViviendaId!)
          : Future.value(PaginatedResponse<MovimientoSaldoModel>(
              pagina: 1,
              tamanoPagina: 20,
              total: 0,
              items: [],
            ));

      final results = await Future.wait([
        saldoFuture,
        cargosFuture,
        pagosFuture,
        movimientosFuture,
      ]);

      if (mounted) {
        setState(() {
          _miSaldo = results[0] as MiSaldoResponse;
          _cargos = (results[1] as PaginatedResponse<CargoModel>).items;
          _pagos = (results[2] as PaginatedResponse<PagoModel>).items;
          _movimientos =
              (results[3] as PaginatedResponse<MovimientoSaldoModel>).items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorHandler.extractErrorMessage(
            e,
            defaultMessage: 'No fue posible cargar el estado financiero.',
          );
        });
      }
    }
  }

  Future<void> _aplicarSaldoAFavor(CargoModel cargo) async {
    final saldoVivienda = _obtenerSaldoViviendaActual();
    final saldoFavor = saldoVivienda?.saldoAFavor ?? _miSaldo?.saldoAFavor ?? 0.0;

    if (saldoFavor <= 0) {
      widget.controller.notifyToast('No cuentas con saldo a favor disponible.', success: false);
      return;
    }

    final montoAplicar = saldoFavor >= cargo.saldoPendiente ? cargo.saldoPendiente : saldoFavor;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar Saldo a Favor'),
        content: Text(
          '¿Deseas aplicar \$${montoAplicar.toStringAsFixed(2)} de tu saldo a favor acumulado a la cuota "${cargo.concepto}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
            child: const Text('Aplicar Saldo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _pagosService.aplicarSaldo(cargo.id, montoAplicar);
      widget.controller.notifyToast('¡Saldo a favor aplicado exitosamente!', success: true);
      _cargarDatos();
    } catch (e) {
      final err = ErrorHandler.extractErrorMessage(
        e,
        defaultMessage: 'No fue posible aplicar el saldo a favor.',
      );
      widget.controller.notifyToast(err, success: false);
    }
  }

  SaldoViviendaResumen? _obtenerSaldoViviendaActual() {
    if (_miSaldo == null) return null;
    if (_selectedViviendaId == null) {
      return _miSaldo!.viviendas.isNotEmpty ? _miSaldo!.viviendas.first : null;
    }
    return _miSaldo!.viviendas.firstWhere(
      (v) => v.viviendaId == _selectedViviendaId,
      orElse: () => SaldoViviendaResumen(
        viviendaId: _selectedViviendaId!,
        numeroCasa: '',
        totalPendiente: _miSaldo!.totalPendiente,
        totalVencido: _miSaldo!.totalVencido,
        totalCargosAbiertos: _miSaldo!.totalCargosAbiertos,
        saldoAFavor: _miSaldo!.saldoAFavor,
      ),
    );
  }

  Color _obtenerColorEstadoCargo(String estado) {
    switch (estado) {
      case EstadoCargo.pendiente:
        return const Color(0xFFD97706); // Amarillo / Alerta
      case EstadoCargo.parcial:
        return const Color(0xFFEA580C); // Naranja
      case EstadoCargo.pagado:
        return const Color(0xFF059669); // Verde
      case EstadoCargo.cancelado:
      default:
        return const Color(0xFF64748B); // Gris
    }
  }

  Color _obtenerColorBgEstadoCargo(String estado) {
    switch (estado) {
      case EstadoCargo.pendiente:
        return const Color(0xFFFEF3C7);
      case EstadoCargo.parcial:
        return const Color(0xFFFFEDD5);
      case EstadoCargo.pagado:
        return const Color(0xFFD1FAE5);
      case EstadoCargo.cancelado:
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _obtenerColorEstadoPago(String estado) {
    switch (estado) {
      case EstadoPago.pendienteConfirmacion:
        return const Color(0xFF1D4ED8); // Azul
      case EstadoPago.confirmado:
        return const Color(0xFF059669); // Verde
      case EstadoPago.rechazado:
        return const Color(0xFFDC2626); // Rojo
      case EstadoPago.anulado:
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _obtenerColorBgEstadoPago(String estado) {
    switch (estado) {
      case EstadoPago.pendienteConfirmacion:
        return const Color(0xFFDBEAFE);
      case EstadoPago.confirmado:
        return const Color(0xFFD1FAE5);
      case EstadoPago.rechazado:
        return const Color(0xFFFEE2E2);
      case EstadoPago.anulado:
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saldoVivienda = _obtenerSaldoViviendaActual();
    final totalPendiente = saldoVivienda?.totalPendiente ?? _miSaldo?.totalPendiente ?? 0.0;
    final totalVencido = saldoVivienda?.totalVencido ?? _miSaldo?.totalVencido ?? 0.0;
    final saldoAFavor = saldoVivienda?.saldoAFavor ?? _miSaldo?.saldoAFavor ?? 0.0;
    final cargosAbiertos = saldoVivienda?.totalCargosAbiertos ?? _miSaldo?.totalCargosAbiertos ?? 0;

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
          'Pagos y Estado de Cuenta',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF111C99),
              indicatorWeight: 3,
              labelColor: const Color(0xFF111C99),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Cargos y Cuotas'),
                Tab(text: 'Historial de Pagos'),
                Tab(text: 'Saldo a Favor'),
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
                  // Selector de Vivienda si tiene más de 1
                  if (widget.misViviendas.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedViviendaId,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF111C99)),
                          items: widget.misViviendas.map((v) {
                            final id = (v['id'] as num?)?.toInt() ?? 0;
                            final numCasa = (v['numeroCasa'] ?? 'S/N').toString();
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                'Vivienda: Casa #$numCasa',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedViviendaId = val);
                              _cargarDatos();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Resumen Financiero Hero Card
                  _buildFinancialSummaryCard(
                    totalPendiente: totalPendiente,
                    totalVencido: totalVencido,
                    saldoAFavor: saldoAFavor,
                    cargosAbiertos: cargosAbiertos,
                  ),
                  const SizedBox(height: 20),

                  // Contenido de Pestañas
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
                            return _buildCargosTab();
                          case 1:
                            return _buildPagosTab();
                          case 2:
                          default:
                            return _buildMovimientosTab();
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

  Widget _buildFinancialSummaryCard({
    required double totalPendiente,
    required double totalVencido,
    required double saldoAFavor,
    required int cargosAbiertos,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111C99), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111C99).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Balance General',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalPendiente == 0
                      ? const Color(0xFF059669)
                      : const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  totalPendiente == 0 ? 'Al Corriente' : '$cargosAbiertos Cargo(s)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${totalPendiente.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const Text(
            'Total por liquidar',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // Submétricas
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFCA5A5)),
                        SizedBox(width: 4),
                        Text(
                          'Total Vencido',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${totalVencido.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: totalVencido > 0 ? const Color(0xFFFCA5A5) : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.savings_outlined, size: 14, color: Color(0xFF86EFAC)),
                        SizedBox(width: 4),
                        Text(
                          'Saldo a Favor',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${saldoAFavor.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF86EFAC),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
  // Pestaña 1: Cargos y Cuotas
  // ==========================================
  Widget _buildCargosTab() {
    if (_cargos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 48),
            SizedBox(height: 12),
            Text(
              '¡Estás al corriente!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 4),
            Text(
              'No tienes cuotas ni cargos pendientes de pago.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final saldoVivienda = _obtenerSaldoViviendaActual();
    final saldoFavor = saldoVivienda?.saldoAFavor ?? _miSaldo?.saldoAFavor ?? 0.0;

    return Column(
      children: _cargos.map((cargo) {
        final color = _obtenerColorEstadoCargo(cargo.estado);
        final bg = _obtenerColorBgEstadoCargo(cargo.estado);
        final estaVencido = cargo.estaVencido;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: estaVencido ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
              width: estaVencido ? 1.5 : 1.0,
            ),
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
              // Header del cargo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              cargo.concepto,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (estaVencido) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'VENCIDO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tipo: ${cargo.tipo}${cargo.periodo != null ? ' • Periodo: ${cargo.periodo}' : ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cargo.estado,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Balances
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total del Cargo', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(
                          '\$${cargo.monto.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('Pagado', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(
                          '\$${cargo.montoPagado.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Saldo Restante', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(
                          '\$${cargo.saldoPendiente.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: cargo.saldoPendiente > 0 ? const Color(0xFF111C99) : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (cargo.fechaVencimiento != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'Vence: ${cargo.fechaVencimiento}',
                      style: TextStyle(
                        fontSize: 12,
                        color: estaVencido ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                        fontWeight: estaVencido ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // Botones de Acción
              if (cargo.saldoPendiente > 0 && cargo.estado != EstadoCargo.cancelado)
                Row(
                  children: [
                    if (saldoFavor > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _aplicarSaldoAFavor(cargo),
                          icon: const Icon(Icons.savings_outlined, size: 16),
                          label: const Text('Aplicar Saldo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF047857),
                            side: const BorderSide(color: Color(0xFFA7F3D0)),
                            backgroundColor: const Color(0xFFECFDF5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () async {
                          HapticHelper.selection();
                          final vivId = _selectedViviendaId ?? cargo.viviendaId;
                          final success = await ReportarPagoModal.show(
                            context,
                            cargo: cargo,
                            viviendaId: vivId,
                            pagosService: _pagosService,
                            controller: widget.controller,
                          );
                          if (success == true) {
                            _cargarDatos();
                          }
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Reportar Pago'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF111C99),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
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
  // Pestaña 2: Historial de Pagos
  // ==========================================
  Widget _buildPagosTab() {
    if (_pagos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.history_rounded, color: Color(0xFF64748B), size: 44),
            SizedBox(height: 12),
            Text(
              'Sin pagos registrados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 4),
            Text(
              'Los pagos que reportes o sean confirmados por administración aparecerán aquí.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _pagos.map((pago) {
        final color = _obtenerColorEstadoPago(pago.estado);
        final bg = _obtenerColorBgEstadoPago(pago.estado);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pago.estado == EstadoPago.pendienteConfirmacion
                          ? 'En Revisión'
                          : pago.estado,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Método: ${pago.metodo}${pago.folioComprobante != null && pago.folioComprobante!.isNotEmpty ? ' • Folio: ${pago.folioComprobante}' : ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              if (pago.fechaPago != null)
                Text(
                  'Fecha: ${pago.fechaPago!.toLocal().toString().split(' ').first}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),

              // Banner de Motivo de Rechazo
              if (pago.estado == EstadoPago.rechazado &&
                  pago.motivoRechazo != null &&
                  pago.motivoRechazo!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Motivo de rechazo: ${pago.motivoRechazo}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                    label: const Text('Ver Comprobante'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
  // Pestaña 3: Movimientos de Saldo a Favor
  // ==========================================
  Widget _buildMovimientosTab() {
    if (_movimientos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF64748B), size: 44),
            SizedBox(height: 12),
            Text(
              'Sin movimientos de saldo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 4),
            Text(
              'Los abonos por excedentes y aplicaciones a cuotas se registrarán en esta sección.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _movimientos.map((mov) {
        final isAbono = mov.tipo == TipoMovimientoSaldo.abono;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAbono ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAbono ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: isAbono ? const Color(0xFF059669) : const Color(0xFF1D4ED8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mov.concepto ?? (isAbono ? 'Abono a favor' : 'Aplicación a cargo'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Saldo: \$${mov.saldoAnterior.toStringAsFixed(2)} → \$${mov.saldoNuevo.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Text(
                '${isAbono ? '+' : '-'}\$${mov.monto.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isAbono ? const Color(0xFF059669) : const Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
