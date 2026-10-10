import 'package:flutter/material.dart';
import '../Models/paquete_model.dart';
import '../Services/app_controller.dart';
import '../Services/paqueteria_service.dart';
import '../Utils/haptic_helper.dart';
import '../Widgets/paquete_card.dart';
import '../Widgets/recibir_paquete_modal.dart';
import '../Widgets/entregar_paquete_modal.dart';

class PaqueteriaCasetaScreen extends StatefulWidget {
  final AppController controller;

  final bool isEmbedded;

  const PaqueteriaCasetaScreen({
    super.key,
    required this.controller,
    this.isEmbedded = false,
  });

  @override
  State<PaqueteriaCasetaScreen> createState() => _PaqueteriaCasetaScreenState();
}

class _PaqueteriaCasetaScreenState extends State<PaqueteriaCasetaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  List<PaqueteModel> _esperados = [];
  List<PaqueteModel> _inventario = [];
  List<PaqueteModel> _historico = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final resEsperados = await service.getPaquetesEsperadosCaseta(page: 1, pageSize: 50);
      final resInventario = await service.getInventarioCaseta(page: 1, pageSize: 50);
      final resHistorico = await service.getHistoricoCaseta(page: 1, pageSize: 50);

      if (!mounted) return;

      setState(() {
        _esperados = resEsperados['success'] == true
            ? (resEsperados['items'] as List<PaqueteModel>)
            : [];
        _inventario = resInventario['success'] == true
            ? (resInventario['items'] as List<PaqueteModel>)
            : [];
        _historico = resHistorico['success'] == true
            ? (resHistorico['items'] as List<PaqueteModel>)
            : [];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión al cargar la paquetería de caseta.';
          _isLoading = false;
        });
      }
    }
  }

  List<PaqueteModel> _filtrarLista(List<PaqueteModel> lista) {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return lista;
    return lista.where((p) {
      return p.numeroCasa.toLowerCase().contains(query) ||
          p.destinatarioNombre.toLowerCase().contains(query) ||
          (p.servicioNombre ?? '').toLowerCase().contains(query) ||
          (p.numeroGuia ?? '').toLowerCase().contains(query) ||
          (p.ubicacionAlmacen ?? '').toLowerCase().contains(query);
    }).toList();
  }

  void _abrirModalRecepcion({PaqueteModel? preseleccionado}) async {
    HapticHelper.light();
    final recibido = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecibirPaqueteModal(
        controller: widget.controller,
        paquetesEsperados: _esperados,
        paquetePreseleccionado: preseleccionado,
      ),
    );

    if (recibido == true) {
      _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paquete recibido en caseta. Notificación enviada al residente.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _abrirModalEntrega(PaqueteModel paquete) async {
    HapticHelper.light();
    final entregado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntregarPaqueteModal(
        controller: widget.controller,
        paquete: paquete,
      ),
    );

    if (entregado == true) {
      _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrega registrada exitosamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF059669),
        labelColor: const Color(0xFF059669),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(
            text: _esperados.isNotEmpty ? 'Esperados (${_esperados.length})' : 'Esperados',
          ),
          Tab(
            text: _inventario.isNotEmpty ? 'Inventario (${_inventario.length})' : 'Inventario',
          ),
          const Tab(text: 'Histórico'),
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
                'Caseta · Paquetería',
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
        onPressed: () => _abrirModalRecepcion(),
        backgroundColor: const Color(0xFF059669),
        icon: const Icon(Icons.add_box_rounded, color: Colors.white),
        label: const Text(
          'Recibir Paquete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: const Color(0xFF059669),
        child: Column(
          children: [
            if (widget.isEmbedded) _buildTabBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar por casa, destinatario, guía o caseta...',
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
                  : _errorMessage != null
                      ? _buildErrorView()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildListView(
                              _filtrarLista(_esperados),
                              tipo: 'esperados',
                              emptyMsg: 'No hay paquetes esperados registrados para hoy.',
                            ),
                            _buildListView(
                              _filtrarLista(_inventario),
                              tipo: 'inventario',
                              emptyMsg: 'El inventario de caseta está vacío. ¡Todo ha sido entregado!',
                            ),
                            _buildListView(
                              _filtrarLista(_historico),
                              tipo: 'historico',
                              emptyMsg: 'Sin registros de paquetes en el histórico.',
                            ),
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
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<PaqueteModel> list, {required String tipo, required String emptyMsg}) {
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
                    color: const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
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
          showCasetaActions: true,
          onReceive: paquete.isEsperado ? () => _abrirModalRecepcion(preseleccionado: paquete) : null,
          onDeliver: paquete.isRecibido ? () => _abrirModalEntrega(paquete) : null,
        );
      },
    );
  }
}
