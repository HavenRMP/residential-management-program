import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Widgets/banner_widget.dart';
import 'package:haven/Widgets/field_label.dart';
import 'package:haven/Widgets/qr_dialog.dart';

void main() {
  group('Core UI Components', () {
    testWidgets('FieldLabel renders text with correct styles', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FieldLabel(text: 'Correo Electrónico'),
          ),
        ),
      );

      expect(find.text('Correo Electrónico'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Correo Electrónico'));
      expect(textWidget.style?.fontWeight, FontWeight.w600);
      expect(textWidget.style?.fontSize, 14);
    });

    testWidgets('BannerWidget renders error message and error icon', (WidgetTester tester) async {
      const errorMessage = 'Error al conectar con el servidor';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BannerWidget(message: errorMessage),
          ),
        ),
      );

      expect(find.text(errorMessage), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('Login Form Validation Interactions', () {
    testWidgets('Form shows validation error when inputs are empty or invalid', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      final emailController = TextEditingController();
      final passwordController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: emailController,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'El correo es requerido.';
                      if (!t.contains('@')) return 'Ingrese un correo válido.';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: passwordController,
                    validator: (v) {
                      final t = v ?? '';
                      if (t.isEmpty) return 'La contraseña es requerida.';
                      if (t.length < 6) return 'La contraseña debe tener al menos 6 caracteres.';
                      return null;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      formKey.currentState?.validate();
                    },
                    child: const Text('Validar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Tap validate with empty form
      await tester.tap(find.text('Validar'));
      await tester.pump();

      expect(find.text('El correo es requerido.'), findsOneWidget);
      expect(find.text('La contraseña es requerida.'), findsOneWidget);

      // Enter invalid email and short password
      await tester.enterText(find.byType(TextFormField).first, 'usuario_sin_arroba');
      await tester.enterText(find.byType(TextFormField).last, '123');
      await tester.tap(find.text('Validar'));
      await tester.pump();

      expect(find.text('Ingrese un correo válido.'), findsOneWidget);
      expect(find.text('La contraseña debe tener al menos 6 caracteres.'), findsOneWidget);

      // Enter valid fields
      await tester.enterText(find.byType(TextFormField).first, 'usuario@haven.com');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('Validar'));
      await tester.pump();

      expect(find.text('Ingrese un correo válido.'), findsNothing);
      expect(find.text('La contraseña debe tener al menos 6 caracteres.'), findsNothing);
    });
  });

  group('QrDialog Sharing & Display Tests', () {
    testWidgets('QrDialog renders title, code, subtitle and share buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrDialog(
              codigo: 'HAVEN-7788',
              titulo: 'Pase de Visita',
              subtitulo: 'Muestra este código al vigilante',
              tipoEtiqueta: 'Casa 101',
            ),
          ),
        ),
      );

      expect(find.text('Pase de Visita'), findsOneWidget);
      expect(find.text('HAVEN-7788'), findsOneWidget);
      expect(find.text('Casa 101'), findsOneWidget);
      expect(find.text('Muestra este código al vigilante'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsNWidgets(2)); // Icon in code badge + button
    });

    testWidgets('QrDialog triggers onCompartir when share button is tapped', (WidgetTester tester) async {
      bool compartido = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrDialog(
              codigo: 'CODE-999',
              onCompartir: () {
                compartido = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Compartir'));
      await tester.pump();

      expect(compartido, isTrue);
    });
  });
}
