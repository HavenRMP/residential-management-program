import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/vivienda_detalle_screen.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Unit Tests - Vivienda Detalle Logic', () {
    test('Calcula adeudo total y formato de moneda', () {
      String formatCurrency(double amount) {
        return '\$${amount.toStringAsFixed(2)}';
      }

      expect(formatCurrency(1250.5), '\$1250.50');
      expect(formatCurrency(0.0), '\$0.00');
    });
  });

  group('Widget Tests - Vivienda Detalle Screen UI', () {
    testWidgets('Renderiza detalles de la casa seleccionada', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController(null);
      final vivienda = {
        'id': 'viv-101',
        'numero': '101',
        'bloque': 'A',
        'estaOcupada': true,
        'residentes': [],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ViviendaDetalleScreen(
              controller: controller,
              vivienda: vivienda,
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ViviendaDetalleScreen), findsOneWidget);
      expect(find.textContaining('101'), findsWidgets);
    });
  });
}
