import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../Services/app_controller.dart';
import '../Services/viviendas_service.dart';

class ViviendaDetalleScreen extends StatefulWidget {
  const ViviendaDetalleScreen({
    super.key,
    required this.controller,
    required this.vivienda,
    required this.onChanged,
  });

  final AppController controller;
  final Map<String, dynamic> vivienda;
  final VoidCallback onChanged;

  @override
  State<ViviendaDetalleScreen> createState() => _ViviendaDetalleScreenState();
}

class _ViviendaDetalleScreenState extends State<ViviendaDetalleScreen> {
  late Map<String, dynamic> _vivienda;
  bool _isDeleting = false;
  bool _isGeneratingCode = false;
  Map<String, dynamic>? _habitanteAsignado;
  bool _isActionHabitanteLoading = false;

  @override
  void initState() {
    super.initState();
    _vivienda = Map<String, dynamic>.from(widget.vivienda);
    if (_vivienda['residente'] is Map) {
      _habitanteAsignado = Map<String, dynamic>.from(_vivienda['residente']);
    } else if (_vivienda['habitante'] is Map) {
      _habitanteAsignado = Map<String, dynamic>.from(_vivienda['habitante']);
    }
    _loadResidenteIfNeeded();
  }

  Future<void> _loadResidenteIfNeeded() async {
    if (widget.vivienda['residente'] != null) return;
    
    // Siempre intentamos obtener los residentes si no vienen adjuntos
    setState(() => _isActionHabitanteLoading = true);
    try {
      final srv = ViviendasService(widget.controller);
      final resList = await srv.obtenerResidentesVivienda(_vivienda['id']);
      if (resList.isNotEmpty) {
        if (mounted) {
          setState(() {
            _habitanteAsignado = Map<String, dynamic>.from(resList.first);
            _vivienda['residente'] = _habitanteAsignado;
          });
        }
      }
    } catch (_) {
      // Ignorar error y dejarlo como vacante temporalmente
    } finally {
      if (mounted) setState(() => _isActionHabitanteLoading = false);
    }
  }

