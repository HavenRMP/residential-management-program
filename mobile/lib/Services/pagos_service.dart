import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../Models/pagos_models.dart';
import '../Utils/error_handler.dart';
import 'app_controller.dart';

class PagosService {
  final AppController controller;

  PagosService(this.controller);

  String get baseUrl {
    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['API_BASE_URL_PAGOS'] ?? dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.trim().isNotEmpty) {
        return envUrl.trim();
      }
    }
    return 'https://pagos-api-2b2k.onrender.com';
  }

  Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final token = await controller.getValidAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (isJson) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ==========================================
  // 1. Módulo Comprobantes (/api/comprobantes)
  // ==========================================

  /// Sube un comprobante mediante multipart/form-data
  Future<ComprobanteUploadResponse> uploadComprobante({
    required int viviendaId,
    required List<int> fileBytes,
    required String filename,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/comprobantes');
      final request = http.MultipartRequest('POST', uri);

      final token = await controller.getValidAccessToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['vivienda_id'] = viviendaId.toString();
      request.fields['viviendaId'] = viviendaId.toString();

      final multipartFile = http.MultipartFile.fromBytes(
        'archivo',
        fileBytes,
        filename: filename,
      );
      request.files.add(multipartFile);

      final streamedResponse = await controller.httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return ComprobanteUploadResponse.fromJson(decoded);
        }
        throw Exception('Respuesta inesperada al subir el comprobante');
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible subir el comprobante.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.uploadComprobante');
      rethrow;
    }
  }

  // ==========================================
  // 2. Módulo Pagos (/api/pagos)
  // ==========================================

  /// El residente reporta una transferencia o depósito para saldar un cargo
  Future<PagoModel> reportarPago({
    required String cargoId,
    required double monto,
    required String metodo,
    DateTime? fechaPago,
    String? folioComprobante,
    required String rutaComprobante,
    String? hashComprobante,
    String? bancoOrigen,
    String? notas,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pagos/reportar');
      final date = fechaPago ?? DateTime.now();
      final fechaStr = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final body = {
        'cargo_id': cargoId,
        'cargoId': cargoId,
        'monto': monto,
        'metodo': metodo,
        'fecha_pago': fechaStr,
        'fechaPago': date.toUtc().toIso8601String(),
        'referencia': folioComprobante ?? '',
        'folioComprobante': folioComprobante ?? '',
        if (bancoOrigen != null && bancoOrigen.isNotEmpty) 'banco_origen': bancoOrigen,
        'comprobante': {
          'ruta': rutaComprobante,
          if (hashComprobante != null) 'hash': hashComprobante,
        },
        'comprobante_ruta': rutaComprobante,
        if (hashComprobante != null) 'comprobante_hash': hashComprobante,
        'rutaComprobante': rutaComprobante,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      };

      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return PagoModel.fromJson(decoded as Map<String, dynamic>);
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible reportar el pago.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.reportarPago');
      rethrow;
    }
  }

  /// El Administrador registra un pago recibido en ventanilla/efectivo o conciliado
  Future<PagoModel> registrarPagoAdmin({
    required String cargoId,
    required double monto,
    required String metodo,
    DateTime? fechaPago,
    String? folioComprobante,
    String? rutaComprobante,
    String? hashComprobante,
    String? bancoOrigen,
    String? notas,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pagos');
      final date = fechaPago ?? DateTime.now();
      final fechaStr = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final body = {
        'cargo_id': cargoId,
        'cargoId': cargoId,
        'monto': monto,
        'metodo': metodo,
        'fecha_pago': fechaStr,
        'fechaPago': date.toUtc().toIso8601String(),
        if (folioComprobante != null) ...{
          'referencia': folioComprobante,
          'folioComprobante': folioComprobante,
        },
        if (bancoOrigen != null && bancoOrigen.isNotEmpty) 'banco_origen': bancoOrigen,
        if (rutaComprobante != null && rutaComprobante.isNotEmpty) ...{
          'comprobante': {
            'ruta': rutaComprobante,
            if (hashComprobante != null) 'hash': hashComprobante,
          },
          'comprobante_ruta': rutaComprobante,
          if (hashComprobante != null) 'comprobante_hash': hashComprobante,
          'rutaComprobante': rutaComprobante,
        },
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      };

      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return PagoModel.fromJson(decoded as Map<String, dynamic>);
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible registrar el pago.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.registrarPagoAdmin');
      rethrow;
    }
  }

  /// El Administrador valida el comprobante y confirma el pago
  Future<Map<String, dynamic>> confirmarPago(String pagoId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pagos/$pagoId/confirmar');
      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible confirmar el pago.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.confirmarPago');
      rethrow;
    }
  }

  /// Rechaza un pago reportado indicando el motivo
  Future<Map<String, dynamic>> rechazarPago(String pagoId, String motivo) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pagos/$pagoId/rechazar');
      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({'motivo': motivo}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible rechazar el pago.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.rechazarPago');
      rethrow;
    }
  }

  /// Anula un pago que previamente estaba confirmado
  Future<Map<String, dynamic>> anularPago(String pagoId, String motivo) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pagos/$pagoId/anular');
      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({'motivo': motivo}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible anular el pago.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.anularPago');
      rethrow;
    }
  }

  /// Listado general de pagos con filtros y paginación
  Future<PaginatedResponse<PagoModel>> getPagos({
    int? viviendaId,
    String? cargoId,
    String? estado,
    String? metodo,
    String? origen,
    DateTime? desde,
    DateTime? hasta,
    int pagina = 1,
    int tamanoPagina = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': pagina.toString(),
        'pageSize': tamanoPagina.toString(),
        'pagina': pagina.toString(),
        'tamanoPagina': tamanoPagina.toString(),
        if (viviendaId != null) ...{
          'vivienda_id': viviendaId.toString(),
          'viviendaId': viviendaId.toString(),
        },
        if (cargoId != null && cargoId.isNotEmpty) ...{
          'cargo_id': cargoId,
          'cargoId': cargoId,
        },
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (metodo != null && metodo.isNotEmpty) 'metodo': metodo,
        if (origen != null && origen.isNotEmpty) 'origen': origen,
        if (desde != null) ...{
          'fecha_pago_desde': "${desde.year.toString().padLeft(4, '0')}-${desde.month.toString().padLeft(2, '0')}-${desde.day.toString().padLeft(2, '0')}",
          'desde': desde.toUtc().toIso8601String(),
        },
        if (hasta != null) ...{
          'fecha_pago_hasta': "${hasta.year.toString().padLeft(4, '0')}-${hasta.month.toString().padLeft(2, '0')}-${hasta.day.toString().padLeft(2, '0')}",
          'hasta': hasta.toUtc().toIso8601String(),
        },
      };

      final uri = Uri.parse('$baseUrl/api/pagos').replace(queryParameters: queryParams);
      final response = await controller.httpClient.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return PaginatedResponse<PagoModel>.fromJson(
            decoded,
            (item) => PagoModel.fromJson(item),
          );
        } else if (decoded is List) {
          final list = decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => PagoModel.fromJson(item))
              .toList();
          return PaginatedResponse<PagoModel>(
            pagina: pagina,
            tamanoPagina: tamanoPagina,
            total: list.length,
            items: list,
          );
        }
        return PaginatedResponse<PagoModel>(
          pagina: pagina,
          tamanoPagina: tamanoPagina,
          total: 0,
          items: [],
        );
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible obtener la lista de pagos.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.getPagos');
      rethrow;
    }
  }

  /// Obtiene una URL firmada de corta duración para visualizar o descargar el comprobante
  Future<String> getComprobanteUrl(String pagoId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pagos/$pagoId/comprobante-url');
      final response = await controller.httpClient.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && (decoded['url'] != null || decoded['urlFirmada'] != null)) {
          return (decoded['url'] ?? decoded['urlFirmada']).toString();
        }
        throw Exception('URL firmada no encontrada en la respuesta');
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible obtener el enlace del comprobante.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.getComprobanteUrl');
      rethrow;
    }
  }

  // ==========================================
  // 3. Módulo Cargos (/api/cargos)
  // ==========================================

  /// Crea un cobro manual extraordinario o individual (Admin)
  Future<CargoModel> crearCargo({
    required int viviendaId,
    required String tipo,
    required String concepto,
    required double monto,
    required String fechaVencimiento,
    required String periodo,
    String? notas,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/cargos');
      final body = {
        'vivienda_id': viviendaId,
        'viviendaId': viviendaId,
        'tipo': tipo,
        'concepto': concepto,
        'monto': monto,
        'fecha_vencimiento': fechaVencimiento,
        'fechaVencimiento': fechaVencimiento,
        'periodo': periodo,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      };

      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return CargoModel.fromJson(decoded as Map<String, dynamic>);
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible crear el cargo.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.crearCargo');
      rethrow;
    }
  }

  /// Lista los cargos de la vivienda (inquilino) o del condominio (admin)
  Future<PaginatedResponse<CargoModel>> getCargos({
    int? viviendaId,
    String? estado,
    String? tipo,
    String? periodo,
    bool? vencidosSolo,
    int pagina = 1,
    int tamanoPagina = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': pagina.toString(),
        'pageSize': tamanoPagina.toString(),
        'pagina': pagina.toString(),
        'tamanoPagina': tamanoPagina.toString(),
        if (viviendaId != null) ...{
          'vivienda_id': viviendaId.toString(),
          'viviendaId': viviendaId.toString(),
        },
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
        if (periodo != null && periodo.isNotEmpty) 'periodo': periodo,
        if (vencidosSolo != null) ...{
          'vencido': vencidosSolo.toString(),
          'vencidosSolo': vencidosSolo.toString(),
        },
      };

      final uri = Uri.parse('$baseUrl/api/cargos').replace(queryParameters: queryParams);
      final response = await controller.httpClient.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return PaginatedResponse<CargoModel>.fromJson(
            decoded,
            (item) => CargoModel.fromJson(item),
          );
        } else if (decoded is List) {
          final list = decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => CargoModel.fromJson(item))
              .toList();
          return PaginatedResponse<CargoModel>(
            pagina: pagina,
            tamanoPagina: tamanoPagina,
            total: list.length,
            items: list,
          );
        }
        return PaginatedResponse<CargoModel>(
          pagina: pagina,
          tamanoPagina: tamanoPagina,
          total: 0,
          items: [],
        );
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible consultar los cargos.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.getCargos');
      rethrow;
    }
  }

  /// Detalle completo de un cargo, incluyendo el historial de abonos
  Future<CargoModel> getCargoDetalle(String cargoId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/cargos/$cargoId');
      final response = await controller.httpClient.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return CargoModel.fromJson(decoded as Map<String, dynamic>);
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible obtener el detalle del cargo.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.getCargoDetalle');
      rethrow;
    }
  }

  /// Aplica saldo a favor acumulado de la vivienda a un cargo pendiente
  Future<Map<String, dynamic>> aplicarSaldo(String cargoId, double monto) async {
    try {
      final uri = Uri.parse('$baseUrl/api/cargos/$cargoId/aplicar-saldo');
      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({'monto': monto}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible aplicar el saldo al cargo.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.aplicarSaldo');
      rethrow;
    }
  }

  /// Cancela un cargo (solo si no tiene pagos confirmados asociados)
  Future<Map<String, dynamic>> cancelarCargo(String cargoId, String motivo) async {
    try {
      final uri = Uri.parse('$baseUrl/api/cargos/$cargoId/cancelar');
      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({'motivo': motivo}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible cancelar el cargo.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.cancelarCargo');
      rethrow;
    }
  }

  // ==========================================
  // 4. Módulo Plantillas (/api/plantillas-cargo)
  // ==========================================

  /// Configura cuotas periódicas de forma masiva (Admin)
  Future<Map<String, dynamic>> crearPlantilla({
    required String concepto,
    required String tipo,
    required double monto,
    required int diaVencimiento,
    required String vigenciaInicio,
    String? vigenciaFin,
    required String responsablePago,
    required List<Map<String, dynamic>> viviendas,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/plantillas-cargo');
      final body = {
        'concepto': concepto,
        'tipo': tipo,
        'monto': monto,
        'dia_vencimiento': diaVencimiento,
        'diaVencimiento': diaVencimiento,
        'vigencia_inicio': vigenciaInicio,
        'vigenciaInicio': vigenciaInicio,
        if (vigenciaFin != null) ...{
          'vigencia_fin': vigenciaFin,
          'vigenciaFin': vigenciaFin,
        },
        'responsable_pago': responsablePago,
        'responsablePago': responsablePago,
        'viviendas': viviendas,
      };

      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible crear la plantilla de cargo.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.crearPlantilla');
      rethrow;
    }
  }

  /// Disparador manual para generar cargos del periodo a partir de plantillas activas (Admin)
  Future<Map<String, dynamic>> generarCargosPeriodo(String periodo) async {
    try {
      final uri = Uri.parse('$baseUrl/api/plantillas-cargo/generar');
      final response = await controller.httpClient.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({'periodo': periodo}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible generar los cargos del periodo.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.generarCargosPeriodo');
      rethrow;
    }
  }

  // ==========================================
  // 5. Módulo Saldos (/api/saldos)
  // ==========================================

  /// Consulta rápida de la posición financiera del usuario residente en sesión
  Future<MiSaldoResponse> getMiSaldo() async {
    try {
      final uri = Uri.parse('$baseUrl/api/saldos/mi-saldo');
      final response = await controller.httpClient.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return MiSaldoResponse.fromJson(decoded as Map<String, dynamic>);
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible obtener el saldo de la cuenta.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.getMiSaldo');
      rethrow;
    }
  }

  /// Obtiene el balance consolidado de una casa específica
  Future<SaldoViviendaResumen> getSaldoVivienda(int viviendaId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/saldos/viviendas/$viviendaId');
      final response = await controller.httpClient.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return SaldoViviendaResumen.fromJson(decoded as Map<String, dynamic>);
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible obtener el saldo de la vivienda.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.getSaldoVivienda');
      rethrow;
    }
  }

  /// Historial de entradas y salidas de la bolsa de saldo a favor
  Future<PaginatedResponse<MovimientoSaldoModel>> getMovimientosSaldo(
    int viviendaId, {
    String? tipo,
    DateTime? desde,
    DateTime? hasta,
    int pagina = 1,
    int tamanoPagina = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'pagina': pagina.toString(),
        'tamanoPagina': tamanoPagina.toString(),
        if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
        if (desde != null) 'desde': desde.toUtc().toIso8601String(),
        if (hasta != null) 'hasta': hasta.toUtc().toIso8601String(),
      };

      final uri = Uri.parse('$baseUrl/api/saldos/viviendas/$viviendaId/movimientos')
          .replace(queryParameters: queryParams);

      final response = await controller.httpClient.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return PaginatedResponse<MovimientoSaldoModel>.fromJson(
            decoded,
            (item) => MovimientoSaldoModel.fromJson(item),
          );
        } else if (decoded is List) {
          final list = decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => MovimientoSaldoModel.fromJson(item))
              .toList();
          return PaginatedResponse<MovimientoSaldoModel>(
            pagina: pagina,
            tamanoPagina: tamanoPagina,
            total: list.length,
            items: list,
          );
        }
        return PaginatedResponse<MovimientoSaldoModel>(
          pagina: pagina,
          tamanoPagina: tamanoPagina,
          total: 0,
          items: [],
        );
      } else {
        final errorMsg = ErrorHandler.extractErrorMessage(
          response.body,
          statusCode: response.statusCode,
          defaultMessage: 'No fue posible consultar los movimientos de saldo.',
        );
        throw Exception(errorMsg);
      }
    } catch (e, stack) {
      ErrorHandler.trackError(e, stack, 'PagosService.getMovimientosSaldo');
      rethrow;
    }
  }
}
