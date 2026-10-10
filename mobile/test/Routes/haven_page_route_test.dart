import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Routes/haven_page_route.dart';
import 'package:haven/Themes/animation_constants.dart';

void main() {
  group('HavenPageRoute Tests', () {
    test('configura duraciones predeterminadas correctamente', () {
      final route = HavenPageRoute(builder: (_) => const SizedBox());
      expect(route.transitionDuration, equals(HavenAnimationDurations.pageTransition));
      expect(route.reverseTransitionDuration, equals(HavenAnimationDurations.pageTransitionReverse));
    });

    testWidgets('HavenPageRoute.slideHorizontal empuja pantalla y anima fluidamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    HavenPageRoute.slideHorizontal(
                      builder: (_) => const Scaffold(body: Text('Pantalla Horizontal')),
                    ),
                  );
                },
                child: const Text('Navegar Horizontal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navegar Horizontal'));
      await tester.pump(); // Inicia la transición
      expect(find.byType(SlideTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Pantalla Horizontal'), findsOneWidget);
    });

    testWidgets('HavenPageRoute.slideUp empuja pantalla modal con Slide y Fade', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  HavenPageRoute.push(
                    context,
                    const Scaffold(body: Text('Pantalla Slide Up')),
                    type: HavenTransitionType.slideUp,
                  );
                },
                child: const Text('Navegar Slide Up'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navegar Slide Up'));
      await tester.pump();
      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Pantalla Slide Up'), findsOneWidget);
    });

    testWidgets('HavenPageRoute.fadeScale empuja pantalla con ScaleTransition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  HavenPageRoute.push(
                    context,
                    const Scaffold(body: Text('Pantalla Fade Scale')),
                    type: HavenTransitionType.fadeScale,
                  );
                },
                child: const Text('Navegar Fade Scale'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navegar Fade Scale'));
      await tester.pump();
      expect(find.byType(ScaleTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Pantalla Fade Scale'), findsOneWidget);
    });

    testWidgets('HavenPageRoute.pushReplacement reemplaza la pantalla activa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  HavenPageRoute.pushReplacement(
                    context,
                    const Scaffold(body: Text('Pantalla Reemplazada')),
                  );
                },
                child: const Text('Reemplazar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Reemplazar'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla Reemplazada'), findsOneWidget);
      expect(find.text('Reemplazar'), findsNothing);
    });
  });
}
