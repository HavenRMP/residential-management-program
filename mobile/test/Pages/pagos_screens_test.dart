import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:haven/Models/pagos_models.dart';
import 'package:haven/Pages/pagos_residente_screen.dart';
import 'package:haven/Pages/pagos_admin_screen.dart';
import 'package:haven/Widgets/reportar_pago_modal.dart';
import 'package:haven/Widgets/crear_cargo_modal.dart';
import 'package:haven/Widgets/comprobante_dialog.dart';
import 'package:haven/Services/pagos_service.dart';
import 'package:haven/Services/app_controller.dart';

class MockAppController extends AppController {
  MockAppController(http.Client client) : super.unavailable() {
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

  group('Pagos UI Tests', () {
    testWidgets('PagosResidenteScreen renders financial summary and tabs', (tester) async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path.contains('/api/saldos/mi-saldo')) {
          return http.Response(
            jsonEncode({
              'totalPendiente': 1500.0,
              'totalVencido': 500.0,
              'totalCargosAbiertos': 1,
              'saldoAFavor': 250.0,
              'viviendas': [
                {
                  'viviendaId': 10,
                  'numeroCasa': '101',
                  'totalPendiente': 1500.0,
                  'totalVencido': 500.0,
                  'totalCargosAbiertos': 1,
                  'saldoAFavor': 250.0,
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/api/cargos')) {
          return http.Response(
            jsonEncode({
              'pagina': 1,
              'tamanoPagina': 20,
              'total': 1,
              'items': [
                {
                  'id': 'cargo-1',
                  'viviendaId': 10,
                  'tipo': 'Mantenimiento',
                  'concepto': 'Mantenimiento Noviembre',
                  'monto': 1500.0,
                  'saldoPendiente': 1500.0,
                  'estado': 'Pendiente',
                  'fechaVencimiento': '2026-11-15',
                  'pagosAsociados': [],
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/api/pagos')) {
          return http.Response(
            jsonEncode({'pagina': 1, 'tamanoPagina': 20, 'total': 0, 'items': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/api/saldos/viviendas')) {
          return http.Response(
            jsonEncode({'pagina': 1, 'tamanoPagina': 20, 'total': 0, 'items': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final controller = MockAppController(mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: PagosResidenteScreen(
            controller: controller,
            misViviendas: const [
              {'id': 10, 'numeroCasa': '101', 'tipo': 'Casa'}
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pagos y Estado de Cuenta'), findsOneWidget);
      expect(find.text('\$1500.00'), findsWidgets);
      expect(find.text('Cargos y Cuotas'), findsOneWidget);
      expect(find.text('Historial de Pagos'), findsOneWidget);
      expect(find.text('Saldo a Favor'), findsWidgets);
      expect(find.text('Mantenimiento Noviembre'), findsOneWidget);
      expect(find.text('Reportar Pago'), findsOneWidget);
    });

    testWidgets('ReportarPagoModal renders form fields and upload section', (tester) async {
      final mockClient = http_testing.MockClient((req) async => http.Response('{}', 200));
      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      const cargo = CargoModel(
        id: 'cargo-99',
        viviendaId: 10,
        tipo: 'Mantenimiento',
        concepto: 'Cuota Especial',
        monto: 850.0,
        saldoPendiente: 850.0,
        estado: 'Pendiente',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportarPagoModal(
              cargo: cargo,
              viviendaId: 10,
              pagosService: service,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reportar Pago de Cuota'), findsOneWidget);
      expect(find.text('Cuota Especial'), findsOneWidget);
      expect(find.text('Saldo pendiente: \$850.00'), findsOneWidget);
      expect(find.text('Tomar Foto'), findsOneWidget);
      expect(find.text('Galería'), findsOneWidget);
      expect(find.text('Reportar Pago'), findsOneWidget);
    });

    testWidgets('PagosAdminScreen renders validation tabs and action buttons', (tester) async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path.contains('/api/Viviendas')) {
          return http.Response(
            jsonEncode([
              {'id': 10, 'numeroCasa': '101'}
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/api/pagos') &&
            request.url.queryParameters['estado'] == 'PendienteConfirmacion') {
          return http.Response(
            jsonEncode({
              'pagina': 1,
              'tamanoPagina': 20,
              'total': 1,
              'items': [
                {
                  'id': 'pago-777',
                  'cargoId': 'cargo-1',
                  'monto': 1250.0,
                  'metodo': 'Transferencia',
                  'estado': 'PendienteConfirmacion',
                  'folioComprobante': 'TRF-123',
                  'notas': 'Comprobante de depósito',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/api/cargos')) {
          return http.Response(
            jsonEncode({'pagina': 1, 'tamanoPagina': 20, 'total': 0, 'items': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/api/pagos')) {
          return http.Response(
            jsonEncode({'pagina': 1, 'tamanoPagina': 20, 'total': 0, 'items': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final controller = MockAppController(mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: PagosAdminScreen(controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Administración de Cobranza'), findsOneWidget);
      expect(find.text('Por Validar'), findsWidgets);
      expect(find.text('Cargos'), findsOneWidget);
      expect(find.text('Plantillas'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('\$1250.00'), findsOneWidget);
      expect(find.text('Confirmar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
    });

    testWidgets('CrearCargoModal renders fields properly', (tester) async {
      final mockClient = http_testing.MockClient((req) async => http.Response('{}', 200));
      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrearCargoModal(
              viviendas: const [
                {'id': 10, 'numeroCasa': '101'}
              ],
              pagosService: service,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nuevo Cargo Manual'), findsOneWidget);
      expect(find.text('Casa #101'), findsOneWidget);
      expect(find.text('Crear Cargo'), findsOneWidget);
    });

    testWidgets('ComprobanteDialog renders receipt viewer structure', (tester) async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            'pagoId': 'pago-1',
            'urlFirmada': 'https://example.com/recibo.jpg',
            'expiraEn': '2026-10-23T18:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = MockAppController(mockClient);
      final service = PagosService(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComprobanteDialog(
              pagoId: 'pago-1',
              urlFirmadaInicial: 'https://example.com/recibo.jpg',
              pagosService: service,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Comprobante de Pago'), findsOneWidget);
      expect(
        find.text('Enlace firmado de alta seguridad. Expira en 5 minutos.'),
        findsOneWidget,
      );
      expect(find.text('Cerrar'), findsOneWidget);
    });
  });
}
