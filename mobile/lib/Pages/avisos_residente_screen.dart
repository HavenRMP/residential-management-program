import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/app_controller.dart';
import '../Services/avisos_service.dart';

class AvisosResidenteScreen extends StatefulWidget {
  const AvisosResidenteScreen({super.key, required this.controller});
  
  final AppController controller;

  @override
  State<AvisosResidenteScreen> createState() => _AvisosResidenteScreenState();
}

class _AvisosResidenteScreenState extends State<AvisosResidenteScreen> {
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  List<dynamic> _avisos = [];
  List<String> _readAvisos = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReadAvisos().then((_) {
      _cargarAvisos(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadReadAvisos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _readAvisos = prefs.getStringList('read_avisos') ?? [];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _cargarAvisos();
    }
  }

  Future<void> _cargarAvisos({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    
    if (!_hasMore || (_isFetchingMore && !refresh)) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
      } else {
        _isFetchingMore = true;
      }
    });

    try {
      final service = AvisosService(widget.controller);
      final response = await service.getAvisosVigentes(page: _currentPage, pageSize: 10);
      
      if (response != null) {
        final rawItems = response['items'] as List<dynamic>? ?? [];
        final items = rawItems.where((a) {
          final isVigente = a['vigente'] == true || a['activo'] == true || a['estado'] == 'activo';
          return isVigente;
        }).toList();
        
        setState(() {
          if (refresh) {
            _avisos = items;
          } else {
            _avisos.addAll(items);
          }
          _currentPage++;
          _hasMore = items.length == 10;
          _isLoading = false;
          _isFetchingMore = false;
        });
      } else {
        // Service returned null (connection error or empty) - show empty state
        setState(() {
          if (refresh) _avisos = [];
          _isLoading = false;
          _isFetchingMore = false;
          _hasMore = false;
        });
      }
    } catch (e) {
      setState(() {
        if (refresh) _avisos = [];
        _isLoading = false;
        _isFetchingMore = false;
        _hasMore = false;
      });
    }
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
          : RefreshIndicator(
              onRefresh: () => _cargarAvisos(refresh: true),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _avisos.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _avisos.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final aviso = _avisos[index];
                  return _buildAvisoCard(aviso);
                },
              ),
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
    final id = aviso['id']?.toString() ?? '';
    final isRead = _readAvisos.contains(id);
    final titulo = aviso['titulo'] ?? 'Aviso';
    final contenido = aviso['contenido'] ?? '';
    final autor = aviso['creado_por_nombre'] ?? 'Administrador';
    
    // Parse fecha si es necesario
    String fechaStr = '';
    if (aviso['fecha_publicacion'] != null) {
      try {
        final parsedDt = DateTime.parse(aviso['fecha_publicacion']);
        fechaStr = '${parsedDt.day}/${parsedDt.month}/${parsedDt.year}';
      } catch (_) {}
    }

    return InkWell(
      onTap: () async {
        if (id.isNotEmpty && !isRead) {
          final prefs = await SharedPreferences.getInstance();
          final updated = List<String>.from(_readAvisos)..add(id);
          await prefs.setStringList('read_avisos', updated);
          if (mounted) {
            setState(() {
              _readAvisos = updated;
            });
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFF111C99).withValues(alpha: 0.3),
            width: isRead ? 1 : 1.5,
          ),
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
                    color: isRead ? const Color(0xFFFEF2F2) : const Color(0xFF111C99),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isRead ? Icons.campaign_rounded : Icons.notifications_active_rounded, 
                    color: isRead ? const Color(0xFFDC2626) : Colors.white, 
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (!isRead)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111C99),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NUEVO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
      ),
    );
  }
}
