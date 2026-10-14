import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Models/paquete_model.dart';
import 'package:haven/Models/servicio_paqueteria_model.dart';
import 'package:haven/Models/paquete_dtos.dart';

void main() {
  group('PaqueteModel Tests', () {
    test('Deserializa correctamente JSON con camelCase y snake_case', () {
      final json = {
        'id': 'd69e4695-1715-46b5-9002-8610a76f2845',
        'condominioId': 'b7371510-724d-45db-996a-0d8438128528',
        'condominioNombre': 'Residencial San Carlos',
        'viviendaId': 12,
        'numeroCasa': '101-A',
        'servicioId': 3,
        'servicioNombre': 'Amazon',
        'destinatarioNombre': 'Juan Perez',
        'numeroGuia': 'TRACK123456',
        'descripcion': 'Caja grande con monitor',
        'notas': 'Dejar en caseta',
        'fechaEsperadaDesde': '2026-10-10T14:00:00Z',
        'fechaEsperadaHasta': '2026-10-10T18:00:00Z',
        'estado': 'recibido',
        'esInesperado': false,
        'ubicacionAlmacen': 'Estante A1',
        'recibidoEn': '2026-10-10T15:30:00Z',
        'recibidoPorNombre': 'Guardia Carlos',
        'entregadoEn': null,
        'entregadoANombre': null,
      };

      final model = PaqueteModel.fromJson(json);

      expect(model.id, 'd69e4695-1715-46b5-9002-8610a76f2845');
      expect(model.condominioNombre, 'Residencial San Carlos');
      expect(model.viviendaId, 12);
      expect(model.numeroCasa, '101-A');
      expect(model.servicioNombre, 'Amazon');
      expect(model.destinatarioNombre, 'Juan Perez');
      expect(model.numeroGuia, 'TRACK123456');
      expect(model.estado, 'recibido');
      expect(model.isRecibido, isTrue);
      expect(model.isEsperado, isFalse);
      expect(model.estadoLabel, 'En Caseta');
      expect(model.esInesperado, isFalse);
      expect(model.ubicacionAlmacen, 'Estante A1');
      expect(model.recibidoEn, isNotNull);
      expect(model.recibidoPorNombre, 'Guardia Carlos');
    });

    test('Verifica getters de estado y labels', () {
      final esperado = PaqueteModel(
        id: '1',
        viviendaId: 1,
        numeroCasa: '1',
        destinatarioNombre: 'Ana',
        estado: 'esperado',
      );
      expect(esperado.isEsperado, isTrue);
      expect(esperado.estadoLabel, 'Esperado');

      final entregado = esperado.copyWith(estado: 'entregado');
      expect(entregado.isEntregado, isTrue);
      expect(entregado.estadoLabel, 'Entregado');

      final cancelado = esperado.copyWith(estado: 'cancelado');
      expect(cancelado.isCancelado, isTrue);
      expect(cancelado.estadoLabel, 'Cancelado');

      final vencido = esperado.copyWith(estado: 'vencido');
      expect(vencido.isVencido, isTrue);
      expect(vencido.estadoLabel, 'Vencido');

      final devuelto = esperado.copyWith(estado: 'devuelto');
      expect(devuelto.isDevuelto, isTrue);
      expect(devuelto.estadoLabel, 'Devuelto');
    });

    test('Serializa y deserializa via toJson de forma consistente', () {
      final model = PaqueteModel(
        id: 'pkg-1',
        condominioId: 'condo-1',
        condominioNombre: 'Haven Park',
        viviendaId: 5,
        numeroCasa: '12B',
        servicioId: 1,
        servicioNombre: 'DHL',
        destinatarioNombre: 'Maria Gomez',
        numeroGuia: 'DHL-999',
        descripcion: 'Sobre de documentos',
        estado: 'esperado',
        esInesperado: false,
      );

      final json = model.toJson();
      expect(json['id'], 'pkg-1');
      expect(json['condominioId'], 'condo-1');
      expect(json['viviendaId'], 5);
      expect(json['servicioNombre'], 'DHL');
      expect(json['destinatarioNombre'], 'Maria Gomez');

      final deserializado = PaqueteModel.fromJson(json);
      expect(deserializado.id, model.id);
      expect(deserializado.destinatarioNombre, model.destinatarioNombre);
    });
  });

  group('ServicioPaqueteriaModel Tests', () {
    test('Deserializa servicio con valores por defecto', () {
      final json = {
        'id': 1,
        'nombre': 'Amazon Logistics',
        'iconoUrl': 'https://example.com/icon.png',
        'activo': true,
        'esSistema': true,
      };

      final servicio = ServicioPaqueteriaModel.fromJson(json);
      expect(servicio.id, 1);
      expect(servicio.nombre, 'Amazon Logistics');
      expect(servicio.iconoUrl, 'https://example.com/icon.png');
      expect(servicio.activo, isTrue);
      expect(servicio.esSistema, isTrue);

      final serialized = servicio.toJson();
      expect(serialized['nombre'], 'Amazon Logistics');
      expect(serialized['esSistema'], isTrue);
    });
  });

  group('Paquete DTOs Tests', () {
    test('CreatePaqueteEsperadoDto serializa correctamente', () {
      final dto = CreatePaqueteEsperadoDto(
        viviendaId: 10,
        destinatarioNombre: 'Pedro Pascal',
        servicioNombre: 'Mercado Libre',
        numeroGuia: 'ML12345',
        notas: 'Entregar antes de las 6pm',
      );

      final json = dto.toJson();
      expect(json['viviendaId'], 10);
      expect(json['destinatarioNombre'], 'Pedro Pascal');
      expect(json['servicioNombre'], 'Mercado Libre');
      expect(json['numeroGuia'], 'ML12345');
      expect(json['notas'], 'Entregar antes de las 6pm');
    });

    test('UpdatePaqueteEsperadoDto omite campos nulos', () {
      final dto = UpdatePaqueteEsperadoDto(
        destinatarioNombre: 'Nombre Modificado',
      );

      final json = dto.toJson();
      expect(json.containsKey('destinatarioNombre'), isTrue);
      expect(json['destinatarioNombre'], 'Nombre Modificado');
      expect(json.containsKey('servicioNombre'), isFalse);
      expect(json.containsKey('numeroGuia'), isFalse);
    });

    test('RecibirPaqueteDto caso esperado e inesperado', () {
      final esperado = RecibirPaqueteDto(
        paqueteId: 'guid-pkg-1',
        ubicacionAlmacen: 'Caseta Rack 2',
      );
      final jsonEsperado = esperado.toJson();
      expect(jsonEsperado['paqueteId'], 'guid-pkg-1');
      expect(jsonEsperado['ubicacionAlmacen'], 'Caseta Rack 2');

      final inesperado = RecibirPaqueteDto(
        viviendaId: 7,
        destinatarioNombre: 'Sofia Reyes',
        servicioNombre: 'Estafeta',
      );
      final jsonInesperado = inesperado.toJson();
      expect(jsonInesperado['viviendaId'], 7);
      expect(jsonInesperado['destinatarioNombre'], 'Sofia Reyes');
      expect(jsonInesperado['servicioNombre'], 'Estafeta');
    });

    test('EntregarPaqueteDto y CancelPaqueteDto serializan correctamente', () {
      final entrega = EntregarPaqueteDto(entregadoANombre: 'Sofia Reyes (Hija)');
      expect(entrega.toJson()['entregadoANombre'], 'Sofia Reyes (Hija)');

      final cancel = CancelPaqueteDto(motivo: 'Compra cancelada');
      expect(cancel.toJson()['motivo'], 'Compra cancelada');
    });
  });
}
