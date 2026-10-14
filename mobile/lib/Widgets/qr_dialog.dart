import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../Utils/share_helper.dart';
import '../Utils/haptic_helper.dart';
import '../Utils/brightness_helper.dart';
import 'digital_pass_card.dart';

class QrDialog extends StatefulWidget {
  const QrDialog({
    super.key,
    required this.codigo,
    this.titulo = 'Código de Acceso',
    this.subtitulo = 'Muestra este código QR en la caseta para validar tu acceso.',
    this.tipoEtiqueta,
    this.textoAdicional,
    this.onCompartir,
  });

  final String codigo;
  final String titulo;
  final String subtitulo;
  final String? tipoEtiqueta;
  final String? textoAdicional;
  final VoidCallback? onCompartir;

  static Future<void> show(
    BuildContext context, {
    required String codigo,
    String titulo = 'Código de Acceso',
    String subtitulo = 'Muestra este código QR en la caseta para validar tu acceso.',
    String? tipoEtiqueta,
    String? textoAdicional,
    VoidCallback? onCompartir,
  }) {
    return showDialog(
      context: context,
      builder: (_) => QrDialog(
        codigo: codigo,
        titulo: titulo,
        subtitulo: subtitulo,
        tipoEtiqueta: tipoEtiqueta,
        textoAdicional: textoAdicional,
        onCompartir: onCompartir,
      ),
    );
  }

  @override
  State<QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<QrDialog> {
  @override
  void initState() {
    super.initState();
    BrightnessHelper.setMaxBrightness();
  }

  @override
  void dispose() {
    BrightnessHelper.resetBrightness();
    super.dispose();
  }

  void _compartir(BuildContext context, String cleanCode) {
    if (widget.onCompartir != null) {
      HapticHelper.light();
      widget.onCompartir!();
    } else {
      _compartirPng(context, cleanCode);
    }
  }

  void _compartirTexto(BuildContext context, String cleanCode) {
    HapticHelper.light();
    ShareHelper.compartirCodigo(
      context,
      codigo: cleanCode,
      titulo: widget.titulo,
      subtitulo: widget.subtitulo,
      tipoEtiqueta: widget.tipoEtiqueta,
      textoAdicional: widget.textoAdicional,
    );
  }

  void _compartirPng(BuildContext context, String cleanCode) {
    HapticHelper.selection();
    DigitalPassPreviewDialog.show(
      context,
      codigo: cleanCode,
      titulo: widget.titulo,
      subtitulo: widget.subtitulo,
      tipoEtiqueta: widget.tipoEtiqueta,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanCode = widget.codigo.trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header con título y botón de cerrar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titulo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (widget.tipoEtiqueta != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Text(
                            widget.tipoEtiqueta!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111C99),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    HapticHelper.light();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contenedor del código QR
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: cleanCode,
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(4),
              ),
            ),
            const SizedBox(height: 16),

            // Código alfanumérico
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cleanCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      HapticHelper.success();
                      Clipboard.setData(ClipboardData(text: cleanCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código copiado al portapapeles'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Tooltip(
                      message: 'Copiar código',
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _compartirPng(context, cleanCode),
                    borderRadius: BorderRadius.circular(6),
                    child: const Tooltip(
                      message: 'Generar tarjeta PNG',
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.image_outlined, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _compartirTexto(context, cleanCode),
                    borderRadius: BorderRadius.circular(6),
                    child: const Tooltip(
                      message: 'Compartir texto',
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.share_rounded, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Subtítulo explicativo
            Text(
              widget.subtitulo,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // Botones de acción: Cerrar, Compartir Texto y Compartir Imagen PNG
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () {
                    HapticHelper.light();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _compartirPng(context, cleanCode),
                  icon: const Icon(Icons.image_outlined, size: 17),
                  label: const Text('Pase PNG', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111C99),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _compartir(context, cleanCode),
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: const Text('Compartir', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111C99),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
