import 'package:flutter/material.dart';
import '../Models/visita_model.dart';
import '../Services/app_controller.dart';
import '../Services/visitas_service.dart';
import 'perfil_screen.dart';

class VigilanteDashboardScreen extends StatefulWidget {
  final AppController controller;

  const VigilanteDashboardScreen({super.key, required this.controller});

  @override
  State<VigilanteDashboardScreen> createState() => _VigilanteDashboardScreenState();
}

class _VigilanteDashboardScreenState extends State<VigilanteDashboardScreen> {
  final _searchController = TextEditingController();
  final _codigoModalController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _busquedaActual = '';
  List<VisitaModel> _visitas = [];

  // ID de la visita que actualmente está procesando entrada o salida
  String? _processingVisitaId;

  @override
  void initState() {
    super.initState();
    _cargarVisitas(refresh: true);
    _scrollController.addListener(_onScroll);
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
          if (refresh && res['error'] != null) {
            widget.controller.notifyToast(res['error'], success: false);
          }
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
        title: const Text('Registrar Entrada'),
        content: Text(
          '¿Confirmar ingreso del visitante ${visita.nombreCompletoVisitante} para la casa #${visita.numeroCasa}?',
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
        widget.controller.notifyToast(
          '¡Entrada registrada! Se notificó al residente.',
          success: true,
        );
        _cargarVisitas(refresh: true);
      } else {
        widget.controller.notifyToast(
          res['error'] ?? 'Error al registrar entrada',
          success: false,
        );
      }
    }
  }

  Future<void> _registrarSalida(VisitaModel visita) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Salida'),
        content: Text(
          '¿Confirmar salida del visitante ${visita.nombreCompletoVisitante}?',
        ),
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
        widget.controller.notifyToast(
          res['error'] ?? 'Error al registrar salida',
          success: false,
        );
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
                  Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF111C99)),
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
                            Navigator.pop(dialogCtx);
                            _mostrarResultadoValidacion(visita);
                          } else {
                            setModalState(() {
                              errorLocal = res['error'] ?? 'Código inválido o expirado';
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111C99),
                  ),
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
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pase Válido y Vigente',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                            ),
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
                if (v.notas != null && v.notas!.isNotEmpty)
                  _buildInfoRow('Notas', v.notas!),
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
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
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
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final nombre = user?.nombre ?? 'Vigilante';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirValidarCodigoDialog,
        backgroundColor: const Color(0xFF111C99),
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text(
          'Validar Código',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF111C99),
        onRefresh: () => _cargarVisitas(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Banner de Caseta y Buscador
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
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
                  ],
                ),
              ),
            ),

            // Lista de Visitas de Hoy
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF111C99)),
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
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 48,
                            color: Color(0xFF111C99),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _visitas.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Casa #${v.numeroCasa}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF111C99),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        v.motivo.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _buildEstadoBadge(v.estado),
                                ],
                              ),
                              const SizedBox(height: 12),
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
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 12),

                              // Botones de acción de Vigilancia
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
