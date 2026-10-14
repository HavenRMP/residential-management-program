import 'package:flutter/material.dart';
import '../Services/app_controller.dart';
import '../Services/biometric_service.dart';
import '../Utils/haptic_helper.dart';

/// Pantalla de bloqueo biométrico que protege el acceso a la sesión activa
/// si el usuario activó la autenticación con huella o reconocimiento facial.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({
    super.key,
    required this.controller,
    this.biometricService,
  });

  final AppController controller;
  final BiometricService? biometricService;

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  late final BiometricService _biometricService;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _biometricService = widget.biometricService ?? BiometricService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final success = await _biometricService.authenticate(
        localizedReason: 'Confirma tu identidad para desbloquear HAVEN',
      );

      if (success && mounted) {
        widget.controller.unlockBiometric();
        HapticHelper.success();
      } else if (mounted) {
        HapticHelper.error();
      }
    } catch (_) {
      if (mounted) {
        HapticHelper.error();
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final userName = (user?.nombre ?? '').trim().isNotEmpty
        ? user!.nombre!
        : 'Usuario';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Escudo Haven
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF111C99), Color(0xFF1E1B4B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2A111C99),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'HAVEN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Color(0xFF111C99),
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Aplicación Bloqueada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'Hola, $userName. Confirma tus datos biométricos para acceder a tu sesión.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Botón Desbloquear
                  FilledButton.icon(
                    key: const Key('btn_desbloquear_biometria'),
                    onPressed: _isAuthenticating ? null : _authenticate,
                    icon: _isAuthenticating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.fingerprint_rounded, size: 20),
                    label: Text(
                      _isAuthenticating ? 'Verificando...' : 'Desbloquear con biometría',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111C99),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Botón Salir / Cerrar Sesión
                  OutlinedButton.icon(
                    key: const Key('btn_cerrar_sesion_lock'),
                    onPressed: () {
                      HapticHelper.light();
                      widget.controller.logout();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
