import 'package:flutter/material.dart';
import '../Models/area_comun_model.dart';
import '../Services/app_controller.dart';
import '../Services/reservas_service.dart';
import '../Utils/error_handler.dart';

class SolicitarReservaModal extends StatefulWidget {
  final AppController controller;
  final AreaComunModel? preselectedArea;

  const SolicitarReservaModal({
    super.key,
    required this.controller,
    this.preselectedArea,
  });

  @override
  State<SolicitarReservaModal> createState() => _SolicitarReservaModalState();
}

class _SolicitarReservaModalState extends State<SolicitarReservaModal> {
  late final ReservasService _reservasService;
  List<AreaComunModel> _areas = [];
  AreaComunModel? _selectedArea;
  bool _isLoadingAreas = true;
  bool _isSubmitting = false;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _reservasService = ReservasService(widget.controller);
    _selectedArea = widget.preselectedArea;
    _cargarAreas();
  }

  Future<void> _cargarAreas() async {
    try {
      final res = await _reservasService.getAreas(soloActivas: true, pageSize: 50);
      if (mounted) {
        setState(() {
          _isLoadingAreas = false;
          if (res['success'] == true) {
            _areas = res['items'] as List<AreaComunModel>;
            if (_selectedArea == null && _areas.isNotEmpty) {
              _selectedArea = _areas.first;
            } else if (_selectedArea != null) {
              final found = _areas.where((a) => a.id == _selectedArea!.id);
              if (found.isNotEmpty) {
                _selectedArea = found.first;
              }
            }
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudieron cargar las áreas comunes.', success: false);
          }
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'SolicitarReservaModal._cargarAreas');
      if (mounted) {
        setState(() => _isLoadingAreas = false);
        widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
      }
    }
  }

  TimeOfDay? _parseTime(String raw) {
    try {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'SolicitarReservaModal._parseTime');
    }
    return null;
  }

  int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _seleccionarFecha() async {
    final now = DateTime.now();
    // RE007: Ventana de 7 a 30 días de anticipación
    final firstAllowedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
    final lastAllowedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null &&
              _selectedDate!.isAfter(firstAllowedDate) &&
              _selectedDate!.isBefore(lastAllowedDate)
          ? _selectedDate!
          : firstAllowedDate,
      firstDate: firstAllowedDate,
      lastDate: lastAllowedDate,
      helpText: 'SELECCIONA LA FECHA (7 A 30 DÍAS DE ANTICIPACIÓN)',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _seleccionarHoraInicio() async {
    final initial = _startTime ?? const TimeOfDay(hour: 10, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'HORA DE INICIO',
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Si la hora de fin es menor o igual, sugerir hora fin 2 horas después
        if (_endTime == null || _timeToMinutes(_endTime!) <= _timeToMinutes(picked)) {
          final newHour = (picked.hour + 2) % 24;
          _endTime = TimeOfDay(hour: newHour, minute: picked.minute);
        }
      });
    }
  }

  Future<void> _seleccionarHoraFin() async {
    final initial = _endTime ?? const TimeOfDay(hour: 12, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'HORA DE FINALIZACIÓN',
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  String? _validarFormulario() {
    if (_selectedArea == null) {
      return 'Selecciona un área común.';
    }
    if (_selectedDate == null) {
      return 'Selecciona la fecha de la reserva.';
    }
    if (_startTime == null || _endTime == null) {
      return 'Selecciona el horario de inicio y fin.';
    }

    final startMin = _timeToMinutes(_startTime!);
    final endMin = _timeToMinutes(_endTime!);

    if (endMin <= startMin) {
      return 'La hora de fin debe ser posterior a la de inicio.';
    }

    final duracionMin = endMin - startMin;
    // RE006: Mínimo 30 minutos y máximo 12 horas (720 min)
    if (duracionMin < 30) {
      return 'La reserva debe durar como mínimo 30 minutos.';
    }
    if (duracionMin > 720) {
      return 'La reserva no puede exceder las 12 horas.';
    }

    // RE005: Horario de operación del área común
    final apertura = _parseTime(_selectedArea!.horaApertura);
    final cierre = _parseTime(_selectedArea!.horaCierre);

    if (apertura != null && cierre != null) {
      final aperturaMin = _timeToMinutes(apertura);
      final cierreMin = _timeToMinutes(cierre);

      if (startMin < aperturaMin || endMin > cierreMin) {
        return 'El horario solicitado está fuera del horario de operación (${_selectedArea!.horarioFormateado}).';
      }
    }

    return null;
  }

  Future<void> _enviarSolicitud() async {
    final error = _validarFormulario();
    if (error != null) {
      widget.controller.notifyToast(error, success: false);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final inicioDt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      final finDt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      final res = await _reservasService.solicitarReserva(
        areaId: _selectedArea!.id,
        inicio: inicioDt,
        fin: finDt,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res['success'] == true) {
          widget.controller.notifyToast(
            '¡Solicitud de reserva enviada exitosamente!',
            success: true,
          );
          Navigator.pop(context, true);
        } else {
          widget.controller.notifyToast(
            res['error'] ?? 'No se pudo crear la reserva.',
            success: false,
          );
        }
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'SolicitarReservaModal._enviarSolicitud');
      if (mounted) {
        setState(() => _isSubmitting = false);
        widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = (widget.controller.currentUser?.rol ??
            widget.controller.currentUser?.rolNombre ??
            '')
        .toLowerCase();
    final isSubusuario = role.contains('subusuario') || role.contains('inquilino');

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_available_rounded, color: Color(0xFF111C99), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Solicitar Reserva',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            if (isSubusuario)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Como subusuario o inquilino, tu solicitud requerirá primero el visto bueno del Titular de la vivienda antes de pasar a administración.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),

            // Selector de Área Común
            const Text(
              'Área Común',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            if (_isLoadingAreas)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else if (_areas.isEmpty)
              const Text('No hay áreas comunes activas disponibles.', style: TextStyle(color: Colors.red))
            else
              DropdownButtonFormField<AreaComunModel>(
                initialValue: _selectedArea,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _areas.map((area) {
                  return DropdownMenuItem<AreaComunModel>(
                    value: area,
                    child: Text('${area.nombre} (${area.horarioFormateado})'),
                  );
                }).toList(),
                onChanged: (area) {
                  setState(() => _selectedArea = area);
                },
              ),

            const SizedBox(height: 16),

            // Selector de Fecha (Anticipación 7-30 días)
            const Text(
              'Fecha del Evento',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _seleccionarFecha,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF111C99)),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? 'Seleccionar fecha (7 a 30 días de anticipación)'
                          : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedDate == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Selector de Horas
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hora de Inicio',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _seleccionarHoraInicio,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF111C99)),
                              const SizedBox(width: 8),
                              Text(
                                _startTime == null
                                    ? '--:--'
                                    : '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hora de Fin',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _seleccionarHoraFin,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_filled_rounded, size: 18, color: Color(0xFF111C99)),
                              const SizedBox(width: 8),
                              Text(
                                _endTime == null
                                    ? '--:--'
                                    : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Nota informativa sobre confirmación obligatoria
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 6),
                      Text(
                        'Políticas del Condominio',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Máximo 1 reserva por día por vivienda.\n'
                    '• Cuando la solicitud sea aprobada, deberás confirmarla entre 7 días y 72 horas antes del evento.\n'
                    '• Duración permitida: 30 minutos a 12 horas.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isSubmitting ? null : _enviarSolicitud,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111C99),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Enviar Solicitud',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
