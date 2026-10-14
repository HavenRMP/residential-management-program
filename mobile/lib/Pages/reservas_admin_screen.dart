import 'package:flutter/material.dart';
import '../Models/area_comun_model.dart';
import '../Models/reserva_model.dart';
import '../Services/app_controller.dart';
import '../Services/reservas_service.dart';
import '../Utils/error_handler.dart';

class ReservasAdminScreen extends StatefulWidget {
  final AppController controller;
  final bool isEmbedded;

  const ReservasAdminScreen({
    super.key,
    required this.controller,
    this.isEmbedded = false,
  });

  @override
  State<ReservasAdminScreen> createState() => _ReservasAdminScreenState();
}

class _ReservasAdminScreenState extends State<ReservasAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ReservasService _reservasService;

  // Tab 1: Pendientes Admin
  List<ReservaModel> _pendientes = [];
  bool _isLoadingPendientes = true;
  String? _errorPendientes;

  // Tab 2: Todas las Reservas
  List<ReservaModel> _todasReservas = [];
  bool _isLoadingTodas = true;
  String _filtroEstado = 'todas';
  String? _errorTodas;

  // Tab 3: Áreas Comunes
  List<AreaComunModel> _areas = [];
  bool _isLoadingAreas = true;
  String? _errorAreas;
  bool _verBajas = false;

  // Tab 4: No-Shows
  List<ReservaModel> _noShows = [];
  bool _isLoadingNoShows = true;
  String? _errorNoShows;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _reservasService = ReservasService(widget.controller);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarPendientes(),
      _cargarTodasReservas(),
      _cargarAreas(),
      _cargarNoShows(),
    ]);
  }

  Future<void> _cargarPendientes() async {
    setState(() {
      _isLoadingPendientes = true;
      _errorPendientes = null;
    });
    try {
      final res = await _reservasService.getReservasAdmin(estado: 'pendiente_admin', pageSize: 50);
      if (mounted) {
        setState(() {
          _isLoadingPendientes = false;
          if (res['success'] == true) {
            _pendientes = res['items'] as List<ReservaModel>;
          } else {
            _errorPendientes = res['error'] ?? 'No se pudieron cargar las solicitudes pendientes.';
          }
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasAdminScreen._cargarPendientes');
      if (mounted) {
        setState(() {
          _isLoadingPendientes = false;
          _errorPendientes = ErrorHandler.parseException(e);
        });
      }
    }
  }

  Future<void> _cargarTodasReservas() async {
    setState(() {
      _isLoadingTodas = true;
      _errorTodas = null;
    });
    try {
      final estadoParam = _filtroEstado == 'todas' ? null : _filtroEstado;
      final res = await _reservasService.getReservasAdmin(estado: estadoParam, pageSize: 50);
      if (mounted) {
        setState(() {
          _isLoadingTodas = false;
          if (res['success'] == true) {
            _todasReservas = res['items'] as List<ReservaModel>;
          } else {
            _errorTodas = res['error'] ?? 'No se pudieron cargar las reservas.';
          }
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasAdminScreen._cargarTodasReservas');
      if (mounted) {
        setState(() {
          _isLoadingTodas = false;
          _errorTodas = ErrorHandler.parseException(e);
        });
      }
    }
  }

  Future<void> _cargarAreas() async {
    setState(() {
      _isLoadingAreas = true;
      _errorAreas = null;
    });
    try {
      // Mostrar todas (activas e inactivas) para administración
      final res = await _reservasService.getAreas(soloActivas: false, pageSize: 50);
      if (mounted) {
        setState(() {
          _isLoadingAreas = false;
          if (res['success'] == true) {
            _areas = res['items'] as List<AreaComunModel>;
          } else {
            _errorAreas = res['error'] ?? 'No se pudieron cargar las áreas comunes.';
          }
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasAdminScreen._cargarAreas');
      if (mounted) {
        setState(() {
          _isLoadingAreas = false;
          _errorAreas = ErrorHandler.parseException(e);
        });
      }
    }
  }

  Future<void> _cargarNoShows() async {
    setState(() {
      _isLoadingNoShows = true;
      _errorNoShows = null;
    });
    try {
      final res = await _reservasService.getNoShows(pageSize: 50);
      if (mounted) {
        setState(() {
          _isLoadingNoShows = false;
          if (res['success'] == true) {
            _noShows = res['items'] as List<ReservaModel>;
          } else {
            _errorNoShows = res['error'] ?? 'No se pudo cargar el historial de inasistencias.';
          }
        });
      }
    } catch (e, s) {
      ErrorHandler.trackError(e, s, 'ReservasAdminScreen._cargarNoShows');
      if (mounted) {
        setState(() {
          _isLoadingNoShows = false;
          _errorNoShows = ErrorHandler.parseException(e);
        });
      }
    }
  }

  Future<void> _aprobarReserva(ReservaModel reserva) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar Reserva'),
        content: Text(
          '¿Deseas autorizar la reserva para "${reserva.areaNombre}" solicitada por ${reserva.solicitanteCompleto} (Casa #${reserva.numeroCasa ?? 'S/N'}) para el ${_formatearFecha(reserva.inicio)}?\n\n'
          'El residente deberá confirmar su asistencia dentro de la ventana de 7 días a 72 horas antes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text('Aprobar Reserva'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _reservasService.aprobarReservaAdmin(reserva.id);
        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('Reserva aprobada exitosamente.', success: true);
            _cargarPendientes();
            _cargarTodasReservas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudo aprobar la reserva.', success: false);
          }
        }
      } catch (e, s) {
        ErrorHandler.trackError(e, s, 'ReservasAdminScreen._aprobarReserva');
        if (mounted) {
          widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
        }
      }
    }
  }

  Future<void> _rechazarReserva(ReservaModel reserva) async {
    final motivoCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar Reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Especifica el motivo del rechazo para ${reserva.solicitanteCompleto}:'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo del rechazo (obligatorio)',
                hintText: 'Ej. Área en mantenimiento, evento condominal...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () {
              if (motivoCtrl.text.trim().isEmpty) {
                widget.controller.notifyToast('El motivo es obligatorio.', success: false);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _reservasService.rechazarReservaAdmin(reserva.id, motivo: motivoCtrl.text.trim());
        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('Reserva rechazada.', success: true);
            _cargarPendientes();
            _cargarTodasReservas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudo rechazar.', success: false);
          }
        }
      } catch (e, s) {
        ErrorHandler.trackError(e, s, 'ReservasAdminScreen._rechazarReserva');
        if (mounted) {
          widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
        }
      }
    }
  }

  Future<void> _cancelarReservaAdmin(ReservaModel reserva) async {
    if (reserva.esBloqueo) {
      widget.controller.notifyToast(
        'No se puede cancelar un bloqueo a través de este endpoint.',
        success: false,
      );
      return;
    }
    final motivoCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Reserva Aprobada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Especifica el motivo de la cancelación administrativa para "${reserva.areaNombre}":'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (obligatorio)',
                hintText: 'Ej. Reparación urgente de instalaciones...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () {
              if (motivoCtrl.text.trim().isEmpty) {
                widget.controller.notifyToast('El motivo es obligatorio.', success: false);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Cancelar Reserva'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _reservasService.cancelarReservaAdmin(reserva.id, motivo: motivoCtrl.text.trim());
        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('Reserva cancelada por administración.', success: true);
            _cargarTodasReservas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudo cancelar.', success: false);
          }
        }
      } catch (e, s) {
        ErrorHandler.trackError(e, s, 'ReservasAdminScreen._cancelarReservaAdmin');
        if (mounted) {
          widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
        }
      }
    }
  }

  Future<void> _marcarNoShow(ReservaModel reserva) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Inasistencia (No-Show)'),
        content: Text(
          '¿Confirmas que el residente ${reserva.solicitanteCompleto} (Casa #${reserva.numeroCasa ?? 'S/N'}) no asistió ni utilizó las instalaciones en el horario acordado?\n\n'
          'Esta acción sumará al historial de inasistencias del titular y solicitante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Marcar No-Show'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _reservasService.marcarNoUtilizada(reserva.id);
        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('Inasistencia registrada correctamente.', success: true);
            _cargarTodasReservas();
            _cargarNoShows();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudo registrar.', success: false);
          }
        }
      } catch (e, s) {
        ErrorHandler.trackError(e, s, 'ReservasAdminScreen._marcarNoShow');
        if (mounted) {
          widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
        }
      }
    }
  }

  Future<void> _abrirModalCrearArea() async {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TimeOfDay horaApertura = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay horaCierre = const TimeOfDay(hour: 22, minute: 0);

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Nueva Área Común'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del área *',
                    hintText: 'Ej. Alberca Principal, Salón de Eventos',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Equipamiento',
                    hintText: 'Ej. Asadores, camastros, sanitarios...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('Horario de Operación:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: horaApertura);
                          if (picked != null) {
                            setModalState(() => horaApertura = picked);
                          }
                        },
                        child: Text('Abre: ${horaApertura.hour.toString().padLeft(2, '0')}:${horaApertura.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: horaCierre);
                          if (picked != null) {
                            setModalState(() => horaCierre = picked);
                          }
                        },
                        child: Text('Cierra: ${horaCierre.hour.toString().padLeft(2, '0')}:${horaCierre.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty) {
                  widget.controller.notifyToast('El nombre es obligatorio.', success: false);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      final apStr = '${horaApertura.hour.toString().padLeft(2, '0')}:${horaApertura.minute.toString().padLeft(2, '0')}:00';
      final ciStr = '${horaCierre.hour.toString().padLeft(2, '0')}:${horaCierre.minute.toString().padLeft(2, '0')}:00';

      try {
        final res = await _reservasService.crearArea(
          nombre: nombreCtrl.text.trim(),
          descripcion: descCtrl.text.trim(),
          horaApertura: apStr,
          horaCierre: ciStr,
        );

        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('Área común registrada exitosamente.', success: true);
            _cargarAreas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'Error al registrar área.', success: false);
          }
        }
      } catch (e, s) {
        ErrorHandler.trackError(e, s, 'ReservasAdminScreen._abrirModalCrearArea');
        if (mounted) {
          widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
        }
      }
    }
  }

  TimeOfDay _parseTime(String raw, {int fallbackHour = 8, int fallbackMinute = 0}) {
    try {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return TimeOfDay(hour: fallbackHour, minute: fallbackMinute);
  }

  Future<void> _abrirModalEditarArea(AreaComunModel area) async {
    final nombreCtrl = TextEditingController(text: area.nombre);
    final descCtrl = TextEditingController(text: area.descripcion ?? '');
    TimeOfDay horaApertura = _parseTime(area.horaApertura, fallbackHour: 8);
    TimeOfDay horaCierre = _parseTime(area.horaCierre, fallbackHour: 22);

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Editar Área Común'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del área *',
                    hintText: 'Ej. Alberca Principal',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Equipamiento',
                    hintText: 'Ej. Asadores, camastros...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('Horario de Operación:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: horaApertura);
                          if (picked != null) {
                            setModalState(() => horaApertura = picked);
                          }
                        },
                        child: Text('Abre: ${horaApertura.hour.toString().padLeft(2, '0')}:${horaApertura.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: horaCierre);
                          if (picked != null) {
                            setModalState(() => horaCierre = picked);
                          }
                        },
                        child: Text('Cierra: ${horaCierre.hour.toString().padLeft(2, '0')}:${horaCierre.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty) {
                  widget.controller.notifyToast('El nombre es obligatorio.', success: false);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
              child: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      final apStr = '${horaApertura.hour.toString().padLeft(2, '0')}:${horaApertura.minute.toString().padLeft(2, '0')}:00';
      final ciStr = '${horaCierre.hour.toString().padLeft(2, '0')}:${horaCierre.minute.toString().padLeft(2, '0')}:00';

      try {
        final res = await _reservasService.actualizarArea(
          area.id,
          nombre: nombreCtrl.text.trim(),
          descripcion: descCtrl.text.trim(),
          horaApertura: apStr,
          horaCierre: ciStr,
        );

        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast('Área común actualizada correctamente.', success: true);
            _cargarAreas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'Error al actualizar área.', success: false);
          }
        }
      } catch (e, s) {
        ErrorHandler.trackError(e, s, 'ReservasAdminScreen._abrirModalEditarArea');
        if (mounted) {
          widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
        }
      }
    }
  }

  Future<void> _cambiarEstadoArea(AreaComunModel area) async {
    final esBaja = area.activo;
    final accion = esBaja ? 'dar de baja' : 'reactivar';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esBaja ? 'Dar de baja área' : 'Reactivar área'),
        content: Text('¿Deseas $accion el área "${area.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: esBaja ? const Color(0xFFDC2626) : const Color(0xFF059669),
            ),
            child: Text(esBaja ? 'Dar de baja' : 'Reactivar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = esBaja
            ? await _reservasService.bajaArea(area.id)
            : await _reservasService.reactivarArea(area.id);

        if (mounted) {
          if (res['success'] == true) {
            widget.controller.notifyToast(
              esBaja ? 'Área dada de baja.' : 'Área reactivada.',
              success: true,
            );
            _cargarAreas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'No se pudo completar.', success: false);
          }
        }
      } catch (e, s) {
        ErrorHandler.trackError(e, s, 'ReservasAdminScreen._cambiarEstadoArea');
        if (mounted) {
          widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
        }
      }
    }
  }

  Future<void> _abrirModalBloqueoMantenimiento() async {
    if (_areas.isEmpty) {
      widget.controller.notifyToast('No hay áreas para bloquear.', success: false);
      return;
    }

    AreaComunModel selectedArea = _areas.first;
    DateTime fecha = DateTime.now().add(const Duration(days: 1));
    TimeOfDay horaInicio = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay horaFin = const TimeOfDay(hour: 18, minute: 0);
    final motivoCtrl = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Bloqueo por Mantenimiento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Área a bloquear:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<AreaComunModel>(
                  initialValue: selectedArea,
                  items: _areas.map((a) => DropdownMenuItem(value: a, child: Text(a.nombre))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedArea = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Fecha del bloqueo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: fecha,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setModalState(() => fecha = picked);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(_formatearFecha(fecha)),
                ),
                const SizedBox(height: 14),
                const Text('Horario:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final p = await showTimePicker(context: ctx, initialTime: horaInicio);
                          if (p != null) setModalState(() => horaInicio = p);
                        },
                        child: Text('Inicio: ${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final p = await showTimePicker(context: ctx, initialTime: horaFin);
                          if (p != null) setModalState(() => horaFin = p);
                        },
                        child: Text('Fin: ${horaFin.hour.toString().padLeft(2, '0')}:${horaFin.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: motivoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del bloqueo / reparación *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Mientras dure el bloqueo nadie podrá reservar el área. Las reservas pendientes o aprobadas que caigan en ese horario se cierran: se rechazan las pendientes y se cancelan las aprobadas, y se avisa a sus titulares con el motivo. Un bloqueo no se puede quitar después.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (motivoCtrl.text.trim().isEmpty) {
                  widget.controller.notifyToast('El motivo es obligatorio.', success: false);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Aplicar Bloqueo'),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      final inicioDt = DateTime(fecha.year, fecha.month, fecha.day, horaInicio.hour, horaInicio.minute);
      final finDt = DateTime(fecha.year, fecha.month, fecha.day, horaFin.hour, horaFin.minute);

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Bloquear esta área?'),
          content: Text(
            '${selectedArea.nombre} quedará bloqueada ${_formatearFecha(fecha)} de ${_formatearHora(inicioDt)} a ${_formatearHora(finDt)}. Las reservas de ese horario se rechazarán o cancelarán y el bloqueo no se podrá quitar.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Confirmar Bloqueo'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      try {
        final res = await _reservasService.crearBloqueo(
          areaId: selectedArea.id,
          inicio: inicioDt,
          fin: finDt,
          motivo: motivoCtrl.text.trim(),
        );

        if (mounted) {
          if (res['success'] == true) {
            final afect = res['totalReservasAfectadas'] ?? 0;
            final mensaje = afect == 0
                ? 'Bloqueo registrado. No había reservas en ese horario.'
                : afect == 1
                    ? 'Bloqueo registrado. Una reserva que caía en ese horario quedó rechazada o cancelada.'
                    : 'Bloqueo registrado. $afect reservas que caían en ese horario quedaron rechazadas o canceladas.';
            widget.controller.notifyToast(
              mensaje,
              success: true,
            );
            _cargarTodasReservas();
          } else {
            widget.controller.notifyToast(res['error'] ?? 'Error al crear bloqueo.', success: false);
          }
        }
      } catch (e, s) {
        ErrorHandler.trackError(e, s, 'ReservasAdminScreen._abrirModalBloqueoMantenimiento');
        if (mounted) {
          widget.controller.notifyToast(ErrorHandler.parseException(e), success: false);
        }
      }
    }
  }

  String _formatearFecha(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatearHora(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: const Color(0xFF111C99),
      unselectedLabelColor: const Color(0xFF64748B),
      indicatorColor: const Color(0xFF111C99),
      isScrollable: true,
      tabs: [
        Tab(
          child: Row(
            children: [
              const Text('Pendientes'),
              if (_pendientes.isNotEmpty) ...[
                const SizedBox(width: 6),
                Badge(
                  label: Text('${_pendientes.length}'),
                  backgroundColor: const Color(0xFFD97706),
                ),
              ],
            ],
          ),
        ),
        const Tab(text: 'Todas'),
        const Tab(text: 'Áreas Comunes'),
        const Tab(text: 'No-Shows'),
      ],
    );
  }

  Widget _buildEmbeddedHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: Color(0xFF111C99), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Administración de Reservas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _cargarTodo,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
          ),
          _buildTabBar(),
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
              title: const Text(
                'Administración de Reservas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              bottom: _buildTabBar(),
              actions: [
                IconButton(
                  onPressed: _cargarTodo,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
      body: Column(
        children: [
          if (widget.isEmbedded) _buildEmbeddedHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendientesTab(),
                _buildTodasTab(),
                _buildAreasTab(),
                _buildNoShowsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: SOLICITUDES PENDIENTES DE ADMIN
  // ─────────────────────────────────────────────────────────────
  Widget _buildPendientesTab() {
    return RefreshIndicator(
      onRefresh: _cargarPendientes,
      child: _isLoadingPendientes
          ? const Center(child: CircularProgressIndicator())
          : _errorPendientes != null && _pendientes.isEmpty
              ? _buildErrorView(_errorPendientes!, _cargarPendientes)
              : _pendientes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          const Text(
                            'No hay solicitudes pendientes de aprobación',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendientes.length,
                  itemBuilder: (ctx, idx) {
                    final item = _pendientes[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.areaNombre,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: const Text(
                                  'Pendiente Admin',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Solicitante: ${item.solicitanteCompleto} (Casa #${item.numeroCasa ?? 'S/N'})',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fecha: ${_formatearFecha(item.inicio)} de ${_formatearHora(item.inicio)} a ${_formatearHora(item.fin)}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 10),
                          // Métricas de No-shows del residente
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.history_rounded, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Inasistencias previas: Titular (${item.noShowsTitular}) | Solicitante (${item.noShowsSolicitante})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: (item.noShowsTitular > 0 || item.noShowsSolicitante > 0)
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _rechazarReserva(item),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                                  ),
                                  child: const Text('Rechazar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _aprobarReserva(item),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                                  child: const Text('Aprobar'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: TODAS LAS RESERVAS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTodasTab() {
    return RefreshIndicator(
      onRefresh: _cargarTodasReservas,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFiltroChip('todas', 'Todas'),
                const SizedBox(width: 8),
                _buildFiltroChip('aprobada', 'Aprobadas'),
                const SizedBox(width: 8),
                _buildFiltroChip('confirmada', 'Confirmadas'),
                const SizedBox(width: 8),
                _buildFiltroChip('cancelada', 'Canceladas'),
                const SizedBox(width: 8),
                _buildFiltroChip('no_utilizada', 'No-Shows'),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingTodas
                ? const Center(child: CircularProgressIndicator())
                : _errorTodas != null && _todasReservas.isEmpty
                    ? _buildErrorView(_errorTodas!, _cargarTodasReservas)
                    : _todasReservas.isEmpty
                        ? const Center(child: Text('No hay reservas registradas.'))
                        : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _todasReservas.length,
                        itemBuilder: (ctx, idx) {
                          final item = _todasReservas[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.areaNombre,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: item.estadoColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: item.estadoColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        item.estadoEtiqueta,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.estadoColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.esBloqueo
                                      ? (item.motivo != null && item.motivo!.trim().isNotEmpty
                                          ? 'Motivo: ${item.motivo}'
                                          : 'Bloqueo administrativo del área')
                                      : '${item.solicitanteCompleto} (Casa #${item.numeroCasa ?? 'S/N'})',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatearFecha(item.inicio)} de ${_formatearHora(item.inicio)} a ${_formatearHora(item.fin)}',
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                ),
                                if (item.esBloqueo) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Un bloqueo no se puede quitar desde aquí.',
                                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                                  ),
                                ] else if (item.esMarcableNoShow || item.esAprobada || item.esConfirmada) ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (item.esAprobada || item.esConfirmada)
                                        TextButton.icon(
                                          onPressed: () => _cancelarReservaAdmin(item),
                                          icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFDC2626)),
                                          label: const Text('Cancelar Admin', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                                        ),
                                      if (item.esMarcableNoShow) ...[
                                        const SizedBox(width: 8),
                                        FilledButton.tonalIcon(
                                          onPressed: () => _marcarNoShow(item),
                                          icon: const Icon(Icons.person_off_rounded, size: 15),
                                          label: const Text('Marcar No-Show', style: TextStyle(fontSize: 12)),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFFF3E8FF),
                                            foregroundColor: const Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
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

  Widget _buildFiltroChip(String estado, String etiqueta) {
    final selected = _filtroEstado == estado;
    return ChoiceChip(
      label: Text(etiqueta),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _filtroEstado = estado);
          _cargarTodasReservas();
        }
      },
      selectedColor: const Color(0xFF111C99),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF334155),
        fontSize: 12,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: ÁREAS COMUNES
  // ─────────────────────────────────────────────────────────────
  Widget _buildAreasTab() {
    final activas = _areas.where((a) => a.activo).toList();
    final deBaja = _areas.where((a) => !a.activo).toList();
    final visibles = _verBajas ? [...activas, ...deBaja] : activas;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _cargarAreas,
        child: _isLoadingAreas
            ? const Center(child: CircularProgressIndicator())
            : _errorAreas != null && _areas.isEmpty
                ? _buildErrorView(_errorAreas!, _cargarAreas)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (activas.isEmpty && deBaja.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'No hay áreas activas',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Los residentes no pueden reservar nada. Reactiva un área o da de alta una nueva.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      if (deBaja.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _verBajas = !_verBajas),
                              icon: Icon(
                                _verBajas ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 16,
                                color: const Color(0xFF475569),
                              ),
                              label: Text(
                                '${_verBajas ? 'Ocultar' : 'Mostrar'} áreas dadas de baja (${deBaja.length})',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                      if (visibles.isEmpty && deBaja.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'El condominio aún no tiene áreas comunes registradas.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        ...visibles.map((area) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: area.activo ? Colors.white : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        area.nombre,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: area.activo ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: area.activo ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5),
                                        ),
                                      ),
                                      child: Text(
                                        area.activo ? 'Activa' : 'Dada de Baja',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: area.activo ? const Color(0xFF047857) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (area.descripcion != null && area.descripcion!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(area.descripcion!, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  'Horario: ${area.horarioFormateado}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _abrirModalEditarArea(area),
                                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF111C99)),
                                      label: const Text('Editar', style: TextStyle(color: Color(0xFF111C99), fontSize: 13)),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _cambiarEstadoArea(area),
                                      icon: Icon(
                                        area.activo ? Icons.block_rounded : Icons.replay_rounded,
                                        size: 16,
                                        color: area.activo ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      ),
                                      label: Text(
                                        area.activo ? 'Dar de Baja' : 'Reactivar',
                                        style: TextStyle(
                                          color: area.activo ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_bloqueo',
            onPressed: _abrirModalBloqueoMantenimiento,
            backgroundColor: const Color(0xFFDC2626),
            icon: const Icon(Icons.build_circle_outlined, color: Colors.white),
            label: const Text('Bloqueo Mantenimiento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_nueva_area',
            onPressed: _abrirModalCrearArea,
            backgroundColor: const Color(0xFF111C99),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Nueva Área', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 4: NO-SHOWS
  // ─────────────────────────────────────────────────────────────
  Widget _buildNoShowsTab() {
    return RefreshIndicator(
      onRefresh: _cargarNoShows,
      child: _isLoadingNoShows
          ? const Center(child: CircularProgressIndicator())
          : _errorNoShows != null && _noShows.isEmpty
              ? _buildErrorView(_errorNoShows!, _cargarNoShows)
              : _noShows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sentiment_satisfied_alt_rounded, size: 64, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          const Text(
                            'No hay inasistencias registradas',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Los residentes han cumplido con sus reservas confirmadas.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _noShows.length,
                  itemBuilder: (ctx, idx) {
                    final item = _noShows[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.areaNombre,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFD8B4FE)),
                                ),
                                child: const Text(
                                  'Inasistencia',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Residente: ${item.solicitanteCompleto} (Casa #${item.numeroCasa ?? 'S/N'})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fecha programada: ${_formatearFecha(item.inicio)} de ${_formatearHora(item.inicio)} a ${_formatearHora(item.fin)}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildErrorView(String message, Future<void> Function() onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text(
              'Ocurrió un problema al cargar los datos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111C99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
