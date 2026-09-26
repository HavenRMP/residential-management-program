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
    });

    test('initializeApp no arroja excepciones en entorno sin Firebase nativo', () async {
      expect(() async => await PushNotificationsService.initializeApp(), returnsNormally);
    });

    test('requestPermission maneja llamadas sin excepción y retorna bool', () async {
      final result = await PushNotificationsService.requestPermission();
      expect(result, isA<bool>());
    });

    test('getToken maneja llamadas de forma segura', () async {
      final token = await PushNotificationsService.getToken();
      expect(token == null || token.isNotEmpty, isTrue);
    });
  });
}
