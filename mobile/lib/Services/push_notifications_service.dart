import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../firebase_options.dart';

/// Canal principal de alta importancia para Android.
/// Nota: el backend envía el channelId "haven_high_importancechannel" (sin guion bajo).
/// Registramos ambos IDs para compatibilidad.
const AndroidNotificationChannel havenNotificationChannel = AndroidNotificationChannel(
  'haven_high_importance_channel',
  'Notificaciones Haven',
  description: 'Canal de notificaciones y avisos prioritarios de Haven',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

/// Canal legacy/alias que coincide con el channelId que envía el backend.
const AndroidNotificationChannel havenNotificationLegacyChannel = AndroidNotificationChannel(
  'haven_high_importancechannel',
  'Notificaciones Haven (Directo)',
  description: 'Canal de notificaciones y avisos prioritarios de Haven (directo)',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const AndroidNotificationChannel havenNotificationChannelBackend = havenNotificationLegacyChannel;

/// Canal de máxima prioridad para notificaciones de entregas y paquetería en Android.
const AndroidNotificationChannel havenPaqueteriaChannel = AndroidNotificationChannel(
  'haven_paqueteria_channel',
  'Entregas y Paquetería Haven',
  description: 'Notificaciones sobre recepción y entrega de paquetes en caseta',
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
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
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

  /// Callback global para acciones derivadas del clic en notificaciones (ej. invitaciones de sub-usuario)
  static void Function(Map<String, dynamic> data)? onMessageAction;

  /// Inicializa Firebase y configura los canales de notificación tanto para
  /// primer plano (foreground) como para segundo plano (background).
  static Future<void> initializeApp() async {
    if (_isInitialized) return;

    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
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
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final dynamic decoded = jsonDecode(response.payload!);
              if (decoded is Map<String, dynamic>) {
                onMessageAction?.call(decoded);
              }
            } catch (_) {}
          }
        },
      );

      // 4. Crear canales para compatibilidad con el backend
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(havenNotificationChannel);
        await androidPlugin.createNotificationChannel(havenNotificationChannelBackend);
        await androidPlugin.createNotificationChannel(havenPaqueteriaChannel);
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
        onMessageAction?.call(message.data);
      });

      // 7. Verificar si la aplicación fue iniciada por una notificación cuando estaba cerrada
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          debugPrint('[FCM] App abierta desde estado terminado con mensaje: ${initialMessage.notification?.title}');
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onMessageAction?.call(initialMessage.data);
        });
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Error configurando handlers FCM: $e');
      }
    }
  }

  /// Tipos de eventos para paquetería
  static const String eventPaqueteLlegada = 'paquete_llegada';
  static const String eventPaqueteEntregado = 'paquete_entregado';

  /// Valida si el tipo de evento pertenece al módulo de paquetería
  static bool isPaqueteEvent(String? tipo) {
    if (tipo == null) return false;
    final t = tipo.trim().toLowerCase();
    return t == eventPaqueteLlegada || t == eventPaqueteEntregado || t == 'paquete';
  }

  /// Muestra una notificación local en el sistema cuando un mensaje FCM llega en primer plano.
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['titulo'] ?? message.data['title'];
    final body = notification?.body ?? message.data['mensaje'] ?? message.data['body'];

    if (title == null && body == null) return;

    try {
      final tipo = (message.data['tipo'] ?? message.data['tipo_evento'] ?? '').toString();
      final isPaquete = isPaqueteEvent(tipo);
      final channel = isPaquete ? havenPaqueteriaChannel : havenNotificationChannel;

      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
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
        payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Error mostrando notificación local: $e');
      }
    }
  }

  /// Solicita permisos de notificación tanto a nivel del sistema (Android 13+ y iOS)
  /// como en Firebase Cloud Messaging, y suscribe el dispositivo a los tópicos generales y del usuario.
  static Future<bool> requestPermission({String? userId}) async {
    try {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
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
          await _messaging.subscribeToTopic('avisos_urgentes');
          if (userId != null && userId.trim().isNotEmpty) {
            await subscribeToUserTopic(userId);
          }
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

  /// Suscribe el dispositivo al tópico personal del usuario ("user" + userId sin guiones).
  /// El backend envía invitaciones de sub-usuario a este tópico específico.
  /// Llamar después de autenticar al usuario.
  static Future<void> subscribeToUserTopic(String? userId) async {
    try {
      if (userId == null || userId.trim().isEmpty) return;
      if (Firebase.apps.isEmpty) return;

      // El backend genera el topic como: "user" + userId.Replace("-", "")
      final topic = 'user${userId.replaceAll('-', '')}';
      await _messaging.subscribeToTopic(topic);

      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Suscrito al tópico personal: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Error suscribiendo a tópico personal: $e');
      }
    }
  }

  /// Desuscribe el dispositivo del tópico personal del usuario.
  /// Llamar al cerrar sesión.
  static Future<void> unsubscribeFromUserTopic(String? userId) async {
    try {
      if (userId == null || userId.trim().isEmpty) return;
      if (Firebase.apps.isEmpty) return;

      final topic = 'user${userId.replaceAll('-', '')}';
      await _messaging.unsubscribeFromTopic(topic);

      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Desuscrito del tópico personal: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Error desuscribiendo de tópico personal: $e');
      }
    }
  }

  /// Suscribe el dispositivo a un tópico FCM arbitrario (ej. 'avisos', 'avisos_urgentes').
  static Future<void> subscribeToTopic(String topic) async {
    try {
      if (Firebase.apps.isEmpty) return;
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Suscrito al tópico: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Error suscribiendo al tópico $topic: $e');
      }
    }
  }

  /// Desuscribe el dispositivo de un tópico FCM arbitrario.
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (Firebase.apps.isEmpty) return;
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Desuscrito del tópico: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationsService] Error desuscribiendo del tópico $topic: $e');
      }
    }
  }

  /// Obtiene el token FCM actual del dispositivo
  static Future<String?> getToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
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
