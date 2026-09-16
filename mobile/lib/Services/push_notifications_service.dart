import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegúrate de que Firebase esté inicializado si se necesita en background
  // await Firebase.initializeApp();
  if (kDebugMode) {
    print('Mensaje recibido en background: ${message.messageId}');
  }
}

class PushNotificationsService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initializeApp() async {
    // Las opciones se definen en firebase_options.dart autogenerado por flutterfire
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Configurar handler para background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Configurar handler para cuando la app está abierta
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Mensaje recibido en primer plano: ${message.notification?.title}');
      }
      // Aquí se podría mostrar una notificación local si se desea que aparezca un pop-up cuando la app está abierta.
    });
  }

  static Future<bool> requestPermission() async {
    // Pedir permiso usando permission_handler
    var status = await Permission.notification.status;
    
    if (status.isDenied) {
      status = await Permission.notification.request();
    }
    
    if (status.isPermanentlyDenied) {
      // El usuario denegó permanentemente, sugerir abrir ajustes
      return false;
    }

    if (status.isGranted) {
      // Registrar el token de FCM si se necesita enviarlo al backend
      if (kDebugMode) {
        final token = await _messaging.getToken();
        print('FCM Token: $token');
      }
      return true;
    }
    
    return false;
  }
}
