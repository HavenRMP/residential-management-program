import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Models/paquete_model.dart';
import '../Utils/haptic_helper.dart';

class PaqueteCard extends StatelessWidget {
  final PaqueteModel paquete;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onReceive;
  final VoidCallback? onDeliver;
  final bool showCasetaActions;

  const PaqueteCard({
    super.key,
    required this.paquete,
    this.onTap,
    this.onEdit,
    this.onCancel,
    this.onReceive,
    this.onDeliver,
    this.showCasetaActions = false,
  });

  Color _getEstadoColor() {
    switch (paquete.estado.toLowerCase()) {
      case 'esperado':
        return const Color(0xFF2563EB); // Blue
      case 'recibido':
        return const Color(0xFF059669); // Emerald
      case 'entregado':
        return const Color(0xFF475569); // Slate
      case 'cancelado':
        return const Color(0xFFDC2626); // Red
      case 'vencido':
        return const Color(0xFFD97706); // Amber
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getEstadoBgColor() {
    switch (paquete.estado.toLowerCase()) {
      case 'esperado':
        return const Color(0xFFEFF6FF);
      case 'recibido':
        return const Color(0xFFECFDF5);
      case 'entregado':
        return const Color(0xFFF1F5F9);
      case 'cancelado':
        return const Color(0xFFFEF2F2);
      case 'vencido':
        return const Color(0xFFFFFBEB);
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  IconData _getServicioIcon() {
    final nombre = (paquete.servicioNombre ?? '').toLowerCase();
    if (nombre.contains('amazon')) return Icons.shopping_bag_outlined;
    if (nombre.contains('mercado')) return Icons.handshake_outlined;
    if (nombre.contains('dhl') || nombre.contains('fedex') || nombre.contains('ups')) {
      return Icons.local_shipping_outlined;
    }
    return Icons.inventory_2_outlined;
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'N/A';
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final y = fecha.year;
    final h = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = _getEstadoColor();
    final estadoBg = _getEstadoBgColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paquete.isRecibido ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
          width: paquete.isRecibido ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: paquete.isRecibido
                ? const Color(0xFF059669).withValues(alpha: 0.08)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado: Empresa y Estado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getServicioIcon(),
                        color: const Color(0xFF111C99),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paquete.servicioNombre != null && paquete.servicioNombre!.isNotEmpty
                                ? paquete.servicioNombre!
                                : 'Paquetería',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Destinatario: ${paquete.destinatarioNombre}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: estadoBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: estadoColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: estadoColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            paquete.estadoLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: estadoColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Información de casa y guía
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.home_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Casa #${paquete.numeroCasa}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (paquete.numeroGuia != null && paquete.numeroGuia!.isNotEmpty) ...[
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            HapticHelper.light();
                            Clipboard.setData(ClipboardData(text: paquete.numeroGuia!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Número de guía copiado'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code_2_rounded, size: 15, color: Color(0xFF111C99)),
                                const SizedBox(width: 4),
                                Text(
                                  paquete.numeroGuia!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111C99),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Ubicación en almacén si está en caseta
                if (paquete.ubicacionAlmacen != null && paquete.ubicacionAlmacen!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 15, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ubicación en caseta: ${paquete.ubicacionAlmacen}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Fechas
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        paquete.isRecibido
                            ? 'Recibido: ${_formatFecha(paquete.recibidoEn)}'
                            : paquete.isEntregado
                                ? 'Entregado: ${_formatFecha(paquete.entregadoEn)}'
                                : 'Registrado: ${_formatFecha(paquete.creadoEn)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),

                // Entrega a nombre de
                if (paquete.isEntregado && paquete.entregadoANombre != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.how_to_reg_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Recibió: ${paquete.entregadoANombre}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ],

                // Botones de acción según el rol y estado
                if (!showCasetaActions && paquete.isEsperado) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onCancel != null)
                        TextButton.icon(
                          onPressed: () {
                            HapticHelper.light();
                            onCancel!();
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                          label: const Text(
                            'Cancelar',
                            style: TextStyle(color: Color(0xFFDC2626), fontSize: 12.5),
                          ),
                        ),
                      if (onEdit != null) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            HapticHelper.light();
                            onEdit!();
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Modificar', style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ],
                  ),
                ],

                if (showCasetaActions) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (paquete.isEsperado && onReceive != null)
                        FilledButton.icon(
                          onPressed: () {
                            HapticHelper.light();
                            onReceive!();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Recibir en Caseta', style: TextStyle(fontSize: 12.5)),
                        ),
                      if (paquete.isRecibido && onDeliver != null)
                        FilledButton.icon(
                          onPressed: () {
                            HapticHelper.light();
                            onDeliver!();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF111C99),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.handshake_outlined, size: 16),
                          label: const Text('Entregar a Residente', style: TextStyle(fontSize: 12.5)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
