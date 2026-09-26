import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Services/avisos_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL_AVISOS=https://avisos-api-qg5b.onrender.com',
    );
  });

  group('Avisos Prioridad Tests', () {
    test('createAviso envía prioridad en el payload', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/avisos' && request.method == 'POST') {
          capturedBody = jsonDecode(request.body);
          return http.Response(
            jsonEncode({'id': 'aviso-123', 'titulo': 'Corte de agua', 'prioridad': 'urgente'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = AvisosService(controller);

      final res = await service.createAviso(
        'Corte de agua',
        'Se suspenderá el servicio a las 3pm',
        duracionDias: 3,
        prioridad: 'urgente',
      );

      expect(res, isNotNull);
      expect(capturedBody, isNotNull);
      expect(capturedBody!['titulo'], 'Corte de agua');
      expect(capturedBody!['prioridad'], 'urgente');
      expect(capturedBody!['duracion_dias'], 3);
    });

    test('updateAviso envía prioridad cuando se especifica', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/avisos/aviso-1' && request.method == 'PUT') {
          capturedBody = jsonDecode(request.body);
          return http.Response(
            jsonEncode({'id': 'aviso-1', 'titulo': 'Editado', 'prioridad': 'mantenimiento'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);
      final service = AvisosService(controller);

      final res = await service.updateAviso(
        'aviso-1',
        'Editado',
        'Contenido nuevo',
        prioridad: 'mantenimiento',
      );

      expect(res, isNotNull);
      expect(capturedBody, isNotNull);
      expect(capturedBody!['prioridad'], 'mantenimiento');
    });
  });
}
