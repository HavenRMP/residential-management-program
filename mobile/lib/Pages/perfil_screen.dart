import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Services/app_controller.dart';
import '../Themes/app_theme.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({
    super.key,
    required this.controller,
    this.isOnboarding = false,
  });

  final AppController controller;
  final bool isOnboarding;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidosCtrl;
  late final TextEditingController _telefonoCtrl;
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.isOnboarding || widget.controller.isProfileIncomplete;
    final user = widget.controller.currentUser;

    final rawNombre = (user?.nombre ?? '').trim();
    final cleanNombre = rawNombre.toLowerCase() == 'sin nombre'
        ? ''
        : rawNombre;

    _nombreCtrl = TextEditingController(text: cleanNombre);
    _apellidosCtrl = TextEditingController(text: user?.apellidos ?? '');
    _telefonoCtrl = TextEditingController(text: user?.telefono ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidosCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  void _resetFormValues() {
    final user = widget.controller.currentUser;
    final rawNombre = (user?.nombre ?? '').trim();
    final cleanNombre = rawNombre.toLowerCase() == 'sin nombre'
        ? ''
        : rawNombre;
    _nombreCtrl.text = cleanNombre;
    _apellidosCtrl.text = user?.apellidos ?? '';
    _telefonoCtrl.text = user?.telefono ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await widget.controller.completarPerfil(
      _nombreCtrl.text,
      _apellidosCtrl.text,
      _telefonoCtrl.text,
    );

    if (success && mounted) {
      if (widget.isOnboarding) {
        // En onboarding, al guardar se refresca el router automáticamente
      } else {
        setState(() {
          _isEditMode = false;
        });
      }
    }
  }

  String _getInitials() {
    final user = widget.controller.currentUser;
    final n = (user?.nombre ?? '').trim();
    final a = (user?.apellidos ?? '').trim();
    final first = n.isNotEmpty && n.toLowerCase() != 'sin nombre' ? n[0] : '';
    final second = a.isNotEmpty ? a[0] : '';
    final combined = '$first$second'.toUpperCase();
    if (combined.isNotEmpty) return combined;
    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'H';
  }

  Color _getAvatarBgColor() {
    final role = (widget.controller.currentUser?.rol ?? '').toLowerCase();
    if (role.contains('admin')) return const Color(0xFFEEF2FF);
    if (role.contains('vigilan')) return const Color(0xFFFEF3C7);
    return const Color(0xFFECFDF5);
  }

  Color _getAvatarTextColor() {
    final role = (widget.controller.currentUser?.rol ?? '').toLowerCase();
    if (role.contains('admin')) return const Color(0xFF4338CA);
    if (role.contains('vigilan')) return const Color(0xFF92400E);
    return const Color(0xFF047857);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final isEffectiveOnboarding =
        widget.isOnboarding || widget.controller.isProfileIncomplete;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          isEffectiveOnboarding ? 'Completar Registro' : 'Mi Perfil',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: isEffectiveOnboarding
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
        automaticallyImplyLeading: !isEffectiveOnboarding,
        actions: [
          if (isEffectiveOnboarding)
            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text('¿Seguro que quieres salir de sesión?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Salir'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  widget.controller.logout();
                }
              },
              icon: const Icon(
                Icons.logout,
                size: 18,
                color: Color(0xFF64748B),
              ),
              label: const Text(
                'Salir',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Corporativo de Onboarding (Idéntico a Web)
                if (isEffectiveOnboarding)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E293B)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x15000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0x332563EB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x553B82F6)),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: Color(0xFF60A5FA),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registro de información de contacto',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Para habilitar tu acceso al condominio y permitir que la administración vincule tu vivienda, es indispensable registrar tu nombre completo y número telefónico a 10 dígitos.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFCBD5E1),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Tarjeta Principal de Perfil
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x05000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabecera con Avatar
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: _getAvatarBgColor(),
                              child: Text(
                                _getInitials(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getAvatarTextColor(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${user?.nombre ?? 'Usuario'} ${user?.apellidos ?? ''}'
                                        .trim(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      (user?.rol ?? user?.role ?? 'Residente')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // Contenido: Modo Lectura vs Modo Edición
                      if (!_isEditMode && !isEffectiveOnboarding)
                        _buildViewMode(user)
                      else
                        _buildEditMode(isEffectiveOnboarding),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewMode(dynamic user) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoTile(
            label: 'CORREO ELECTRÓNICO',
            value: user?.email ?? 'No disponible',
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            label: 'TELÉFONO',
            value:
                (user?.telefono != null &&
                    (user!.telefono as String).trim().isNotEmpty)
                ? user.telefono
                : 'No registrado',
            icon: Icons.phone_outlined,
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            label: 'ROL EN EL SISTEMA',
            value: user?.rol ?? user?.role ?? 'Residente',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            label: 'MIEMBRO EN',
            value: 'Residencial Haven',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _resetFormValues();
                _isEditMode = true;
              });
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'Editar perfil',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111C99),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode(bool isOnboarding) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isOnboarding ? 'Datos de Contacto' : 'Actualizar Información',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 20),
            const FieldLabel(text: 'Nombre(s) *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nombreCtrl,
              decoration: AppTheme.inputDecoration('Tu nombre oficial'),
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty || text.toLowerCase() == 'sin nombre') {
                  return 'El nombre es obligatorio.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const FieldLabel(text: 'Apellidos *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _apellidosCtrl,
              decoration: AppTheme.inputDecoration('Tus apellidos oficiales'),
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) {
                  return 'Los apellidos son obligatorios.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const FieldLabel(text: 'Teléfono (10 dígitos) *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: AppTheme.inputDecoration('Ej. 4421234567'),
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) {
                  return 'El teléfono es obligatorio.';
                }
                if (text.length != 10) {
                  return 'El teléfono debe tener exactamente 10 dígitos.';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final isLoading = widget.controller.isLoading;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: isLoading ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111C99),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isOnboarding
                                  ? 'Completar registro'
                                  : 'Guardar cambios',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    if (!isOnboarding) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                setState(() {
                                  _resetFormValues();
                                  _isEditMode = false;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }
}
