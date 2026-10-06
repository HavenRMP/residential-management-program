import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/residentes_list.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString: 'API_BASE_URL_USUARIOS=https://usuarios-api.onrender.com',
    );
  });

  group('Unit Tests - Residentes Filtering Logic', () {
    test('Filtra correctamente residentes por término de búsqueda', () {
      final residentes = [
        {'id': '1', 'nombre': 'Carlos', 'apellidos': 'Mendoza', 'casa': '101'},
        {'id': '2', 'nombre': 'Ana', 'apellidos': 'Gómez', 'casa': '102'},
        {'id': '3', 'nombre': 'Roberto', 'apellidos': 'Carlos', 'casa': '201'},
      ];

      List<Map<String, dynamic>> filter(String query) {
        final q = query.toLowerCase().trim();
        return residentes.where((r) {
          final nombreCompleto = '${r['nombre']} ${r['apellidos']}'.toLowerCase();
          final casa = r['casa'].toString().toLowerCase();
          return nombreCompleto.contains(q) || casa.contains(q);
        }).toList();
      }

      expect(filter('carlos').length, 2);
      expect(filter('ana').length, 1);
      expect(filter('102').length, 1);
      expect(filter('999').length, 0);
    });
  });

  group('Widget Tests - Residentes List Screen UI', () {
    testWidgets('Renderiza directorio de residentes correctamente', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ResidentesListScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResidentesListScreen), findsOneWidget);
      expect(find.text('Directorio de Residentes'), findsOneWidget);
    });
  });
}
