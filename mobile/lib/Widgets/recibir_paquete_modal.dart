import 'package:flutter/material.dart';
import '../Models/paquete_model.dart';
import '../Models/paquete_dtos.dart';
import '../Services/app_controller.dart';
import '../Services/paqueteria_service.dart';
import '../Utils/haptic_helper.dart';

class RecibirPaqueteModal extends StatefulWidget {
  final AppController controller;
  final List<PaqueteModel> paquetesEsperados;
  final PaqueteModel? paquetePreseleccionado;

  const RecibirPaqueteModal({
    super.key,
    required this.controller,
    this.paquetesEsperados = const [],
    this.paquetePreseleccionado,
  });

  @override
  State<RecibirPaqueteModal> createState() => _RecibirPaqueteModalState();
}

class _RecibirPaqueteModalState extends State<RecibirPaqueteModal> {
  final _formKey = GlobalKey<FormState>();

  late bool _esInesperado;
  String? _paqueteIdSeleccionado;

  // Campos para caso inesperado
  final TextEditingController _casaCtrl = TextEditingController();
  final TextEditingController _destinatarioCtrl = TextEditingController();
  final TextEditingController _servicioCtrl = TextEditingController();
  final TextEditingController _numeroGuiaCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();
  final TextEditingController _ubicacionAlmacenCtrl = TextEditingController();

  int? _viviendaIdEncontrada;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _serviciosComunes = [
    'Amazon',
    'Mercado Libre',
    'DHL',
    'FedEx',
    'Estafeta',
    'UPS',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.paquetePreseleccionado != null) {
      _esInesperado = false;
      _paqueteIdSeleccionado = widget.paquetePreseleccionado!.id;
    } else if (widget.paquetesEsperados.isNotEmpty) {
      _esInesperado = false;
      _paqueteIdSeleccionado = widget.paquetesEsperados.first.id;
    } else {
      _esInesperado = true;
    }
  }

  @override
  void dispose() {
    _casaCtrl.dispose();
    _destinatarioCtrl.dispose();
    _servicioCtrl.dispose();
    _numeroGuiaCtrl.dispose();
    _descripcionCtrl.dispose();
    _ubicacionAlmacenCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = PaqueteriaService(widget.controller);

    RecibirPaqueteDto dto;
    if (!_esInesperado) {
      if (_paqueteIdSeleccionado == null || _paqueteIdSeleccionado!.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Selecciona el paquete esperado a recibir.';
        });
        return;
      }

      dto = RecibirPaqueteDto(
        paqueteId: _paqueteIdSeleccionado,
        ubicacionAlmacen: _ubicacionAlmacenCtrl.text.trim().isNotEmpty
            ? _ubicacionAlmacenCtrl.text.trim()
            : null,
      );
    } else {
      final casaNumero = _casaCtrl.text.trim();
      final viviendaId = _viviendaIdEncontrada ?? int.tryParse(casaNumero);

      if (viviendaId == null || viviendaId <= 0) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Número o identificador de vivienda inválido.';
        });
        return;
      }

      dto = RecibirPaqueteDto(
        viviendaId: viviendaId,
        destinatarioNombre: _destinatarioCtrl.text.trim(),
        servicioNombre: _servicioCtrl.text.trim(),
        numeroGuia: _numeroGuiaCtrl.text.trim().isNotEmpty ? _numeroGuiaCtrl.text.trim() : null,
        descripcion: _descripcionCtrl.text.trim().isNotEmpty ? _descripcionCtrl.text.trim() : null,
        ubicacionAlmacen: _ubicacionAlmacenCtrl.text.trim().isNotEmpty
            ? _ubicacionAlmacenCtrl.text.trim()
            : null,
      );
    }

    final res = await service.recibirPaquete(dto);
    if (!mounted) return;

    if (res['success'] == true) {
      HapticHelper.success();
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['error'] ?? 'No se pudo recibir el paquete en caseta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Barra de arrastre
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

              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.move_to_inbox_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recepción de Paquete en Caseta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Detonará notificación automática al residente',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Selector Caso A vs Caso B
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Paquete Esperado'),
                    icon: Icon(Icons.bookmark_added_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Inesperado / Sorpresa'),
                    icon: Icon(Icons.flash_on_outlined, size: 16),
                  ),
                ],
                selected: {_esInesperado},
                onSelectionChanged: (val) {
                  HapticHelper.light();
                  setState(() => _esInesperado = val.first);
                },
              ),
              const SizedBox(height: 18),

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

              // Caso A: Paquete Esperado
              if (!_esInesperado) ...[
                if (widget.paquetesEsperados.isEmpty && widget.paquetePreseleccionado == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No hay paquetes esperados registrados hoy. Puedes registrarlo como "Inesperado / Sorpresa".',
                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  )
                else ...[
                  const Text(
                    'Selecciona el paquete esperado *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _paqueteIdSeleccionado,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: (widget.paquetePreseleccionado != null
                            ? [widget.paquetePreseleccionado!]
                            : widget.paquetesEsperados)
                        .map<DropdownMenuItem<String>>((p) {
                      return DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(
                          'Casa #${p.numeroCasa} - ${p.destinatarioNombre} (${p.servicioNombre ?? 'Paquetería'})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _paqueteIdSeleccionado = val),
                    validator: (val) => val == null ? 'Selecciona un paquete' : null,
                  ),
                ],
              ] else ...[
                // Caso B: Paquete Inesperado
                const Text(
                  'Número o ID de casa/vivienda *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _casaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.home_outlined),
                    hintText: 'Ej. 101 o ID numérico',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Indica el número de casa' : null,
                ),
                const SizedBox(height: 14),

                const Text(
                  'Nombre del destinatario *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _destinatarioCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline),
                    hintText: 'Ej. Ana Martínez',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'El destinatario es obligatorio' : null,
                ),
                const SizedBox(height: 14),

                const Text(
                  'Empresa de paquetería *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: 'Amazon',
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _serviciosComunes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val == 'Otro') {
                      _servicioCtrl.clear();
                    } else {
                      _servicioCtrl.text = val ?? '';
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _servicioCtrl,
                  decoration: InputDecoration(
                    hintText: 'Nombre de mensajería (ej. Amazon, DHL...)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Indica la empresa de paquetería' : null,
                ),
                const SizedBox(height: 14),

                const Text(
                  'Número de guía o rastreo (opcional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _numeroGuiaCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.qr_code_outlined),
                    hintText: 'Ej. 78923412',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Ubicación física en caseta (para ambos casos)
              const Text(
                'Ubicación en almacén / caseta (opcional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ubicacionAlmacenCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.place_outlined),
                  hintText: 'Ej. Bodega A - Estante 2',
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
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _guardar,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(_isLoading ? 'Guardando...' : 'Recibir Paquete'),
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
