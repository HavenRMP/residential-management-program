import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haven/Models/area_comun_model.dart';
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
}
