import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Services/app_controller.dart';
import '../Services/push_notifications_service.dart';
import '../Services/condominios_service.dart';
import '../Services/viviendas_service.dart';
import '../Services/avisos_service.dart';
import '../Models/auth_user.dart';
import 'avisos_residente_screen.dart';
import 'perfil_screen.dart';

class ResidenteDashboardScreen extends StatefulWidget {
  const ResidenteDashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ResidenteDashboardScreen> createState() =>
      _ResidenteDashboardScreenState();
}

class _ResidenteDashboardScreenState extends State<ResidenteDashboardScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _misViviendas = [];
  bool _isLoadingViviendas = true;
  int _unreadAvisosCount = 0;

  @override
  void initState() {
    super.initState();
    _cargarMisViviendas();
    _solicitarPermisos();
    _checkUnreadAvisos();
  }

  Future<void> _checkUnreadAvisos() async {
    try {
      final srv = AvisosService(widget.controller);
      final res = await srv.getAvisosVigentes(page: 1, pageSize: 50);
      if (res != null) {
        final items = res['items'] as List<dynamic>? ?? [];
        final prefs = await SharedPreferences.getInstance();
        final readIds = prefs.getStringList('read_avisos') ?? <String>[];
        
        int unread = 0;
        for (var aviso in items) {
          final id = aviso['id']?.toString() ?? '';
          if (id.isNotEmpty && !readIds.contains(id)) {
            unread++;
          }
        }
        
        if (mounted) {
          setState(() => _unreadAvisosCount = unread);
        }
      }
    } catch (_) {}
  }

  Future<void> _solicitarPermisos() async {
    await PushNotificationsService.requestPermission();
  }

  bool _isRedeeming = false;
  final _codigoController = TextEditingController();

  Future<void> _redimirCodigo() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) return;

    setState(() => _isRedeeming = true);
    
    final vivService = ViviendasService(widget.controller);
    final condService = CondominiosService(widget.controller);
    
    final userId = widget.controller.currentUser?.id;
    bool exitoso = false;
    String errorMsg = 'Código inválido o expirado';

    // Intentar redimir como código de condominio primero
    try {
      final resCond = await condService.redimirCodigo(codigo, usuarioId: userId);
      if (resCond != null && resCond['success'] == true) {
        exitoso = true;
      } else if (resCond != null && resCond['error'] != null) {
        errorMsg = resCond['error'];
      }
    } catch (_) {}

    // Si no funcionó como condominio, intentar como vivienda
    if (!exitoso) {
      try {
        final resViv = await vivService.redimirCodigo(codigo, usuarioId: userId);
        if (resViv != null && resViv['success'] == true) {
          exitoso = true;
        } else if (resViv != null && resViv['error'] != null) {
          // Priority to the vivienda error if it failed here too
          errorMsg = resViv['error'];
        }
      } catch (_) {}
    }

    setState(() => _isRedeeming = false);

    if (exitoso) {
      widget.controller.notifyToast('¡Código validado exitosamente!', success: true);
      _codigoController.clear();
      // Allow backend trigger to apply changes
      await Future.delayed(const Duration(milliseconds: 800));
      await widget.controller.forceRefreshSession();
      // Wait for profile and state to settle
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _checkUnreadAvisos();
        _cargarMisViviendas();
      }
    } else {
      widget.controller.notifyToast(errorMsg, success: false);
    }
  }

  Future<void> _cargarMisViviendas() async {
    setState(() => _isLoadingViviendas = true);
    try {
      final list = await widget.controller.obtenerMisViviendas();
      if (mounted) {
        setState(() {
          _misViviendas = list;
          _isLoadingViviendas = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _misViviendas = [];
          _isLoadingViviendas = false;
        });
      }
    }
  }

  bool _hasTelefono() {
    final tel = widget.controller.currentUser?.telefono;
    return tel != null && tel.trim().length >= 10 && tel != 'No registrado';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final nombre = user?.nombre ?? 'Residente';
    final hasCondominio = user?.condominioId != null && user?.condominioId!.isNotEmpty == true;

    final List<Widget> pages = [
      _buildHomePage(nombre, user),
      if (hasCondominio) AvisosResidenteScreen(
        controller: widget.controller,
        onAvisoRead: () {
          if (mounted && _unreadAvisosCount > 0) {
            setState(() => _unreadAvisosCount--);
          }
        },
      ),
      PerfilScreen(controller: widget.controller),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: () {
            setState(() => _currentIndex = 2);
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF059669),
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'R',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Residente',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
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
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                widget.controller.logout();
              }
            },
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
              if (hasCondominio && index == 1) {
                 _checkUnreadAvisos();
              }
            });
          },
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          indicatorColor: const Color(0xFFEEF2FF),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF111C99)),
              label: 'Inicio',
            ),
            if (hasCondominio)
              NavigationDestination(
                icon: _unreadAvisosCount > 0 
                  ? Badge(label: Text('$_unreadAvisosCount'), child: const Icon(Icons.campaign_outlined, color: Color(0xFF64748B)))
                  : const Icon(Icons.campaign_outlined, color: Color(0xFF64748B)),
                selectedIcon: _unreadAvisosCount > 0
                  ? Badge(label: Text('$_unreadAvisosCount'), child: const Icon(Icons.campaign_rounded, color: Color(0xFF111C99)))
                  : const Icon(Icons.campaign_rounded, color: Color(0xFF111C99)),
                label: 'Avisos',
              ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF111C99)),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage(String nombre, AuthUser? user) {
    return RefreshIndicator(
      color: const Color(0xFF111C99),
      onRefresh: _cargarMisViviendas,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero de Bienvenida
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola, $nombre!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (user?.condominioId != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.business, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              const Text(
                                'Condominio Vinculado',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Bienvenido a tu portal condominal.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Módulo "Mi Vivienda"
                if (_isLoadingViviendas)
                  _buildLoadingVivienda()
                else if (_misViviendas.isNotEmpty)
                  _buildViviendasAsignadas()
                else
                  _buildViviendaPendiente(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingVivienda() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: Color(0xFF111C99)),
        ),
      ),
    );
  }

  Widget _buildViviendasAsignadas() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: Color(0xFF111C99),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mi Vivienda',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Unidades asociadas a tu cuenta',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._misViviendas.map((v) {
            final numCasa = (v['numeroCasa'] ?? 'S/N').toString();
            final tipo = (v['tipo'] ?? 'Residencial').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Casa #$numCasa',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Text(
                          'Activa',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tipo: $tipo',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildViviendaPendiente() {
    final user = widget.controller.currentUser;
    final telefono = user?.telefono ?? 'No registrado';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.home_work_outlined,
                      color: Color(0xFF111C99),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Mi Vivienda',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 12, color: Color(0xFFB45309)),
                    SizedBox(width: 4),
                    Text(
                      'Pendiente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asignación de unidad en proceso',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'La administración verificará tu número de teléfono y asociará tu vivienda correspondiente.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),
                _buildStatusItem(
                  title: 'Cuenta de Residente',
                  subtitle: user?.email ?? 'Activo',
                  isDone: true,
                ),
                const SizedBox(height: 10),
                _buildStatusItem(
                  title: 'Teléfono de Contacto',
                  subtitle: telefono,
                  isDone: _hasTelefono(),
                ),
                const SizedBox(height: 10),
                _buildStatusItem(
                  title: 'Vivienda Condominal',
                  subtitle: 'En espera de vinculación',
                  isDone: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _currentIndex = 2),
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text(
                'Actualizar mi perfil de contacto',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111C99),
                side: const BorderSide(color: Color(0xFF111C99)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '¿Tienes un código de vinculación?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codigoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Ingresa el código (ej. A1B2C3)',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isRedeeming ? null : _redimirCodigo,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111C99),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isRedeeming 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Redimir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildStatusItem({
    required String title,
    required String subtitle,
    required bool isDone,
  }) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: isDone ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDone
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// VIGILANTE SCREEN
// ==========================================
