import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Canal de alta importancia para Android para garantizar que las notificaciones
/// se muestren como banner heads-up con sonido y vibración en el sistema operativo.
const AndroidNotificationChannel havenNotificationChannel = AndroidNotificationChannel(
  'haven_high_importance_channel',
  'Notificaciones Haven',
  description: 'Canal de notificaciones y avisos prioritarios de Haven',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

/// Handler de mensajes en background requerido por Firebase Cloud Messaging.
/// Debe ser una función de nivel superior con la anotación @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[FCM Background] Error al inicializar Firebase: $e');
    }
  }

  if (kDebugMode) {
    debugPrint('[FCM Background] Mensaje ID: ${message.messageId}');
    debugPrint('[FCM Background] Notificación: ${message.notification?.title} - ${message.notification?.body}');
    debugPrint('[FCM Background] Datos: ${message.data}');
  }
}

class PushNotificationsService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Inicializa Firebase y configura los canales de notificación tanto para
  /// primer plano (foreground) como para segundo plano (background).
  static Future<void> initializeApp() async {
    if (_isInitialized) return;

    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PushNotificationsService] Firebase.initializeApp aviso: $e');
        }
      }
    }

    // Si Firebase no está configurado (por ejemplo, en entorno de tests unitarios), salir limpiamente
    if (Firebase.apps.isEmpty) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Firebase no inicializado en este entorno.');
      }
      return;
    }

    try {
      // 1. Configurar handler para background
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Configurar opciones de presentación visual en primer plano para iOS/macOS
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Inicializar flutter_local_notifications para desplegar notificaciones en Android/iOS
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (kDebugMode) {
            debugPrint('[LocalNotifications] Notificación pulsada con payload: ${response.payload}');
          }
        },
      );

      // 4. Crear el canal de alta importancia en Android
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(havenNotificationChannel);
      }

      // 5. Configurar listener para cuando la app está abierta en primer plano (foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('[FCM Foreground] Mensaje recibido: ${message.notification?.title}');
        }
        _showForegroundNotification(message);
      });

      // 6. Listener para cuando el usuario toca la notificación y la app pasa al primer plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('[FCM] App abierta desde notificación: ${message.notification?.title}');
        }
      });

      // 7. Verificar si la aplicación fue iniciada por una notificación cuando estaba cerrada
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null && kDebugMode) {
        debugPrint('[FCM] App abierta desde estado terminado con mensaje: ${initialMessage.notification?.title}');
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Error configurando handlers FCM: $e');
      }
    }
  }

  /// Muestra una notificación local en el sistema cuando un mensaje FCM llega en primer plano.
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['titulo'] ?? message.data['title'];
    final body = notification?.body ?? message.data['mensaje'] ?? message.data['body'];

    if (title == null && body == null) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        havenNotificationChannel.id,
        havenNotificationChannel.name,
        channelDescription: havenNotificationChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: details,
        payload: message.data.isNotEmpty ? message.data.toString() : null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Error mostrando notificación local: $e');
      }
    }
  }

  /// Solicita permisos de notificación tanto a nivel del sistema (Android 13+ y iOS)
  /// como en Firebase Cloud Messaging, y suscribe el dispositivo a los tópicos generales.
  static Future<bool> requestPermission() async {
    try {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
        } catch (_) {}
      }

      if (Firebase.apps.isEmpty) {
        return false;
      }

      // 1. Solicitar permisos mediante FCM
      final fcmSettings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // 2. Solicitar permiso usando permission_handler para asegurar POST_NOTIFICATIONS en Android 13+
      var status = await Permission.notification.status;
      if (status.isDenied) {
        status = await Permission.notification.request();
      }

      final isGranted = fcmSettings.authorizationStatus == AuthorizationStatus.authorized ||
          fcmSettings.authorizationStatus == AuthorizationStatus.provisional ||
          status.isGranted;

      if (isGranted) {
        // Suscribirse a tópicos para recibir avisos y novedades
        try {
          await _messaging.subscribeToTopic('general');
          await _messaging.subscribeToTopic('avisos');
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PushNotificationsService] Error suscribiendo a tópicos: $e');
          }
        }

        // Obtener y registrar el token FCM para depuración
        if (kDebugMode) {
          try {
            final token = await _messaging.getToken();
            debugPrint('[PushNotificationsService] FCM Token: $token');
          } catch (e) {
            debugPrint('[PushNotificationsService] Error obteniendo FCM Token: $e');
          }
        }
        return true;
      }

      if (status.isPermanentlyDenied) {
        return false;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] requestPermission exception: $e');
      }
      return false;
    }
  }

  /// Obtiene el token FCM actual del dispositivo
  static Future<String?> getToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
        } catch (_) {}
      }

      if (Firebase.apps.isEmpty) {
        return null;
      }

      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] getToken error: $e');
      }
      return null;
    }
  }
}
