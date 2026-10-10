import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haven/Pages/paqueteria_residente_screen.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/app_theme.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL_VISITAS=https://visitas-api.onrender.com',
    );
  });

  group('PaqueteriaResidenteScreen Widget Tests', () {
    testWidgets('Renderiza pantalla, tabs y lista de paquetes esperados', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/paqueteria/mis-paquetes') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'pkg-1',
                  'viviendaId': 1,
                  'numeroCasa': '12A',
                  'destinatarioNombre': 'Juan Pérez',
                  'servicioNombre': 'Amazon',
                  'estado': 'esperado',
                },
                {
                  'id': 'pkg-2',
                  'viviendaId': 1,
                  'numeroCasa': '12A',
                  'destinatarioNombre': 'Juan Pérez',
                  'servicioNombre': 'Mercado Libre',
                  'estado': 'recibido',
                  'ubicacionAlmacen': 'Bodega 1',
                },
              ],
              'totalCount': 2,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/paqueteria/servicios') {
          return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PaqueteriaResidenteScreen(
            controller: controller,
            misViviendas: [
              {'id': 1, 'numeroCasa': '12A'}
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paquetería y Envíos'), findsOneWidget);
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Avisar Paquete'), findsOneWidget);

      expect(find.text('Amazon'), findsOneWidget);
      expect(find.text('Mercado Libre'), findsOneWidget);

      // Banner destacado de paquete recibido
      expect(find.text('¡Tienes 1 paquete(s) en caseta!'), findsOneWidget);
    });

    testWidgets('Muestra estado vacío amigable cuando no hay paquetes', (tester) async {
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
          home: PaqueteriaResidenteScreen(
            controller: controller,
            misViviendas: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tienes paquetes pendientes'), findsOneWidget);
    });
  });
}
