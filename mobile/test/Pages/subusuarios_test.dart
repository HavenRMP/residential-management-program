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
      };

      final item = SubusuarioItem.fromJson(json);

      expect(item.id, 'sub-1');
      expect(item.nombre, 'María López');
      expect(item.email, 'maria@gmail.com');
      expect(item.telefono, '5512345678');
      expect(item.parentesco, 'Cónyuge');
      expect(item.isActivo, isTrue);
      expect(item.isPendiente, isFalse);
      expect(item.codigo, isNull);
    });

    test('Deserializa correctamente invitación pendiente con código y fecha', () {
      final json = {
        'id': 'inv-99',
        'nombre': 'Juan Pérez',
        'email': 'juan@gmail.com',
        'telefono': '5598765432',
        'parentesco': 'Hijo/a',
        'estado': 'Pendiente',
        'codigo': 'SUB-AB12',
        'expira_en': '2026-09-27T10:00:00Z',
      };

      final item = SubusuarioItem.fromJson(json);

      expect(item.id, 'inv-99');
      expect(item.isPendiente, isTrue);
      expect(item.isActivo, isFalse);
      expect(item.codigo, 'SUB-AB12');
      expect(item.expiraEn, isNotNull);
      expect(item.expiraEn!.day, 27);
    });
  });

  group('SubusuariosService Tests', () {
    test('getSubusuarios envía viviendaId y parsea items', () async {
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
              'nombre': 'Invitado Pendiente',
              'email': 'inv@haven.com',
              'telefono': '0987654321',
              'parentesco': 'Familiar',
              'estado': 'Pendiente',
              'codigo': 'SUB-1234',
              'expira_en': '2026-09-28T00:00:00Z',
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
      expect(items[1].codigo, 'SUB-1234');
    });

    test('invitarSubusuario envía payload correcto y devuelve nuevo item', () async {
      Map<String, dynamic>? capturedPayload;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/subusuarios/invitar' && request.method == 'POST') {
          capturedPayload = jsonDecode(request.body);
          final responseData = {
            'id': 'inv-new',
            'nombre': capturedPayload!['nombre'],
            'email': capturedPayload!['email'],
            'telefono': capturedPayload!['telefono'],
            'parentesco': capturedPayload!['parentesco'],
            'estado': 'Pendiente',
            'codigo': 'SUB-XYZ9',
            'expira_en': '2026-09-27T12:00:00Z',
          };
          return http.Response(jsonEncode(responseData), 201, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = SubusuariosService(controller);

      final result = await service.invitarSubusuario(
        viviendaId: 15,
        nombre: 'Pedro',
        apellidos: 'Ramírez',
        email: 'pedro@haven.com',
        telefono: '5512341234',
        parentesco: 'Inquilino/a',
      );

      expect(result['success'], isTrue);
      expect(capturedPayload!['vivienda_id'], 15);
      expect(capturedPayload!['nombre'], 'Pedro');
      expect(capturedPayload!['apellidos'], 'Ramírez');
      expect(capturedPayload!['email'], 'pedro@haven.com');

      final SubusuarioItem item = result['item'];
      expect(item.id, 'inv-new');
      expect(item.codigo, 'SUB-XYZ9');
      expect(item.isPendiente, isTrue);
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
        isInvitacion: false,
      );

      expect(success, isTrue);
      expect(requestedUrl, contains('viviendaId=8'));
      expect(requestedUrl, contains('isInvitacion=false'));
    });
  });
}
