import 'package:flutter/material.dart';
import '../Models/area_comun_model.dart';
import '../Models/reserva_model.dart';
import '../Services/app_controller.dart';
import '../Services/reservas_service.dart';
import '../Utils/error_handler.dart';

enum RangoCaseta { hoy, manana, proximos3Dias, semana, personalizado }

class CalendarioReservasVigilanteModal extends StatefulWidget {
  final AppController controller;
  final bool isEmbedded;

  const CalendarioReservasVigilanteModal({
    super.key,
    required this.controller,
    this.isEmbedded = false,
  });

  @override
  State<CalendarioReservasVigilanteModal> createState() =>
      _CalendarioReservasVigilanteModalState();
}

class _CalendarioReservasVigilanteModalState
    extends State<CalendarioReservasVigilanteModal> {
  late final ReservasService _reservasService;
  List<ReservaModel> _eventos = [];
  List<AreaComunModel> _areas = [];
  String? _selectedAreaId;
  RangoCaseta _rango = RangoCaseta.hoy;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _reservasService = ReservasService(widget.controller);
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarAreas(),
      _cargarCalendario(),
    ]);
  }

  Future<void> _cargarAreas() async {
    try {
      final res = await _reservasService.getAreas(soloActivas: true, pageSize: 50);
      if (mounted && res['success'] == true) {
        setState(() {
          _areas = res['items'] as List<AreaComunModel>;
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'CalendarioReservasVigilanteModal._cargarAreas');
    }
  }

  (DateTime, DateTime) _calcularRango() {
    final ahora = DateTime.now();
    switch (_rango) {
      case RangoCaseta.hoy:
        final from = DateTime(ahora.year, ahora.month, ahora.day, 0, 0, 0);
        final to = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        return (from, to);

      case RangoCaseta.manana:
        final manana = ahora.add(const Duration(days: 1));
        final from = DateTime(manana.year, manana.month, manana.day, 0, 0, 0);
        final to = DateTime(manana.year, manana.month, manana.day, 23, 59, 59);
        return (from, to);

      case RangoCaseta.proximos3Dias:
        final from = DateTime(ahora.year, ahora.month, ahora.day, 0, 0, 0);
        final fin = ahora.add(const Duration(days: 3));
        final to = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);
        return (from, to);

      case RangoCaseta.semana:
        final from = DateTime(ahora.year, ahora.month, ahora.day, 0, 0, 0);
        final fin = ahora.add(const Duration(days: 7));
        final to = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);
        return (from, to);

      case RangoCaseta.personalizado:
        final from = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
        final to = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
        return (from, to);
    }
  }

  Future<void> _cargarCalendario() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (from, to) = _calcularRango();

    try {
      final res = await _reservasService.getCalendario(
        from: from,
        to: to,
        areaId: _selectedAreaId,
        pageSize: 100,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (res['success'] == true) {
            _eventos = res['items'] as List<ReservaModel>;
          } else {
            _errorMessage = res['error'] ?? 'No fue posible cargar el calendario.';
          }
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'CalendarioReservasVigilanteModal._cargarCalendario');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorHandler.parseException(e);
        });
      }
    }
  }

  Future<void> _cambiarFechaPersonalizada() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _rango = RangoCaseta.personalizado;
      });
      _cargarCalendario();
    }
  }

  String _formatearHora(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatearFecha(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.isEmbedded ? null : MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.all(widget.isEmbedded ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: widget.isEmbedded
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: Color(0xFFD97706), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Uso de Áreas Comunes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              if (widget.isEmbedded)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFFD97706)),
                  tooltip: 'Actualizar agenda',
                  onPressed: _cargarTodo,
                )
              else
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Banner de modo restringido de vigilancia
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.security_rounded, size: 16, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vista restringida para control de caseta. Muestra horarios ocupados y bloqueos de áreas.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Selector de Áreas (Todas o específica)
          if (_areas.isNotEmpty) ...[
            DropdownButtonFormField<String?>(
              initialValue: _selectedAreaId,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                labelText: 'Filtrar por Área Común',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas las áreas comunes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ..._areas.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.nombre))),
              ],
              onChanged: (val) {
                setState(() => _selectedAreaId = val);
                _cargarCalendario();
              },
            ),
            const SizedBox(height: 10),
          ],
          // Selector de Rango Rápido
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRangoChip(RangoCaseta.hoy, 'Hoy'),
                const SizedBox(width: 6),
                _buildRangoChip(RangoCaseta.manana, 'Mañana'),
                const SizedBox(width: 6),
                _buildRangoChip(RangoCaseta.proximos3Dias, 'Próx. 3 días'),
                const SizedBox(width: 6),
                _buildRangoChip(RangoCaseta.semana, 'Esta semana'),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFFD97706)),
                  label: Text(
                    _rango == RangoCaseta.personalizado ? _formatearFecha(_selectedDate) : 'Fecha',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _rango == RangoCaseta.personalizado ? FontWeight.bold : FontWeight.normal,
                      color: _rango == RangoCaseta.personalizado ? const Color(0xFFD97706) : const Color(0xFF334155),
                    ),
                  ),
                  onPressed: _cambiarFechaPersonalizada,
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _eventos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _cargarCalendario,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _eventos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.event_available_rounded, size: 48, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 10),
                                Text(
                                  'Sin reservas ni bloqueos en este periodo.',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _eventos.length,
                            itemBuilder: (ctx, idx) {
                              final evento = _eventos[idx];
                              final esBloqueo = evento.tipo?.toUpperCase() == 'BLOQUEO';
                              final ahora = DateTime.now();
                              final yaPaso = evento.fin.isBefore(ahora);
                              final enCurso = evento.inicio.isBefore(ahora) && evento.fin.isAfter(ahora);

                              final badgeTexto = esBloqueo
                                  ? 'Bloqueo'
                                  : enCurso
                                      ? 'En curso'
                                      : yaPaso
                                          ? 'Terminó'
                                          : 'Próxima';

                              final badgeColor = esBloqueo
                                  ? const Color(0xFF334155)
                                  : enCurso
                                      ? const Color(0xFF047857)
                                      : yaPaso
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF111C99);

                              final badgeBg = esBloqueo
                                  ? const Color(0xFFF1F5F9)
                                  : enCurso
                                      ? const Color(0xFFECFDF5)
                                      : yaPaso
                                          ? const Color(0xFFF1F5F9)
                                          : const Color(0xFFEFF6FF);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: esBloqueo
                                        ? const Color(0xFFCBD5E1)
                                        : yaPaso
                                            ? const Color(0xFFE2E8F0)
                                            : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: esBloqueo
                                            ? const Color(0xFFFEF2F2)
                                            : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        esBloqueo
                                            ? Icons.build_circle_rounded
                                            : Icons.access_time_filled_rounded,
                                        color: esBloqueo
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF111C99),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  evento.areaNombre,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: badgeBg,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  badgeTexto,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: badgeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Horario ocupado: ${_formatearHora(evento.inicio)} - ${_formatearHora(evento.fin)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                          if (esBloqueo) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              'Área bloqueada${evento.motivo != null && evento.motivo!.isNotEmpty ? ': ${evento.motivo!}' : ''}',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626)),
                                            ),
                                          ] else ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              'Casa #${evento.numeroCasa ?? 'S/N'}${evento.solicitanteCompleto.isNotEmpty ? ' · ${evento.solicitanteCompleto}' : ''}',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangoChip(RangoCaseta rango, String etiqueta) {
    final selected = _rango == rango;
    return ChoiceChip(
      label: Text(etiqueta),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _rango = rango);
          _cargarCalendario();
        }
      },
      selectedColor: const Color(0xFFFEF3C7),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? const Color(0xFFB45309) : const Color(0xFF334155),
      ),
    );
  }
}
