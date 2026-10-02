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

                  ],
      ),
    );
  }
}
