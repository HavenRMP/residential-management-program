import 'package:flutter/material.dart';

import '../Services/app_controller.dart';
import '../Pages/login_screen.dart';
import '../Pages/admin_dashboard.dart';
import '../Pages/vigilante_dashboard.dart';
import '../Pages/residente_dashboard.dart';
import '../Pages/perfil_screen.dart';
import '../Widgets/splash_screen.dart';
import '../Themes/animation_constants.dart';

/// Enrutador principal de nivel superior que gestiona el estado de autenticación
/// y rol del usuario, incorporando transiciones suaves y fluidas entre estados.
class AppRouter extends StatelessWidget {
  final AppController controller;

  const AppRouter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final Widget activeScreen;

        if (controller.isInitializing) {
          activeScreen = const SplashScreen(
            key: ValueKey('router_splash'),
          );
        } else if (!controller.isAuthenticated) {
          activeScreen = LoginScreen(
            key: const ValueKey('router_login'),
            controller: controller,
          );
        } else if (controller.isProfileIncomplete) {
          activeScreen = PerfilScreen(
            key: const ValueKey('router_onboarding'),
            controller: controller,
            isOnboarding: true,
          );
        } else {
          final role = (controller.currentUser?.rol ??
                  controller.currentUser?.role ??
                  controller.currentUser?.rolNombre ??
                  '')
              .toLowerCase()
              .trim();

          if (role == 'administrador' ||
              role == 'admin' ||
              role == 'administrator' ||
              role == '1') {
            activeScreen = AdminDashboardScreen(
              key: const ValueKey('router_admin'),
              controller: controller,
            );
          } else if (role == 'vigilante' ||
              role == 'guardia' ||
              role == 'guard' ||
              role == '3') {
            activeScreen = VigilanteDashboardScreen(
              key: const ValueKey('router_vigilante'),
              controller: controller,
            );
          } else {
            activeScreen = ResidenteDashboardScreen(
              key: const ValueKey('router_residente'),
              controller: controller,
            );
          }
        }

        return AnimatedSwitcher(
          duration: HavenAnimationDurations.pageTransition,
          reverseDuration: HavenAnimationDurations.pageTransitionReverse,
          switchInCurve: HavenAnimationCurves.scaleEnterCurve,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: HavenAnimationCurves.scaleEnterCurve,
                  ),
                ),
                child: child,
              ),
            );
          },
          child: activeScreen,
        );
      },
    );
  }
}
