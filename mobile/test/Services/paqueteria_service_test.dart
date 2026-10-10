import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haven/Models/paquete_dtos.dart';
import 'package:haven/Models/paquete_model.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Services/paqueteria_service.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL_VISITAS=https://visitas-api-test.onrender.com',
    );
  });

  group('PaqueteriaService Residente Endpoints', () {
    test('getMisPaquetes procesa respuesta paginada exitosa', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/paqueteria/mis-paquetes' && request.method == 'GET') {
          expect(request.url.queryParameters['page'], '1');
          expect(request.url.queryParameters['pageSize'], '10');
          expect(request.url.queryParameters['estado'], 'esperado');

          final data = {
            'items': [
              {
                'id': 'pkg-1',
                'viviendaId': 10,
                'numeroCasa': '15',
                'destinatarioNombre': 'Juan Perez',
                'servicioNombre': 'Amazon',
                'estado': 'esperado',
              }
            ],
            'page': 1,
            'pageSize': 10,
            'totalCount': 1,
          };
          return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = PaqueteriaService(controller);

      final result = await service.getMisPaquetes(estado: 'esperado');
      expect(result['success'], isTrue);
      final items = result['items'] as List<PaqueteModel>;
      expect(items.length, 1);
      expect(items.first.destinatarioNombre, 'Juan Perez');
      expect(items.first.servicioNombre, 'Amazon');
      expect(result['totalCount'], 1);
    });

    test('createPaqueteEsperado envía POST con payload correcto', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/paqueteria' && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['viviendaId'], 5);
          expect(body['destinatarioNombre'], 'Laura Gomez');
          expect(body['servicioNombre'], 'Mercado Libre');

          final responseData = {
            'id': 'pkg-nuevo',
            'viviendaId': 5,
            'numeroCasa': '20B',
            'destinatarioNombre': 'Laura Gomez',
            'servicioNombre': 'Mercado Libre',
            'estado': 'esperado',
          };
          return http.Response(jsonEncode(responseData), 201, headers: {'content-type': 'application/json'});
        }
        return http.Response('Bad Request', 400);
      });

      final controller = AppController(null, client: mockClient);
      final service = PaqueteriaService(controller);

      final dto = CreatePaqueteEsperadoDto(
        viviendaId: 5,
        destinatarioNombre: 'Laura Gomez',
        servicioNombre: 'Mercado Libre',
      );
      final res = await service.createPaqueteEsperado(dto);
      expect(res['success'], isTrue);
      final paquete = res['data'] as PaqueteModel;
      expect(paquete.id, 'pkg-nuevo');
      expect(paquete.destinatarioNombre, 'Laura Gomez');
    });

    test('updatePaqueteEsperado envía PUT exitosamente', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/paqueteria/pkg-123' && request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['numeroGuia'], 'GUIA-ACTUALIZADA');

          return http.Response(
            jsonEncode({
              'id': 'pkg-123',
              'viviendaId': 1,
              'numeroCasa': '1',
              'destinatarioNombre': 'Laura',
              'numeroGuia': 'GUIA-ACTUALIZADA',
              'estado': 'esperado',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Error', 400);
      });

      final controller = AppController(null, client: mockClient);
      final service = PaqueteriaService(controller);

      final res = await service.updatePaqueteEsperado(
        'pkg-123',
        UpdatePaqueteEsperadoDto(numeroGuia: 'GUIA-ACTUALIZADA'),
      );
      expect(res['success'], isTrue);
      expect((res['data'] as PaqueteModel).numeroGuia, 'GUIA-ACTUALIZADA');
    });

    test('cancelarPaqueteEsperado envía POST con motivo', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/paqueteria/pkg-cancel/cancelar' && request.method == 'POST') {
          final body = jsonDecode(request.body);
          expect(body['motivo'], 'Devuelto por vendedor');
          return http.Response('', 204);
        }
        return http.Response('Not Found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = PaqueteriaService(controller);

      final res = await service.cancelarPaqueteEsperado('pkg-cancel', motivo: 'Devuelto por vendedor');
      expect(res['success'], isTrue);
    });
  });

  group('PaqueteriaService Caseta & Servicios Endpoints', () {
    test('getPaquetesEsperadosCaseta y getInventarioCaseta funcionan', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/paqueteria/esperados') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'esp-1',
                  'viviendaId': 3,
                  'numeroCasa': '12',
                  'destinatarioNombre': 'Carlos',
                  'estado': 'esperado',
                }
              ],
              'totalCount': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/paqueteria/inventario') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'inv-1',
                  'viviendaId': 4,
                  'numeroCasa': '14',
                  'destinatarioNombre': 'Rosa',
                  'estado': 'recibido',
                }
              ],
              'totalCount': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = PaqueteriaService(controller);

      final esperados = await service.getPaquetesEsperadosCaseta();
      expect(esperados['success'], isTrue);
      expect((esperados['items'] as List<PaqueteModel>).first.id, 'esp-1');

      final inventario = await service.getInventarioCaseta();
      expect(inventario['success'], isTrue);
      expect((inventario['items'] as List<PaqueteModel>).first.id, 'inv-1');
    });

    test('recibirPaquete y entregarPaquete procesan correctamente', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/paqueteria/recepcion' && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 'pkg-rec',
              'viviendaId': 8,
              'numeroCasa': '88',
              'destinatarioNombre': 'Pedro',
              'estado': 'recibido',
              'ubicacionAlmacen': 'Gaveta 3',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/paqueteria/pkg-rec/entrega' && request.method == 'POST') {
          final body = jsonDecode(request.body);
          expect(body['entregadoANombre'], 'Pedro Personalmente');
          return http.Response(
            jsonEncode({
              'id': 'pkg-rec',
              'viviendaId': 8,
              'numeroCasa': '88',
              'destinatarioNombre': 'Pedro',
              'estado': 'entregado',
              'entregadoANombre': 'Pedro Personalmente',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Error', 400);
      });

      final controller = AppController(null, client: mockClient);
      final service = PaqueteriaService(controller);

      final recRes = await service.recibirPaquete(RecibirPaqueteDto(
        paqueteId: 'pkg-rec',
        ubicacionAlmacen: 'Gaveta 3',
      ));
      expect(recRes['success'], isTrue);
      expect((recRes['data'] as PaqueteModel).isRecibido, isTrue);

      final entRes = await service.entregarPaquete('pkg-rec', 'Pedro Personalmente');
      expect(entRes['success'], isTrue);
      expect((entRes['data'] as PaqueteModel).isEntregado, isTrue);
    });

    test('getServicios obtiene lista de catálogo', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/paqueteria/servicios' && request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {'id': 1, 'nombre': 'Amazon', 'activo': true},
              {'id': 2, 'nombre': 'DHL', 'activo': true},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Error', 500);
      });

      final controller = AppController(null, client: mockClient);
      final service = PaqueteriaService(controller);

      final servicios = await service.getServicios();
      expect(servicios.length, 2);
      expect(servicios[0].nombre, 'Amazon');
      expect(servicios[1].nombre, 'DHL');
    });

    test('Maneja error del servidor con mensaje claro', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'El paquete ya fue recibido previamente.'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = AppController(null, client: mockClient);
      final service = PaqueteriaService(controller);

      final res = await service.updatePaqueteEsperado('pkg-x', UpdatePaqueteEsperadoDto());
      expect(res['success'], isFalse);
      expect(res['error'], contains('El paquete ya fue recibido previamente.'));
    });
  });
}
