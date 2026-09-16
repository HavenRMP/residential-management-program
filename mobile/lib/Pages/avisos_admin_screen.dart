import 'package:flutter/material.dart';
import '../Services/app_controller.dart';
import '../Services/avisos_service.dart';
import 'en_construccion_screen.dart';

class AvisosAdminScreen extends StatefulWidget {
  const AvisosAdminScreen({super.key, required this.controller});
  
  final AppController controller;

  @override
  State<AvisosAdminScreen> createState() => _AvisosAdminScreenState();
}

class _AvisosAdminScreenState extends State<AvisosAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  // Vigentes
  List<dynamic> _avisosVigentes = [];
  bool _isFetchingVigentes = false;
  bool _hasMoreVigentes = true;
  int _pageVigentes = 1;
  final ScrollController _scrollVigentes = ScrollController();

  // Histórico
  List<dynamic> _avisosHistorico = [];
  bool _isFetchingHistorico = false;
  bool _hasMoreHistorico = true;
  int _pageHistorico = 1;
  final ScrollController _scrollHistorico = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarAmbos();
    
    _scrollVigentes.addListener(() {
      if (_scrollVigentes.position.pixels >= _scrollVigentes.position.maxScrollExtent - 200) {
        _cargarVigentes();
      }
    });
    
    _scrollHistorico.addListener(() {
      if (_scrollHistorico.position.pixels >= _scrollHistorico.position.maxScrollExtent - 200) {
        _cargarHistorico();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollVigentes.dispose();
    _scrollHistorico.dispose();
    super.dispose();
  }

  Future<void> _cargarAmbos() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _cargarVigentes(refresh: true),
      _cargarHistorico(refresh: true),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _cargarVigentes({bool refresh = false}) async {
    if (refresh) {
      _pageVigentes = 1;
      _hasMoreVigentes = true;
    }
    if (!_hasMoreVigentes || (_isFetchingVigentes && !refresh)) return;

    setState(() => _isFetchingVigentes = true);
    try {
      final service = AvisosService(widget.controller);
      final response = await service.getAvisosVigentes(page: _pageVigentes, pageSize: 10);
      if (response != null) {
        final items = response['items'] as List<dynamic>? ?? [];
        setState(() {
          if (refresh) {
            _avisosVigentes = items;
          } else {
            _avisosVigentes.addAll(items);
          }
          _pageVigentes++;
          _hasMoreVigentes = items.length == 10;
        });
      }
    } catch (_) {}
    setState(() => _isFetchingVigentes = false);
  }

  Future<void> _cargarHistorico({bool refresh = false}) async {
    if (refresh) {
      _pageHistorico = 1;
      _hasMoreHistorico = true;
    }
    if (!_hasMoreHistorico || (_isFetchingHistorico && !refresh)) return;

    setState(() => _isFetchingHistorico = true);
    try {
      final service = AvisosService(widget.controller);
      final response = await service.getAvisosHistorico(page: _pageHistorico, pageSize: 10);
      if (response != null) {
        final items = response['items'] as List<dynamic>? ?? [];
        setState(() {
          if (refresh) {
            _avisosHistorico = items;
          } else {
            _avisosHistorico.addAll(items);
          }
          _pageHistorico++;
          _hasMoreHistorico = items.length == 10;
        });
      }
    } catch (_) {}
    setState(() => _isFetchingHistorico = false);
  }

  void _redirigirAConstruccion(String mensaje) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const EnConstruccionScreen(titulo: 'Gestión de Avisos (No disponible)'),
      ),
    );
  }

  Future<void> _crearAviso() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    int duracionDias = 7;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Crear Nuevo Aviso'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Contenido'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: duracionDias,
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3 días')),
                    DropdownMenuItem(value: 7, child: Text('1 semana (7 días)')),
                    DropdownMenuItem(value: 14, child: Text('2 semanas')),
                    DropdownMenuItem(value: 30, child: Text('1 mes')),
                  ],
                  onChanged: (value) {
                    if (value != null) duracionDias = value;
                  },
                  decoration: const InputDecoration(labelText: 'Duración'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111C99)),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final titulo = titleController.text.trim();
      final contenido = contentController.text.trim();
      
      if (titulo.isEmpty || contenido.isEmpty) {
        widget.controller.notifyToast('El título y contenido son obligatorios', success: false);
        return;
      }

      setState(() => _isLoading = true);
      try {
        final service = AvisosService(widget.controller);
        final res = await service.createAviso(titulo, contenido, duracionDias: duracionDias);
        
        if (res != null) {
          widget.controller.notifyToast('Aviso creado exitosamente', success: true);
          await _cargarAmbos();
        } else {
          widget.controller.notifyToast('Error al crear el aviso', success: false);
          setState(() => _isLoading = false);
        }
      } catch (e) {
        _redirigirAConstruccion('Error al crear aviso');
      }
    }
  }

  Future<void> _eliminarAviso(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Aviso'),
        content: const Text('¿Estás seguro de que deseas eliminar este aviso?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        final service = AvisosService(widget.controller);
        final success = await service.deleteAviso(id);
        
        if (success) {
          widget.controller.notifyToast('Aviso eliminado exitosamente', success: true);
          await _cargarAmbos();
        } else {
          widget.controller.notifyToast('Error al eliminar el aviso', success: false);
          setState(() => _isLoading = false);
        }
      } catch (e) {
        _redirigirAConstruccion('Error al eliminar aviso');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Gestión de Avisos'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF111C99),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF111C99),
          tabs: const [
            Tab(text: 'Vigentes'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crearAviso,
        backgroundColor: const Color(0xFF111C99),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListaAvisos(_avisosVigentes, _scrollVigentes, _hasMoreVigentes, esVigente: true),
                _buildListaAvisos(_avisosHistorico, _scrollHistorico, _hasMoreHistorico, esVigente: false),
              ],
            ),
    );
  }

  Widget _buildListaAvisos(List<dynamic> avisos, ScrollController controller, bool hasMore, {required bool esVigente}) {
    if (avisos.isEmpty) {
      return Center(
        child: Text(
          esVigente ? 'No hay avisos vigentes' : 'No hay historial de avisos',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: avisos.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == avisos.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final aviso = avisos[index];
        final id = aviso['id'];
        final titulo = aviso['titulo'] ?? 'Aviso';
        final contenido = aviso['contenido'] ?? '';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    if (esVigente)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _eliminarAviso(id),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  contenido,
                  style: const TextStyle(color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
