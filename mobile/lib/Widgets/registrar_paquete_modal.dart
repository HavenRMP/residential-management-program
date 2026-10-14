import 'package:flutter/material.dart';
import '../Models/paquete_model.dart';
import '../Models/paquete_dtos.dart';
import '../Models/servicio_paqueteria_model.dart';
import '../Services/app_controller.dart';
import '../Services/paqueteria_service.dart';
import '../Utils/haptic_helper.dart';

class RegistrarPaqueteModal extends StatefulWidget {
  final AppController controller;
  final List<dynamic> misViviendas;
  final PaqueteModel? paqueteAEditar;
  final List<ServicioPaqueteriaModel> serviciosDisponibles;

  const RegistrarPaqueteModal({
    super.key,
    required this.controller,
    required this.misViviendas,
    this.paqueteAEditar,
    this.serviciosDisponibles = const [],
  });

  @override
  State<RegistrarPaqueteModal> createState() => _RegistrarPaqueteModalState();
}

class _RegistrarPaqueteModalState extends State<RegistrarPaqueteModal> {
  final _formKey = GlobalKey<FormState>();

  late int? _viviendaIdSeleccionada;
  late TextEditingController _destinatarioCtrl;
  late TextEditingController _numeroGuiaCtrl;
  late TextEditingController _descripcionCtrl;
  late TextEditingController _notasCtrl;
  late TextEditingController _otroServicioCtrl;

