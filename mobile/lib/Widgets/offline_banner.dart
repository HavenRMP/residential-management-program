import 'package:flutter/material.dart';

/// Banner visual para advertir al usuario que está en modo fuera de línea con datos en caché.
class OfflineBanner extends StatelessWidget {
  final String mensaje;
  final int pendingSyncCount;
  final VoidCallback? onSyncPressed;
  final bool isSyncing;

  const OfflineBanner({
    super.key,
    this.mensaje = 'Modo sin conexión. Mostrando datos guardados.',
    this.pendingSyncCount = 0,
    this.onSyncPressed,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Ámbar suave
        border: const Border(
          bottom: BorderSide(color: Color(0xFFFDE68A), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pendingSyncCount > 0
                  ? '$mensaje ($pendingSyncCount pendientes)'
                  : mensaje,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
                  ],
      ),
    );
  }
}
