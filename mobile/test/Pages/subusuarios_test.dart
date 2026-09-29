import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haven/Models/subusuario.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Services/subusuarios_service.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL_USUARIOS=https://usuarios-api-n1qi.onrender.com',
    );
  });

  group('SubusuarioItem Model Tests', () {
    test('Deserializa correctamente sub-usuario activo', () {
      final json = {
        'id': 'sub-1',
        'nombre': 'María López',
        'email': 'maria@gmail.com',
        'telefono': '5512345678',
        'parentesco': 'Cónyuge',
        'estado': 'Activo',
        'creado_en': '2026-09-27T10:00:00Z',
      };

      final item = SubusuarioItem.fromJson(json);

      expect(item.id, 'sub-1');
      expect(item.nombre, 'María López');
      expect(item.email, 'maria@gmail.com');
      expect(item.telefono, '5512345678');
      expect(item.parentesco, 'Cónyuge');
      expect(item.isActivo, isTrue);
      expect(item.isPendiente, isFalse);
      expect(item.creadoEn, isNotNull);
    });

    test('Deserializa correctamente invitación pendiente del titular', () {
      final json = {
        'id': 'inv-99',
        'nombre': 'Pendiente',
        'email': 'juan@gmail.com',
        'telefono': 'Pendiente',
        'parentesco': 'Hijo/a',
        'estado': 'Pendiente',
        'creado_en': '2026-09-27T10:00:00Z',
      };

      final item = SubusuarioItem.fromJson(json);

      expect(item.id, 'inv-99');
      expect(item.isPendiente, isTrue);
      expect(item.isActivo, isFalse);
      expect(item.email, 'juan@gmail.com');
      expect(item.creadoEn, isNotNull);
    });
  });

  group('InvitacionSubusuario Model Tests (Panel Invitado)', () {
    test('Deserializa correctamente invitación recibida', () {
      final json = {
        'id': 'inv-recibida-1',
        'vivienda_id': 123,
        'numero_casa': '10A',
        'condominio_nombre': 'Residencial Las Palmas',
        'titular_nombre': 'Carlos Perez',
        'titular_id': 'uuid-titular',
        'parentesco': 'Hermano',
        'estado': 'PENDIENTE',
        'creado_en': '2026-09-27T10:00:00Z',
      };

      final inv = InvitacionSubusuario.fromJson(json);

      expect(inv.id, 'inv-recibida-1');
      expect(inv.viviendaId, 123);
      expect(inv.numeroCasa, '10A');
      expect(inv.condominioNombre, 'Residencial Las Palmas');
      expect(inv.titularNombre, 'Carlos Perez');
      expect(inv.parentesco, 'Hermano');
      expect(inv.isPendiente, isTrue);
    });
  });

  group('SubusuariosService Tests', () {
    test('getSubusuarios envía viviendaId y parsea items unificados', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/subusuarios/mis-subusuarios' &&
            request.url.queryParameters['viviendaId'] == '10') {
          final data = [
            {
              'id': 'sub-1',
              'nombre': 'Sub Activo',
              'email': 'sub@haven.com',
              'telefono': '1234567890',
              'parentesco': 'Cónyuge',
              'estado': 'Activo',
            },
            {
              'id': 'inv-1',
              'nombre': 'Pendiente',
              'email': 'inv@haven.com',
              'telefono': 'Pendiente',
              'parentesco': 'Hermano',
              'estado': 'Pendiente',
              'creado_en': '2026-09-28T00:00:00Z',
            },
          ];
          return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = SubusuariosService(controller);

      final items = await service.getSubusuarios(10);
      expect(items.length, 2);
      expect(items[0].isActivo, isTrue);
      expect(items[1].isPendiente, isTrue);
      expect(items[1].email, 'inv@haven.com');
    });

    test('invitarSubusuario envía email y parentesco y devuelve nuevo item', () async {
      Map<String, dynamic>? capturedPayload;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/subusuarios/invitar' && request.method == 'POST') {
          capturedPayload = jsonDecode(request.body);
          final responseData = {
            'id': 'inv-new',
            'nombre': 'Pendiente',
            'email': capturedPayload!['email'],
            'telefono': 'Pendiente',
            'parentesco': capturedPayload!['parentesco'],
            'estado': 'Pendiente',
            'creado_en': '2026-09-27T12:00:00Z',
          };
          return http.Response(jsonEncode(responseData), 201, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = SubusuariosService(controller);

      final result = await service.invitarSubusuario(
        viviendaId: 15,
        email: 'familiar@haven.com',
        parentesco: 'Hermano',
      );

      expect(result['success'], isTrue);
      expect(capturedPayload!['vivienda_id'], 15);
      expect(capturedPayload!['email'], 'familiar@haven.com');
      expect(capturedPayload!['parentesco'], 'Hermano');

      final SubusuarioItem item = result['item'];
      expect(item.id, 'inv-new');
      expect(item.email, 'familiar@haven.com');
      expect(item.isPendiente, isTrue);
    });

    test('invitarSubusuario maneja 404 si el usuario no está registrado', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'No se encontró ningún usuario con ese correo electrónico. Pídele que se registre primero.'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final controller = AppController(null, client: mockClient);
      final service = SubusuariosService(controller);

      final result = await service.invitarSubusuario(
        viviendaId: 15,
        email: 'noexiste@haven.com',
        parentesco: 'Familiar',
      );

      expect(result['success'], isFalse);
      expect(result['error'], contains('registre primero'));
    });

    test('revocarSubusuario ejecuta DELETE con viviendaId e isInvitacion', () async {
      String? requestedUrl;

      final mockClient = MockClient((request) async {
        if (request.url.path.startsWith('/api/subusuarios/sub-to-delete') &&
            request.method == 'DELETE') {
          requestedUrl = request.url.toString();
          return http.Response('', 204);
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = SubusuariosService(controller);

      final success = await service.revocarSubusuario(
        'sub-to-delete',
        viviendaId: 8,
        isInvitacion: true,
      );

      expect(success, isTrue);
      expect(requestedUrl, contains('viviendaId=8'));
      expect(requestedUrl, contains('isInvitacion=true'));
    });

    test('getMisInvitaciones retorna invitaciones recibidas', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/subusuarios/mis-invitaciones') {
          final data = [
            {
              'id': 'inv-123',
              'vivienda_id': 50,
              'numero_casa': '12B',
              'condominio_nombre': 'Condominio Central',
              'titular_nombre': 'Ana Gómez',
              'titular_id': 'uuid-titular-ana',
              'parentesco': 'Hija',
              'estado': 'PENDIENTE',
              'creado_en': '2026-09-28T12:00:00Z',
            }
          ];
          return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = SubusuariosService(controller);

      final invitaciones = await service.getMisInvitaciones();
      expect(invitaciones.length, 1);
      expect(invitaciones[0].numeroCasa, '12B');
      expect(invitaciones[0].titularNombre, 'Ana Gómez');
    });

    test('responderInvitacion envía ACEPTADA correctamente', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/subusuarios/invitaciones/inv-123/responder' &&
            request.method == 'POST') {
          capturedBody = jsonDecode(request.body);
          return http.Response(
            jsonEncode({'message': 'Invitación aceptada exitosamente.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = SubusuariosService(controller);

      final res = await service.responderInvitacion('inv-123', aceptar: true);
      expect(res['success'], isTrue);
      expect(capturedBody!['respuesta'], 'ACEPTADA');
    });

    test('responderInvitacion envía RECHAZADA correctamente', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/subusuarios/invitaciones/inv-456/responder' &&
            request.method == 'POST') {
          capturedBody = jsonDecode(request.body);
          return http.Response(
            jsonEncode({'message': 'Invitación rechazada exitosamente.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = SubusuariosService(controller);

      final res = await service.responderInvitacion('inv-456', aceptar: false);
      expect(res['success'], isTrue);
      expect(capturedBody!['respuesta'], 'RECHAZADA');
    });
  });
}
