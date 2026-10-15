import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Models/area_comun_model.dart';
import 'package:haven/Models/reserva_model.dart';
import 'package:haven/Models/bloqueo_model.dart';

void main() {
  group('AreaComunModel', () {
    test('Correctly deserializes from json with camelCase and snake_case', () {
      final json = {
        'id': 'area-123',
        'nombre': 'Alberca Principal',
        'descripcion': 'Alberca climatizada',
        'horaApertura': '09:00:00',
        'horaCierre': '21:00:00',
        'activo': true,
        'totalReservasActivas': 2,
        'totalBloqueosActivos': 1,
      };

      final area = AreaComunModel.fromJson(json);
      expect(area.id, 'area-123');
      expect(area.nombre, 'Alberca Principal');
      expect(area.horarioFormateado, '09:00 - 21:00');
      expect(area.activo, isTrue);
      expect(area.totalReservasActivas, 2);
      expect(area.totalBloqueosActivos, 1);
    });
  });

  group('ReservaModel', () {
    test('Correctly deserializes and verifies state helper properties', () {
      final now = DateTime.now();
      final fechaInicio = now.add(const Duration(days: 4)); // 96h -> between 72h and 7d
      final fechaFin = fechaInicio.add(const Duration(hours: 2));

      final json = {
        'id': 'res-1',
        'areaId': 'area-1',
        'areaNombre': 'Pádel',
        'estado': 'APROBADA',
        'inicio': fechaInicio.toUtc().toIso8601String(),
        'fin': fechaFin.toUtc().toIso8601String(),
        'solicitanteNombre': 'Juan',
        'solicitanteApellidos': 'Pérez',
        'numeroCasa': '101',
      };

      final reserva = ReservaModel.fromJson(json);
      expect(reserva.id, 'res-1');
      expect(reserva.esAprobada, isTrue);
      expect(reserva.esConfirmable, isTrue);
      expect(reserva.esCancelable, isTrue);
      expect(reserva.solicitanteCompleto, 'Juan Pérez');
    });

    test('Confirmable is false when less than 72 hours before start', () {
      final now = DateTime.now();
      final fechaInicio = now.add(const Duration(hours: 48)); // 48h < 72h
      final fechaFin = fechaInicio.add(const Duration(hours: 2));

      final reserva = ReservaModel(
        id: 'res-2',
        areaId: 'area-1',
        areaNombre: 'Gimnasio',
        estado: 'APROBADA',
        inicio: fechaInicio,
        fin: fechaFin,
      );

      expect(reserva.esConfirmable, isFalse);
    });

    test('tipo BLOQUEO sets esBloqueo, special label and disables cancellation/approval', () {
      final now = DateTime.now();
      final bloqueo = ReservaModel(
        id: 'bloq-10',
        areaId: 'area-1',
        areaNombre: 'Salón',
        tipo: 'BLOQUEO',
        estado: 'APROBADA',
        inicio: now.add(const Duration(days: 2)),
        fin: now.add(const Duration(days: 2, hours: 4)),
        motivo: 'Mantenimiento preventivo',
      );

      expect(bloqueo.esBloqueo, isTrue);
      expect(bloqueo.esBloqueoActivo, isTrue);
      expect(bloqueo.esAprobada, isFalse);
      expect(bloqueo.esConfirmable, isFalse);
      expect(bloqueo.esCancelable, isFalse);
      expect(bloqueo.esMarcableNoShow, isFalse);
      expect(bloqueo.estadoEtiqueta, 'Bloqueo');

      final bloqueoPasado = ReservaModel(
        id: 'bloq-past',
        areaId: 'area-1',
        areaNombre: 'Salón',
        tipo: 'BLOQUEO',
        estado: 'APROBADA',
        inicio: now.subtract(const Duration(hours: 4)),
        fin: now.subtract(const Duration(hours: 1)),
        motivo: 'Mantenimiento previo',
      );
      expect(bloqueoPasado.esBloqueo, isTrue);
      expect(bloqueoPasado.esBloqueoActivo, isFalse);
    });
  });

  group('BloqueoModel', () {
    test('Correctly deserializes from JSON', () {
      final json = {
        'bloqueoId': 'bloq-1',
        'areaId': 'area-2',
        'inicio': '2026-11-20T08:00:00Z',
        'fin': '2026-11-20T18:00:00Z',
        'motivo': 'Pintura y mantenimiento',
        'totalReservasAfectadas': 3,
      };

      final bloqueo = BloqueoModel.fromJson(json);
      expect(bloqueo.bloqueoId, 'bloq-1');
      expect(bloqueo.motivo, 'Pintura y mantenimiento');
      expect(bloqueo.reservasAfectadas, 3);
    });

    test('Deserializes with backend format and optional fields', () {
      final json = {
        'bloqueoId': 'bloq-2',
        'areaId': 'area-3',
        'areaNombre': 'Piscina',
        'inicio': '2026-11-22T09:00:00Z',
        'fin': '2026-11-22T19:00:00Z',
        'motivo': 'Limpieza',
        'reservasAfectadas': 1,
        'estado': 'APROBADA',
      };

      final bloqueo = BloqueoModel.fromJson(json);
      expect(bloqueo.bloqueoId, 'bloq-2');
      expect(bloqueo.areaNombre, 'Piscina');
      expect(bloqueo.estado, 'APROBADA');
      expect(bloqueo.reservasAfectadas, 1);
    });
  });
}
