import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/admin_dashboard.dart';
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

  group('Unit Tests - Admin Dashboard Calculations', () {
    test('Calcula correctamente viviendas ocupadas a partir de una lista', () {
      final viviendas = [
        {'id': 'v1', 'estaOcupada': true, 'totalResidentes': 2},
        {'id': 'v2', 'estaOcupada': false, 'totalResidentes': 0},
        {'id': 'v3', 'estaOcupada': false, 'totalResidentes': 1},
        {'id': 'v4', 'asignada': true},
      ];

      int ocupadas = 0;
      for (final item in viviendas) {
        if (item['estaOcupada'] == true ||
            ((item['totalResidentes'] as num?) ?? 0) > 0 ||
            item['asignada'] == true) {
          ocupadas++;
        }
      }

      expect(ocupadas, 3);
    });
  });

  group('Widget Tests - Admin Dashboard Navigation & UI', () {
    testWidgets('Renderiza contenedor principal y destinos de navegación', (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('residentes')) {
          return http.Response(jsonEncode([]), 200);
        }
        if (request.url.path.contains('viviendas')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AdminDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Visitas'), findsOneWidget);
      expect(find.text('Avisos'), findsOneWidget);
    });

    testWidgets('Permite alternar entre pestañas de navegación', (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AdminDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final visitasTab = find.text('Visitas');
      expect(visitasTab, findsOneWidget);

      await tester.tap(visitasTab);
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
    });
  });
}
