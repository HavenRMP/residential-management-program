import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../Services/app_controller.dart';
import '../Services/condominios_service.dart';
import '../Services/viviendas_service.dart';
import 'residentes_list.dart';
import 'viviendas_list.dart';
import 'avisos_admin_screen.dart';
import 'perfil_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  bool _isGeneratingCode = false;
  int _totalViviendas = 0;
  int _totalResidentes = 0;
  int _viviendasOcupadas = 0;
  bool _isLoadingStats = true;
  bool _isSystemOnline = false;
  String _dbVersionText = 'Base de datos operativa';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final viviendasSrv = ViviendasService(widget.controller);
      final viviendas = await viviendasSrv.listar();
      
      int ocupadas = 0;
      if (viviendas.isNotEmpty) {
        final asignaciones = await Future.wait(
          viviendas.map((v) => viviendasSrv.obtenerResidentesVivienda(v['id']).catchError((_) => <dynamic>[]))
        );

        for (int i = 0; i < viviendas.length; i++) {
          final res = asignaciones[i];
          if (res.isNotEmpty) {
            ocupadas++;
          }
          // We can also attach the asignada state to the map if we want
          viviendas[i]['asignada'] = res.isNotEmpty;
        }
      }

      int residentesCount = 0;
      final token = await widget.controller.getValidAccessToken();
      final res = await widget.controller.httpClient.get(
        Uri.parse(
          '${dotenv.env['API_BASE_URL_USUARIOS'] ?? 'https://usuarios-api-n1qi.onrender.com'}/api/Auth/residentes',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          residentesCount = decoded.length;
        } else if (decoded is Map) {
          if (decoded['items'] is List) {
            residentesCount = (decoded['items'] as List).length;
          } else if (decoded['data'] is List) {
            residentesCount = (decoded['data'] as List).length;
          }
        }
      }

      bool isOnline = false;
      String dbVersionTxt = 'Base de datos operativa';
      try {
        final healthRes = await widget.controller.httpClient.get(
          Uri.parse('${dotenv.env['API_BASE_URL_USUARIOS'] ?? 'https://usuarios-api-n1qi.onrender.com'}/api/Auth/ping')
        ).timeout(const Duration(seconds: 5));
        isOnline = healthRes.statusCode == 200;
        if (isOnline) {
          try {
            final body = jsonDecode(healthRes.body);
            if (body is Map && body['dbVersion'] != null) {
              dbVersionTxt = 'BD v${body['dbVersion']}';
            }
          } catch (_) {}
        }
      } catch (_) {
        isOnline = false;
      }

      if (mounted) {
        setState(() {
          _dbVersionText = dbVersionTxt;
          _totalViviendas = viviendas.length;
          _viviendasOcupadas = ocupadas;
          _totalResidentes = residentesCount;
          _isSystemOnline = isOnline;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final nombre = user?.nombre ?? 'Admin';
    final condominioId = user?.condominioId;

    final List<Widget> pages = [
      _buildHomePage(context, nombre, condominioId),
      ResidentesListScreen(controller: widget.controller),
      ViviendasListScreen(controller: widget.controller),
      AvisosAdminScreen(controller: widget.controller),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PerfilScreen(controller: widget.controller),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF111C99),
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A',
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
                      'Administrador',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: const Color(0xFFEEF2FF),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: Color(0xFF64748B)),
            selectedIcon: Icon(
              Icons.dashboard_rounded,
              color: Color(0xFF111C99),
            ),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded, color: Color(0xFF64748B)),
            selectedIcon: Icon(Icons.people_rounded, color: Color(0xFF111C99)),
            label: 'Residentes',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined, color: Color(0xFF64748B)),
            selectedIcon: Icon(
              Icons.apartment_rounded,
              color: Color(0xFF111C99),
            ),
            label: 'Viviendas',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined, color: Color(0xFF64748B)),
            selectedIcon: Icon(
              Icons.campaign_rounded,
              color: Color(0xFF111C99),
            ),
            label: 'Avisos',
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage(
    BuildContext context,
    String nombre,
    String? condominioId,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF111C99), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF111C99).withValues(alpha: 0.3),
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
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Panel de Administración del Condominio',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Generate code section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            Icons.qr_code_2_rounded,
                            color: Color(0xFF111C99),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Código de Invitación',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Genera un código para vincular residentes',
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (condominioId == null || _isGeneratingCode)
                            ? null
                            : () async {
                                setState(() => _isGeneratingCode = true);
                                final srv = CondominiosService(
                                  widget.controller,
                                );
                                final res = await srv.generarCodigo(
                                  condominioId,
                                  minutosVigencia: 1440,
                                );

                                if (mounted) {
                                  setState(() => _isGeneratingCode = false);
                                }

                                if (res != null && context.mounted) {
                                  final codigo =
                                      res['codigo'] ?? res['code'] ?? '—';
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Row(
                                        children: const [
                                          Icon(
                                            Icons.qr_code_2_rounded,
                                            color: Color(0xFF111C99),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Código Generado'),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 24,
                                              horizontal: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEEF2FF),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF111C99,
                                                ).withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: SelectableText(
                                              codigo.toString(),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 6,
                                                color: Color(0xFF111C99),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Comparte este código con el residente.\nExpira en 24 horas y es de un solo uso.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        FilledButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF111C99,
                                            ),
                                          ),
                                          child: const Text('Entendido'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  if (context.mounted) {
                                    widget.controller.notifyToast(
                                      'Error al generar código',
                                      success: false,
                                    );
                                  }
                                }
                              },
                        icon: _isGeneratingCode
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          _isGeneratingCode ? 'Generando...' : 'Generar Código',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF111C99),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick stats / navigation hints
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Acciones Rápidas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (_isLoadingStats)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF111C99),
                      ),
                    )
                  else
                    InkWell(
                      onTap: () {
                        setState(() => _isLoadingStats = true);
                        _fetchStats();
                      },
                      child: const Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Actualizar',
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
              const SizedBox(height: 16),
              _buildActionCard(
                title: 'Gestión de Viviendas',
                icon: Icons.home_work_outlined,
                onTap: () => setState(() => _currentIndex = 2),
                insight: _totalViviendas > 0
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ocupación',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${((_viviendasOcupadas / _totalViviendas) * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: _viviendasOcupadas / _totalViviendas,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_viviendasOcupadas de $_totalViviendas viviendas ocupadas',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        '0 viviendas registradas',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                title: 'Directorio de Residentes',
                icon: Icons.people_outline,
                onTap: () => setState(() => _currentIndex = 1),
                insight: Text(
                  '$_totalResidentes residentes en el padrón',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                title: 'Gestión de Avisos',
                icon: Icons.campaign_outlined,
                onTap: () => setState(() => _currentIndex = 3),
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                title: 'Estado del Sistema',
                icon: Icons.dns_outlined,
                onTap: () async {
                  if (_isSystemOnline) {
                    widget.controller.notifyToast('API en línea - $_dbVersionText', success: true);
                  } else {
                    widget.controller.notifyToast('Sistema fuera de línea o con problemas', success: false);
                  }
                },
                insight: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isSystemOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444), // Emerald 500 or Red 500
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSystemOnline ? 'En línea y operativo' : 'Fuera de línea',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isSystemOnline ? const Color(0xFF047857) : const Color(0xFFB91C1C), // Emerald 700 or Red 700
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Widget? insight,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF111C99), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
            if (insight != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),
              insight,
            ],
          ],
        ),
      ),
    );
  }
}
