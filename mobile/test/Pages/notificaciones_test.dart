import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haven/Models/notificacion.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Services/notificaciones_service.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL_USUARIOS=https://usuarios-api-n1qi.onrender.com',
    );
  });

  group('Notificacion Model Tests', () {
    test('Deserializa correctamente JSON de NotificacionDto', () {
      final json = {
        'id': 'notif-123',
        'usuario_id': 'user-456',
        'usuario_nombre': 'Carlos',
        'usuario_email': 'carlos@haven.com',
        'tipo_evento': 'aviso_urgente',
        'titulo': 'Corte de Agua',
        'mensaje': 'Mantenimiento en bombas a las 4pm',
        'url_redireccion': '/avisos',
        'leida': false,
        'creado_en': '2026-09-26T12:00:00Z',
      };

      final notif = Notificacion.fromJson(json);

      expect(notif.id, 'notif-123');
      expect(notif.usuarioId, 'user-456');
      expect(notif.tipoEvento, 'aviso_urgente');
      expect(notif.titulo, 'Corte de Agua');
      expect(notif.mensaje, 'Mantenimiento en bombas a las 4pm');
      expect(notif.urlRedireccion, '/avisos');
      expect(notif.leida, isFalse);
      expect(notif.creadoEn.year, 2026);
    });

    test('copyWith actualiza el campo leida correctamente', () {
      final notif = Notificacion(
        id: '1',
        titulo: 'Aviso',
        mensaje: 'Test',
        creadoEn: DateTime.now(),
        leida: false,
      );

      final updated = notif.copyWith(leida: true);
      expect(updated.leida, isTrue);
      expect(updated.id, '1');
    });
  });

  group('NotificacionesService Tests', () {
    test('getNotificaciones devuelve lista mapeada', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/notificaciones' && request.method == 'GET') {
          final data = [
            {
              'id': 'n-1',
              'titulo': 'Bienvenido',
              'mensaje': 'Gracias por unirte',
              'tipo_evento': 'general',
              'leida': false,
              'creado_en': '2026-09-26T10:00:00Z',
            },
            {
              'id': 'n-2',
              'titulo': 'Pago registrado',
              'mensaje': 'Cuota de agosto recibida',
              'tipo_evento': 'pago',
              'leida': true,
              'creado_en': '2026-09-25T10:00:00Z',
            },
          ];
          return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = NotificacionesService(controller);

      final notificaciones = await service.getNotificaciones();
      expect(notificaciones.length, 2);
      expect(notificaciones[0].titulo, 'Bienvenido');
      expect(notificaciones[0].leida, isFalse);
      expect(notificaciones[1].titulo, 'Pago registrado');
      expect(notificaciones[1].leida, isTrue);
    });

    test('getContadorNoLeidas devuelve número correcto', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/notificaciones/contador-no-leidas' && request.method == 'GET') {
          return http.Response(jsonEncode({'count': 5}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = NotificacionesService(controller);

      final count = await service.getContadorNoLeidas();
      expect(count, 5);
    });

    test('marcarComoLeida envía PATCH correctamente', () async {
      String? requestedPath;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/notificaciones/notif-abc/leer' && request.method == 'PATCH') {
          requestedPath = request.url.path;
          return http.Response('', 204);
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = NotificacionesService(controller);

      final success = await service.marcarComoLeida('notif-abc');
      expect(success, isTrue);
      expect(requestedPath, '/api/notificaciones/notif-abc/leer');
    });

    test('marcarTodasComoLeidas envía POST correctamente', () async {
      bool called = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/notificaciones/marcar-todas' && request.method == 'POST') {
          called = true;
          return http.Response('', 204);
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = NotificacionesService(controller);

      final success = await service.marcarTodasComoLeidas();
      expect(success, isTrue);
      expect(called, isTrue);
    });
  });
}
