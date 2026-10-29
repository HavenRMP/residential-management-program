import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../Models/pagos_models.dart';
import '../Services/pagos_service.dart';
import '../Services/app_controller.dart';
import '../Utils/error_handler.dart';

class ReportarPagoModal extends StatefulWidget {
  final CargoModel cargo;
  final int viviendaId;
  final PagosService pagosService;
  final AppController controller;

  const ReportarPagoModal({
    super.key,
    required this.cargo,
    required this.viviendaId,
    required this.pagosService,
    required this.controller,
  });

  static Future<bool?> show(
    BuildContext context, {
    required CargoModel cargo,
    required int viviendaId,
    required PagosService pagosService,
    required AppController controller,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportarPagoModal(
        cargo: cargo,
        viviendaId: viviendaId,
        pagosService: pagosService,
        controller: controller,
      ),
    );
  }

  @override
  State<ReportarPagoModal> createState() => _ReportarPagoModalState();
}

class _ReportarPagoModalState extends State<ReportarPagoModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoController;
  late final TextEditingController _folioController;
  late final TextEditingController _bancoController;
  late final TextEditingController _notasController;

  String _metodoSeleccionado = MetodoPago.transferencia;
  DateTime _fechaPago = DateTime.now();

  final ImagePicker _picker = ImagePicker();
  bool _isUploadingFile = false;
  String? _uploadError;
  String? _rutaComprobante;
  String? _hashComprobante;
  String? _archivoNombre;
  int? _tamanoBytes;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _montoController = TextEditingController(
      text: widget.cargo.saldoPendiente > 0
          ? widget.cargo.saldoPendiente.toStringAsFixed(2)
          : widget.cargo.monto.toStringAsFixed(2),
    );
    _folioController = TextEditingController();
    _bancoController = TextEditingController();
    _notasController = TextEditingController();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _folioController.dispose();
    _bancoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarYSubirComprobante(ImageSource source) async {
    setState(() {
      _uploadError = null;
    });

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name.isNotEmpty
          ? pickedFile.name
          : 'comprobante_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        setState(() {
          _uploadError = 'El archivo supera el límite de 5 MB.';
        });
        return;
      }

      setState(() {
        _isUploadingFile = true;
        _archivoNombre = filename;
        _tamanoBytes = bytes.lengthInBytes;
      });

      final uploadResult = await widget.pagosService.uploadComprobante(
        viviendaId: widget.viviendaId,
        fileBytes: bytes,
        filename: filename,
      );

      if (mounted) {
        setState(() {
          _isUploadingFile = false;
          _rutaComprobante = uploadResult.ruta;
          _hashComprobante = uploadResult.hash;
          _uploadError = null;
        });
        widget.controller.notifyToast('Comprobante subido y optimizado.', success: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
          _uploadError = ErrorHandler.extractErrorMessage(
            e,
            defaultMessage: 'No se pudo subir el comprobante. Intenta nuevamente.',
          );
        });
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPago,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() => _fechaPago = picked);
    }
  }

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    if (_rutaComprobante == null || _rutaComprobante!.isEmpty) {
      setState(() {
        _uploadError = 'Debes adjuntar el comprobante para reportar la transferencia.';
      });
      return;
    }

    final monto = double.tryParse(_montoController.text.trim().replaceAll(',', '')) ?? 0.0;
    if (monto <= 0) {
      widget.controller.notifyToast('El monto debe ser mayor a 0.', success: false);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.pagosService.reportarPago(
        cargoId: widget.cargo.id,
        monto: monto,
        metodo: _metodoSeleccionado,
        fechaPago: _fechaPago,
        folioComprobante: _folioController.text.trim().isNotEmpty
            ? _folioController.text.trim()
            : null,
        bancoOrigen: _bancoController.text.trim().isNotEmpty
            ? _bancoController.text.trim()
            : null,
        rutaComprobante: _rutaComprobante!,
        hashComprobante: _hashComprobante,
        notas: _notasController.text.trim().isNotEmpty
            ? _notasController.text.trim()
            : null,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        widget.controller.notifyToast(
          '¡Pago reportado! Queda pendiente de confirmación por administración.',
          success: true,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorMsg = ErrorHandler.extractErrorMessage(
          e,
          defaultMessage: 'No se pudo registrar el pago.',
        );
        widget.controller.notifyToast(errorMsg, success: false);
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
                // Top handle
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

                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Reportar Pago de Cuota',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Summary of selected cargo
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111C99),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.cargo.concepto,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Saldo pendiente: \$${widget.cargo.saldoPendiente.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Monto
                const Text(
                  'Monto a pagar (\$)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.attach_money_rounded, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF111C99), width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingresa el monto del pago.';
                    }
                    final num = double.tryParse(val.trim().replaceAll(',', ''));
                    if (num == null || num <= 0) {
                      return 'Ingresa un monto válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Método de pago
                const Text(
                  'Método de Pago',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _metodoSeleccionado,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.payment_rounded, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  items: MetodoPago.todos.map((metodo) {
                    return DropdownMenuItem(
                      value: metodo,
                      child: Text(metodo),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _metodoSeleccionado = val);
                  },
                ),
                const SizedBox(height: 14),

                // Fecha de Pago
                const Text(
                  'Fecha de Pago',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _seleccionarFecha,
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
                            const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Text(
                              '${_fechaPago.year}-${_fechaPago.month.toString().padLeft(2, '0')}-${_fechaPago.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Folio / Referencia
                const Text(
                  'Folio / Referencia de Transferencia (opcional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _folioController,
                  decoration: InputDecoration(
                    hintText: 'Ej. TRF-908234 o Clave de rastreo',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Banco Origen
                const Text(
                  'Banco de Origen (opcional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bancoController,
                  decoration: InputDecoration(
                    hintText: 'Ej. BBVA, Santander, Banorte, STP...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Notas
                const Text(
                  'Notas / Observaciones (opcional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notasController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ej. Pago cuota de mantenimiento de octubre',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Adjuntar Comprobante
                const Text(
                  'Comprobante de Pago *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sube una foto o captura clara del comprobante bancario (JPG, PNG o PDF, máx. 5 MB).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),

                // Upload container
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _rutaComprobante != null
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _rutaComprobante != null
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_isUploadingFile) ...[
                        const Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF111C99)),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Optimizando y subiendo comprobante al servidor...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (_rutaComprobante != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _archivoNombre ?? 'Comprobante listo',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF065F46),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_tamanoBytes != null)
                                    Text(
                                      '${(_tamanoBytes! / 1024).toStringAsFixed(1)} KB - Optimizado',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _rutaComprobante = null;
                                  _archivoNombre = null;
                                  _tamanoBytes = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                              tooltip: 'Quitar',
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _seleccionarYSubirComprobante(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                label: const Text('Tomar Foto'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _seleccionarYSubirComprobante(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_outlined, size: 18),
                                label: const Text('Galería'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (_uploadError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _uploadError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                FilledButton(
                  onPressed: (_isSubmitting || _isUploadingFile || _rutaComprobante == null)
                      ? null
                      : _enviarReporte,
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
                      : const Text(
                          'Reportar Pago',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
