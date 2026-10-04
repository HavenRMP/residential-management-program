import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../Services/app_controller.dart';
import '../Services/viviendas_service.dart';
import '../Utils/error_handler.dart';
import 'vivienda_detalle_screen.dart';

class ViviendasListScreen extends StatefulWidget {
  const ViviendasListScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<ViviendasListScreen> createState() => _ViviendasListScreenState();
}

class _ViviendasListScreenState extends State<ViviendasListScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _viviendas = [];
  late ViviendasService _viviendasService;
  String _filtro = 'todas'; // 'todas', 'disponibles', 'ocupadas'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _viviendasService = ViviendasService(widget.controller);
    _fetchViviendas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isViviendaOcupada(Map<String, dynamic> v) {
    if (v['estaOcupada'] == true) return true;
    final total = v['totalResidentes'];
    if (total is num && total > 0) return true;
    final res = v['residentes'];
    if (res is List && res.isNotEmpty) return true;
    if (v['asignada'] == true) return true;
    return false;
  }

  String? _getNombreResidente(Map<String, dynamic> v) {
    final res = v['residentes'];
    if (res is List && res.isNotEmpty) {
      final first = res.first;
      if (first is Map) {
        final nombre =
            '${first['nombre'] ?? ''} ${first['apellidos'] ?? ''}'.trim();
        if (nombre.isNotEmpty) {
          if (res.length > 1) {
            return '$nombre (+${res.length - 1})';
          }
          return nombre;
        }
      }
    }
    return null;
  }

  Future<void> _fetchViviendas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await _viviendasService.listarConResidentes();
      _viviendas = list;
    } catch (e) {
      _errorMessage = ErrorHandler.parseException(
        e,
        defaultMessage: 'No se pudieron cargar las viviendas.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteVivienda(int id) async {
    try {
      final success = await _viviendasService.eliminar(id);
      if (success) {
        widget.controller.notifyToast(
          'Vivienda eliminada correctamente',
          success: true,
        );
        if (mounted) {
          _fetchViviendas();
        }
      } else {
        widget.controller.notifyToast(
          'No se pudo eliminar la vivienda',
          success: false,
        );
      }
    } catch (e) {
      widget.controller.notifyToast(
        ErrorHandler.parseException(
          e,
          defaultMessage: 'Error de comunicación al eliminar vivienda.',
        ),
        success: false,
      );
    }
  }

  void _showFormDialog({Map<String, dynamic>? vivienda}) {
    final bool isEdit = vivienda != null;
    final formKey = GlobalKey<FormState>();
    final numeroCasaController = TextEditingController(
      text: isEdit ? vivienda['numeroCasa'] : '',
    );
    final tipoController = TextEditingController(
      text: isEdit ? vivienda['tipo'] : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Editar Vivienda' : 'Nueva Vivienda'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: numeroCasaController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Casa',
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: tipoController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo (Opcional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final payload = {
                    'numeroCasa': numeroCasaController.text.trim(),
                    'tipo': tipoController.text.trim(),
                  };

                  final url = isEdit
                      ? '${dotenv.env['API_BASE_URL_VIVIENDAS'] ?? 'https://viviendas-api.onrender.com'}/api/Viviendas/${vivienda['id']}'
                      : '${dotenv.env['API_BASE_URL_VIVIENDAS'] ?? 'https://viviendas-api.onrender.com'}/api/Viviendas';

                  try {
                    http.Response res;
                    if (isEdit) {
                      res = await widget.controller.httpClient.put(
                        Uri.parse(url),
                        headers: {
                          'Authorization':
                              'Bearer ${widget.controller.accessToken}',
                          'Content-Type': 'application/json',
                        },
                        body: jsonEncode(payload),
                      );
                    } else {
                      res = await widget.controller.httpClient.post(
                        Uri.parse(url),
                        headers: {
                          'Authorization':
                              'Bearer ${widget.controller.accessToken}',
                          'Content-Type': 'application/json',
                        },
                        body: jsonEncode(payload),
                      );
                    }

                    if (res.statusCode >= 200 && res.statusCode < 300) {
                      widget.controller.notifyToast(
                        isEdit
                            ? 'Actualizado correctamente'
                            : 'Creado correctamente',
                        success: true,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      _fetchViviendas();
                    } else {
                      final errorMsg = ErrorHandler.extractErrorMessage(
                        res.body,
                        statusCode: res.statusCode,
                        defaultMessage: isEdit
                            ? 'No se pudo actualizar la vivienda'
                            : 'No se pudo crear la vivienda',
                      );
                      widget.controller.notifyToast(
                        errorMsg,
                        success: false,
                      );
                    }
                  } catch (e) {
                    widget.controller.notifyToast(
                      ErrorHandler.parseException(
                        e,
                        defaultMessage: 'Error de comunicación al guardar vivienda.',
                      ),
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

  Widget _buildFilterChip({
    required String label,
    required int count,
    required String filterValue,
    required Color activeColor,
    required Color activeBg,
    required Color dotColor,
  }) {
    final isSelected = _filtro == filterValue;
    return InkWell(
      onTap: () {
        setState(() {
          _filtro = filterValue;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: isSelected ? activeColor : dotColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _viviendas.length;
    final ocupadasCount = _viviendas.where((item) {
      final v = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
      return _isViviendaOcupada(v);
    }).length;
    final disponiblesCount = totalCount - ocupadasCount;

    final filteredViviendas = _viviendas.where((item) {
      final v = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
      final isOcupada = _isViviendaOcupada(v);
      if (_filtro == 'disponibles' && isOcupada) return false;
      if (_filtro == 'ocupadas' && !isOcupada) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final numCasa = (v['numeroCasa'] ?? '').toString().toLowerCase();
        final tipo = (v['tipo'] ?? '').toString().toLowerCase();
        final res = _getNombreResidente(v)?.toLowerCase() ?? '';
        if (!numCasa.contains(q) && !tipo.contains(q) && !res.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Gestión de Viviendas',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(
              _isSearchVisible ? Icons.search_off : Icons.search,
              color: const Color(0xFF0F172A),
            ),
            tooltip: _isSearchVisible ? 'Ocultar búsqueda' : 'Buscar vivienda',
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            tooltip: 'Actualizar',
            onPressed: _fetchViviendas,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda expandible
          if (_isSearchVisible)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar por casa, tipo o residente...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              ),
            ),

          // Pestañas / Filtros de Disponibilidad
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'Todas',
                    count: totalCount,
                    filterValue: 'todas',
                    activeColor: const Color(0xFF0F172A),
                    activeBg: const Color(0xFFF1F5F9),
                    dotColor: const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Disponibles',
                    count: disponiblesCount,
                    filterValue: 'disponibles',
                    activeColor: const Color(0xFF047857),
                    activeBg: const Color(0xFFECFDF5),
                    dotColor: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Ocupadas',
                    count: ocupadasCount,
                    filterValue: 'ocupadas',
                    activeColor: const Color(0xFF1D4ED8),
                    activeBg: const Color(0xFFEFF6FF),
                    dotColor: const Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
          ),

          // Lista de Viviendas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchViviendas,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : filteredViviendas.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _filtro == 'disponibles'
                                        ? Icons.home_work_outlined
                                        : _filtro == 'ocupadas'
                                            ? Icons.people_outline
                                            : Icons.search_off,
                                    size: 48,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No se encontraron resultados para "$_searchQuery"'
                                        : _filtro == 'disponibles'
                                            ? 'No hay viviendas disponibles'
                                            : _filtro == 'ocupadas'
                                                ? 'No hay viviendas ocupadas'
                                                : 'No hay viviendas registradas',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF334155),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_filtro != 'todas' || _searchQuery.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _filtro = 'todas';
                                          _searchQuery = '';
                                          _searchController.clear();
                                        });
                                      },
                                      child: const Text('Mostrar todas las viviendas'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchViviendas,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredViviendas.length,
                              itemBuilder: (context, index) {
                                final rawV = filteredViviendas[index];
                                final v = rawV is Map<String, dynamic>
                                    ? rawV
                                    : Map<String, dynamic>.from(rawV as Map);
                                final isOcupada = _isViviendaOcupada(v);
                                final residenteNom = _getNombreResidente(v);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                      color: isOcupada
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0xFFD1FAE5),
                                      width: isOcupada ? 1 : 1.2,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ViviendaDetalleScreen(
                                            controller: widget.controller,
                                            vivienda: v,
                                            onChanged: _fetchViviendas,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isOcupada
                                                ? const Color(0xFFEFF6FF)
                                                : const Color(0xFFECFDF5),
                                            radius: 22,
                                            child: Icon(
                                              isOcupada
                                                  ? Icons.home_work_rounded
                                                  : Icons.home_rounded,
                                              color: isOcupada
                                                  ? const Color(0xFF1D4ED8)
                                                  : const Color(0xFF047857),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  children: [
                                                    Text(
                                                      v['numeroCasa'] != null &&
                                                              v['numeroCasa'].toString().trim().isNotEmpty
                                                          ? v['numeroCasa'].toString().trim()
                                                          : 'S/N',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2.5,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isOcupada
                                                            ? const Color(0xFFEFF6FF)
                                                            : const Color(0xFFECFDF5),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                          color: isOcupada
                                                              ? const Color(0xFFBFDBFE)
                                                              : const Color(0xFFA7F3D0),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.circle,
                                                            size: 6,
                                                            color: isOcupada
                                                                ? const Color(0xFF2563EB)
                                                                : const Color(0xFF10B981),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            isOcupada ? 'Ocupada' : 'Disponible',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: isOcupada
                                                                  ? const Color(0xFF1D4ED8)
                                                                  : const Color(0xFF047857),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  v['tipo'] != null &&
                                                          (v['tipo'] as String).isNotEmpty
                                                      ? v['tipo']
                                                      : 'Vivienda Residencial',
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if (isOcupada && residenteNom != null) ...[
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.person_outline,
                                                        size: 14,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          residenteNom,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF334155),
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.all(5),
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  color: Color(0xFF111C99),
                                                  size: 19,
                                                ),
                                                tooltip: 'Editar',
                                                onPressed: () =>
                                                    _showFormDialog(vivienda: v),
                                              ),
                                              IconButton(
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.all(5),
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Color(0xFFDC2626),
                                                  size: 19,
                                                ),
                                                tooltip: 'Eliminar',
                                                onPressed: () => _deleteVivienda(v['id']),
                                              ),
                                              const Icon(
                                                Icons.chevron_right,
                                                color: Color(0xFF94A3B8),
                                                size: 19,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFF0F172A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

