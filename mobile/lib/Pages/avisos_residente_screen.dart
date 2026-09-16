import 'package:flutter/material.dart';
import '../Services/app_controller.dart';
import '../Services/avisos_service.dart';
import 'en_construccion_screen.dart';

class AvisosResidenteScreen extends StatefulWidget {
  const AvisosResidenteScreen({super.key, required this.controller});
  
  final AppController controller;

  @override
  State<AvisosResidenteScreen> createState() => _AvisosResidenteScreenState();
}

class _AvisosResidenteScreenState extends State<AvisosResidenteScreen> {
  bool _isLoading = true;
  List<dynamic> _avisos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarAvisos();
  }

  Future<void> _cargarAvisos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = AvisosService(widget.controller);
      final avisos = await service.getAvisosVigentes();
      
      if (avisos != null) {
        setState(() {
          _avisos = avisos;
          _isLoading = false;
        });
      } else {
        _redirigirAConstruccion('No se pudieron cargar los avisos');
      }
    } catch (e) {
      _redirigirAConstruccion('Error al cargar avisos');
    }
  }

  void _redirigirAConstruccion(String mensaje) {
    // Si hay un error general que rompe la pantalla, según los requerimientos, 
    // se manda a la pantalla de EnConstruccion
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const EnConstruccionScreen(titulo: 'Avisos no disponibles'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tablón de Avisos'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: _avisos.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _avisos.length,
              itemBuilder: (context, index) {
                final aviso = _avisos[index];
                return _buildAvisoCard(aviso);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              Icons.notifications_off_outlined,
              size: 64,
              color: Color(0xFF111C99),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin avisos vigentes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'El administrador del condominio aún\nno ha publicado ningún aviso.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisoCard(dynamic aviso) {
    final titulo = aviso['titulo'] ?? 'Aviso';
    final contenido = aviso['contenido'] ?? '';
    final autor = aviso['creado_por_nombre'] ?? 'Administrador';
    
    // Parse fecha si es necesario
    String fechaStr = '';
    if (aviso['fecha_publicacion'] != null) {
      try {
        final dt = DateTime.parse(aviso['fecha_publicacion']);
        fechaStr = '\${dt.day}/\${dt.month}/\${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFFDC2626), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            contenido,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Por: $autor',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (fechaStr.isNotEmpty)
                Text(
                  fechaStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
