import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/residente_dashboard.dart';
import 'package:haven/Pages/vigilante_dashboard.dart';
import 'package:haven/Pages/admin_dashboard.dart';
import 'package:haven/Pages/paqueteria_residente_screen.dart';
import 'package:haven/Pages/paqueteria_caseta_screen.dart';
import 'package:haven/Widgets/qr_scanner_view.dart';
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

  group('Dashboard Horizontal Swipe & Camera Isolation Tests', () {
    testWidgets('ResidenteDashboard soporta deslizamiento horizontal y aísla el sensor de cámara', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Verifica que exista el PageView del dashboard de residentes
      final pageViewFinder = find.byKey(const Key('residente_dashboard_page_view'));
      expect(pageViewFinder, findsOneWidget);

      // En la pestaña Inicio (0), el sensor de cámara NO debe estar montado
      expect(find.byType(QrScannerView), findsNothing);

      // Deslizar horizontalmente hacia la izquierda (hacia Visitas)
      await tester.drag(pageViewFinder, const Offset(-450, 0));
      await tester.pumpAndSettle();

      // Cámara sigue totalmente apagada/desmontada
      expect(find.byType(QrScannerView), findsNothing);

      // Deslizar hacia la pestaña de Paquetes
      await tester.drag(pageViewFinder, const Offset(-450, 0));
      await tester.pumpAndSettle();

      expect(find.byType(PaqueteriaResidenteScreen), findsOneWidget);
      expect(find.byType(QrScannerView), findsNothing);

      // Navegar a la pestaña Escanear mediante la barra de navegación
      final escanearTab = find.text('Escanear');
      expect(escanearTab, findsOneWidget);
      await tester.tap(escanearTab);
      await tester.pumpAndSettle();

      // Ahora sí se monta el visor de cámara para escanear
      expect(find.byType(QrScannerView), findsOneWidget);

      // Navegar de regreso a Inicio
      final inicioTab = find.text('Inicio');
      await tester.tap(inicioTab);
      await tester.pumpAndSettle();

      // La cámara debe desmontarse inmediatamente para apagar el sensor de hardware
      expect(find.byType(QrScannerView), findsNothing);
    });

    testWidgets('VigilanteDashboard soporta deslizamiento horizontal entre Visitas y Paquetería', (WidgetTester tester) async {
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

      final pageViewFinder = find.byKey(const Key('vigilante_dashboard_page_view'));
      expect(pageViewFinder, findsOneWidget);

      // Navegar a la pestaña Paquetería
      final paqueteriaTab = find.text('Paquetería');
      expect(paqueteriaTab, findsOneWidget);
      await tester.tap(paqueteriaTab);
      await tester.pumpAndSettle();

      expect(find.byType(PaqueteriaCasetaScreen), findsOneWidget);
    });

    testWidgets('AdminDashboard soporta PageView con desplazamiento horizontal fluido', (WidgetTester tester) async {
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
          home: AdminDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_dashboard_page_view')), findsOneWidget);
    });
  });
}
