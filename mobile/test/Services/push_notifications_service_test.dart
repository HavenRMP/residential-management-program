import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:haven/Services/push_notifications_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationsService Tests', () {
    test('Configuración del canal de notificación tiene alta importancia y nombre esperado', () {
      expect(havenNotificationChannel.id, 'haven_high_importance_channel');
      expect(havenNotificationChannel.name, 'Notificaciones Haven');
      expect(havenNotificationChannel.importance, Importance.max);
      expect(havenNotificationChannel.playSound, isTrue);
      expect(havenNotificationChannel.enableVibration, isTrue);

      expect(havenNotificationLegacyChannel.id, 'haven_high_importancechannel');
      expect(havenNotificationLegacyChannel.name, 'Notificaciones Haven (Directo)');
      expect(havenNotificationLegacyChannel.importance, Importance.max);
      expect(havenNotificationLegacyChannel.playSound, isTrue);
      expect(havenNotificationLegacyChannel.enableVibration, isTrue);

      expect(havenPaqueteriaChannel.id, 'haven_paqueteria_channel');
      expect(havenPaqueteriaChannel.name, 'Entregas y Paquetería Haven');
      expect(havenPaqueteriaChannel.importance, Importance.max);
      expect(havenPaqueteriaChannel.playSound, isTrue);
      expect(havenPaqueteriaChannel.enableVibration, isTrue);
    });

    test('isPaqueteEvent reconoce eventos de paquetería', () {
      expect(PushNotificationsService.isPaqueteEvent('paquete_llegada'), isTrue);
      expect(PushNotificationsService.isPaqueteEvent('paquete_entregado'), isTrue);
      expect(PushNotificationsService.isPaqueteEvent('paquete'), isTrue);
      expect(PushNotificationsService.isPaqueteEvent('visita_llegada'), isFalse);
      expect(PushNotificationsService.isPaqueteEvent(null), isFalse);
    });

    test('initializeApp no arroja excepciones en entorno sin Firebase nativo', () async {
      expect(() async => await PushNotificationsService.initializeApp(), returnsNormally);
    });

    test('requestPermission maneja llamadas sin excepción y retorna bool', () async {
      final result = await PushNotificationsService.requestPermission(userId: 'test-user-123');
      expect(result, isA<bool>());
    });

    test('subscribeToUserTopic y unsubscribeFromUserTopic no fallan sin Firebase nativo', () async {
      expect(() async => await PushNotificationsService.subscribeToUserTopic('test-user-id'), returnsNormally);
      expect(() async => await PushNotificationsService.unsubscribeFromUserTopic('test-user-id'), returnsNormally);
      expect(() async => await PushNotificationsService.subscribeToUserTopic(null), returnsNormally);
      expect(() async => await PushNotificationsService.unsubscribeFromUserTopic(null), returnsNormally);
    });

    test('getToken maneja llamadas de forma segura', () async {
      final token = await PushNotificationsService.getToken();
      expect(token == null || token.isNotEmpty, isTrue);
    });
  });
}
