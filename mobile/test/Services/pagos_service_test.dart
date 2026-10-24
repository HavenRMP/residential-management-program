import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:haven/Models/pagos_models.dart';
import 'package:haven/Services/pagos_service.dart';
import 'package:haven/Services/app_controller.dart';

class MockAppController extends AppController {
  MockAppController(http.Client client)
      : super.unavailable() {
    _testHttpClient = client;
  }

  late final http.Client _testHttpClient;

  @override
  http.Client get httpClient => _testHttpClient;

  @override
  Future<String?> getValidAccessToken() async => 'mock-jwt-token';
}

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL_PAGOS=https://pagos-api.onrender.com',
    );
  });

  group('PagosService Tests', () {
    test('reportarPago sends correct payload and returns PagoModel', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/pagos/reportar');
        expect(request.headers['Authorization'], 'Bearer mock-jwt-token');

        final body = jsonDecode(request.body);
        expect(body['cargoId'], 'cargo-123');
        expect(body['monto'], 1250.0);
        expect(body['metodo'], 'Transferencia');
        expect(body['rutaComprobante'], 'comprobantes/recibo.jpg');

        return http.Response(
          jsonEncode({
            'id': 'pago-999',
            'cargoId': 'cargo-123',
            'monto': 1250.0,
            'metodo': 'Transferencia',
            'estado': 'PendienteConfirmacion',
            'folioComprobante': 'TRF-111',
            'rutaComprobante': 'comprobantes/recibo.jpg',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      final pago = await service.reportarPago(
        cargoId: 'cargo-123',
        monto: 1250.0,
        metodo: MetodoPago.transferencia,
        rutaComprobante: 'comprobantes/recibo.jpg',
        folioComprobante: 'TRF-111',
      );

      expect(pago.id, 'pago-999');
      expect(pago.monto, 1250.0);
      expect(pago.estado, EstadoPago.pendienteConfirmacion);
    });

    test('confirmarPago sends POST /api/pagos/{id}/confirmar', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/pagos/pago-1/confirmar');

        return http.Response(
          jsonEncode({
            'pagoId': 'pago-1',
            'estado': 'Confirmado',
            'montoAplicado': 1250.0,
            'saldoRestanteCargo': 0.0,
            'nuevoEstadoCargo': 'Pagado',
            'saldoFavorGenerado': 0.0,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      final res = await service.confirmarPago('pago-1');
      expect(res['estado'], 'Confirmado');
      expect(res['nuevoEstadoCargo'], 'Pagado');
    });

    test('rechazarPago sends reason payload', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/pagos/pago-2/rechazar');
        final body = jsonDecode(request.body);
        expect(body['motivo'], 'Comprobante ilegible');

        return http.Response(
          jsonEncode({
            'pagoId': 'pago-2',
            'estado': 'Rechazado',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      final res = await service.rechazarPago('pago-2', 'Comprobante ilegible');
      expect(res['estado'], 'Rechazado');
    });

    test('getPagos queries with filters and parses PaginatedResponse', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/pagos');
        expect(request.url.queryParameters['estado'], 'PendienteConfirmacion');
        expect(request.url.queryParameters['pagina'], '1');

        return http.Response(
          jsonEncode({
            'pagina': 1,
            'tamanoPagina': 20,
            'total': 1,
            'items': [
              {
                'id': 'pago-55',
                'cargoId': 'cargo-1',
                'monto': 800.0,
                'metodo': 'Transferencia',
                'estado': 'PendienteConfirmacion',
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      final res = await service.getPagos(estado: EstadoPago.pendienteConfirmacion);
      expect(res.total, 1);
      expect(res.items.first.id, 'pago-55');
    });

    test('getComprobanteUrl returns signed temporary url', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/pagos/pago-10/comprobante-url');

        return http.Response(
          jsonEncode({
            'pagoId': 'pago-10',
            'urlFirmada': 'https://storage.supabase.co/sign/comprobante.jpg?token=abc',
            'expiraEn': '2026-10-22T17:15:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      final url = await service.getComprobanteUrl('pago-10');
      expect(url, contains('https://storage.supabase.co/sign'));
    });

    test('getCargos queries charges and parses correctly', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/cargos');
        expect(request.url.queryParameters['viviendaId'], '12');

        return http.Response(
          jsonEncode({
            'pagina': 1,
            'tamanoPagina': 20,
            'total': 2,
            'items': [
              {
                'id': 'cargo-1',
                'viviendaId': 12,
                'tipo': 'Mantenimiento',
                'concepto': 'Cuota Octubre',
                'monto': 1200.0,
                'saldoPendiente': 1200.0,
                'estado': 'Pendiente',
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      final res = await service.getCargos(viviendaId: 12);
      expect(res.total, 2);
      expect(res.items.first.concepto, 'Cuota Octubre');
    });

    test('getMiSaldo returns resident balance breakdown', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/saldos/mi-saldo');

        return http.Response(
          jsonEncode({
            'totalPendiente': 1500.0,
            'totalVencido': 500.0,
            'totalCargosAbiertos': 2,
            'saldoAFavor': 300.0,
            'viviendas': [
              {
                'viviendaId': 8,
                'numeroCasa': 'Casa 8-B',
                'totalPendiente': 1500.0,
                'totalVencido': 500.0,
                'totalCargosAbiertos': 2,
                'saldoAFavor': 300.0,
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      final saldo = await service.getMiSaldo();
      expect(saldo.totalPendiente, 1500.0);
      expect(saldo.saldoAFavor, 300.0);
      expect(saldo.viviendas.length, 1);
    });

    test('Error responses extract user-friendly messages', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'El monto transferido no coincide con el recibo adjunto.'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      expect(
        () => service.confirmarPago('pago-bad'),
        throwsA(predicate((e) =>
            e.toString().contains('El monto transferido no coincide'))),
      );
    });
  });
}
