import 'Themes/app_theme.dart';
import 'Services/app_controller.dart';
import 'Routes/app_router.dart';
import 'Services/push_notifications_service.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    supabaseInitError = e.toString();
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
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'haven',
      theme: AppTheme.lightTheme,
      home: AppRouter(controller: controller),
    );
  }
}
