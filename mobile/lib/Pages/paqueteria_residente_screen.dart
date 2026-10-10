import 'package:flutter/material.dart';
import '../Models/paquete_model.dart';
import '../Models/servicio_paqueteria_model.dart';
import '../Services/app_controller.dart';
import '../Services/paqueteria_service.dart';
import '../Utils/haptic_helper.dart';
import '../Widgets/paquete_card.dart';
import '../Widgets/registrar_paquete_modal.dart';

class PaqueteriaResidenteScreen extends StatefulWidget {
  final AppController controller;
  final List<dynamic> misViviendas;
  final String? focusPaqueteId;

  final bool isEmbedded;

  const PaqueteriaResidenteScreen({
    super.key,
    required this.controller,
    this.misViviendas = const [],
    this.focusPaqueteId,
    this.isEmbedded = false,
  });

  @override
  State<PaqueteriaResidenteScreen> createState() => _PaqueteriaResidenteScreenState();
}

class _PaqueteriaResidenteScreenState extends State<PaqueteriaResidenteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  List<PaqueteModel> _paquetes = [];
  List<ServicioPaqueteriaModel> _servicios = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _viviendaFiltroId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = PaqueteriaService(widget.controller);
      final res = await service.getMisPaquetes(
        page: 1,
        pageSize: 50,
        viviendaId: _viviendaFiltroId,
      );

      final servList = await service.getServicios();

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _paquetes = res['items'] as List<PaqueteModel>;
          _servicios = servList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'No se pudieron cargar los paquetes.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión al cargar paquetería.';
          _isLoading = false;
        });
      }
    }
  }

  List<PaqueteModel> get _pendientes {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _paquetes.where((p) {
      final esPendiente = p.isEsperado || p.isRecibido;
      if (!esPendiente) return false;
      if (query.isEmpty) return true;
      return p.destinatarioNombre.toLowerCase().contains(query) ||
          (p.servicioNombre ?? '').toLowerCase().contains(query) ||
          (p.numeroGuia ?? '').toLowerCase().contains(query);
    }).toList();
  }

  List<PaqueteModel> get _historial {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _paquetes.where((p) {
      final esHistorial = p.isEntregado || p.isCancelado || p.isDevuelto || p.isVencido;
      if (!esHistorial) return false;
      if (query.isEmpty) return true;
      return p.destinatarioNombre.toLowerCase().contains(query) ||
          (p.servicioNombre ?? '').toLowerCase().contains(query) ||
          (p.numeroGuia ?? '').toLowerCase().contains(query);
    }).toList();
  }

  int get _enCasetaCount => _paquetes.where((p) => p.isRecibido).length;

  void _abrirModalRegistro({PaqueteModel? paqueteAEditar}) async {
    HapticHelper.light();
    final modificado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrarPaqueteModal(
        controller: widget.controller,
        misViviendas: widget.misViviendas,
        paqueteAEditar: paqueteAEditar,
        serviciosDisponibles: _servicios,
      ),
    );

    if (modificado == true) {
      _cargarDatos();
    }
  }

  Future<void> _confirmarCancelar(PaqueteModel paquete) async {
    HapticHelper.light();
    final motivoCtrl = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar Paquete Esperado', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que deseas cancelar el registro del paquete de ${paquete.servicioNombre ?? 'paquetería'}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: motivoCtrl,
              decoration: InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ej. Cancelé la compra en tienda',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar Paquete'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final service = PaqueteriaService(widget.controller);
      final res = await service.cancelarPaqueteEsperado(
        paquete.id,
        motivo: motivoCtrl.text.trim().isNotEmpty ? motivoCtrl.text.trim() : null,
      );

      if (mounted) {
        if (res['success'] == true) {
          HapticHelper.success();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paquete cancelado correctamente'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _cargarDatos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'No se pudo cancelar el paquete'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
    motivoCtrl.dispose();
  }

  void _mostrarDetallePaquete(PaqueteModel paquete) {
    HapticHelper.light();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF111C99), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                paquete.servicioNombre ?? 'Paquete',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Estado', paquete.estadoLabel, highlight: true),
              _buildDetailRow('Destinatario', paquete.destinatarioNombre),
              _buildDetailRow('Casa', '#${paquete.numeroCasa}'),
              if (paquete.numeroGuia != null)
                _buildDetailRow('Número de guía', paquete.numeroGuia!),
              if (paquete.ubicacionAlmacen != null)
                _buildDetailRow('Ubicación caseta', paquete.ubicacionAlmacen!),
              if (paquete.descripcion != null)
                _buildDetailRow('Descripción', paquete.descripcion!),
              if (paquete.notas != null)
                _buildDetailRow('Notas', paquete.notas!),
              if (paquete.recibidoEn != null)
                _buildDetailRow('Recibido en', paquete.recibidoEn.toString().split('.')[0]),
              if (paquete.entregadoEn != null)
                _buildDetailRow('Entregado en', paquete.entregadoEn.toString().split('.')[0]),
              if (paquete.entregadoANombre != null)
                _buildDetailRow('Entregado a', paquete.entregadoANombre!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight ? const Color(0xFF111C99) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF111C99),
        labelColor: const Color(0xFF111C99),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Pendientes'),
                if (_enCasetaCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_enCasetaCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Historial'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.white,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
              title: const Text(
                'Paquetería y Envíos',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _buildTabBar(),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirModalRegistro(),
        backgroundColor: const Color(0xFF111C99),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Avisar Paquete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: const Color(0xFF111C99),
        child: Column(
          children: [
            if (widget.isEmbedded) _buildTabBar(),
            // Banner de Alerta si hay paquetes en caseta
            if (_enCasetaCount > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Tienes $_enCasetaCount paquete(s) en caseta!',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Ya puedes acudir a vigilancia a recoger tus entregas.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar por empresa, guía o destinatario...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),

            // Contenido de Tabs
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF111C99)),
                    )
                  : _errorMessage != null
                      ? _buildErrorView()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildListView(_pendientes, esHistorial: false),
                            _buildListView(_historial, esHistorial: true),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<PaqueteModel> list, {required bool esHistorial}) {
    if (list.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    esHistorial ? Icons.history_rounded : Icons.mark_unread_chat_alt_outlined,
                    size: 48,
                    color: const Color(0xFF111C99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  esHistorial
                      ? 'Sin historial de entregas'
                      : 'No tienes paquetes pendientes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  esHistorial
                      ? 'Los paquetes entregados o cancelados se mostrarán aquí.'
                      : 'Cuando compres en línea, avisa a caseta para que lo reciban de inmediato.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                if (!esHistorial) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _abrirModalRegistro(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Avisar un Paquete'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final paquete = list[i];
        return PaqueteCard(
          key: ValueKey(paquete.id),
          paquete: paquete,
          onTap: () => _mostrarDetallePaquete(paquete),
          onEdit: paquete.isEsperado ? () => _abrirModalRegistro(paqueteAEditar: paquete) : null,
          onCancel: paquete.isEsperado ? () => _confirmarCancelar(paquete) : null,
        );
      },
    );
  }
}
