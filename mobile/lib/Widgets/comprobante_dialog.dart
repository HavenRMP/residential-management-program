import 'package:flutter/material.dart';
import '../Services/pagos_service.dart';
import '../Utils/error_handler.dart';

class ComprobanteDialog extends StatefulWidget {
  final String pagoId;
  final String? urlFirmadaInicial;
  final PagosService pagosService;

  const ComprobanteDialog({
    super.key,
    required this.pagoId,
    this.urlFirmadaInicial,
    required this.pagosService,
  });

  static Future<void> show(
    BuildContext context, {
    required String pagoId,
    String? urlFirmada,
    required PagosService pagosService,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ComprobanteDialog(
        pagoId: pagoId,
        urlFirmadaInicial: urlFirmada,
        pagosService: pagosService,
      ),
    );
  }

  @override
  State<ComprobanteDialog> createState() => _ComprobanteDialogState();
}

class _ComprobanteDialogState extends State<ComprobanteDialog> {
  String? _url;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.urlFirmadaInicial != null && widget.urlFirmadaInicial!.isNotEmpty) {
      _url = widget.urlFirmadaInicial;
      _isLoading = false;
    } else {
      _cargarUrlFirmada();
    }
  }

  Future<void> _cargarUrlFirmada() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = await widget.pagosService.getComprobanteUrl(widget.pagoId);
      if (mounted) {
        setState(() {
          _url = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorHandler.extractErrorMessage(
            e,
            defaultMessage: 'No se pudo cargar el enlace del comprobante.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: Color(0xFF111C99), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Comprobante de Pago',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF111C99), size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Enlace firmado de alta seguridad. Expira en 5 minutos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF111C99)),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 40,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    OutlinedButton.icon(
                                      onPressed: _cargarUrlFirmada,
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: const Text('Reintentar'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _url != null
                              ? InteractiveViewer(
                                  minScale: 0.8,
                                  maxScale: 4.0,
                                  child: Image.network(
                                    _url!,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      final total = progress.expectedTotalBytes;
                                      final loaded = progress.cumulativeBytesLoaded;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: total != null ? loaded / total : null,
                                          color: const Color(0xFF111C99),
                                        ),
                                      );
                                    },
                                    errorBuilder: (ctx, err, stack) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.broken_image_rounded,
                                                color: Color(0xFF94A3B8),
                                                size: 48,
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'No se pudo renderizar la vista previa de imagen o es un documento PDF.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              OutlinedButton.icon(
                                                onPressed: _cargarUrlFirmada,
                                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                                label: const Text('Actualizar enlace'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
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
