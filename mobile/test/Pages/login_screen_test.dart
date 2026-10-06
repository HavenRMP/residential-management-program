import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Pages/login_screen.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'remember_login_email': true,
      'saved_login_email': 'residente@haven.com',
    });
  });

  group('Unit Tests - Login Validation Logic', () {
    test('Verifica formato de correos válidos e inválidos', () {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      expect(emailRegex.hasMatch('test@haven.com'), isTrue);
      expect(emailRegex.hasMatch('admin.soporte@dominio.org'), isTrue);
      expect(emailRegex.hasMatch('correo-invalido'), isFalse);
      expect(emailRegex.hasMatch('sin_arroba.com'), isFalse);
      expect(emailRegex.hasMatch(''), isFalse);
    });

    test('Verifica longitud mínima y validez de contraseña', () {
      bool isValidPassword(String pass) => pass.trim().isNotEmpty && pass.length >= 6;
      expect(isValidPassword('123456'), isTrue);
      expect(isValidPassword('mi_clave_segura'), isTrue);
      expect(isValidPassword('12345'), isFalse);
      expect(isValidPassword('   '), isFalse);
    });
  });

  group('Widget Tests - Login Screen UI & Interactions', () {
    testWidgets('Renderiza campos de texto, botones principales y checkbox', (WidgetTester tester) async {
      final controller = AppController(null);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: LoginScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Recordar mi correo'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('residente@haven.com'), findsOneWidget);
    });

    testWidgets('Muestra mensajes de validación cuando los campos están vacíos', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'remember_login_email': false,
        'saved_login_email': '',
      });

      final controller = AppController(null);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: LoginScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Limpiar el campo si tenía texto
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '');
      await tester.enterText(textFields.last, '');

      // Presionar el botón Entrar
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();

      // Verificar que aparecieron los mensajes de validación exactos
      expect(find.text('El correo es requerido.'), findsOneWidget);
      expect(find.text('La contraseña es requerida.'), findsOneWidget);
    });

    testWidgets('Alterna la visibilidad de la contraseña al pulsar el icono del ojo', (WidgetTester tester) async {
      final controller = AppController(null);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: LoginScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleIcon = find.byIcon(Icons.visibility_off_outlined);
      expect(toggleIcon, findsOneWidget);

      await tester.tap(toggleIcon);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });
}
