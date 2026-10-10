import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Themes/app_theme.dart';
import 'package:haven/Routes/haven_page_transitions_builder.dart';

void main() {
  group('AppTheme PageTransitionsTheme Tests', () {
    test('lightTheme tiene configurado HavenPageTransitionsBuilder en todas las plataformas soportadas', () {
      final theme = AppTheme.lightTheme;
      final builders = theme.pageTransitionsTheme.builders;

      expect(builders[TargetPlatform.android], isA<HavenPageTransitionsBuilder>());
      expect(builders[TargetPlatform.iOS], isA<HavenPageTransitionsBuilder>());
      expect(builders[TargetPlatform.macOS], isA<HavenPageTransitionsBuilder>());
      expect(builders[TargetPlatform.windows], isA<HavenPageTransitionsBuilder>());
      expect(builders[TargetPlatform.linux], isA<HavenPageTransitionsBuilder>());
    });

    testWidgets('MaterialPageRoute hereda HavenPageTransitionsBuilder en navegación real', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        body: Text('Segunda Pantalla'),
                      ),
                    ),
                  );
                },
                child: const Text('Ir a Segunda'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ir a Segunda'), findsOneWidget);
      await tester.tap(find.text('Ir a Segunda'));
      await tester.pump(); // Inicia la transición

      // Durante la transición existen SlideTransition y FadeTransition
      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);

      // Avanzar al final de la transición
      await tester.pumpAndSettle();
      expect(find.text('Segunda Pantalla'), findsOneWidget);
    });
  });
}
