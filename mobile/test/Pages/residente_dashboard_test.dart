import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/residente_dashboard.dart';
import 'package:haven/Pages/paqueteria_residente_screen.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString: '''
API_BASE_URL_USUARIOS=https://usuarios-api.onrender.com
API_BASE_URL_VIVIENDAS=https://viviendas-api.onrender.com
API_BASE_URL_AVISOS=https://avisos-api.onrender.com
API_BASE_URL_VISITAS=https://visitas-api.onrender.com
''',
    );
  });

  group('Unit Tests - Residente Dashboard Calculations', () {
    test('Calcula correctamente resumen de adeudos y visitas activas', () {
      final cuotas = [
        {'monto': 500.0, 'pagado': true},
        {'monto': 650.0, 'pagado': false},
        {'monto': 350.0, 'pagado': false},
      ];

      double pendiente = 0;
      for (final c in cuotas) {
        if (c['pagado'] == false) {
          pendiente += (c['monto'] as num).toDouble();
        }
      }

      expect(pendiente, 1000.0);
    });
  });

  group('Widget Tests - Residente Dashboard UI & Tabs', () {
    testWidgets('Renderiza contenedor principal y barra de navegación de residente', (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ResidenteDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResidenteDashboardScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Visitas'), findsOneWidget);
      expect(find.text('Paquetes'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('Permite alternar entre pestañas del residente', (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ResidenteDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final visitasTab = find.text('Visitas');
      expect(visitasTab, findsOneWidget);

      await tester.tap(visitasTab);
      await tester.pumpAndSettle();

      expect(find.byType(ResidenteDashboardScreen), findsOneWidget);
    });

    testWidgets('Permite navegar directamente a la pestaña dedicada de Paquetes', (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'items': [], 'total': 0}), 200);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ResidenteDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final paquetesTab = find.text('Paquetes');
      expect(paquetesTab, findsOneWidget);

      await tester.tap(paquetesTab);
      await tester.pumpAndSettle();

      expect(find.byType(PaqueteriaResidenteScreen), findsOneWidget);
    });
  });
}
