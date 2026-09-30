import 'package:flutter/material.dart';
import '../Models/visita_model.dart';
import '../Services/app_controller.dart';
import '../Services/visitas_service.dart';

class ProgramarVisitaModal extends StatefulWidget {
  final AppController controller;
  final List<Map<String, dynamic>> misViviendas;
  final VisitaModel? visitaParaEditar;

  const ProgramarVisitaModal({
    super.key,
    required this.controller,
    required this.misViviendas,
    this.visitaParaEditar,
  });

  @override
  State<ProgramarVisitaModal> createState() => _ProgramarVisitaModalState();
}

class _ProgramarVisitaModalState extends State<ProgramarVisitaModal> {
  final _formKey = GlobalKey<FormState>();

  late int _selectedViviendaId;
  final _nombreController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _placasController = TextEditingController();
  final _notasController = TextEditingController();
  int _numAcompanantes = 0;
  String _motivo = 'personal';
  int _horasVigencia = 24;
  late DateTime _fechaLlegadaEsperada;

  bool _isSaving = false;

  final List<Map<String, String>> _motivos = [
    {'value': 'personal', 'label': 'Personal', 'icon': '👤'},
    {'value': 'familiar', 'label': 'Familiar', 'icon': '👨‍👩‍👧‍👦'},
    {'value': 'proveedor', 'label': 'Proveedor', 'icon': '🛠️'},
    {'value': 'servicio', 'label': 'Servicio', 'icon': '🧹'},
    {'value': 'paqueteria', 'label': 'Paquetería', 'icon': '📦'},
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.visitaParaEditar;
    if (edit != null) {
      _selectedViviendaId = edit.viviendaId;
      _nombreController.text = edit.nombreVisitante;
      _apellidosController.text = edit.apellidosVisitante;
      _telefonoController.text = edit.telefonoVisitante ?? '';
      _placasController.text = edit.vehiculoPlacas ?? '';
      _notasController.text = edit.notas ?? '';
      _numAcompanantes = edit.numAcompanantes;
      _motivo = edit.motivo.isNotEmpty ? edit.motivo : 'personal';
      _fechaLlegadaEsperada = edit.fechaLlegadaEsperada;
      final diff = edit.vigenciaHasta.difference(edit.fechaLlegadaEsperada).inHours;
      _horasVigencia = diff > 0 ? diff : 24;
    } else {
      _selectedViviendaId = widget.misViviendas.isNotEmpty
          ? (widget.misViviendas.first['id'] is num
              ? (widget.misViviendas.first['id'] as num).toInt()
              : int.tryParse(widget.misViviendas.first['id'].toString()) ?? 0)
          : 0;
      // Default fecha esperada: ahora redondeado a los próximos 15 mins
      final now = DateTime.now();
      _fechaLlegadaEsperada = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    _placasController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaHora() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _fechaLlegadaEsperada,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
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

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaLlegadaEsperada),
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

    if (pickedTime == null || !mounted) return;

    setState(() {
      _fechaLlegadaEsperada = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedViviendaId == 0) {
      widget.controller.notifyToast('Selecciona una vivienda válida', success: false);
      return;
    }

    setState(() => _isSaving = true);
    final service = VisitasService(widget.controller);

    final safeAcompanantes = _numAcompanantes.clamp(0, 20);

    if (widget.visitaParaEditar != null) {
      final res = await service.editarVisita(
        widget.visitaParaEditar!.id,
        nombreVisitante: _nombreController.text,
        apellidosVisitante: _apellidosController.text,
        telefonoVisitante: _telefonoController.text,
        motivo: _motivo,
        numAcompanantes: safeAcompanantes,
        vehiculoPlacas: _placasController.text,
        notas: _notasController.text,
        fechaLlegadaEsperada: _fechaLlegadaEsperada,
        horasVigencia: _horasVigencia,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (res['success'] == true) {
          widget.controller.notifyToast('Visita actualizada exitosamente', success: true);
          Navigator.pop(context, true);
        } else {
          widget.controller.notifyToast(res['error'] ?? 'Error al actualizar visita', success: false);
        }
      }
    } else {
      final res = await service.programarVisita(
        viviendaId: _selectedViviendaId,
        nombreVisitante: _nombreController.text,
        apellidosVisitante: _apellidosController.text,
        telefonoVisitante: _telefonoController.text,
        motivo: _motivo,
        numAcompanantes: safeAcompanantes,
        vehiculoPlacas: _placasController.text,
        notas: _notasController.text,
        fechaLlegadaEsperada: _fechaLlegadaEsperada,
        horasVigencia: _horasVigencia,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (res['success'] == true) {
          final VisitaModel nueva = res['visita'] as VisitaModel;
          widget.controller.notifyToast('¡Visita programada! Código: ${nueva.codigo ?? ''}', success: true);
          Navigator.pop(context, true);
        } else {
          widget.controller.notifyToast(res['error'] ?? 'Error al programar visita', success: false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.visitaParaEditar != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
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
                    Text(
                      isEditing ? 'Editar Visita' : 'Programar Visita',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Selección de Vivienda (si tiene más de una)
                if (!isEditing && widget.misViviendas.length > 1) ...[
                  const Text(
                    'Vivienda destino *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: _selectedViviendaId != 0 ? _selectedViviendaId : null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: widget.misViviendas.map((v) {
                      final id = (v['id'] is num)
                          ? (v['id'] as num).toInt()
                          : int.tryParse(v['id'].toString()) ?? 0;
                      final casa = v['numeroCasa'] ?? 'S/N';
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text('Casa #$casa'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedViviendaId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Nombres y Apellidos
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nombre *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nombreController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Ej. Roberto',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
                            'Apellidos *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _apellidosController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Ej. Sánchez',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Teléfono y Placas
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Teléfono (opcional)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _telefonoController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: '10 dígitos',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            'Placas (opcional)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _placasController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Ej. ABC-123',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Motivo (selector visual)
                const Text(
                  'Motivo de la visita *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _motivos.map((m) {
                    final selected = _motivo == m['value'];
                    return ChoiceChip(
                      label: Text('${m['icon']} ${m['label']}'),
                      selected: selected,
                      selectedColor: const Color(0xFF111C99),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF334155),
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _motivo = m['value']!);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Número de acompañantes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acompañantes adicionales',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        Text(
                          'Personas que vienen con el visitante (máx. 20)',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: _numAcompanantes > 0
                              ? () => setState(() => _numAcompanantes--)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$_numAcompanantes',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: _numAcompanantes < 20
                              ? () => setState(() => _numAcompanantes++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fecha y Hora de llegada esperada
                const Text(
                  'Fecha y hora estimada de llegada *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _seleccionarFechaHora,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available_rounded, color: Color(0xFF111C99)),
                            const SizedBox(width: 10),
                            Text(
                              '${_fechaLlegadaEsperada.day.toString().padLeft(2, '0')}/${_fechaLlegadaEsperada.month.toString().padLeft(2, '0')}/${_fechaLlegadaEsperada.year} a las ${_fechaLlegadaEsperada.hour.toString().padLeft(2, '0')}:${_fechaLlegadaEsperada.minute.toString().padLeft(2, '0')} hrs',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Horas de Vigencia
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Vigencia del pase',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    DropdownButton<int>(
                      value: _horasVigencia,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 6, child: Text('6 horas')),
                        DropdownMenuItem(value: 12, child: Text('12 horas')),
                        DropdownMenuItem(value: 24, child: Text('24 horas (Recomendado)')),
                        DropdownMenuItem(value: 48, child: Text('48 horas')),
                        DropdownMenuItem(value: 72, child: Text('72 horas')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _horasVigencia = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notas
                const Text(
                  'Notas o instrucciones para caseta (opcional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notasController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ej. Trae herramientas para plomería',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // Botón Guardar
                FilledButton(
                  onPressed: _isSaving ? null : _guardar,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111C99),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isEditing ? 'Guardar Cambios' : 'Generar Pase de Visita',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
