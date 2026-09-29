import 'package:flutter/material.dart';
import '../Models/subusuario.dart';
import '../Services/app_controller.dart';
import '../Services/subusuarios_service.dart';

class InvitacionesRecibidasScreen extends StatefulWidget {
  const InvitacionesRecibidasScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<InvitacionesRecibidasScreen> createState() => _InvitacionesRecibidasScreenState();
}

class _InvitacionesRecibidasScreenState extends State<InvitacionesRecibidasScreen> {
  late final SubusuariosService _service;
  bool _isLoading = true;
  List<InvitacionSubusuario> _invitaciones = [];
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _service = SubusuariosService(widget.controller);
    _cargarInvitaciones();
  }

  Future<void> _cargarInvitaciones() async {
    setState(() => _isLoading = true);
    final lista = await _service.getMisInvitaciones();
    if (mounted) {
      setState(() {
        _invitaciones = lista;
        _isLoading = false;
      });
    }
  }

  Future<void> _responder(InvitacionSubusuario inv, bool aceptar) async {
    if (_processingIds.contains(inv.id)) return;

    if (!aceptar) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Rechazar invitación'),
          content: Text(
            '¿Seguro que deseas rechazar la invitación para vincularte a la vivienda #${inv.numeroCasa ?? ''} de ${inv.titularNombre ?? 'el titular'}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    setState(() => _processingIds.add(inv.id));

    final res = await _service.responderInvitacion(inv.id, aceptar: aceptar);

    if (mounted) {
      setState(() => _processingIds.remove(inv.id));

      if (res['success'] == true) {
        widget.controller.notifyToast(
          aceptar
              ? '¡Invitación aceptada! Ya tienes acceso a la vivienda.'
              : 'Invitación rechazada.',
          success: true,
        );
        if (aceptar) {
          await widget.controller.forceRefreshSession();
        }
        await _cargarInvitaciones();
        if (aceptar && mounted && _invitaciones.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        }
      } else {
        widget.controller.notifyToast(
          res['error'] ?? 'No se pudo procesar la respuesta',
          success: false,
        );
      }
    }
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return '';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Invitaciones Recibidas'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF111C99)))
          : RefreshIndicator(
              color: const Color(0xFF111C99),
              onRefresh: _cargarInvitaciones,
              child: _invitaciones.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _invitaciones.length,
                      itemBuilder: (context, index) {
                        final inv = _invitaciones[index];
                        return _buildInvitacionCard(inv);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 64,
                        color: Color(0xFF111C99),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No tienes invitaciones pendientes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cuando el titular de una vivienda te invite con tu correo electrónico, aparecerá aquí para que puedas aceptarla.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvitacionCard(InvitacionSubusuario inv) {
    final isProcessing = _processingIds.contains(inv.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.home_rounded, color: Color(0xFF111C99), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.condominioNombre ?? 'Condominio',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Casa #${inv.numeroCasa ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text(
                  'Pendiente',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Invitado por: ',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Expanded(
                child: Text(
                  inv.titularNombre ?? 'Titular de la vivienda',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.favorite_outline_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Parentesco: ',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Text(
                inv.parentesco,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111C99),
                ),
              ),
            ],
          ),
          if (inv.creadoEn != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  'Recibida: ${_formatFecha(inv.creadoEn)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(color: Color(0xFF111C99)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _responder(inv, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => _responder(inv, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111C99),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Aceptar invitación', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
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