  int? _servicioIdSeleccionado;
  String? _servicioNombreSeleccionado;
  bool _esOtroServicio = false;

  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _serviciosComunes = [
    'Amazon',
    'Mercado Libre',
    'DHL',
    'FedEx',
    'Estafeta',
    'UPS',
    'Correos de México',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    final editando = widget.paqueteAEditar;

    if (editando != null) {
      _viviendaIdSeleccionada = editando.viviendaId;
      _destinatarioCtrl = TextEditingController(text: editando.destinatarioNombre);
      _numeroGuiaCtrl = TextEditingController(text: editando.numeroGuia ?? '');
      _descripcionCtrl = TextEditingController(text: editando.descripcion ?? '');
      _notasCtrl = TextEditingController(text: editando.notas ?? '');
      _servicioIdSeleccionado = editando.servicioId;
      _servicioNombreSeleccionado = editando.servicioNombre;
      _esOtroServicio = editando.servicioNombre != null &&
          !_serviciosComunes.contains(editando.servicioNombre);
      _otroServicioCtrl = TextEditingController(
        text: _esOtroServicio ? (editando.servicioNombre ?? '') : '',
      );
      _fechaDesde = editando.fechaEsperadaDesde;
      _fechaHasta = editando.fechaEsperadaHasta;
    } else {
      if (widget.misViviendas.isNotEmpty) {
        _viviendaIdSeleccionada = (widget.misViviendas.first['id'] as num?)?.toInt();
      } else {
        _viviendaIdSeleccionada = null;
      }

      final userName = '${widget.controller.currentUser?.nombre ?? ''} ${widget.controller.currentUser?.apellidos ?? ''}'.trim();
      _destinatarioCtrl = TextEditingController(text: userName);
      _numeroGuiaCtrl = TextEditingController();
      _descripcionCtrl = TextEditingController();
      _notasCtrl = TextEditingController();
      _servicioNombreSeleccionado = 'Amazon';
      _otroServicioCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _destinatarioCtrl.dispose();
    _numeroGuiaCtrl.dispose();
    _descripcionCtrl.dispose();
    _notasCtrl.dispose();
    _otroServicioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_viviendaIdSeleccionada == null || _viviendaIdSeleccionada! <= 0) {
      setState(() => _errorMessage = 'Selecciona una vivienda para registrar el paquete.');
      return;
    }

    String servicioFinal = _esOtroServicio
        ? _otroServicioCtrl.text.trim()
        : (_servicioNombreSeleccionado ?? '').trim();

    if (servicioFinal.isEmpty) {
      setState(() => _errorMessage = 'Especifica la empresa de paquetería.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = PaqueteriaService(widget.controller);

    if (widget.paqueteAEditar != null) {
      final dto = UpdatePaqueteEsperadoDto(
        destinatarioNombre: _destinatarioCtrl.text.trim(),
        servicioId: _servicioIdSeleccionado,
        servicioNombre: servicioFinal,
        numeroGuia: _numeroGuiaCtrl.text.trim().isNotEmpty ? _numeroGuiaCtrl.text.trim() : null,
        descripcion: _descripcionCtrl.text.trim().isNotEmpty ? _descripcionCtrl.text.trim() : null,
        notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
        fechaEsperadaDesde: _fechaDesde,
        fechaEsperadaHasta: _fechaHasta,
      );

      final res = await service.updatePaqueteEsperado(widget.paqueteAEditar!.id, dto);
      if (!mounted) return;

      if (res['success'] == true) {
        HapticHelper.success();
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['error'] ?? 'Error al actualizar el paquete.';
        });
      }
    } else {
      final dto = CreatePaqueteEsperadoDto(
        viviendaId: _viviendaIdSeleccionada!,
        destinatarioNombre: _destinatarioCtrl.text.trim(),
        servicioId: _servicioIdSeleccionado,
        servicioNombre: servicioFinal,
        numeroGuia: _numeroGuiaCtrl.text.trim().isNotEmpty ? _numeroGuiaCtrl.text.trim() : null,
        descripcion: _descripcionCtrl.text.trim().isNotEmpty ? _descripcionCtrl.text.trim() : null,
        notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
        fechaEsperadaDesde: _fechaDesde,
        fechaEsperadaHasta: _fechaHasta,
      );

      final res = await service.createPaqueteEsperado(dto);
      if (!mounted) return;

      if (res['success'] == true) {
        HapticHelper.success();
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['error'] ?? 'Error al registrar el paquete.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.paqueteAEditar != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre superior
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

              // Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      esEdicion ? Icons.edit_note_rounded : Icons.local_shipping_rounded,
                      color: const Color(0xFF111C99),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esEdicion ? 'Modificar Paquete Esperado' : 'Avisar Paquete Esperado',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          esEdicion
                              ? 'Actualiza los datos antes de que llegue a caseta'
                              : 'Notifica a vigilancia que recibirás un paquete',
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
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Selector de Vivienda (solo en creación si hay varias)
              if (!esEdicion) ...[
                const Text(
                  'Vivienda de entrega *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: _viviendaIdSeleccionada,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.home_outlined),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: widget.misViviendas.map<DropdownMenuItem<int>>((v) {
                    final id = (v['id'] as num?)?.toInt() ?? 0;
                    final numCasa = (v['numeroCasa'] ?? 'N/A').toString();
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text('Casa #$numCasa'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _viviendaIdSeleccionada = val),
                  validator: (val) => val == null ? 'Selecciona una vivienda' : null,
                ),
                const SizedBox(height: 14),
              ],

              // Destinatario
              const Text(
                'Nombre del destinatario *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _destinatarioCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline),
                  hintText: 'Ej. Juan Pérez',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'El nombre del destinatario es obligatorio'
                    : null,
              ),
              const SizedBox(height: 14),

              // Empresa de Paquetería
              const Text(
                'Empresa de paquetería *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _esOtroServicio
                    ? 'Otro'
                    : (_serviciosComunes.contains(_servicioNombreSeleccionado)
                        ? _servicioNombreSeleccionado
                        : 'Otro'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.business_outlined),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _serviciosComunes.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    if (val == 'Otro') {
                      _esOtroServicio = true;
                      _servicioNombreSeleccionado = null;
                    } else {
                      _esOtroServicio = false;
                      _servicioNombreSeleccionado = val;
                    }
                  });
                },
              ),
              if (_esOtroServicio) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _otroServicioCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.edit_outlined),
                    hintText: 'Escribe el nombre de la empresa',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (_esOtroServicio && (val == null || val.trim().isEmpty))
                      ? 'Indica el nombre de la empresa'
                      : null,
                ),
              ],
              const SizedBox(height: 14),

              // Número de guía / Tracking
              const Text(
                'Número de guía o rastreo (opcional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _numeroGuiaCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.numbers_outlined),
                  hintText: 'Ej. 9845729103',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Descripción y notas
              const Text(
                'Descripción del paquete (opcional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Ej. Caja mediana con zapatos',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Notas para vigilancia
              const Text(
                'Instrucciones o notas para caseta (opcional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notasCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Ej. Si llega después de las 7pm, favor de resguardar',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _guardar,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111C99),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(esEdicion ? 'Actualizar' : 'Guardar Aviso'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
