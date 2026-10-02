import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../Utils/share_helper.dart';

class QrDialog extends StatelessWidget {
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

  void _compartir(BuildContext context, String cleanCode) {
    if (onCompartir != null) {
      onCompartir!();
    } else {
      ShareHelper.compartirCodigo(
        context,
        codigo: cleanCode,
        titulo: titulo,
        subtitulo: subtitulo,
        tipoEtiqueta: tipoEtiqueta,
        textoAdicional: textoAdicional,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanCode = codigo.trim();

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
                        titulo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (tipoEtiqueta != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Text(
                            tipoEtiqueta!,
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
                  onPressed: () => Navigator.of(context).pop(),
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
                    onTap: () => _compartir(context, cleanCode),
                    borderRadius: BorderRadius.circular(6),
                    child: const Tooltip(
                      message: 'Compartir código',
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
              subtitulo,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // Botones de acción: Cerrar y Compartir
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: () => _compartir(context, cleanCode),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Compartir', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111C99),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
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
