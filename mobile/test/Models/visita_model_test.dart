import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Models/visita_model.dart';

void main() {
  group('VisitaModel Tests', () {
    test('deserializa correctamente con campo estado poblado', () {
      final json = {
        'id': 'v-1',
        'vivienda_id': 12,
        'numero_casa': '101',
        'nombre_visitante': 'Carlos',
        'apellidos_visitante': 'Gómez',
        'estado': 'programada',
      };

      final visita = VisitaModel.fromJson(json);
      expect(visita.id, 'v-1');
      expect(visita.nombreVisitante, 'Carlos');
      expect(visita.estado, 'programada');
      expect(visita.isProgramada, isTrue);
    });

    test('deserializa estado desde campo estado_calculado si estado viene vacío', () {
      final json = {
        'id': 'v-2',
        'nombre_visitante': 'Laura',
        'estado': '',
        'estado_calculado': 'expirada',
      };

      final visita = VisitaModel.fromJson(json);
      expect(visita.estado, 'expirada');
      expect(visita.isExpirada, isTrue);
    });

    test('deserializa con fallback a programada si estado y estado_calculado son nulos o vacíos', () {
      final json = {
        'id': 'v-3',
        'nombre_visitante': 'Roberto',
        'estado': '   ',
        'estado_calculado': null,
      };

      final visita = VisitaModel.fromJson(json);
      expect(visita.estado, 'programada');
      expect(visita.isProgramada, isTrue);
    });

    test('toJson y copyWith preservan campos esenciales', () {
      final original = VisitaModel(
        id: 'v-4',
        viviendaId: 5,
        numeroCasa: '50A',
        nombreVisitante: 'Mario',
        apellidosVisitante: 'Rossi',
        motivo: 'personal',
        numAcompanantes: 2,
        fechaLlegadaEsperada: DateTime(2026, 10, 14, 15, 0),
        vigenciaHasta: DateTime(2026, 10, 14, 18, 0),
        estado: 'en_curso',
      );

      final json = original.toJson();
      expect(json['id'], 'v-4');
      expect(json['estado'], 'en_curso');

      final modificado = original.copyWith(estado: 'finalizada');
      expect(modificado.estado, 'finalizada');
      expect(modificado.isFinalizada, isTrue);
      expect(modificado.nombreCompletoVisitante, 'Mario Rossi');
    });

    test('isPorAtender y llegaAntesDeTiempo clasifican correctamente según ventana de caseta', () {
      final ahora = DateTime(2026, 10, 15, 10, 0);

      // Visita dentro de la ventana de 24 horas (llega hoy en 4 horas)
      final visitaHoy = VisitaModel(
        id: 'v-hoy',
        viviendaId: 1,
        numeroCasa: '10',
        nombreVisitante: 'Juan',
        apellidosVisitante: 'Pérez',
        motivo: 'personal',
        numAcompanantes: 0,
        fechaLlegadaEsperada: DateTime(2026, 10, 15, 14, 0),
        vigenciaHasta: DateTime(2026, 10, 15, 20, 0),
        estado: 'programada',
      );
      expect(visitaHoy.isPorAtender(ahora), isTrue);
      expect(visitaHoy.llegaAntesDeTiempo(ahora), isFalse);

      // Visita programada para dentro de 3 días (anticipada)
      final visitaFutura = VisitaModel(
        id: 'v-futura',
        viviendaId: 1,
        numeroCasa: '10',
        nombreVisitante: 'Ana',
        apellidosVisitante: 'López',
        motivo: 'personal',
        numAcompanantes: 0,
        fechaLlegadaEsperada: DateTime(2026, 10, 18, 10, 0),
        vigenciaHasta: DateTime(2026, 10, 18, 18, 0),
        estado: 'programada',
      );
      expect(visitaFutura.isPorAtender(ahora), isFalse);
      expect(visitaFutura.llegaAntesDeTiempo(ahora), isTrue);
      expect(visitaFutura.motivoNoAtendible(ahora), contains('24 horas'));

      // Visita en curso siempre se atiende
      final visitaEnCurso = visitaHoy.copyWith(estado: 'en_curso');
      expect(visitaEnCurso.isPorAtender(ahora), isTrue);
      expect(visitaEnCurso.llegaAntesDeTiempo(ahora), isFalse);

      // Visita vencida
      final visitaVencida = VisitaModel(
        id: 'v-vencida',
        viviendaId: 1,
        numeroCasa: '10',
        nombreVisitante: 'Pedro',
        apellidosVisitante: 'Sánchez',
        motivo: 'personal',
        numAcompanantes: 0,
        fechaLlegadaEsperada: DateTime(2026, 10, 14, 10, 0),
        vigenciaHasta: DateTime(2026, 10, 14, 18, 0),
        estado: 'programada',
      );
      expect(visitaVencida.isVencida(ahora), isTrue);
      expect(visitaVencida.isPorAtender(ahora), isFalse);
      expect(visitaVencida.llegaAntesDeTiempo(ahora), isFalse);
      expect(visitaVencida.motivoNoAtendible(ahora), contains('vigencia ya terminó'));

      // Visita cancelada o finalizada
      final cancelada = visitaHoy.copyWith(estado: 'cancelada');
      expect(cancelada.motivoNoAtendible(ahora), contains('fue cancelada'));
      final finalizada = visitaHoy.copyWith(estado: 'finalizada');
      expect(finalizada.motivoNoAtendible(ahora), contains('ya terminó'));
    });
  });
}
