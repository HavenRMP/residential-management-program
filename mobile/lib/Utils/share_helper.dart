import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  /// Comparte un código formateado con detalles contextuales.
  static Future<void> compartirCodigo(
    BuildContext context, {
    required String codigo,
    String? titulo,
    String? subtitulo,
    String? tipoEtiqueta,
    String? textoAdicional,
  }) async {
    final cleanCode = codigo.trim();
    if (cleanCode.isEmpty) return;

    Rect? origin;
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
        origin = box.localToGlobal(Offset.zero) & box.size;
      }
    } catch (_) {}

    final buffer = StringBuffer();
    if (titulo != null && titulo.trim().isNotEmpty) {
      buffer.writeln('🔐 ${titulo.trim()}');
    } else {
      buffer.writeln('🔐 Código HAVEN');
    }

    if (tipoEtiqueta != null && tipoEtiqueta.trim().isNotEmpty) {
      buffer.writeln('📍 ${tipoEtiqueta.trim()}');
    }

    buffer.writeln('\nCódigo: $cleanCode');

    if (subtitulo != null && subtitulo.trim().isNotEmpty) {
      buffer.writeln('\n${subtitulo.trim()}');
    }

    if (textoAdicional != null && textoAdicional.trim().isNotEmpty) {
      buffer.writeln('\n${textoAdicional.trim()}');
    }

    buffer.writeln('\n— Generado desde HAVEN Residencial —');

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString().trim(),
        subject: titulo != null && titulo.isNotEmpty
            ? '$titulo: $cleanCode'
            : 'Código HAVEN: $cleanCode',
        sharePositionOrigin: origin,
      ),
    );
  }
}
