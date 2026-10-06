import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../Services/app_controller.dart';
import '../Widgets/banner_widget.dart';
import '../Utils/haptic_helper.dart';

class RegistroResidenteScreen extends StatefulWidget {
  const RegistroResidenteScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<RegistroResidenteScreen> createState() =>
      _RegistroResidenteScreenState();
}

class _RegistroResidenteScreenState extends State<RegistroResidenteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isSubmittingGoogle = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _localError;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
            letterSpacing: 0.6,
          ),
          children: const [
            TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF111C99), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _localError = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ok = await widget.controller.registerResidente(
        nombre: _nombreController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        telefono: _telefonoController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (ok && mounted) {
        // Si el registro fue exitoso y el router detecta sesión o completado, cerramos la pantalla
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => _isSubmittingGoogle = true);
    try {
      await widget.controller.loginWithGoogle();
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingGoogle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final errorMessage = _localError ?? widget.controller.errorMessage;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icono Casa Haven
                      Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE0E7FF)),
                          ),
                          child: const Icon(
                            Icons.home_rounded,
                            size: 32,
                            color: Color(0xFF111C99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Título y Subtítulo
                      const Text(
                        'Crear cuenta de residente',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Regístrate para acceder al portal y solicitar la vinculación a tu vivienda',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Banner de Error
                      if (errorMessage != null) ...[
                        BannerWidget(message: errorMessage),
                        const SizedBox(height: 16),
                      ],

                      // Fila 1: Nombre y Apellidos
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('NOMBRE'),
                                TextFormField(
                                  controller: _nombreController,
                                  decoration: _inputDecoration(
                                    'Ej. Juan Carlos',
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                  validator: (v) {
                                    final t = (v ?? '').trim();
                                    if (t.isEmpty ||
                                        t.toLowerCase() == 'sin nombre') {
                                      return 'Requerido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('APELLIDOS'),
                                TextFormField(
                                  controller: _apellidosController,
                                  decoration: _inputDecoration(
                                    'Ej. Pérez Gómez',
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? 'Requerido'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Teléfono de Contacto
                      _buildLabel('TELÉFONO DE CONTACTO'),
                      TextFormField(
                        controller: _telefonoController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _inputDecoration(
                          '10 dígitos numéricos (ej. 4421234567)',
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'El teléfono es obligatorio';
                          if (t.length != 10) {
                            return 'Debe tener exactamente 10 dígitos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Correo Electrónico
                      _buildLabel('CORREO ELECTRÓNICO'),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('tu@correo.com'),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'El correo es obligatorio';
                          if (!t.contains('@') || !t.contains('.')) {
                            return 'Ingresa un correo electrónico válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Fila 4: Contraseña y Confirmar Contraseña
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('CONTRASEÑA'),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: _inputDecoration(
                                    'Mínimo 6 caracteres',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 18,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if ((v ?? '').isEmpty) return 'Requerida';
                                    if ((v ?? '').length < 6) {
                                      return 'Mín. 6 car.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('CONFIRMAR CONTRASEÑA'),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  decoration: _inputDecoration(
                                    'Repite la contraseña',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 18,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if ((v ?? '').isEmpty) return 'Requerida';
                                    if (v != _passwordController.text) {
                                      return 'No coincide';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Botón: Crear mi cuenta
                      ElevatedButton(
                        onPressed: _isSubmitting || _isSubmittingGoogle
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111C99),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF111C99)
                              .withValues(alpha: 0.6),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Crear mi cuenta',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),

                      // Divisor "o"
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'o',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Botón: Registrarme con Google
                      OutlinedButton.icon(
                        onPressed: _isSubmitting || _isSubmittingGoogle
                            ? null
                            : _submitGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isSubmittingGoogle
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : SvgPicture.asset(
                                'assets/google.svg',
                                width: 20,
                                height: 20,
                              ),
                        label: Text(
                          _isSubmittingGoogle
                              ? 'Redirigiendo...'
                              : 'Registrarme con Google',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Footer: ¿Ya tienes una cuenta registrada? Inicia sesión aquí
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿Ya tienes una cuenta registrada? ',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticHelper.light();
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Inicia sesión aquí',
                              style: TextStyle(
                                color: Color(0xFF111C99),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
