import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haven/Models/area_comun_model.dart';
import 'package:haven/Models/reserva_model.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Services/reservas_service.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL_RESERVAS=https://reservas-api-test.onrender.com',
    );
  });

  group('ReservasService - Áreas Comunes', () {
    test('getAreas retorna listado paginado exitoso', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/areas') {
          final data = {
            'items': [
              {
                'id': 'area-1',
                'nombre': 'Alberca',
                'horaApertura': '08:00:00',
                'horaCierre': '20:00:00',
                'activo': true,
              }
            ],
            'page': 1,
            'pageSize': 20,
            'totalCount': 1,
          };
          return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final result = await service.getAreas();
      expect(result['success'], isTrue);
      final items = result['items'] as List<AreaComunModel>;
      expect(items.length, 1);
      expect(items.first.nombre, 'Alberca');
    });

    test('crearArea envía POST con payload correcto', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/areas' && request.method == 'POST') {
          final decoded = jsonDecode(request.body);
          expect(decoded['nombre'], 'Gimnasio');
          expect(decoded['horaApertura'], '06:00:00');

          final data = {
            'id': 'area-2',
            'nombre': 'Gimnasio',
            'horaApertura': '06:00:00',
            'horaCierre': '22:00:00',
            'activo': true,
          };
          return http.Response(jsonEncode(data), 201, headers: {'content-type': 'application/json'});
        }
        return http.Response('Bad request', 400);
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.crearArea(
        nombre: 'Gimnasio',
        horaApertura: '06:00:00',
        horaCierre: '22:00:00',
      );
      expect(res['success'], isTrue);
      expect((res['area'] as AreaComunModel).nombre, 'Gimnasio');
    });
  });

  group('ReservasService - Acciones de Residente', () {
    test('solicitarReserva exitosa', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/reservas' && request.method == 'POST') {
          final data = {
            'id': 'res-10',
            'areaId': 'area-1',
            'areaNombre': 'Alberca',
            'estado': 'PENDIENTE_ADMIN',
            'inicio': '2026-11-10T14:00:00Z',
            'fin': '2026-11-10T18:00:00Z',
          };
          return http.Response(jsonEncode(data), 201, headers: {'content-type': 'application/json'});
        }
        return http.Response('Error', 400);
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.solicitarReserva(
        areaId: 'area-1',
        inicio: DateTime.utc(2026, 11, 10, 14),
        fin: DateTime.utc(2026, 11, 10, 18),
      );

      expect(res['success'], isTrue);
      final reserva = res['reserva'] as ReservaModel;
      expect(reserva.id, 'res-10');
      expect(reserva.estado, 'PENDIENTE_ADMIN');
    });

    test('solicitarReserva mapea mensaje de error RE007 de la API', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'La reserva debe hacerse con entre 7 y 30 días de anticipación.'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.solicitarReserva(
        areaId: 'area-1',
        inicio: DateTime.now().add(const Duration(days: 1)),
        fin: DateTime.now().add(const Duration(days: 1, hours: 2)),
      );

      expect(res['success'], isFalse);
      expect(res['error'], contains('7 y 30 días'));
    });

    test('confirmarReserva exitosa retorna success true', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/reservas/res-10/confirmar' && request.method == 'POST') {
          return http.Response('', 204);
        }
        return http.Response('Error', 400);
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.confirmarReserva('res-10');
      expect(res['success'], isTrue);
    });

    test('cancelarReserva exitosa retorna success true', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/reservas/res-10/cancelar' && request.method == 'POST') {
          return http.Response('', 204);
        }
        return http.Response('Error', 400);
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.cancelarReserva('res-10', motivo: 'Cambio de planes');
      expect(res['success'], isTrue);
    });
  });

  group('ReservasService - Panel Admin', () {
    test('aprobarReservaAdmin exitosa retorna success true', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/admin/reservas/res-10/aprobar' && request.method == 'POST') {
          return http.Response('', 204);
        }
        return http.Response('Error', 400);
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.aprobarReservaAdmin('res-10');
      expect(res['success'], isTrue);
    });

    test('crearBloqueo exitoso retorna datos del bloqueo y reservas afectadas', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/admin/bloqueos' && request.method == 'POST') {
          final data = {
            'bloqueoId': 'b1a2c3d4-e5f6-7890-abcd-ef1234567890',
            'areaId': 'area-1',
            'inicio': '2026-11-20T08:00:00Z',
            'fin': '2026-11-20T18:00:00Z',
            'motivo': 'Mantenimiento preventivo',
            'totalReservasAfectadas': 2,
          };
          return http.Response(jsonEncode(data), 201, headers: {'content-type': 'application/json'});
        }
        return http.Response('Error', 400);
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.crearBloqueo(
        areaId: 'area-1',
        inicio: DateTime.utc(2026, 11, 20, 8),
        fin: DateTime.utc(2026, 11, 20, 18),
        motivo: 'Mantenimiento preventivo',
      );

      expect(res['success'], isTrue);
      expect(res['totalReservasAfectadas'], 2);
    });
  });

  group('ReservasService - Manejo Descriptivo de Errores y Excepciones', () {
    test('getAreas maneja TimeoutException descriptivamente sin crashear', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Request timed out after 10s');
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.getAreas();
      expect(res['success'], isFalse);
      expect(res['error'], contains('Tiempo de espera agotado'));
      expect(res['items'], isEmpty);
    });

    test('getCalendario maneja SocketException (sin conexión) descriptivamente', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('No address associated with hostname');
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.getCalendario(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 2),
      );
      expect(res['success'], isFalse);
      expect(res['error'], contains('Sin conexión a internet'));
      expect(res['items'], isEmpty);
    });

    test('solicitarReserva maneja http.ClientException de red adecuadamente', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection reset by peer');
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.solicitarReserva(
        areaId: 'area-1',
        inicio: DateTime.now().add(const Duration(days: 10)),
        fin: DateTime.now().add(const Duration(days: 10, hours: 2)),
      );
      expect(res['success'], isFalse);
      expect(res['error'], isNotEmpty);
    });

    test('getMisReservas maneja respuesta HTML inesperada (502 Gateway) sin volcar etiquetas', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '<html><body><h1>502 Bad Gateway</h1><p>Render is currently unavailable</p></body></html>',
          502,
          headers: {'content-type': 'text/html'},
        );
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.getMisReservas();
      expect(res['success'], isFalse);
      expect(res['error'], isNot(contains('<html')));
      expect(res['items'], isEmpty);
    });

    test('solicitarReserva traduce código RE008 (reserva ya existente en la fecha)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'RE008'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.solicitarReserva(
        areaId: 'area-1',
        inicio: DateTime.now().add(const Duration(days: 8)),
        fin: DateTime.now().add(const Duration(days: 8, hours: 2)),
      );
      expect(res['success'], isFalse);
      expect(res['error'], 'Ya tienes una reserva para ese día.');
    });

    test('solicitarReserva traduce código RE009 (choque de horario o bloqueo de área)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'RE009: Conflict with existing reservation'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.solicitarReserva(
        areaId: 'area-1',
        inicio: DateTime.now().add(const Duration(days: 8)),
        fin: DateTime.now().add(const Duration(days: 8, hours: 2)),
      );
      expect(res['success'], isFalse);
      expect(res['error'], 'El horario choca con otra reserva aprobada o con un bloqueo del área.');
    });

    test('confirmarReserva traduce código RE011 (fuera de ventana permitida)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'RE011'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.confirmarReserva('res-bad-time');
      expect(res['success'], isFalse);
      expect(res['error'], 'La reserva solo puede confirmarse entre 7 días y 72 horas antes del evento.');
    });

    test('marcarNoUtilizada traduce código RE013 (reserva aún no concluida)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'RE013'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.marcarNoUtilizada('res-in-progress');
      expect(res['success'], isFalse);
      expect(res['error'], 'La reserva aún no termina, no puede marcarse como no utilizada.');
    });

    test('rechazarReservaAdmin traduce código RE010 cuando falta el motivo', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'RE010'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.rechazarReservaAdmin('res-no-motivo', motivo: '');
      expect(res['success'], isFalse);
      expect(res['error'], 'El motivo es obligatorio.');
    });

    test('getAreaById retorna error descriptivo si el recurso no existe (404)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Area not found'}), 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = ReservasService(controller);

      final res = await service.getAreaById('area-inexistente');
      expect(res['success'], isFalse);
      expect(res['error'], isNotEmpty);
      expect(res['area'], isNull);
    });
  });
}

