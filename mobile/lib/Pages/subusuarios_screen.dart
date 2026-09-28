import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Models/subusuario.dart';
import '../Services/app_controller.dart';
import '../Services/subusuarios_service.dart';

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
  int get _cuposDisponibles => (SubusuariosService.maxSubusuarios - _items.length).clamp(0, SubusuariosService.maxSubusuarios);

  Future<void> _revocarSubusuario(SubusuarioItem item) async {
    final esInvitacion = item.isPendiente;
    final accion = esInvitacion ? 'cancelar la invitación de' : 'revocar el acceso a';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(esInvitacion ? 'Cancelar Invitación' : 'Revocar Sub-usuario'),
        content: Text('¿Seguro que deseas $accion "${item.nombre}"?'),
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
      widget.controller.notifyToast('Has alcanzado el límite máximo de 2 sub-usuarios', success: false);
      return;
    }

    final nombreController = TextEditingController();
    final apellidosController = TextEditingController();
    final emailController = TextEditingController();
    final telController = TextEditingController();
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
                  Icon(Icons.person_add_rounded, color: Color(0xFF111C99)),
                  SizedBox(width: 8),
                  Text('Invitar Sub-usuario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre(s) *', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: apellidosController,
                        decoration: const InputDecoration(labelText: 'Apellidos *', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa los apellidos' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Correo electrónico *', border: OutlineInputBorder()),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: telController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Teléfono (10 dígitos) *', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().length < 10) ? 'Teléfono debe tener 10 dígitos' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: parentesco,
                        decoration: const InputDecoration(labelText: 'Parentesco', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Familiar', child: Text('Familiar')),
                          DropdownMenuItem(value: 'Cónyuge', child: Text('Cónyuge')),
                          DropdownMenuItem(value: 'Hijo/a', child: Text('Hijo/a')),
                          DropdownMenuItem(value: 'Padre/Madre', child: Text('Padre/Madre')),
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
      final res = await _service.invitarSubusuario(
        viviendaId: widget.viviendaId,
        nombre: nombreController.text,
        apellidos: apellidosController.text,
        email: emailController.text,
        telefono: telController.text,
        parentesco: parentesco,
      );

      if (mounted) {
        if (res['success'] == true) {
          final SubusuarioItem? nuevo = res['item'] as SubusuarioItem?;
          widget.controller.notifyToast('Invitación creada exitosamente', success: true);
          _cargarSubusuarios();

          if (nuevo?.codigo != null && nuevo!.codigo!.isNotEmpty) {
            _mostrarCodigoGenerado(nuevo.codigo!);
          }
        } else {
          widget.controller.notifyToast(res['error'] ?? 'Error al invitar sub-usuario', success: false);
        }
      }
    }
  }

  void _mostrarCodigoGenerado(String codigo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código de Invitación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Comparte este código con tu sub-usuario. Tiene una vigencia de 1 día.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    codigo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF111C99),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF111C99), size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codigo));
                      widget.controller.notifyToast('Código copiado al portapapeles', success: true);
                    },
                    tooltip: 'Copiar código',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
                  const SizedBox(height: 80), // espacio para el FAB
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
            'Has utilizado $cuposUsados de $total cupos permitidos. Cada sub-usuario podrá ver avisos y pre-registrar visitas.',
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
                'No hay invitaciones pendientes por redimir.',
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
                  item.isActivo ? Icons.person_rounded : Icons.hourglass_top_rounded,
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
                      item.nombre,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
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
                        Text(
                          item.isActivo ? 'Activo' : 'Pendiente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.isActivo ? const Color(0xFF059669) : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                onPressed: () => _revocarSubusuario(item),
                tooltip: item.isActivo ? 'Revocar sub-usuario' : 'Cancelar invitación',
              ),
            ],
          ),
          if (item.email.isNotEmpty && item.email != 'Pendiente') ...[
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
          if (item.codigo != null && item.codigo!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Código: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E3A8A)),
                      ),
                      Text(
                        item.codigo!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Color(0xFF111C99),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item.codigo!));
                      widget.controller.notifyToast('Código copiado al portapapeles', success: true);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: Color(0xFF111C99)),
                          SizedBox(width: 4),
                          Text('Copiar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111C99))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
