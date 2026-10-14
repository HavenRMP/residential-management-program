import 'Themes/app_theme.dart';
import 'Services/app_controller.dart';
import 'Routes/app_router.dart';
import 'Routes/haven_page_route.dart';
import 'Services/push_notifications_service.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'Pages/invitaciones_recibidas_screen.dart';
import 'Pages/visitas_residente_screen.dart';
import 'Pages/avisos_residente_screen.dart';
import 'Pages/paqueteria_residente_screen.dart';
import 'Widgets/offline_banner.dart';
import 'Utils/error_handler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Whether Supabase was successfully initialized.
/// When false the app will show LoginScreen without attempting auth operations.
bool supabaseReady = false;
String? supabaseInitError;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Intenta inicializar Firebase y las notificaciones.
    // Esto requiere que se haya ejecutado flutterfire configure
    await PushNotificationsService.initializeApp();
  } catch (e) {
    debugPrint('[main] Error al inicializar notificaciones push: $e');
  }

  try {
    await dotenv.load(fileName: ".env").timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[main] dotenv.load() timed out after 10 s');
      },
    );

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
          authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        // Ignorar el error si Supabase ya está inicializado (por ejemplo, en un hot restart)
        try {
          final _ = Supabase.instance.client;
        } catch (_) {
          rethrow;
        }
      }
      supabaseReady = true;
    } else {
      debugPrint('[main] Supabase credentials missing in .env');
    }
  } catch (e) {
    supabaseInitError = ErrorHandler.parseException(
      e,
      defaultMessage: 'No se pudo conectar con el servicio de autenticación.',
    );
    debugPrint('[main] Initialization error (app will still launch): $e');
  }

  runApp(const HavenApp());
}

class HavenApp extends StatefulWidget {
  const HavenApp({super.key});

  @override
  State<HavenApp> createState() => _HavenAppState();
}

class _HavenAppState extends State<HavenApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    if (supabaseReady) {
      controller = AppController(Supabase.instance.client);
      unawaited(controller.bootstrap());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(controller.checkBackendConnection());
      });
    } else {
      // Supabase didn't initialize — create a stub controller that
      // immediately transitions out of the splash so the user can retry.
      controller = AppController.unavailable(supabaseInitError);
    }

    PushNotificationsService.onMessageAction = (data) async {
      final tipo = data['tipo']?.toString().toLowerCase();
      if (!controller.isAuthenticated) return;

      if (tipo == 'invitacion') {
        navigatorKey.currentState?.push(
          HavenPageRoute.slideHorizontal(
            builder: (_) => InvitacionesRecibidasScreen(controller: controller),
          ),
        );
      } else if (tipo == 'visita_llegada' || tipo == 'visita' || tipo == 'visita_entrada') {
        final misViviendas = await controller.obtenerMisViviendas();
        navigatorKey.currentState?.push(
          HavenPageRoute.slideHorizontal(
            builder: (_) => VisitasResidenteScreen(
              controller: controller,
              misViviendas: misViviendas,
            ),
          ),
        );
      } else if (tipo == 'aviso' || tipo == 'aviso_urgente') {
        navigatorKey.currentState?.push(
          HavenPageRoute.slideHorizontal(
            builder: (_) => AvisosResidenteScreen(controller: controller),
          ),
        );
      } else if (tipo == 'paquete_llegada' ||
          tipo == 'paquete_entregado' ||
          tipo == 'paquete' ||
          tipo == 'paqueteria') {
        final misViviendas = await controller.obtenerMisViviendas();
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => PaqueteriaResidenteScreen(
              controller: controller,
              misViviendas: misViviendas,
              focusPaqueteId: data['paquete_id']?.toString() ?? data['paqueteId']?.toString(),
            ),
          ),
        );
      }
    };
  }

  @override
  void dispose() {
    PushNotificationsService.onMessageAction = null;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'haven',
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final isOffline = controller.isOffline;
            return Material(
              color: Colors.white,
              child: Column(
                children: [
                  if (isOffline)
                    Container(
                      color: const Color(0xFFFEF3C7),
                      child: SafeArea(
                        bottom: false,
                        child: OfflineBanner(
                          mensaje: 'Modo sin conexión. Mostrando datos guardados.',
                          pendingSyncCount: controller.pendingSyncCount,
                          onSyncPressed: () => controller.syncOfflineData(),
                          isSyncing: controller.isSyncing,
                        ),
                      ),
                    ),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: isOffline,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      home: AppRouter(controller: controller),
    );
  }
}
