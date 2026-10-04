import 'package:flutter/material.dart';

import '../Services/app_controller.dart';
import '../Pages/login_screen.dart';
import '../Pages/admin_dashboard.dart';
import '../Pages/vigilante_dashboard.dart';
import '../Pages/residente_dashboard.dart';
import '../Pages/perfil_screen.dart';
import '../Widgets/splash_screen.dart';

class AppRouter extends StatelessWidget {
  final AppController controller;

  const AppRouter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isInitializing) {
          return const SplashScreen();
        }

        if (!controller.isAuthenticated) {
          return LoginScreen(controller: controller);
        }

        // Onboarding para usuarios nuevos de Google (o perfil incompleto)
        if (controller.isProfileIncomplete) {
          return PerfilScreen(controller: controller, isOnboarding: true);
        }

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
          return AdminDashboardScreen(controller: controller);
        }
        if (role == 'vigilante' ||
            role == 'guardia' ||
            role == 'guard' ||
            role == '3') {
          return VigilanteDashboardScreen(controller: controller);
        }
        return ResidenteDashboardScreen(controller: controller);
      },
    );
  }
}
