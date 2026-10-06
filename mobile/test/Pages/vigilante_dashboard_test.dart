import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/vigilante_dashboard.dart';
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

  group('Unit Tests - Vigilante Dashboard Logic', () {
    test('Verifica formato de códigos de acceso QR o manual', () {
      bool isValidCode(String code) {
        final clean = code.trim().toUpperCase();
        return clean.length >= 6 && RegExp(r'^[A-Z0-9]+$').hasMatch(clean);
      }

      expect(isValidCode('VISITA123'), isTrue);
      expect(isValidCode('ABC123'), isTrue);
      expect(isValidCode('123'), isFalse);
      expect(isValidCode('codigo-con-guion'), isFalse);
    });
  });

  group('Widget Tests - Vigilante Dashboard UI & Tabs', () {
    testWidgets('Renderiza contenedor de vigilante y barra de navegación', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: VigilanteDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VigilanteDashboardScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Visitas'), findsOneWidget);
      expect(find.text('Directorio'), findsOneWidget);
    });

    testWidgets('Permite alternar a la pestaña Directorio', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: VigilanteDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final directorioTab = find.text('Directorio');
      expect(directorioTab, findsOneWidget);

      await tester.tap(directorioTab);
      await tester.pumpAndSettle();

      expect(find.byType(VigilanteDashboardScreen), findsOneWidget);
    });
  });
}
