import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haven/Pages/paqueteria_caseta_screen.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/app_theme.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL_VISITAS=https://visitas-api.onrender.com',
    );
  });

  group('PaqueteriaCasetaScreen Widget Tests', () {
    testWidgets('Renderiza pantalla de caseta, tabs y botones principales', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/paqueteria/esperados') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'esp-1',
                  'viviendaId': 3,
                  'numeroCasa': '15',
                  'destinatarioNombre': 'Rosa Hernandez',
                  'servicioNombre': 'FedEx',
                  'estado': 'esperado',
                }
              ],
              'totalCount': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/paqueteria/inventario') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'inv-1',
                  'viviendaId': 4,
                  'numeroCasa': '16',
                  'destinatarioNombre': 'Miguel Angel',
                  'servicioNombre': 'Amazon',
                  'estado': 'recibido',
                  'ubicacionAlmacen': 'Estante B2',
                }
              ],
              'totalCount': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/paqueteria/historico') {
          return http.Response(
            jsonEncode({'items': [], 'totalCount': 0}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PaqueteriaCasetaScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caseta · Paquetería'), findsOneWidget);
      expect(find.text('Esperados (1)'), findsOneWidget);
      expect(find.text('Inventario (1)'), findsOneWidget);
      expect(find.text('Histórico'), findsOneWidget);
      expect(find.text('Recibir Paquete'), findsOneWidget);

      expect(find.text('FedEx'), findsOneWidget);
      expect(find.text('Recibir en Caseta'), findsOneWidget);

      // Alternar a pestaña Inventario
      final inventarioTab = find.text('Inventario (1)');
      await tester.tap(inventarioTab);
      await tester.pumpAndSettle();

      expect(find.text('Amazon'), findsOneWidget);
      expect(find.text('Entregar a Residente'), findsOneWidget);
    });

    testWidgets('Muestra estado vacío amigable cuando el inventario está vacío', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'items': [], 'totalCount': 0}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PaqueteriaCasetaScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay paquetes esperados registrados para hoy.'), findsOneWidget);
    });
  });
}
