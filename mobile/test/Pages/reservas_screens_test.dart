import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haven/Pages/reservas_residente_screen.dart';
import 'package:haven/Pages/reservas_admin_screen.dart';
import 'package:haven/Widgets/calendario_reservas_vigilante_modal.dart';
import 'package:haven/Widgets/solicitar_reserva_modal.dart';
import 'package:haven/Services/app_controller.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL_RESERVAS=https://reservas-api-test.onrender.com',
    );
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('ReservasResidenteScreen Widget Tests', () {
    testWidgets('Renders tabs and displays empty state when no reservations', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/reservas/mias') {
          return http.Response(jsonEncode({'items': [], 'totalCount': 0}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/reservas/por-aprobar-titular') {
          return http.Response(jsonEncode({'items': [], 'totalCount': 0}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/areas') {
          return http.Response(jsonEncode({'items': [], 'totalCount': 0}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(createTestWidget(ReservasResidenteScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('Reservas de Áreas Comunes'), findsOneWidget);
      expect(find.text('Mis Reservas'), findsOneWidget);
      expect(find.text('Por Aprobar'), findsOneWidget);
      expect(find.text('Áreas y Horarios'), findsOneWidget);
      expect(find.text('No tienes reservas en este estado'), findsOneWidget);
      expect(find.text('Nueva Reserva'), findsOneWidget);
    });

    testWidgets('Renders reservation cards when data is returned', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/reservas/mias') {
          final data = {
            'items': [
              {
                'id': 'res-1',
                'areaId': 'area-1',
                'areaNombre': 'Alberca Familiar',
                'estado': 'APROBADA',
                'inicio': '2026-11-10T14:00:00Z',
                'fin': '2026-11-10T18:00:00Z',
              }
            ],
            'totalCount': 1,
          };
          return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/reservas/por-aprobar-titular' || request.url.path == '/api/areas') {
          return http.Response(jsonEncode({'items': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(createTestWidget(ReservasResidenteScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('Alberca Familiar'), findsOneWidget);
      expect(find.text('Aprobada'), findsOneWidget);
    });
  });

  group('ReservasAdminScreen Widget Tests', () {
    testWidgets('Renders admin tabs and displays pending requests', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/admin/reservas') {
          final data = {
            'items': [
              {
                'id': 'res-admin-1',
                'areaId': 'area-1',
                'areaNombre': 'Cancha de Tenis',
                'estado': 'PENDIENTE_ADMIN',
                'solicitanteNombre': 'Carlos',
                'solicitanteApellidos': 'Gómez',
                'numeroCasa': '24',
                'inicio': '2026-11-12T10:00:00Z',
                'fin': '2026-11-12T12:00:00Z',
                'noShowsTitular': 0,
                'noShowsSolicitante': 0,
              }
            ],
            'totalCount': 1,
          };
          return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/areas' || request.url.path == '/api/admin/reservas/no-shows') {
          return http.Response(jsonEncode({'items': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(createTestWidget(ReservasAdminScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('Administración de Reservas'), findsOneWidget);
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Áreas Comunes'), findsOneWidget);
      expect(find.text('Cancha de Tenis'), findsOneWidget);
      expect(find.text('Aprobar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
    });
  });

  group('CalendarioReservasVigilanteModal Tests', () {
    testWidgets('Renders restricted calendar view with events', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/reservas/calendario') {
          final data = {
            'items': [
              {
                'id': 'cal-1',
                'areaId': 'area-1',
                'areaNombre': 'Salón Social',
                'estado': 'CONFIRMADA',
                'tipo': 'reserva',
                'inicio': '2026-11-15T15:00:00Z',
                'fin': '2026-11-15T19:00:00Z',
              }
            ],
            'totalCount': 1,
          };
          return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(createTestWidget(CalendarioReservasVigilanteModal(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('Uso de Áreas Comunes'), findsOneWidget);
      expect(find.text('Salón Social'), findsOneWidget);
      expect(find.textContaining('Horario ocupado:'), findsOneWidget);
    });
  });

  group('SolicitarReservaModal Tests', () {
    testWidgets('Renders common area options and form controls', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/areas') {
          final data = {
            'items': [
              {
                'id': 'area-1',
                'nombre': 'Gimnasio Residencial',
                'horaApertura': '06:00:00',
                'horaCierre': '22:00:00',
                'activo': true,
              }
            ],
            'totalCount': 1,
          };
          return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final controller = AppController(null, client: mockClient);

      await tester.pumpWidget(createTestWidget(SolicitarReservaModal(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('Solicitar Reserva'), findsOneWidget);
      expect(find.text('Área Común'), findsOneWidget);
      expect(find.text('Fecha del Evento'), findsOneWidget);
      expect(find.text('Hora de Inicio'), findsOneWidget);
      expect(find.text('Hora de Fin'), findsOneWidget);
      expect(find.text('Enviar Solicitud'), findsOneWidget);
    });
  });
}
