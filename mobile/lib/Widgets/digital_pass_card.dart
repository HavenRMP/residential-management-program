import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../Utils/haptic_helper.dart';

/// Tarjeta digital de acceso diseñada para previsualización y exportación como imagen PNG.
class DigitalPassCard extends StatelessWidget {
  final String codigo;
  final String titulo;
  final String subtitulo;
  final String? tipoEtiqueta;
  final String? nombreVisitante;

  const DigitalPassCard({
    super.key,
    required this.codigo,
    this.titulo = 'Pase de Acceso',
    this.subtitulo = 'Muestra este código al vigilante en caseta para ingresar.',
    this.tipoEtiqueta,
    this.nombreVisitante,
  });

  @override
  Widget build(BuildContext context) {
    final cleanCode = codigo.trim();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A111C99),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con gradiente elegante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF111C99), Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'HAVEN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    if (tipoEtiqueta != null && tipoEtiqueta!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Text(
                          tipoEtiqueta!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (nombreVisitante != null && nombreVisitante!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Para: $nombreVisitante',
                    style: const TextStyle(
                      color: Color(0xFFC7D2FE),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Cuerpo de la tarjeta con Código QR
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: cleanCode,
                    version: QrVersions.auto,
                    size: 190,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                const SizedBox(height: 14),

                // Código alfanumérico
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    cleanCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      fontFamily: 'monospace',
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Instrucciones
                Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 4),
                const Text(
                  'Control de Acceso Residencial HAVEN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo interactivo que muestra la tarjeta y permite compartirla directamente como imagen PNG.
class DigitalPassPreviewDialog extends StatefulWidget {
  final String codigo;
  final String titulo;
  final String subtitulo;
  final String? tipoEtiqueta;
  final String? nombreVisitante;

  const DigitalPassPreviewDialog({
    super.key,
    required this.codigo,
    this.titulo = 'Pase de Acceso',
    this.subtitulo = 'Muestra este código al vigilante en caseta para ingresar.',
    this.tipoEtiqueta,
    this.nombreVisitante,
  });

  static Future<void> show(
    BuildContext context, {
    required String codigo,
    String titulo = 'Pase de Acceso',
    String subtitulo = 'Muestra este código al vigilante en caseta para ingresar.',
    String? tipoEtiqueta,
    String? nombreVisitante,
  }) {
    return showDialog(
      context: context,
      builder: (_) => DigitalPassPreviewDialog(
        codigo: codigo,
        titulo: titulo,
        subtitulo: subtitulo,
        tipoEtiqueta: tipoEtiqueta,
        nombreVisitante: nombreVisitante,
      ),
    );
  }

  @override
  State<DigitalPassPreviewDialog> createState() => _DigitalPassPreviewDialogState();
}

class _DigitalPassPreviewDialogState extends State<DigitalPassPreviewDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

    Future<void> _shareAsPng() async {}
  @override
  Widget build(BuildContext context) {
    final cleanCode = codigo.trim();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A111C99),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con gradiente elegante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF111C99), Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'HAVEN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    if (tipoEtiqueta != null && tipoEtiqueta!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Text(
                          tipoEtiqueta!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (nombreVisitante != null && nombreVisitante!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Para: $nombreVisitante',
                    style: const TextStyle(
                      color: Color(0xFFC7D2FE),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Cuerpo de la tarjeta con Código QR
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: cleanCode,
                    version: QrVersions.auto,
                    size: 190,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                const SizedBox(height: 14),

                // Código alfanumérico
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    cleanCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      fontFamily: 'monospace',
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Instrucciones
                Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 4),
                const Text(
                  'Control de Acceso Residencial HAVEN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo interactivo que muestra la tarjeta y permite compartirla directamente como imagen PNG.
class DigitalPassPreviewDialog extends StatefulWidget {
  final String codigo;
  final String titulo;
  final String subtitulo;
  final String? tipoEtiqueta;
  final String? nombreVisitante;

  const DigitalPassPreviewDialog({
    super.key,
    required this.codigo,
    this.titulo = 'Pase de Acceso',
    this.subtitulo = 'Muestra este código al vigilante en caseta para ingresar.',
    this.tipoEtiqueta,
    this.nombreVisitante,
  });

  static Future<void> show(
    BuildContext context, {
    required String codigo,
    String titulo = 'Pase de Acceso',
    String subtitulo = 'Muestra este código al vigilante en caseta para ingresar.',
    String? tipoEtiqueta,
    String? nombreVisitante,
  }) {
    return showDialog(
      context: context,
      builder: (_) => DigitalPassPreviewDialog(
        codigo: codigo,
        titulo: titulo,
        subtitulo: subtitulo,
        tipoEtiqueta: tipoEtiqueta,
        nombreVisitante: nombreVisitante,
      ),
    );
  }

  @override
  State<DigitalPassPreviewDialog> createState() => _DigitalPassPreviewDialogState();
}

class _DigitalPassPreviewDialogState extends State<DigitalPassPreviewDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareAsPng() async {
    setState(() => _isSharing = true);
    await HapticHelper.light();

    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isSharing = false);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final clean = widget.codigo.trim();

        await HapticHelper.success();
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                pngBytes,
                mimeType: 'image/png',
                name: 'pase_haven_$clean.png',
              ),
            ],
            text: '🔐 ${widget.titulo}\nCódigo: $clean\n${widget.subtitulo}',
            subject: '${widget.titulo}: $clean',
          ),
        );
      }
    } catch (_) {
      await HapticHelper.error();
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: DigitalPassCard(
              codigo: widget.codigo,
              titulo: widget.titulo,
              subtitulo: widget.subtitulo,
              tipoEtiqueta: widget.tipoEtiqueta,
              nombreVisitante: widget.nombreVisitante,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: _isSharing ? null : _shareAsPng,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.share_rounded, size: 18),
                  label: Text(
                    _isSharing ? 'Generando...' : 'Compartir Imagen PNG',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111C99),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
