import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../Models/visita_model.dart';
import '../Services/app_controller.dart';
import '../Services/visitas_service.dart';
import '../Services/avisos_service.dart';
import '../Services/push_notifications_service.dart';
import 'perfil_screen.dart';

class VigilanteDashboardScreen extends StatefulWidget {
  final AppController controller;

  const VigilanteDashboardScreen({super.key, required this.controller});

  @override
  State<VigilanteDashboardScreen> createState() => _VigilanteDashboardScreenState();
}

class _VigilanteDashboardScreenState extends State<VigilanteDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _solicitarPermisos();
  }

  Future<void> _solicitarPermisos() async {
    await PushNotificationsService.requestPermission(
      userId: widget.controller.currentUser?.id,
    );
    await PushNotificationsService.subscribeToTopic('avisos');
    await PushNotificationsService.subscribeToTopic('avisos_urgentes');
    await PushNotificationsService.subscribeToTopic('general');
    final userId = widget.controller.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      await PushNotificationsService.subscribeToUserTopic(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final nombre = user?.nombre ?? 'Vigilante';

    final List<Widget> pages = [
      _VisitasCasetaSection(controller: widget.controller),
      _DirectorioCasasTab(controller: widget.controller),
      _AvisosCasetaTab(controller: widget.controller),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PerfilScreen(controller: widget.controller),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFD97706),
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'V',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Control de Caseta',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Seguro que quieres salir de sesión?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                widget.controller.logout();
              }
            },
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          indicatorColor: const Color(0xFFFEF3C7),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.badge_rounded, color: Color(0xFFD97706)),
              label: 'Visitas',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_work_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.home_work_rounded, color: Color(0xFFD97706)),
              label: 'Directorio',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.campaign_rounded, color: Color(0xFFD97706)),
              label: 'Avisos',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SECCIÓN VISITAS – CASETA (Tabs: Hoy, Programadas, Historial)
// ─────────────────────────────────────────────────────────────
class _VisitasCasetaSection extends StatefulWidget {
  final AppController controller;
  const _VisitasCasetaSection({required this.controller});

  @override
  State<_VisitasCasetaSection> createState() => _VisitasCasetaSectionState();
}

