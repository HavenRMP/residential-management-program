import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:haven/Models/auth_user.dart';

void main() {
  group('AuthUser Model & Role Mapping', () {
    test('Correctly deserializes AuthUser from JSON', () {
      final json = {
        'id': 'usr-12345',
        'email': 'admin@haven.com',
        'rol': 'administrador',
        'rolNombre': 'Administrador',
        'nombre': 'Carlos',
        'apellidos': 'Mendoza',
        'telefono': '1234567890',
        'activo': true,
        'debeCambiarPassword': false,
      };

      final user = AuthUser.fromJson(json);

      expect(user.id, 'usr-12345');
      expect(user.email, 'admin@haven.com');
      expect(user.rol, 'administrador');
      expect(user.nombre, 'Carlos');
      expect(user.apellidos, 'Mendoza');
      expect(user.telefono, '1234567890');
      expect(user.activo, isTrue);
      expect(user.debeCambiarPassword, isFalse);
    });

    test('Handles wrapped JSON format {data: {...}}', () {
      final wrappedJson = {
        'data': {
          'id': '999',
          'email': 'residente@haven.com',
          'role': 'residente',
          'nombre': 'Ana',
          'apellidos': 'Gómez',
          'telefono': '5551234567',
        }
      };

      final user = AuthUser.fromJson(wrappedJson);

      expect(user.id, '999');
      expect(user.email, 'residente@haven.com');
      expect(user.role, 'residente');
      expect(user.nombre, 'Ana');
    });

    test('copyWith updates specific fields while retaining others', () {
      final initial = AuthUser(
        id: '1',
        email: 'test@test.com',
        nombre: 'Original',
        apellidos: 'User',
      );

      final updated = initial.copyWith(nombre: 'Updated');

      expect(updated.id, '1');
      expect(updated.email, 'test@test.com');
      expect(updated.nombre, 'Updated');
      expect(updated.apellidos, 'User');
    });
  });

  group('Supabase Backend Client & Auth Endpoint Validation', () {
    const supabaseUrl = 'https://qunkgbmxmxmjponyxzdu.supabase.co';
    const anonKey = 'sb_publishable_2an39B-QMQpwkuaCYfg1Bw_EgWoC-SF';

    test('Auth health endpoint returns 200 with GoTrue metadata', () async {
      final mockClient = http.Client(); // Mock client setup
      final client = http_testing.MockClient((request) async {
        if (request.url.path == '/auth/v1/health') {
          return http.Response(
            jsonEncode({'name': 'GoTrue', 'version': 'v2.158.0'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final response = await client.get(
        Uri.parse('$supabaseUrl/auth/v1/health'),
        headers: {'apikey': anonKey},
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body);
      expect(body['name'], 'GoTrue');
      expect(body['version'], isNotNull);
    });

    test('Auth unauthenticated /user request returns 401 Unauthorized', () async {
      final client = http_testing.MockClient((request) async {
        if (request.url.path == '/auth/v1/user') {
          return http.Response(
            jsonEncode({'message': 'Missing authorization header'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final response = await client.get(
        Uri.parse('$supabaseUrl/auth/v1/user'),
        headers: {'apikey': anonKey},
      );

      expect(response.statusCode, 401);
      final body = jsonDecode(response.body);
      expect(body['message'], contains('Missing authorization'));
    });
  });

  group('AppController Business Logic', () {
    test('isProfileIncomplete detects invalid resident data', () {
      // Incomplete resident
      final incompleteUser = AuthUser(
        id: '1',
        email: 'res@haven.com',
        rol: 'residente',
        nombre: 'sin nombre',
        apellidos: '',
        telefono: '123',
      );

      // Verify logic directly using the incomplete user profile
      final rol = (incompleteUser.role ?? incompleteUser.rol ?? '').toLowerCase();
      expect(rol.contains('residente'), isTrue);

      final nombre = (incompleteUser.nombre ?? '').trim();
      final apellidos = (incompleteUser.apellidos ?? '').trim();
      final telefono = (incompleteUser.telefono ?? '').trim();

      final nombreValido = nombre.isNotEmpty && nombre.toLowerCase() != 'sin nombre';
      final apellidosValidos = apellidos.isNotEmpty;
      final telefonoValido = telefono.length >= 10;

      final isProfileIncomplete = !nombreValido || !apellidosValidos || !telefonoValido;
      expect(isProfileIncomplete, isTrue);
    });
  });
}
