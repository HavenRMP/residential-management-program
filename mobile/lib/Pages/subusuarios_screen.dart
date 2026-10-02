import 'package:flutter/material.dart';
import '../Models/subusuario.dart';
import '../Services/app_controller.dart';
import '../Services/subusuarios_service.dart';
import '../Widgets/qr_dialog.dart';
import 'invitaciones_recibidas_screen.dart';
import '../Utils/share_helper.dart';

class SubusuariosScreen extends StatefulWidget {
  const SubusuariosScreen({
    super.key,
    required this.controller,
    required this.viviendaId,
    required this.numeroCasa,
  });

  final AppController controller;
  final int viviendaId;
  final String numeroCasa;

  @override
  State<SubusuariosScreen> createState() => _SubusuariosScreenState();
}

class _SubusuariosScreenState extends State<SubusuariosScreen> {
  late final SubusuariosService _service;
  bool _isLoading = true;
  List<SubusuarioItem> _items = [];

  @override
  void initState() {
    super.initState();
    _service = SubusuariosService(widget.controller);
    _cargarSubusuarios();
  }

  Future<void> _cargarSubusuarios() async {
    setState(() => _isLoading = true);
    final lista = await _service.getSubusuarios(widget.viviendaId);
    if (mounted) {
      setState(() {
        _items = lista;
        _isLoading = false;
      });
    }
  }

  List<SubusuarioItem> get _activos => _items.where((i) => i.isActivo).toList();
  List<SubusuarioItem> get _pendientes => _items.where((i) => i.isPendiente).toList();
  int get _cuposDisponibles =>
      (SubusuariosService.maxSubusuarios - _items.length).clamp(0, SubusuariosService.maxSubusuarios);

  Future<void> _revocarSubusuario(SubusuarioItem item) async {
    final esInvitacion = item.isPendiente;
    final accion = esInvitacion ? 'cancelar la invitación enviada a' : 'revocar el acceso a';
    final identificador = (item.email.isNotEmpty && item.email != 'Desconocido')
        ? item.email
        : item.nombre;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(esInvitacion ? 'Cancelar Invitación' : 'Revocar Sub-usuario'),
        content: Text('¿Seguro que deseas $accion "$identificador"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: Text(esInvitacion ? 'Cancelar invitación' : 'Revocar acceso'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final success = await _service.revocarSubusuario(
      item.id,
      viviendaId: widget.viviendaId,
      isInvitacion: esInvitacion,
    );

    if (mounted) {
      if (success) {
        widget.controller.notifyToast(
          esInvitacion ? 'Invitación cancelada' : 'Sub-usuario revocado',
          success: true,
        );
        _cargarSubusuarios();
      } else {
        widget.controller.notifyToast('No se pudo procesar la solicitud', success: false);
      }
    }
  }

