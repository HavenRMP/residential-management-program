import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Routes/haven_page_transitions_builder.dart';
import 'package:haven/Themes/animation_constants.dart';

void main() {
  group('HavenPageTransitionsBuilder Tests', () {
    testWidgets('construye la jerarquía completa de transiciones (Slide, Fade, Scale)', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: HavenAnimationDurations.pageTransition,
      );
      final secondaryController = AnimationController(
        vsync: const TestVSync(),
        duration: HavenAnimationDurations.pageTransition,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              const builder = HavenPageTransitionsBuilder();
              return builder.buildTransitions(
                MaterialPageRoute(builder: (_) => const SizedBox()),
                context,
                controller,
                secondaryController,
                const Text('Página Prueba'),
              );
            },
          ),
        ),
      );

      expect(find.text('Página Prueba'), findsOneWidget);
      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(ScaleTransition), findsOneWidget);

      controller.dispose();
      secondaryController.dispose();
    });

    testWidgets('anima suavemente de inicio (0.0) a fin (1.0)', (tester) async {
      late AnimationController controller;
      late AnimationController secondaryController;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              controller = AnimationController(
                vsync: const TestVSync(),
                duration: HavenAnimationDurations.pageTransition,
              );
              secondaryController = AnimationController(
                vsync: const TestVSync(),
                duration: HavenAnimationDurations.pageTransition,
              );

              return HavenPageTransitionsBuilder.buildHavenTransition(
                context: context,
                animation: controller,
                secondaryAnimation: secondaryController,
                child: const Text('Contenido'),
              );
            },
          ),
        ),
      );

      // Estado inicial (0.0)
      controller.value = 0.0;
      await tester.pump();
      final textFinder = find.text('Contenido');
      expect(textFinder, findsOneWidget);

      // Mitad de animación (0.5)
      controller.value = 0.5;
      await tester.pump();
      expect(textFinder, findsOneWidget);

      // Fin de animación (1.0)
      controller.value = 1.0;
      await tester.pump();
      expect(textFinder, findsOneWidget);

      // Efecto secundario cuando otra pantalla entra (secondaryController a 1.0)
      secondaryController.value = 1.0;
      await tester.pump();
      expect(textFinder, findsOneWidget);

      controller.dispose();
      secondaryController.dispose();
    });

    testWidgets('respeta dirección RTL invirtiendo el desplazamiento inicial', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: HavenAnimationDurations.pageTransition,
      );
      final secondaryController = AnimationController(
        vsync: const TestVSync(),
        duration: HavenAnimationDurations.pageTransition,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) {
                return HavenPageTransitionsBuilder.buildHavenTransition(
                  context: context,
                  animation: controller,
                  secondaryAnimation: secondaryController,
                  child: const Text('RTL Contenido'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('RTL Contenido'), findsOneWidget);
      controller.dispose();
      secondaryController.dispose();
    });
  });
}
