import 'package:flutter/material.dart';
import '../Models/visita_model.dart';
import '../Services/app_controller.dart';
import '../Services/visitas_service.dart';
import '../Utils/error_handler.dart';
import '../Utils/haptic_helper.dart';

class VisitasAdminScreen extends StatefulWidget {
  final AppController controller;

  const VisitasAdminScreen({super.key, required this.controller});

  @override
  State<VisitasAdminScreen> createState() => _VisitasAdminScreenState();
}

class _VisitasAdminScreenState extends State<VisitasAdminScreen> {
  final ScrollController _scrollController = ScrollController();
  final _viviendaFilterController = TextEditingController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalCount = 0;

  String? _filtroEstado;
  DateTime? _desde;
  DateTime? _hasta;
  int? _viviendaId;

  List<VisitaModel> _visitas = [];

  final List<Map<String, String?>> _filtrosEstado = [
    {'label': 'Todos', 'value': null},
    {'label': 'Programadas', 'value': 'programada'},
    {'label': 'En curso', 'value': 'en_curso'},
    {'label': 'Finalizadas', 'value': 'finalizada'},
    {'label': 'Canceladas', 'value': 'cancelada'},
    {'label': 'Expiradas', 'value': 'expirada'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarHistorico(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _viviendaFilterController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _cargarHistorico();
    }
  }

  Future<void> _cargarHistorico({bool refresh = false}) async {
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
      final res = await service.getHistorico(
        page: _currentPage,
        pageSize: 20,
        desde: _desde,
        hasta: _hasta,
        viviendaId: _viviendaId,
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
            _totalCount = res['totalCount'] ?? items.length;
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
        if (refresh) {
          widget.controller.notifyToast(
            ErrorHandler.parseException(
              e,
              defaultMessage: 'Error al consultar el historial de visitas.',
            ),
            success: false,
          );
        }
      }
    }
  }

  Future<void> _seleccionarRangoFechas() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: (_desde != null && _hasta != null)
          ? DateTimeRange(start: _desde!, end: _hasta!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF111C99),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _desde = picked.start;
        _hasta = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _cargarHistorico(refresh: true);
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroEstado = null;
      _desde = null;
      _hasta = null;
      _viviendaId = null;
      _viviendaFilterController.clear();
    });
    _cargarHistorico(refresh: true);
  }

  void _mostrarDetalle(VisitaModel v) {
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        v.nombreCompletoVisitante,
                        style: const TextStyle(
                          fontSize: 18,
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
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _buildInfoRow('ID Visita', v.id),
                if (v.creadoPorNombre != null) _buildInfoRow('Creado por', v.creadoPorNombre!),
                _buildInfoRow('Llegada programada', _formatearFecha(v.fechaLlegadaEsperada)),
                _buildInfoRow('Vigencia hasta', _formatearFecha(v.vigenciaHasta)),
                if (v.horaEntrada != null) _buildInfoRow('Hora entrada oficial', _formatearFecha(v.horaEntrada!)),
                if (v.horaSalida != null) _buildInfoRow('Hora salida oficial', _formatearFecha(v.horaSalida!)),
                if (v.vehiculoPlacas != null) _buildInfoRow('Vehículo / Placas', v.vehiculoPlacas!),
                if (v.telefonoVisitante != null) _buildInfoRow('Teléfono visitante', v.telefonoVisitante!),
                _buildInfoRow('Acompañantes', '${v.numAcompanantes} personas'),
                if (v.notas != null && v.notas!.isNotEmpty) _buildInfoRow('Notas', v.notas!),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
                  child: const Text('Cerrar'),
                ),
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
    final hasActiveFilter = _filtroEstado != null || _desde != null || _viviendaId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Histórico de Visitas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            Text(
              '$_totalCount registros encontrados',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded, color: Color(0xFF111C99)),
            tooltip: 'Filtrar por fechas',
            onPressed: () {
              HapticHelper.light();
              _seleccionarRangoFechas();
            },
          ),
          if (hasActiveFilter)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded, color: Color(0xFFDC2626)),
              tooltip: 'Limpiar filtros',
              onPressed: () {
                HapticHelper.light();
                _limpiarFiltros();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF111C99),
        onRefresh: () => _cargarHistorico(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Filtros de Estado
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: _filtrosEstado.map((f) {
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
                              HapticHelper.selection();
                              setState(() => _filtroEstado = f['value']);
                              _cargarHistorico(refresh: true);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_desde != null && _hasta != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF111C99)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rango: ${_desde!.day}/${_desde!.month}/${_desde!.year} - ${_hasta!.day}/${_hasta!.month}/${_hasta!.year}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _desde = null;
                                  _hasta = null;
                                });
                                _cargarHistorico(refresh: true);
                              },
                              child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF1E3A8A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history_toggle_off_rounded,
                            size: 48,
                            color: Color(0xFF111C99),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay registros históricos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'No se encontraron visitas con los filtros seleccionados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                          onTap: () {
                            HapticHelper.light();
                            _mostrarDetalle(v);
                          },
                          borderRadius: BorderRadius.circular(16),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF2FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Casa #${v.numeroCasa}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF111C99),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          v.motivo.toUpperCase(),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    _buildEstadoBadge(v.estado),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  v.nombreCompletoVisitante,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.event_note_rounded, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Esperada: ${_formatearFecha(v.fechaLlegadaEsperada)}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    if (v.horaEntrada != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.login_rounded, size: 14, color: Color(0xFF059669)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Entrada: ${_formatearFecha(v.horaEntrada!)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF059669),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (v.horaSalida != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.logout_rounded, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Salida: ${_formatearFecha(v.horaSalida!)}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ],
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
