import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Routes/app_router.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Themes/animation_constants.dart';

void main() {
  group('AppRouter Transition Tests', () {
    testWidgets('AppRouter envuelve las pantallas en un AnimatedSwitcher con animación de fade y escala', (tester) async {
      final controller = AppController(null);

      await tester.pumpWidget(
        MaterialApp(
          home: AppRouter(controller: controller),
        ),
      );

      // Debe existir un AnimatedSwitcher para las transiciones suaves
      expect(find.byType(AnimatedSwitcher), findsOneWidget);

      final animatedSwitcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );

      expect(
        animatedSwitcher.duration,
        equals(HavenAnimationDurations.pageTransition),
      );
      expect(
        animatedSwitcher.reverseDuration,
        equals(HavenAnimationDurations.pageTransitionReverse),
      );

      // En estado de inicialización, muestra splash screen con clave router_splash
      expect(find.byKey(const ValueKey('router_splash')), findsOneWidget);

      // Verifica que el transitionBuilder produce FadeTransition y ScaleTransition
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(ScaleTransition), findsWidgets);
    });

    testWidgets('AppRouter muestra LoginScreen cuando el controlador no está inicializando ni autenticado', (tester) async {
      final controller = AppController.unavailable('Servicio offline');

      await tester.pumpWidget(
        MaterialApp(
          home: AppRouter(controller: controller),
        ),
      );

      expect(find.byKey(const ValueKey('router_login')), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('router_login')), findsOneWidget);
    });
  });
}