  Future<void> _mostrarModalInvitar() async {
    if (_cuposDisponibles <= 0) {
      widget.controller.notifyToast(
        'Has alcanzado el límite máximo de 2 sub-usuarios',
        success: false,
      );
      return;
    }

    final emailController = TextEditingController();
    String parentesco = 'Familiar';
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.mark_email_read_rounded, color: Color(0xFF111C99)),
                  SizedBox(width: 8),
                  Text('Invitar Sub-usuario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF1E3A8A), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'El invitado debe haber creado su cuenta en HAVEN primero con este correo.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico del invitado *',
                          hintText: 'ejemplo@correo.com',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa el correo electrónico';
                          if (!v.contains('@') || !v.contains('.')) return 'Ingresa un correo electrónico válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: parentesco,
                        decoration: const InputDecoration(
                          labelText: 'Parentesco',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people_alt_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Familiar', child: Text('Familiar')),
                          DropdownMenuItem(value: 'Cónyuge', child: Text('Cónyuge')),
                          DropdownMenuItem(value: 'Hijo/a', child: Text('Hijo/a')),
                          DropdownMenuItem(value: 'Padre/Madre', child: Text('Padre/Madre')),
                          DropdownMenuItem(value: 'Hermano/a', child: Text('Hermano/a')),
                          DropdownMenuItem(value: 'Inquilino/a', child: Text('Inquilino/a')),
                          DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => parentesco = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() == true) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
                  child: const Text('Enviar Invitación'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == true) {
      widget.controller.notifyToast('Enviando invitación...', success: true);
      final res = await _service.invitarSubusuario(
        viviendaId: widget.viviendaId,
        email: emailController.text.trim(),
        parentesco: parentesco,
      );

      if (mounted) {
        if (res['success'] == true) {
          widget.controller.notifyToast(
            'Invitación enviada con éxito. Se notificó al usuario.',
            success: true,
          );
          _cargarSubusuarios();

          final itemObj = res['item'];
          final String? itemCodigo = itemObj is SubusuarioItem ? itemObj.codigo : null;
          final codigo = res['codigo']?.toString() ?? itemCodigo;
          if (codigo != null && codigo.isNotEmpty && mounted) {
            QrDialog.show(
              context,
              codigo: codigo,
              titulo: 'Código de Invitación',
              subtitulo:
                  'Comparte este código o pide a tu familiar que lo escanee desde su aplicación HAVEN para vincularse de inmediato a la casa #${widget.numeroCasa}.',
            );
          }
        } else {
          widget.controller.notifyToast(
            res['error'] ?? 'Error al invitar sub-usuario',
            success: false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Sub-usuarios Casa #${widget.numeroCasa}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_rounded, color: Color(0xFF111C99)),
            tooltip: 'Mis Invitaciones Recibidas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvitacionesRecibidasScreen(controller: widget.controller),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarModalInvitar,
        backgroundColor: _cuposDisponibles > 0 ? const Color(0xFF111C99) : const Color(0xFF94A3B8),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Invitar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF111C99)))
          : RefreshIndicator(
              color: const Color(0xFF111C99),
              onRefresh: _cargarSubusuarios,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCuposCard(),
                  const SizedBox(height: 20),
                  _buildSeccionActivos(),
                  const SizedBox(height: 24),
                  _buildSeccionPendientes(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildCuposCard() {
    final cuposUsados = _items.length;
    final total = SubusuariosService.maxSubusuarios;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cupo de Vivienda',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _cuposDisponibles > 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _cuposDisponibles > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Text(
                  '$_cuposDisponibles cupo${_cuposDisponibles == 1 ? '' : 's'} disponible${_cuposDisponibles == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _cuposDisponibles > 0 ? const Color(0xFF047857) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: cuposUsados / total,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              color: cuposUsados < total ? const Color(0xFF111C99) : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Has utilizado $cuposUsados de $total cupos permitidos. Cada sub-usuario vinculado podrá ver avisos y pre-registrar visitas.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionActivos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_alt_rounded, size: 20, color: Color(0xFF111C99)),
            const SizedBox(width: 8),
            Text(
              'Sub-usuarios Activos (${_activos.length})',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_activos.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No hay sub-usuarios activos en esta vivienda.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          )
        else
          ..._activos.map(_buildSubusuarioCard),
      ],
    );
  }

  Widget _buildSeccionPendientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mail_outline_rounded, size: 20, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Text(
              'Invitaciones Pendientes (${_pendientes.length})',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pendientes.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No hay invitaciones pendientes.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          )
        else
          ..._pendientes.map(_buildSubusuarioCard),
      ],
    );
  }

  Widget _buildSubusuarioCard(SubusuarioItem item) {
    final esPendiente = item.isPendiente;
    final titulo = esPendiente
        ? (item.email.isNotEmpty && item.email != 'Desconocido' ? item.email : 'Invitación enviada')
        : item.nombre;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isActivo ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: item.isActivo ? const Color(0xFFEEF2FF) : const Color(0xFFFFFBEB),
                child: Icon(
                  item.isActivo ? Icons.person_rounded : Icons.mail_outline_rounded,
                  color: item.isActivo ? const Color(0xFF111C99) : const Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.parentesco,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.isActivo ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.isActivo ? 'Activo' : 'Pendiente de aceptación',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: item.isActivo ? const Color(0xFF059669) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (esPendiente && item.codigo != null && item.codigo!.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF111C99)),
                  tooltip: 'Compartir código de invitación',
                  onPressed: () {
                    ShareHelper.compartirCodigo(
                      context,
                      codigo: item.codigo!,
                      titulo: 'Invitación de Sub-usuario',
                      subtitulo:
                          'Muestra este código o compártelo para que tu familiar se vincule a la casa #${widget.numeroCasa}.',
                      tipoEtiqueta: 'Casa #${widget.numeroCasa}',
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF111C99)),
                  tooltip: 'Ver código QR de invitación',
                  onPressed: () {
                    QrDialog.show(
                      context,
                      codigo: item.codigo!,
                      titulo: 'Invitación de Sub-usuario',
                      subtitulo:
                          'Muestra este código QR o compártelo para que tu familiar se vincule a la casa #${widget.numeroCasa}.',
                    );
                  },
                ),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                onPressed: () => _revocarSubusuario(item),
                tooltip: item.isActivo ? 'Revocar sub-usuario' : 'Cancelar invitación',
              ),
            ],
          ),
          if (!esPendiente && item.email.isNotEmpty && item.email != 'Pendiente') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(item.email, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ],
          if (item.telefono.isNotEmpty && item.telefono != 'Pendiente') ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(item.telefono, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ],
          if (esPendiente) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Esperando a que el invitado acepte desde su app HAVEN',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                  ),
                ),
                if (item.codigo != null && item.codigo!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          QrDialog.show(
                            context,
                            codigo: item.codigo!,
                            titulo: 'Invitación de Sub-usuario',
                            subtitulo:
                                'Muestra este código QR o compártelo para que tu familiar se vincule a la casa #${widget.numeroCasa}.',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_rounded, size: 15, color: Color(0xFF111C99)),
                              const SizedBox(width: 4),
                              Text(
                                item.codigo!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: Color(0xFF111C99),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => ShareHelper.compartirCodigo(
                          context,
                          codigo: item.codigo!,
                          titulo: 'Invitación de Sub-usuario',
                          subtitulo:
                              'Muestra este código o compártelo para que tu familiar se vincule a la casa #${widget.numeroCasa}.',
                          tipoEtiqueta: 'Casa #${widget.numeroCasa}',
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Tooltip(
                            message: 'Compartir código',
                            child: Icon(Icons.share_rounded, size: 13, color: Color(0xFF111C99)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
