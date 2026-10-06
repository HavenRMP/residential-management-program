import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/perfil_screen.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Unit Tests - Perfil Validation Logic', () {
    test('Valida número de teléfono mexicano de 10 dígitos', () {
      bool isValidPhone(String phone) {
        final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
        return clean.length == 10;
      }

      expect(isValidPhone('5512345678'), isTrue);
      expect(isValidPhone('(55) 1234-5678'), isTrue);
      expect(isValidPhone('12345'), isFalse);
      expect(isValidPhone(''), isFalse);
    });

    test('Valida nombres y apellidos no vacíos', () {
      bool isValidName(String name) {
        final clean = name.trim();
        return clean.isNotEmpty && clean.toLowerCase() != 'sin nombre';
      }

      expect(isValidName('Carlos'), isTrue);
      expect(isValidName('sin nombre'), isFalse);
      expect(isValidName('   '), isFalse);
    });
  });

  group('Widget Tests - Perfil Screen UI', () {
    testWidgets('Renderiza pantalla de perfil con campos principales', (WidgetTester tester) async {
      final controller = AppController(null);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PerfilScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PerfilScreen), findsOneWidget);
      expect(find.text('Mi Perfil'), findsOneWidget);
    });
  });
}
