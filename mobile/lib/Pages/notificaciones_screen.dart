import 'package:flutter/material.dart';
import '../Services/app_controller.dart';
import 'en_construccion_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  void _irAConstruccion(String titulo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnConstruccionScreen(titulo: titulo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notificaciones y Sub-usuarios'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestión de Sub-usuarios',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Puedes invitar hasta 2 sub-usuarios para que tengan acceso a tu vivienda. Las invitaciones tienen una caducidad de 1 día.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.construction_rounded, color: Color(0xFF94A3B8), size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Próximamente',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'La invitación y gestión de sub-usuarios estará disponible pronto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _irAConstruccion('Gestión de Sub-usuarios'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
                    child: const Text('Saber más'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            const Text(
              'Acciones de Sub-usuarios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              'Registrar Visitas',
              'Autoriza la entrada de invitados al condominio.',
              Icons.directions_walk_rounded,
              () => _irAConstruccion('Registrar Visitas'),
            ),
            _buildActionTile(
              'Reservar Áreas',
              'Aparta amenidades del condominio.',
              Icons.pool_rounded,
              () => _irAConstruccion('Reservar Áreas'),
            ),
            _buildActionTile(
              'Autorizar Servicios',
              'Permite la entrada de Uber Eats, Amazon, etc.',
              Icons.delivery_dining_rounded,
              () => _irAConstruccion('Autorizar Servicios'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF111C99)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}
