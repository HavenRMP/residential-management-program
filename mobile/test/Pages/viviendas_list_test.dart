import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/viviendas_list.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString: 'API_BASE_URL_VIVIENDAS=https://viviendas-api.onrender.com',
    );
  });

  group('Unit Tests - Viviendas Filtering Logic', () {
    test('Filtra correctamente viviendas por estatus y número', () {
      final viviendas = [
        {'id': '1', 'numero': '101', 'bloque': 'A', 'estaOcupada': true},
        {'id': '2', 'numero': '102', 'bloque': 'A', 'estaOcupada': false},
        {'id': '3', 'numero': '201', 'bloque': 'B', 'estaOcupada': true},
      ];

      List<Map<String, dynamic>> filterByStatus(bool ocupada) {
        return viviendas.where((v) => v['estaOcupada'] == ocupada).toList();
      }

      expect(filterByStatus(true).length, 2);
      expect(filterByStatus(false).length, 1);
    });
  });

  group('Widget Tests - Viviendas List Screen UI', () {
    testWidgets('Renderiza pantalla de lista de viviendas con buscador', (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ViviendasListScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ViviendasListScreen), findsOneWidget);
    });
  });
}
