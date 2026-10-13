import 'package:flutter/material.dart';
import '../Models/reserva_model.dart';
import '../Services/app_controller.dart';
import '../Services/reservas_service.dart';

class CalendarioReservasVigilanteModal extends StatefulWidget {
  final AppController controller;

  const CalendarioReservasVigilanteModal({
    super.key,
    required this.controller,
  });

  @override
  State<CalendarioReservasVigilanteModal> createState() =>
      _CalendarioReservasVigilanteModalState();
}

class _CalendarioReservasVigilanteModalState
    extends State<CalendarioReservasVigilanteModal> {
  late final ReservasService _reservasService;
  List<ReservaModel> _eventos = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _reservasService = ReservasService(widget.controller);
    _cargarCalendario();
  }

  Future<void> _cargarCalendario() async {
    setState(() => _isLoading = true);
    // Cargar para el día seleccionado (00:00:00 a 23:59:59)
    final from = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    final to = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    final res = await _reservasService.getCalendario(from: from, to: to, pageSize: 100);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _eventos = res['items'] as List<ReservaModel>;
        }
      });
    }
  }

  Future<void> _cambiarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
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
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    'Vista restringida para control de caseta. Muestra horarios ocupados sin datos personales.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Selector de fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fecha: ${_formatearFecha(_selectedDate)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              OutlinedButton.icon(
                onPressed: _cambiarFecha,
                icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                label: const Text('Cambiar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFFDE68A)),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _eventos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_available_rounded, size: 48, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 10),
                            Text(
                              'Sin eventos ni bloqueos programados para este día.',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _eventos.length,
                        itemBuilder: (ctx, idx) {
                          final evento = _eventos[idx];
                          final esMantenimiento = evento.tipo?.toLowerCase() == 'mantenimiento' ||
                              evento.estado.contains('CANCELADA');
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
                                    color: esMantenimiento
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    esMantenimiento
                                        ? Icons.build_circle_rounded
                                        : Icons.access_time_filled_rounded,
                                    color: esMantenimiento
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
                                      Text(
                                        evento.areaNombre,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
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
                                      if (esMantenimiento) ...[
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Tipo: Bloqueo de mantenimiento',
                                          style: TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
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
}
