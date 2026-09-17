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
      for (var v in viviendas) {
        if (v['residente'] != null || v['habitante'] != null) {
          ocupadas++;
        }
      }

      int residentesCount = 0;
      final res = await widget.controller.httpClient.get(
        Uri.parse(
          '${dotenv.env['API_BASE_URL_USUARIOS'] ?? 'https://usuarios-api-n1qi.onrender.com'}/api/Auth/residentes',
        ),
        headers: {'Authorization': 'Bearer ${widget.controller.accessToken}'},
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          residentesCount = decoded.length;
        } else if (decoded is Map && decoded['data'] is List) {
          residentesCount = (decoded['data'] as List).length;
        }
      }

      if (mounted) {
        setState(() {
          _totalViviendas = viviendas.length;
          _viviendasOcupadas = ocupadas;
          _totalResidentes = residentesCount;
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
                    'Indicadores y Acceso',
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
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _buildMetricCard(
                    title: 'VIVIENDAS',
                    value: _totalViviendas.toString(),
                    subtitle: 'Ver catálogo completo',
                    icon: Icons.home_work_outlined,
                    color: const Color(0xFF111C99),
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                  _buildMetricCard(
                    title: 'PADRÓN',
                    value: _totalResidentes.toString(),
                    subtitle: 'Directorio residentes',
                    icon: Icons.people_outline,
                    color: const Color(0xFF4F46E5),
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                  _buildMetricCard(
                    title: 'OCUPACIÓN',
                    value: _totalViviendas > 0
                        ? '${((_viviendasOcupadas / _totalViviendas) * 100).round()}%'
                        : '0%',
                    subtitle: '$_viviendasOcupadas de $_totalViviendas viv.',
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFF059669),
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                  _buildMetricCard(
                    title: 'SISTEMA',
                    value: 'En línea',
                    subtitle: 'Supabase Auth & API v1',
                    icon: Icons.verified_user_outlined,
                    color: const Color(0xFF0F172A),
                    onTap: () {
                      widget.controller.notifyToast(
                        'API v1 Running - Supabase Auth DB v2.0.6',
                        success: true,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, size: 10, color: color),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