  Future<void> _vincularResidente(Map<String, dynamic> residente) async {
    setState(() => _isActionHabitanteLoading = true);
    final viviendaId = _vivienda['id'];
    final usuarioId = residente['id'];
    final url =
        '${dotenv.env['API_BASE_URL_VIVIENDAS'] ?? 'https://viviendas-api.onrender.com'}/api/Viviendas/$viviendaId/residentes';

    try {
      final res = await widget.controller.httpClient.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.controller.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'usuarioId': usuarioId}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        widget.controller.notifyToast(
          'Residente vinculado exitosamente',
          success: true,
        );
        setState(() {
          _habitanteAsignado = residente;
          _vivienda['residente'] = residente;
        });
        widget.onChanged();
      } else if (res.statusCode == 409) {
        widget.controller.notifyToast(
          'El residente ya está asignado a una vivienda',
          success: false,
        );
      } else {
        widget.controller.notifyToast(
          'Error al vincular residente',
          success: false,
        );
      }
    } catch (e) {
      widget.controller.notifyToast(
        'Error de conexión al vincular habitante',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _isActionHabitanteLoading = false);
    }
  }

  Future<void> _desvincularResidente() async {
    if (_habitanteAsignado == null) return;
    final nombre =
        '${_habitanteAsignado!['nombre'] ?? ''} ${_habitanteAsignado!['apellidos'] ?? ''}'
            .trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Desvincular Residente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas desvincular a "$nombre" de esta vivienda? La vivienda pasará a estado vacante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionHabitanteLoading = true);
    final viviendaId = _vivienda['id'];
    final usuarioId = _habitanteAsignado!['id'];
    final url =
        '${dotenv.env['API_BASE_URL_VIVIENDAS'] ?? 'https://viviendas-api.onrender.com'}/api/Viviendas/$viviendaId/residentes/$usuarioId';

    try {
      final res = await widget.controller.httpClient.delete(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.controller.accessToken}'},
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        widget.controller.notifyToast(
          'Residente desvinculado correctamente',
          success: true,
        );
        setState(() {
          _habitanteAsignado = null;
          _vivienda.remove('residente');
        });
        widget.onChanged();
      } else {
        widget.controller.notifyToast(
          'No se pudo desvincular el residente',
          success: false,
        );
      }
    } catch (e) {
      widget.controller.notifyToast(
        'Error de conexión al desvincular',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _isActionHabitanteLoading = false);
    }
  }

  Future<void> _openBuscarResidenteModal() async {
    final searchController = TextEditingController();
    List<dynamic> allResidents = [];
    List<dynamic> filteredResidents = [];
    bool isLoadingResidents = true;
    String? fetchError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            void filter(String query) {
              final q = query.trim().toLowerCase();
              setModalState(() {
                if (q.isEmpty) {
                  filteredResidents = List.from(allResidents);
                } else {
                  filteredResidents = allResidents.where((r) {
                    final nombre =
                        '${r['nombre'] ?? ''} ${r['apellidos'] ?? ''}'
                            .toLowerCase();
                    final email = (r['email'] ?? '').toString().toLowerCase();
                    final tel = (r['telefono'] ?? '').toString().toLowerCase();
                    return nombre.contains(q) ||
                        email.contains(q) ||
                        tel.contains(q);
                  }).toList();
                }
              });
            }

            if (isLoadingResidents &&
                allResidents.isEmpty &&
                fetchError == null) {
              () async {
                try {
                  final url =
                      '${dotenv.env['API_BASE_URL_USUARIOS'] ?? 'https://usuarios-api-n1qi.onrender.com'}/api/Auth/residentes';
                  final token = await widget.controller.getValidAccessToken();
                  final res = await widget.controller.httpClient.get(
                    Uri.parse(url),
                    headers: {
                      'Authorization': 'Bearer $token',
                    },
                  );
                  if (res.statusCode >= 200 && res.statusCode < 300) {
                    final decoded = jsonDecode(res.body);
                    final list = decoded is List
                        ? decoded
                        : (decoded is Map && decoded['items'] is List
                            ? decoded['items']
                            : (decoded is Map && decoded['data'] is List
                                ? decoded['data']
                                : []));
                    setModalState(() {
                      allResidents = list;
                      filteredResidents = list;
                      isLoadingResidents = false;
                    });
                  } else {
                    setModalState(() {
                      fetchError = 'No se pudo cargar la lista de residentes';
                      isLoadingResidents = false;
                    });
                  }
                } catch (e) {
                  setModalState(() {
                    fetchError = 'Error de conexión con el directorio';
                    isLoadingResidents = false;
                  });
                }
              }();
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                maxWidth: 540,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1,
                                size: 20,
                                color: Color(0xFF111C99),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Vincular Residente',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF94A3B8),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: searchController,
                      onChanged: filter,
                      decoration: InputDecoration(
                        hintText: 'Buscar residente por nombre o correo...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchController.clear();
                                  filter('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF111C99),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: isLoadingResidents
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF111C99),
                            ),
                          )
                        : fetchError != null
                        ? Center(
                            child: Text(
                              fetchError!,
                              style: const TextStyle(color: Color(0xFFDC2626)),
                            ),
                          )
                        : filteredResidents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.person_off_outlined,
                                  size: 40,
                                  color: Color(0xFF94A3B8),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'No se encontraron residentes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: filteredResidents.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (context, index) {
                              final r = filteredResidents[index];
                              final nombre =
                                  '${r['nombre'] ?? ''} ${r['apellidos'] ?? ''}'
                                      .trim();
                              final email = r['email'] ?? '';
                              final initial =
                                  (nombre.isNotEmpty ? nombre[0] : 'R')
                                      .toUpperCase();

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF111C99),
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  nombre.isNotEmpty ? nombre : 'Sin Nombre',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                trailing: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF111C99),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _vincularResidente(r);
                                  },
                                  child: const Text(
                                    'Asignar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHabitanteSection() {
    if (_isActionHabitanteLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: Color(0xFF111C99)),
          ),
        ),
      );
    }

    if (_habitanteAsignado != null) {
      final n = (_habitanteAsignado!['nombre'] ?? '').toString();
      final a = (_habitanteAsignado!['apellidos'] ?? '').toString();
      final email = (_habitanteAsignado!['email'] ?? '—').toString();
      final tel = (_habitanteAsignado!['telefono'] ?? '—').toString();
      final initial = '${n.isNotEmpty ? n[0] : ''}${a.isNotEmpty ? a[0] : ''}'
          .toUpperCase();

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Habitante Asignado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Text(
                    'OCUPADA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF111C99),
                  child: Text(
                    initial.isEmpty ? 'R' : initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$n $a'.trim().isNotEmpty
                            ? '$n $a'.trim()
                            : 'Sin Nombre',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (tel != '—') ...[
                        const SizedBox(height: 2),
                        Text(
                          'Tel: $tel',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _desvincularResidente,
                icon: const Icon(Icons.person_remove_outlined, size: 16),
                label: const Text(
                  'Desvincular Residente',
                  style: TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Habitante Asignado',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text(
                  'ESTADO VACANTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.home_work_outlined,
                  size: 36,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vivienda vacante / Sin habitante asignado',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Esta unidad no tiene ningún residente vinculado actualmente. Puedes vincular a un habitante registrado del condominio.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _openBuscarResidenteModal,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text(
                        'Vincular',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111C99),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _isGeneratingCode ? null : () async {
                        setState(() => _isGeneratingCode = true);
                        final srv = ViviendasService(widget.controller);
                        final res = await srv.generarCodigo(_vivienda['id'], minutosVigencia: 1440);
                        
                        if (mounted) {
                          setState(() => _isGeneratingCode = false);
                        }
                        
                        if (res != null && mounted) {
                          final codigo = res['codigo'] ?? res['code'] ?? '—';
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Row(
                                children: const [
                                  Icon(Icons.qr_code_2_rounded, color: Color(0xFF0F172A)),
                                  SizedBox(width: 12),
                                  Text('Código Generado'),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF0F172A).withValues(alpha: 0.3)),
                                    ),
                                    child: SelectableText(
                                      codigo.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 6,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Comparte este código con el residente.\nExpira en 24 horas y es de un solo uso.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                  ),
                                ],
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                                  child: const Text('Entendido'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          if (context.mounted) {
                            widget.controller.notifyToast('Error al generar código', success: false);
                          }
                        }
                      },
                      icon: _isGeneratingCode 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: Text(
                        _isGeneratingCode ? 'Generando...' : 'Código',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVivienda() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Eliminar Vivienda',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la vivienda "${_vivienda['numeroCasa']}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final id = _vivienda['id'];
      final response = await widget.controller.httpClient.delete(
        Uri.parse(
          '${dotenv.env['API_BASE_URL_VIVIENDAS'] ?? 'https://viviendas-api.onrender.com'}/api/Viviendas/$id',
        ),
        headers: {'Authorization': 'Bearer ${widget.controller.accessToken}'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        widget.controller.notifyToast(
          'Vivienda eliminada correctamente',
          success: true,
        );
        widget.onChanged();
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        widget.controller.notifyToast(
          'No se pudo eliminar la vivienda',
          success: false,
        );
      }
    } catch (e) {
      widget.controller.notifyToast('Error de red al eliminar', success: false);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showEditDialog() {
    final formKey = GlobalKey<FormState>();
    final numeroCasaController = TextEditingController(
      text: _vivienda['numeroCasa'] ?? '',
    );
    final tipoController = TextEditingController(text: _vivienda['tipo'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Editar Vivienda',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: numeroCasaController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Casa *',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: tipoController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo (Ej. Casa, Depto)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111C99),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final payload = {
                    'numeroCasa': numeroCasaController.text.trim(),
                    'tipo': tipoController.text.trim(),
                  };
                  final id = _vivienda['id'];
                  final url =
                      '${dotenv.env['API_BASE_URL_VIVIENDAS'] ?? 'https://viviendas-api.onrender.com'}/api/Viviendas/$id';

                  try {
                    final res = await widget.controller.httpClient.put(
                      Uri.parse(url),
                      headers: {
                        'Authorization':
                            'Bearer ${widget.controller.accessToken}',
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode(payload),
                    );

                    if (res.statusCode >= 200 && res.statusCode < 300) {
                      widget.controller.notifyToast(
                        'Actualizado correctamente',
                        success: true,
                      );
                      setState(() {
                        _vivienda['numeroCasa'] = payload['numeroCasa'];
                        _vivienda['tipo'] = payload['tipo'];
                      });
                      widget.onChanged();
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                    } else {
                      widget.controller.notifyToast(
                        'Error al actualizar',
                        success: false,
                      );
                    }
                  } catch (e) {
                    widget.controller.notifyToast(
                      'Error de conexión',
                      success: false,
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  String _formatFecha(dynamic fechaRaw) {
    if (fechaRaw == null) return 'No disponible';
    try {
      final dt = DateTime.parse(fechaRaw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fechaRaw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final numeroCasa = (_vivienda['numeroCasa'] ?? 'S/N').toString();
    final tipo = (_vivienda['tipo'] ?? 'Vivienda Residencial').toString();
    final id = _vivienda['id']?.toString() ?? '—';
    final creadoEn = _formatFecha(
      _vivienda['creadoEn'] ?? _vivienda['creado_en'],
    );
    final bool activo = _vivienda['activo'] ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Detalle de Vivienda',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF111C99)),
            tooltip: 'Editar vivienda',
            onPressed: _showEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            tooltip: 'Eliminar vivienda',
            onPressed: _isDeleting ? null : _deleteVivienda,
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF111C99)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tarjeta de Cabecera
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x05000000),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE0E7FF),
                                ),
                              ),
                              child: const Icon(
                                Icons.home_rounded,
                                color: Color(0xFF111C99),
                                size: 34,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    numeroCasa,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tipo.isNotEmpty
                                        ? tipo
                                        : 'Inmueble Residencial',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: activo
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: activo
                                            ? const Color(0xFFA7F3D0)
                                            : const Color(0xFFFECACA),
                                      ),
                                    ),
                                    child: Text(
                                      activo
                                          ? 'DISPONIBLE / ACTIVA'
                                          : 'INACTIVA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: activo
                                            ? const Color(0xFF047857)
                                            : const Color(0xFFB91C1C),
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
                      const SizedBox(height: 20),

                      // Tarjeta de Información Detallada
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          children: [
                            const Text(
                              'Información del Inmueble',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildDetailRow(
                              icon: Icons.tag,
                              label: 'Identificador (ID)',
                              value: '#$id',
                            ),
                            const Divider(height: 24, color: Color(0xFFF1F5F9)),
                            _buildDetailRow(
                              icon: Icons.meeting_room_outlined,
                              label: 'Número o Identificación',
                              value: numeroCasa,
                            ),
                            const Divider(height: 24, color: Color(0xFFF1F5F9)),
                            _buildDetailRow(
                              icon: Icons.category_outlined,
                              label: 'Tipo de Construcción',
                              value: tipo.isNotEmpty ? tipo : 'No especificado',
                            ),
                            const Divider(height: 24, color: Color(0xFFF1F5F9)),
                            _buildDetailRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Fecha de Registro',
                              value: creadoEn,
                            ),
                            const Divider(height: 24, color: Color(0xFFF1F5F9)),
                            _buildDetailRow(
                              icon: Icons.domain_outlined,
                              label: 'Residencial',
                              value: 'Haven Condominio Residencial',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sección de Habitante Asignado o Estado Vacante
                      _buildHabitanteSection(),
                      const SizedBox(height: 24),

                      // Botones de acción inferiores
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showEditDialog,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text(
                                'Editar Datos',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF111C99),
                                side: const BorderSide(
                                  color: Color(0xFF111C99),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _deleteVivienda,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text(
                                'Eliminar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
