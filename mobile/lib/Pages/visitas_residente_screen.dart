import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Models/visita_model.dart';
import '../Services/app_controller.dart';
import '../Services/visitas_service.dart';
import '../Widgets/programar_visita_modal.dart';

class VisitasResidenteScreen extends StatefulWidget {
  final AppController controller;
  final List<Map<String, dynamic>> misViviendas;

  const VisitasResidenteScreen({
    super.key,
    required this.controller,
    required this.misViviendas,
  });

  @override
  State<VisitasResidenteScreen> createState() => _VisitasResidenteScreenState();
}

class _VisitasResidenteScreenState extends State<VisitasResidenteScreen> {
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _filtroEstado; // null para todas, o 'programada', 'en_curso', 'finalizada', etc.
  List<VisitaModel> _visitas = [];
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String?>> _filtros = [
    {'label': 'Todas', 'value': null},
    {'label': 'Programadas', 'value': 'programada'},
    {'label': 'En curso', 'value': 'en_curso'},
    {'label': 'Finalizadas', 'value': 'finalizada'},
    {'label': 'Canceladas', 'value': 'cancelada'},
    {'label': 'Expiradas', 'value': 'expirada'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarVisitas(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
      final res = await service.getMisVisitas(
        page: _currentPage,
        pageSize: 10,
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
            _hasMore = items.length == 10;
            _isLoading = false;
            _isFetchingMore = false;
          });
        } else {
          setState(() {
            if (refresh) _visitas = [];
            _isLoading = false;
            _isFetchingMore = false;
          });
          if (res['error'] != null && refresh) {
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

  Future<void> _abrirCrearVisita() async {
    if (widget.misViviendas.isEmpty) {
      widget.controller.notifyToast(
        'Necesitas tener una vivienda asignada para crear visitas.',
        success: false,
      );
      return;
    }

    final creada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProgramarVisitaModal(
        controller: widget.controller,
        misViviendas: widget.misViviendas,
      ),
    );

    if (creada == true) {
      _cargarVisitas(refresh: true);
    }
  }

  Future<void> _abrirEditarVisita(VisitaModel visita) async {
    final editada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProgramarVisitaModal(
        controller: widget.controller,
        misViviendas: widget.misViviendas,
        visitaParaEditar: visita,
      ),
    );

    if (editada == true) {
      _cargarVisitas(refresh: true);
    }
  }

  Future<void> _cancelarVisita(VisitaModel visita) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Visita'),
        content: Text(
          '¿Deseas cancelar el pase de visita de ${visita.nombreCompletoVisitante}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar Pase'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final service = VisitasService(widget.controller);
    final res = await service.cancelarVisita(visita.id);
    if (mounted) {
      if (res['success'] == true) {
        widget.controller.notifyToast('Visita cancelada exitosamente', success: true);
        _cargarVisitas(refresh: true);
      } else {
        widget.controller.notifyToast(res['error'] ?? 'No se pudo cancelar la visita', success: false);
      }
    }
  }

  void _mostrarDetalleVisita(VisitaModel v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildDetalleModal(v),
    );
  }

  Widget _buildDetalleModal(VisitaModel v) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    v.nombreCompletoVisitante,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                _buildEstadoBadge(v.estado),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Casa #${v.numeroCasa} · Motivo: ${v.motivo.toUpperCase()}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            // Tarjeta con Código de Acceso
            if (v.codigo != null && v.codigo!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'CÓDIGO DE ACCESO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      v.codigo!,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: v.codigo!));
                        widget.controller.notifyToast('Código copiado al portapapeles', success: true);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copiar código'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4338CA),
                        side: const BorderSide(color: Color(0xFF818CF8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Detalles clave
            _buildInfoRow('Llegada esperada', _formatearFecha(v.fechaLlegadaEsperada)),
            _buildInfoRow('Vigencia hasta', _formatearFecha(v.vigenciaHasta)),
            if (v.telefonoVisitante != null) _buildInfoRow('Teléfono', v.telefonoVisitante!),
            if (v.vehiculoPlacas != null) _buildInfoRow('Vehículo / Placas', v.vehiculoPlacas!),
            _buildInfoRow('Acompañantes', '${v.numAcompanantes} personas'),
            if (v.horaEntrada != null) _buildInfoRow('Hora de entrada', _formatearFecha(v.horaEntrada!)),
            if (v.horaSalida != null) _buildInfoRow('Hora de salida', _formatearFecha(v.horaSalida!)),
            if (v.notas != null && v.notas!.isNotEmpty) _buildInfoRow('Notas', v.notas!),

            const SizedBox(height: 24),
            Row(
              children: [
                if (v.isProgramada) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _abrirEditarVisita(v);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _cancelarVisita(v);
                      },
                      icon: const Icon(Icons.cancel_rounded, size: 16),
                      label: const Text('Cancelar'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCrearVisita,
        backgroundColor: const Color(0xFF111C99),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Nueva Visita',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF111C99),
        onRefresh: () => _cargarVisitas(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Filtros horizontales
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: _filtros.map((f) {
                    final isSelected = _filtroEstado == f['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f['label']!),
                        selected: isSelected,
                        selectedColor: const Color(0xFF111C99),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF111C99) : const Color(0xFFCBD5E1),
                        ),
                        onSelected: (val) {
                          setState(() {
                            _filtroEstado = f['value'];
                          });
                          _cargarVisitas(refresh: true);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Contenido lista
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
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            size: 48,
                            color: Color(0xFF111C99),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay visitas registradas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Crea un pase de visita para permitir el acceso rápido de familiares, amigos o proveedores.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _abrirCrearVisita,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Programar Visita'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF111C99),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
                        child: InkWell(
                          onTap: () => _mostrarDetalleVisita(v),
                          borderRadius: BorderRadius.circular(16),
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
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: const Color(0xFFEFF6FF),
                                            child: Text(
                                              v.nombreVisitante.isNotEmpty
                                                  ? v.nombreVisitante[0].toUpperCase()
                                                  : 'V',
                                              style: const TextStyle(
                                                color: Color(0xFF111C99),
                                                fontWeight: FontWeight.bold,
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
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Casa #${v.numeroCasa} · ${v.motivo.toUpperCase()}',
                                                  style: const TextStyle(
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
                                    _buildEstadoBadge(v.estado),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: Color(0xFFF1F5F9), height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Llegada: ${_formatearFecha(v.fechaLlegadaEsperada)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (v.codigo != null && v.codigo!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          v.codigo!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
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
