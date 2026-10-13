import 'dart:convert';
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
}
