import 'package:flutter/material.dart';
import '../Models/paquete_model.dart';
import '../Services/app_controller.dart';
import '../Services/paqueteria_service.dart';
import '../Utils/haptic_helper.dart';

class EntregarPaqueteModal extends StatefulWidget {
  final AppController controller;
  final PaqueteModel paquete;

  const EntregarPaqueteModal({
    super.key,
    required this.controller,
    required this.paquete,
  });

  @override
  State<EntregarPaqueteModal> createState() => _EntregarPaqueteModalState();
}

class _EntregarPaqueteModalState extends State<EntregarPaqueteModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _recibioCtrl;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-llenar con el destinatario esperado por conveniencia
    _recibioCtrl = TextEditingController(text: widget.paquete.destinatarioNombre);
  }

  @override
  void dispose() {
    _recibioCtrl.dispose();
    super.dispose();
  }

  Future<void> _entregar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = PaqueteriaService(widget.controller);
    final res = await service.entregarPaquete(
      widget.paquete.id,
      _recibioCtrl.text.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      HapticHelper.success();
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['error'] ?? 'No se pudo registrar la entrega del paquete.';
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.handshake_rounded,
                      color: Color(0xFF111C99),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entrega de Paquete en Caseta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Registra el nombre de la persona que recibe en mano',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Tarjeta informativa del paquete
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.paquete.servicioNombre ?? 'Paquetería',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Casa #${widget.paquete.numeroCasa}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF111C99),
                          ),
                        ),
                      ],
                    ),
                    if (widget.paquete.numeroGuia != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Guía: ${widget.paquete.numeroGuia}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                    if (widget.paquete.ubicacionAlmacen != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ubicación: ${widget.paquete.ubicacionAlmacen}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

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

              const Text(
                'Nombre de quien recibe el paquete *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _recibioCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline),
                  hintText: 'Ej. Juan Pérez (Titular o Familiar)',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'El nombre de quien recibe es obligatorio' : null,
              ),
              const SizedBox(height: 24),

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
                      onPressed: _isLoading ? null : _entregar,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111C99),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isLoading ? 'Guardando...' : 'Confirmar Entrega'),
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
