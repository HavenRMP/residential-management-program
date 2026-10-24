import 'package:flutter/material.dart';
import '../Models/pagos_models.dart';
import '../Services/pagos_service.dart';
import '../Services/app_controller.dart';
import '../Utils/error_handler.dart';

class CrearCargoModal extends StatefulWidget {
  final List<dynamic> viviendas;
  final PagosService pagosService;
  final AppController controller;

  const CrearCargoModal({
    super.key,
    required this.viviendas,
    required this.pagosService,
    required this.controller,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<dynamic> viviendas,
    required PagosService pagosService,
    required AppController controller,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CrearCargoModal(
        viviendas: viviendas,
        pagosService: pagosService,
        controller: controller,
      ),
    );
  }

  @override
  State<CrearCargoModal> createState() => _CrearCargoModalState();
}

class _CrearCargoModalState extends State<CrearCargoModal> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedViviendaId;
  String _tipoSeleccionado = TipoCargo.mantenimiento;
  final _conceptoController = TextEditingController();
  final _montoController = TextEditingController();
  final _periodoController = TextEditingController();
  final _notasController = TextEditingController();

  DateTime _fechaVencimiento = DateTime.now().add(const Duration(days: 15));
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.viviendas.isNotEmpty) {
      final first = widget.viviendas.first;
      if (first is Map && first['id'] != null) {
        _selectedViviendaId = (first['id'] as num).toInt();
      }
    }
    final now = DateTime.now();
    _periodoController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _montoController.dispose();
    _periodoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaVencimiento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() => _fechaVencimiento = picked);
    }
  }

  Future<void> _guardarCargo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedViviendaId == null) {
      widget.controller.notifyToast('Selecciona una vivienda.', success: false);
      return;
    }

    final monto = double.tryParse(_montoController.text.trim().replaceAll(',', '')) ?? 0.0;
    if (monto <= 0) {
      widget.controller.notifyToast('El monto debe ser mayor a 0.', success: false);
      return;
    }

    setState(() => _isSubmitting = true);

    final fechaStr =
        '${_fechaVencimiento.year}-${_fechaVencimiento.month.toString().padLeft(2, '0')}-${_fechaVencimiento.day.toString().padLeft(2, '0')}';

    try {
      await widget.pagosService.crearCargo(
        viviendaId: _selectedViviendaId!,
        tipo: _tipoSeleccionado,
        concepto: _conceptoController.text.trim(),
        monto: monto,
        fechaVencimiento: fechaStr,
        periodo: _periodoController.text.trim(),
        notas: _notasController.text.trim().isNotEmpty
            ? _notasController.text.trim()
            : null,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        widget.controller.notifyToast('Cargo creado exitosamente.', success: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final err = ErrorHandler.extractErrorMessage(
          e,
          defaultMessage: 'No fue posible crear el cargo.',
        );
        widget.controller.notifyToast(err, success: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
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
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nuevo Cargo Manual',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Vivienda
                const Text(
                  'Vivienda Destino *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: _selectedViviendaId,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.home_work_outlined, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: widget.viviendas.map((v) {
                    final id = (v['id'] as num?)?.toInt() ?? 0;
                    final numCasa = (v['numeroCasa'] ?? 'S/N').toString();
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text('Casa #$numCasa'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedViviendaId = val);
                  },
                  validator: (val) => val == null ? 'Selecciona una vivienda' : null,
                ),
                const SizedBox(height: 14),

                // Tipo
                const Text(
                  'Tipo de Cargo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _tipoSeleccionado,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: TipoCargo.todos.map((tipo) {
                    return DropdownMenuItem(value: tipo, child: Text(tipo));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _tipoSeleccionado = val);
                  },
                ),
                const SizedBox(height: 14),

                // Concepto
                const Text(
                  'Concepto *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _conceptoController,
                  decoration: InputDecoration(
                    hintText: 'Ej. Cuota Extraordinaria Pintura',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Ingresa el concepto del cargo' : null,
                ),
                const SizedBox(height: 14),

                // Monto y Periodo
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monto (\$) *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _montoController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.attach_money_rounded, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Requerido';
                              final n = double.tryParse(val.trim().replaceAll(',', ''));
                              if (n == null || n <= 0) return 'Monto inválido';
                              return null;
                            },
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
                            'Periodo (YYYY-MM)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _periodoController,
                            decoration: InputDecoration(
                              hintText: '2026-10',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Requerido';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Fecha Vencimiento
                const Text(
                  'Fecha de Vencimiento',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _seleccionarFechaVencimiento,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_rounded, size: 20, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Text(
                              '${_fechaVencimiento.year}-${_fechaVencimiento.month.toString().padLeft(2, '0')}-${_fechaVencimiento.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Notas
                const Text(
                  'Notas (opcional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notasController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Detalles u observaciones internas',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _isSubmitting ? null : _guardarCargo,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111C99),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Crear Cargo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
