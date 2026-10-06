import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/registro_residente_screen.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Unit Tests - Registro Residente Logic', () {
    test('Verifica lógica de contraseñas coincidentes y longitud', () {
      bool passwordsMatch(String p1, String p2) => p1 == p2 && p1.length >= 6;

      expect(passwordsMatch('Password123', 'Password123'), isTrue);
      expect(passwordsMatch('Password123', 'DifferentPassword'), isFalse);
      expect(passwordsMatch('123', '123'), isFalse);
    });
  });

  group('Widget Tests - Registro Residente Screen UI', () {
    testWidgets('Renderiza campos del formulario de registro y botón crear cuenta', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController(null);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RegistroResidenteScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RegistroResidenteScreen), findsOneWidget);
      expect(find.text('Crear mi cuenta'), findsOneWidget);
      expect(find.text('Inicia sesión aquí'), findsOneWidget);
    });
  });
}