class _VisitasCasetaSectionState extends State<_VisitasCasetaSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFFD97706),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Hoy'),
                Tab(text: 'Programadas'),
                Tab(text: 'Historial'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _VisitasHoyTab(controller: widget.controller),
              _VisitasProgramadasTab(controller: widget.controller),
              _VisitasHistorialTab(controller: widget.controller),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 0 – VISITAS DE HOY (control de acceso)
// ─────────────────────────────────────────────────────────────
class _VisitasHoyTab extends StatefulWidget {
  final AppController controller;
  const _VisitasHoyTab({required this.controller});

  @override
  State<_VisitasHoyTab> createState() => _VisitasHoyTabState();
}

class _VisitasHoyTabState extends State<_VisitasHoyTab> {
  final _searchController = TextEditingController();
  final _codigoModalController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _busquedaActual = '';
  List<VisitaModel> _visitas = [];
  String? _processingVisitaId;

  @override
  void initState() {
    super.initState();
    _cargarVisitas(refresh: true);
    _scrollController.addListener(_onScroll);
    PushNotificationsService.requestPermission(
      userId: widget.controller.currentUser?.id,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _codigoModalController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _cargarVisitas();
    }
  }

  Future<void> _cargarVisitas({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    if (!_hasMore || (_isFetchingMore && !refresh)) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
      } else {
        _isFetchingMore = true;
      }
    });

    try {
      final service = VisitasService(widget.controller);
      final res = await service.getVisitasHoy(
        page: _currentPage,
        pageSize: 20,
        busqueda: _busquedaActual.isEmpty ? null : _busquedaActual,
      );

      if (mounted) {
        if (res['success'] == true) {
          final List<VisitaModel> items = res['items'] as List<VisitaModel>;
          setState(() {
            if (refresh) {
              _visitas = items;
            } else {
              _visitas.addAll(items);
            }
            _currentPage++;
            _hasMore = items.length == 20;
            _isLoading = false;
            _isFetchingMore = false;
          });
        } else {
          setState(() {
            if (refresh) _visitas = [];
            _isLoading = false;
            _isFetchingMore = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<void> _registrarEntrada(VisitaModel visita) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registrar Entrada'),
        content: Text(
          '¿Confirmar ingreso de ${visita.nombreCompletoVisitante} para la casa #${visita.numeroCasa}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar Entrada'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingVisitaId = visita.id);
    final service = VisitasService(widget.controller);
    final res = await service.registrarEntrada(visita.id);

    if (mounted) {
      setState(() => _processingVisitaId = null);
      if (res['success'] == true) {
        widget.controller.notifyToast('¡Entrada registrada! Se notificó al residente.', success: true);
        _cargarVisitas(refresh: true);
      } else {
        widget.controller.notifyToast(res['error'] ?? 'Error al registrar entrada', success: false);
      }
    }
  }

  Future<void> _registrarSalida(VisitaModel visita) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registrar Salida'),
        content: Text('¿Confirmar salida de ${visita.nombreCompletoVisitante}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar Salida'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingVisitaId = visita.id);
    final service = VisitasService(widget.controller);
    final res = await service.registrarSalida(visita.id);

    if (mounted) {
      setState(() => _processingVisitaId = null);
      if (res['success'] == true) {
        widget.controller.notifyToast('¡Salida registrada con éxito!', success: true);
        _cargarVisitas(refresh: true);
      } else {
        widget.controller.notifyToast(res['error'] ?? 'Error al registrar salida', success: false);
      }
    }
  }

  Future<void> _abrirValidarCodigoDialog() async {
    _codigoModalController.clear();
    bool isValidating = false;
    String? errorLocal;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Text('Validar Código'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ingresa el código alfanumérico proporcionado por el visitante:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codigoModalController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'CÓDIGO',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: errorLocal,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: isValidating
                      ? null
                      : () async {
                          final cod = _codigoModalController.text.trim();
                          if (cod.isEmpty) {
                            setModalState(() => errorLocal = 'Ingresa un código');
                            return;
                          }
                          setModalState(() {
                            isValidating = true;
                            errorLocal = null;
                          });
                          final service = VisitasService(widget.controller);
                          final res = await service.validarCodigo(cod);
                          setModalState(() => isValidating = false);
                          if (res['success'] == true) {
                            final visita = res['visita'] as VisitaModel;
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              _mostrarResultadoValidacion(visita);
                            }
                          } else {
                            setModalState(() {
                              errorLocal = res['error'] ?? 'Código inválido o expirado';
                            });
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                  child: isValidating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Validar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarResultadoValidacion(VisitaModel v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pase Válido y Vigente',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                          ),
                          Text(
                            'Vivienda Casa #${v.numeroCasa}',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    _buildEstadoBadge(v.estado),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _buildInfoRow('Visitante', v.nombreCompletoVisitante),
                _buildInfoRow('Motivo', v.motivo.toUpperCase()),
                _buildInfoRow('Acompañantes', '${v.numAcompanantes} personas'),
                if (v.vehiculoPlacas != null && v.vehiculoPlacas!.isNotEmpty)
                  _buildInfoRow('Placas de Vehículo', v.vehiculoPlacas!),
                if (v.telefonoVisitante != null && v.telefonoVisitante!.isNotEmpty)
                  _buildInfoRow('Teléfono', v.telefonoVisitante!),
                if (v.notas != null && v.notas!.isNotEmpty) _buildInfoRow('Notas', v.notas!),
                _buildInfoRow('Válido hasta', _formatearFecha(v.vigenciaHasta)),
                const SizedBox(height: 24),
                if (v.isProgramada) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _registrarEntrada(v);
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Registrar Entrada Ahora'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ] else if (v.isEnCurso) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _registrarSalida(v);
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Registrar Salida'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ] else ...[
                  FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  Widget _buildEstadoBadge(String estado) {
    Color bg;
    Color fg;
    String text;

    switch (estado.toLowerCase()) {
      case 'programada':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        text = 'Programada';
        break;
      case 'en_curso':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        text = 'En curso';
        break;
      case 'finalizada':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        text = 'Finalizada';
        break;
      case 'cancelada':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        text = 'Cancelada';
        break;
      case 'expirada':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        text = 'Expirada';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        text = estado;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirValidarCodigoDialog,
        backgroundColor: const Color(0xFFD97706),
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text(
          'Validar Código',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFD97706),
        onRefresh: () => _cargarVisitas(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header con buscador
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Hero
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD97706), Color(0xFFB45309)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Control de Accesos',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Visitas programadas y en curso para hoy',
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Barra de búsqueda
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, código o # casa...',
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _busquedaActual = '');
                                  _cargarVisitas(refresh: true);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (val) {
                        setState(() => _busquedaActual = val.trim());
                        _cargarVisitas(refresh: true);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Lista de visitas
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFD97706)),
                ),
              )
            else if (_visitas.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF7ED),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 48,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _busquedaActual.isNotEmpty
                              ? 'No se encontraron resultados'
                              : 'No hay visitas programadas para hoy',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _busquedaActual.isNotEmpty
                              ? 'Intenta con otro término o código'
                              : 'Las visitas del día aparecerán aquí para control de acceso.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _visitas.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                          ),
                        );
                      }

                      final v = _visitas[index];
                      final isProcessing = _processingVisitaId == v.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x04000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Casa #${v.numeroCasa}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            v.motivo.toUpperCase(),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEstadoBadge(v.estado),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                v.nombreCompletoVisitante,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (v.vehiculoPlacas != null && v.vehiculoPlacas!.isNotEmpty) ...[
                                    const Icon(Icons.directions_car_rounded, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      v.vehiculoPlacas!,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  const Icon(Icons.group_outlined, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${v.numAcompanantes} acompañantes',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              if (v.notas != null && v.notas!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Nota: ${v.notas!}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (v.isProgramada) ...[
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: isProcessing ? null : () => _registrarEntrada(v),
                                        icon: isProcessing
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.login_rounded, size: 16),
                                        label: const Text('Dar Entrada'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF059669),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ] else if (v.isEnCurso) ...[
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: isProcessing ? null : () => _registrarSalida(v),
                                        icon: isProcessing
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.logout_rounded, size: 16),
                                        label: const Text('Dar Salida'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFD97706),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      v.isFinalizada
                                          ? 'Salida: ${v.horaSalida != null ? _formatearFecha(v.horaSalida!) : 'Completada'}'
                                          : 'Visita ${v.estado}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _visitas.length + (_hasMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB-TAB 1 – VISITAS PROGRAMADAS (Futuras)
// ─────────────────────────────────────────────────────────────
class _VisitasProgramadasTab extends StatefulWidget {
  final AppController controller;
  const _VisitasProgramadasTab({required this.controller});

  @override
  State<_VisitasProgramadasTab> createState() => _VisitasProgramadasTabState();
}

class _VisitasProgramadasTabState extends State<_VisitasProgramadasTab> {
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _busquedaActual = '';
  List<VisitaModel> _visitas = [];

  @override
  void initState() {
    super.initState();
    _cargarVisitas(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _cargarVisitas();
    }
  }

  Future<void> _cargarVisitas({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    if (!_hasMore || (_isFetchingMore && !refresh)) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
      } else {
        _isFetchingMore = true;
      }
    });

    try {
      final service = VisitasService(widget.controller);
      final res = await service.getVisitasProgramadas(
        page: _currentPage,
        pageSize: 20,
      );

      if (mounted) {
        if (res['success'] == true) {
          final List<VisitaModel> items = res['items'] as List<VisitaModel>;
          setState(() {
            if (refresh) {
              _visitas = items;
            } else {
              _visitas.addAll(items);
            }
            _currentPage++;
            _hasMore = items.length == 20;
            _isLoading = false;
            _isFetchingMore = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _isFetchingMore = false;
          });
          widget.controller.notifyToast(res['error'] ?? 'Error al cargar visitas programadas', success: false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  List<VisitaModel> get _visitasFiltradas {
    if (_busquedaActual.trim().isEmpty) return _visitas;
    final q = _busquedaActual.trim().toLowerCase();
    return _visitas.where((v) {
      final name = v.nombreCompletoVisitante.toLowerCase();
      final casa = v.numeroCasa.toLowerCase();
      final cod = (v.codigo ?? '').toLowerCase();
      final motivo = v.motivo.toLowerCase();
      return name.contains(q) || casa.contains(q) || cod.contains(q) || motivo.contains(q);
    }).toList();
  }

  String _formatearFechaHora(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  String _etiquetaRelativa(DateTime fecha) {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);
    final diff = fechaDia.difference(hoy).inDays;

    final hora = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    if (diff == 1) {
      return 'Mañana a las $hora';
    } else if (diff == 2) {
      return 'En 2 días · $hora';
    } else if (diff > 2 && diff <= 7) {
      return 'En $diff días · $hora';
    } else {
      return _formatearFechaHora(fecha);
    }
  }

  void _mostrarDetalle(VisitaModel v) {
    _mostrarDetalleVisitaSheet(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final items = _visitasFiltradas;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFFD97706),
        onRefresh: () => _cargarVisitas(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Banner explicativo de programadas
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFFFBEB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Visitas Futuras Programadas',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_visitas.length} visita(s) agendada(s) para los próximos días.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Buscador
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _busquedaActual = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar por visitante, casa o código...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _busquedaActual.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _busquedaActual = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            ),

            // Estado de carga inicial
            if (_isLoading && _visitas.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFD97706)),
                ),
              )
            // Estado vacío
            else if (items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _busquedaActual.isNotEmpty ? Icons.search_off_rounded : Icons.calendar_today_rounded,
                          size: 56,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _busquedaActual.isNotEmpty
                              ? 'No hay visitas que coincidan con "$_busquedaActual"'
                              : 'No hay visitas programadas para los próximos días',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Cuando los residentes agenden visitas futuras, aparecerán aquí automáticamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            // Lista de tarjetas
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(color: Color(0xFFD97706), strokeWidth: 2),
                          ),
                        );
                      }

                      final v = items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x04000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _mostrarDetalle(v),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Encabezado fecha esperada + badge estado
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                            const SizedBox(width: 4),
                                            Text(
                                              _etiquetaRelativa(v.fechaLlegadaEsperada),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          'Casa #${v.numeroCasa}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Visitante y motivo
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: const Color(0xFFFEF3C7),
                                        child: Text(
                                          v.nombreVisitante.isNotEmpty ? v.nombreVisitante[0].toUpperCase() : 'V',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              v.nombreCompletoVisitante,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Motivo: ${v.motivo}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                            if (v.creadoPorNombre != null && v.creadoPorNombre!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Registrada por: ${v.creadoPorNombre}',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Detalles extras (acompañantes, placas, código)
                                  if (v.numAcompanantes > 0 || (v.vehiculoPlacas != null && v.vehiculoPlacas!.isNotEmpty) || v.codigo != null) ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        if (v.numAcompanantes > 0)
                                          _buildTagChip(
                                            icon: Icons.people_outline_rounded,
                                            label: '${v.numAcompanantes} acompañante(s)',
                                          ),
                                        if (v.vehiculoPlacas != null && v.vehiculoPlacas!.isNotEmpty)
                                          _buildTagChip(
                                            icon: Icons.directions_car_outlined,
                                            label: 'Placas: ${v.vehiculoPlacas}',
                                          ),
                                        if (v.codigo != null && v.codigo!.isNotEmpty)
                                          _buildTagChip(
                                            icon: Icons.key_rounded,
                                            label: 'Cód: ${v.codigo}',
                                            highlight: true,
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: items.length + (_hasMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip({required IconData icon, required String label, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: highlight ? const Color(0xFFD97706) : const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? const Color(0xFF92400E) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB-TAB 2 – HISTORIAL DE VISITAS (Pasadas y anteriores)
// ─────────────────────────────────────────────────────────────
class _VisitasHistorialTab extends StatefulWidget {
  final AppController controller;
  const _VisitasHistorialTab({required this.controller});

  @override
  State<_VisitasHistorialTab> createState() => _VisitasHistorialTabState();
}

class _VisitasHistorialTabState extends State<_VisitasHistorialTab> {
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _filtroEstado;
  String _busquedaActual = '';
  List<VisitaModel> _visitas = [];

  final List<Map<String, String?>> _filtrosEstados = [
    {'label': 'Todos', 'val': null},
    {'label': 'Finalizada', 'val': 'finalizada'},
    {'label': 'Expirada', 'val': 'expirada'},
    {'label': 'Cancelada', 'val': 'cancelada'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarVisitas(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _cargarVisitas();
    }
  }

  Future<void> _cargarVisitas({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    if (!_hasMore || (_isFetchingMore && !refresh)) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
      } else {
        _isFetchingMore = true;
      }
    });

    try {
      final service = VisitasService(widget.controller);
      final res = await service.getVisitasPasadas(
        page: _currentPage,
        pageSize: 20,
        estado: _filtroEstado,
      );

      if (mounted) {
        if (res['success'] == true) {
          final List<VisitaModel> items = res['items'] as List<VisitaModel>;
          setState(() {
            if (refresh) {
              _visitas = items;
            } else {
              _visitas.addAll(items);
            }
            _currentPage++;
            _hasMore = items.length == 20;
            _isLoading = false;
            _isFetchingMore = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _isFetchingMore = false;
          });
          widget.controller.notifyToast(res['error'] ?? 'Error al cargar historial', success: false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  List<VisitaModel> get _visitasFiltradas {
    if (_busquedaActual.trim().isEmpty) return _visitas;
    final q = _busquedaActual.trim().toLowerCase();
    return _visitas.where((v) {
      final name = v.nombreCompletoVisitante.toLowerCase();
      final casa = v.numeroCasa.toLowerCase();
      final cod = (v.codigo ?? '').toLowerCase();
      final motivo = v.motivo.toLowerCase();
      return name.contains(q) || casa.contains(q) || cod.contains(q) || motivo.contains(q);
    }).toList();
  }

  String _formatearFechaHora(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  Widget _buildEstadoBadge(String estado) {
    Color bg;
    Color fg;
    String text;

    switch (estado.toLowerCase()) {
      case 'finalizada':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        text = 'Finalizada';
        break;
      case 'cancelada':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        text = 'Cancelada';
        break;
      case 'expirada':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        text = 'Expirada';
        break;
      case 'en_curso':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        text = 'En curso';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        text = estado;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  void _mostrarDetalle(VisitaModel v) {
    _mostrarDetalleVisitaSheet(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final items = _visitasFiltradas;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFFD97706),
        onRefresh: () => _cargarVisitas(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Filtros de estado por chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filtrosEstados.map((f) {
                      final isSelected = _filtroEstado == f['val'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          label: Text(f['label']!),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFFFEF3C7),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (_) {
                            setState(() {
                              _filtroEstado = f['val'];
                            });
                            _cargarVisitas(refresh: true);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Buscador
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _busquedaActual = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar en historial...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _busquedaActual.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _busquedaActual = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            ),

            // Estado de carga inicial
            if (_isLoading && _visitas.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFD97706)),
                ),
              )
            // Estado vacío
            else if (items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 56,
                          color: Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _busquedaActual.isNotEmpty
                              ? 'No se encontraron visitas que coincidan'
                              : 'No hay visitas pasadas registradas',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'El registro de visitas concluidas, canceladas o vencidas aparecerá aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            // Lista de tarjetas del historial
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(color: Color(0xFFD97706), strokeWidth: 2),
                          ),
                        );
                      }

                      final v = items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x04000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _mostrarDetalle(v),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Encabezado casa + badge estado
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Casa #${v.numeroCasa}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                      _buildEstadoBadge(v.estado),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Visitante
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        child: Text(
                                          v.nombreVisitante.isNotEmpty ? v.nombreVisitante[0].toUpperCase() : 'V',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              v.nombreCompletoVisitante,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Motivo: ${v.motivo}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 8),

                                  // Horarios
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Llegada: ${_formatearFechaHora(v.fechaLlegadaEsperada)}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                      if (v.horaEntrada != null)
                                        Text(
                                          'Entró: ${_formatearFechaHora(v.horaEntrada!)}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                  if (v.horaSalida != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Salió: ${_formatearFechaHora(v.horaSalida!)}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: items.length + (_hasMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODAL GENERAL DE DETALLE DE VISITA (Reutilizable para vigilante)
// ─────────────────────────────────────────────────────────────
void _mostrarDetalleVisitaSheet(BuildContext context, VisitaModel v) {
  String formatearDt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFFEF3C7),
                    child: Text(
                      v.nombreVisitante.isNotEmpty ? v.nombreVisitante[0].toUpperCase() : 'V',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.nombreCompletoVisitante,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Vivienda Casa #${v.numeroCasa} · ${v.motivo}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              if (v.codigo != null && v.codigo!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Código de Acceso:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      Text(
                        v.codigo!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildInfoFila('Estado', v.estado.toUpperCase()),
              _buildInfoFila('Llegada esperada', formatearDt(v.fechaLlegadaEsperada)),
              _buildInfoFila('Vigente hasta', formatearDt(v.vigenciaHasta)),
              if (v.horaEntrada != null) _buildInfoFila('Hora de Entrada', formatearDt(v.horaEntrada!)),
              if (v.horaSalida != null) _buildInfoFila('Hora de Salida', formatearDt(v.horaSalida!)),
              _buildInfoFila('Acompañantes', '${v.numAcompanantes} personas'),
              if (v.vehiculoPlacas != null && v.vehiculoPlacas!.isNotEmpty)
                _buildInfoFila('Placas de Vehículo', v.vehiculoPlacas!),
              if (v.telefonoVisitante != null && v.telefonoVisitante!.isNotEmpty)
                _buildInfoFila('Teléfono', v.telefonoVisitante!),
              if (v.creadoPorNombre != null && v.creadoPorNombre!.isNotEmpty)
                _buildInfoFila('Registrada por', v.creadoPorNombre!),
              if (v.notas != null && v.notas!.isNotEmpty) _buildInfoFila('Notas', v.notas!),

              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildInfoFila(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// TAB 1 – DIRECTORIO DE CASAS (solo lectura para vigilante)
// ─────────────────────────────────────────────────────────────
class _DirectorioCasasTab extends StatefulWidget {
  final AppController controller;
  const _DirectorioCasasTab({required this.controller});

  @override
  State<_DirectorioCasasTab> createState() => _DirectorioCasasTabState();
}

class _DirectorioCasasTabState extends State<_DirectorioCasasTab> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _viviendas = [];
  List<dynamic> _viviendasFiltradas = [];
  final TextEditingController _busquedaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarViviendas();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarViviendas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final baseUrl = dotenv.env['API_BASE_URL_VIVIENDAS'] ?? 'https://viviendas-api.onrender.com';
      final token = await widget.controller.getValidAccessToken();
      final res = await widget.controller.httpClient.get(
        Uri.parse('$baseUrl/api/Viviendas'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          list = decoded['items'] as List<dynamic>? ??
              decoded['data'] as List<dynamic>? ??
              [];
        }
        // Ordenar por número de casa
        list.sort((a, b) {
          final na = int.tryParse(a['numeroCasa']?.toString() ?? '') ?? 0;
          final nb = int.tryParse(b['numeroCasa']?.toString() ?? '') ?? 0;
          return na.compareTo(nb);
        });
        if (mounted) {
          setState(() {
            _viviendas = list;
            _viviendasFiltradas = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Error al cargar el directorio (${res.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión';
          _isLoading = false;
        });
      }
    }
  }

  void _filtrar(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _viviendasFiltradas = _viviendas;
      } else {
        _viviendasFiltradas = _viviendas.where((v) {
          final num = (v['numeroCasa'] ?? '').toString().toLowerCase();
          final tipo = (v['tipo'] ?? '').toString().toLowerCase();
          return num.contains(query) || tipo.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFFD97706),
        onRefresh: _cargarViviendas,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _cargarViviendas,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Header con buscador
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Banner Hero
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF334155), Color(0xFF1E293B)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1E293B).withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.home_work_rounded, color: Colors.white, size: 32),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Directorio de Casas',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            '${_viviendas.length} viviendas registradas',
                                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Buscador
                              TextField(
                                controller: _busquedaCtrl,
                                onChanged: _filtrar,
                                decoration: InputDecoration(
                                  hintText: 'Buscar por número o tipo...',
                                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                                  suffixIcon: _busquedaCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 20),
                                          onPressed: () {
                                            _busquedaCtrl.clear();
                                            _filtrar('');
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),

                      // Lista de viviendas
                      if (_viviendasFiltradas.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'No se encontraron viviendas',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final v = _viviendasFiltradas[index];
                                final numCasa = (v['numeroCasa'] ?? 'S/N').toString();
                                final tipo = (v['tipo'] != null && (v['tipo'] as String).isNotEmpty)
                                    ? v['tipo'] as String
                                    : 'Vivienda Residencial';
                                final asignada = v['asignada'] as bool? ?? false;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x04000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.home_rounded,
                                          color: Color(0xFF64748B),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Casa #$numCasa',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              tipo,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: asignada ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: asignada ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Text(
                                          asignada ? 'Ocupada' : 'Libre',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: asignada ? const Color(0xFF047857) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              childCount: _viviendasFiltradas.length,
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 2 – AVISOS DEL CONDOMINIO PARA VIGILANTE (Solo lectura)
// ─────────────────────────────────────────────────────────────
class _AvisosCasetaTab extends StatefulWidget {
  final AppController controller;
  const _AvisosCasetaTab({required this.controller});

  @override
  State<_AvisosCasetaTab> createState() => _AvisosCasetaTabState();
}

class _AvisosCasetaTabState extends State<_AvisosCasetaTab> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  List<dynamic> _avisos = [];
  int _urgentesCount = 0;

  @override
  void initState() {
    super.initState();
    _cargarAvisos(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _cargarAvisos();
    }
  }

  Future<void> _cargarAvisos({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    if (!_hasMore || (_isFetchingMore && !refresh)) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
      } else {
        _isFetchingMore = true;
      }
    });

    try {
      final service = AvisosService(widget.controller);
      final res = await service.getAvisosVigentes(page: _currentPage, pageSize: 15);

      if (mounted) {
        if (res != null) {
          final rawItems = res['items'] as List<dynamic>? ?? [];
          final items = rawItems.where((a) {
            return a['vigente'] == true || a['activo'] == true || a['estado'] == 'activo';
          }).toList();

          int urgentes = 0;
          for (final a in items) {
            final p = (a['prioridad'] ?? '').toString().toLowerCase();
            if (p == 'urgente') urgentes++;
          }

          setState(() {
            if (refresh) {
              _avisos = items;
              _urgentesCount = urgentes;
            } else {
              _avisos.addAll(items);
            }
            _currentPage++;
            _hasMore = items.length == 15;
            _isLoading = false;
            _isFetchingMore = false;
          });
        } else {
          setState(() {
            if (refresh) _avisos = [];
            _isLoading = false;
            _isFetchingMore = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Color _colorPrioridad(String? prioridad) {
    switch ((prioridad ?? '').toLowerCase()) {
      case 'urgente':
        return const Color(0xFFE11D48);
      case 'mantenimiento':
        return const Color(0xFFD97706);
      case 'evento':
        return const Color(0xFF4F46E5);
      case 'informativo':
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _bgPrioridad(String? prioridad) {
    switch ((prioridad ?? '').toLowerCase()) {
      case 'urgente':
        return const Color(0xFFFFF1F2);
      case 'mantenimiento':
        return const Color(0xFFFEF3C7);
      case 'evento':
        return const Color(0xFFEEF2FF);
      case 'informativo':
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  IconData _iconoPrioridad(String? prioridad) {
    switch ((prioridad ?? '').toLowerCase()) {
      case 'urgente':
        return Icons.warning_amber_rounded;
      case 'mantenimiento':
        return Icons.build_outlined;
      case 'evento':
        return Icons.event_outlined;
      case 'informativo':
      default:
        return Icons.info_outline;
    }
  }

  String _tiempoRestante(dynamic aviso) {
    final finStr = aviso['fecha_fin'] ?? aviso['fechaFin'] ?? aviso['vigencia_hasta'];
    if (finStr == null) return 'Vigente';
    try {
      final fin = DateTime.parse(finStr.toString()).toLocal();
      final diff = fin.difference(DateTime.now());
      if (diff.isNegative) return 'Vencido';
      if (diff.inDays > 0) return 'Vence en ${diff.inDays}d';
      if (diff.inHours > 0) return 'Vence en ${diff.inHours}h';
      return 'Vence pronto';
    } catch (_) {
      return 'Vigente';
    }
  }

  void _mostrarDetalleAviso(BuildContext context, dynamic aviso) {
    final titulo = (aviso['titulo'] ?? 'Aviso').toString();
    final contenido = (aviso['contenido'] ?? '').toString();
    final prioridad = (aviso['prioridad'] ?? 'informativo').toString();
    final color = _colorPrioridad(prioridad);
    final bg = _bgPrioridad(prioridad);
    final icono = _iconoPrioridad(prioridad);
    final tiempo = _tiempoRestante(aviso);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(icono, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              prioridad.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tiempo,
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Text(
                      contenido,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFFD97706),
        onRefresh: () => _cargarAvisos(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Banner de avisos del condominio para caseta
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFFFBEB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Avisos del Condominio',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Comunicados y novedades oficiales para el personal de caseta.',
                            style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Text(
                                  '${_avisos.length} vigente${_avisos.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                              if (_urgentesCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_urgentesCount urgente${_urgentesCount == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Estado de carga inicial
            if (_isLoading && _avisos.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFD97706)),
                ),
              )
            // Estado vacío
            else if (_avisos.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 56,
                          color: Color(0xFFCBD5E1),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No hay avisos vigentes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Los comunicados que publique la administración aparecerán aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            // Lista de avisos
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _avisos.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(color: Color(0xFFD97706), strokeWidth: 2),
                          ),
                        );
                      }

                      final a = _avisos[index];
                      final titulo = (a['titulo'] ?? '').toString();
                      final contenido = (a['contenido'] ?? '').toString();
                      final prioridad = (a['prioridad'] ?? 'informativo').toString();
                      final color = _colorPrioridad(prioridad);
                      final bg = _bgPrioridad(prioridad);
                      final icono = _iconoPrioridad(prioridad);
                      final tiempo = _tiempoRestante(a);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x04000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _mostrarDetalleAviso(context, a),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: color, width: 4),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: bg,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(icono, size: 12, color: color),
                                            const SizedBox(width: 4),
                                            Text(
                                              prioridad.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        tiempo,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    titulo,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    contenido,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _avisos.length + (_hasMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
