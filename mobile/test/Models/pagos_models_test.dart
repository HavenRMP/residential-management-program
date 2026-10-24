import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Models/pagos_models.dart';

void main() {
  group('Pagos Models Tests', () {
    test('Enums provide expected values', () {
      expect(EstadoCargo.todos, contains('Pendiente'));
      expect(EstadoPago.todos, contains('PendienteConfirmacion'));
      expect(MetodoPago.todos, contains('Transferencia'));
      expect(TipoCargo.todos, contains('Mantenimiento'));
      expect(TipoMovimientoSaldo.todos, contains('Abono'));
      expect(ResponsablePago.todos, contains('Residente'));
      expect(OrigenPago.todos, contains('Inquilino'));
    });

    test('ComprobanteUploadResponse serializes and deserializes', () {
      final json = {
        'ruta': 'comprobantes/c56/10/recibo.jpg',
        'hash': 'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
        'tamanoBytes': 145020,
        'contentType': 'image/jpeg',
      };

      final resp = ComprobanteUploadResponse.fromJson(json);
      expect(resp.ruta, 'comprobantes/c56/10/recibo.jpg');
      expect(resp.hash, contains('b94d27'));
      expect(resp.tamanoBytes, 145020);
      expect(resp.contentType, 'image/jpeg');

      final serialized = resp.toJson();
      expect(serialized['ruta'], resp.ruta);
      expect(serialized['tamanoBytes'], 145020);
    });

    test('CargoModel deserializes with associated payments and handles estaVencido', () {
      final json = {
        'id': 'cargo-1',
        'viviendaId': 12,
        'numeroCasa': 'Casa 12',
        'tipo': 'Mantenimiento',
        'concepto': 'Mantenimiento Octubre 2026',
        'monto': 1500.0,
        'montoPagado': 1000.0,
        'saldoPendiente': 500.0,
        'estado': 'Parcial',
        'fechaVencimiento': '2026-10-15',
        'periodo': '2026-10',
        'pagosAsociados': [
          {
            'pagoId': 'pago-100',
            'monto': 1000.0,
            'fechaPago': '2026-10-10T12:00:00Z',
            'metodo': 'Transferencia',
            'estado': 'Confirmado',
          }
        ],
      };

      final cargo = CargoModel.fromJson(json);
      expect(cargo.id, 'cargo-1');
      expect(cargo.viviendaId, 12);
      expect(cargo.numeroCasa, 'Casa 12');
      expect(cargo.monto, 1500.0);
      expect(cargo.montoPagado, 1000.0);
      expect(cargo.saldoPendiente, 500.0);
      expect(cargo.pagosAsociados.length, 1);
      expect(cargo.pagosAsociados.first.pagoId, 'pago-100');
      expect(cargo.pagosAsociados.first.monto, 1000.0);
      expect(cargo.estaVencido, isTrue);

      final pagadoJson = Map<String, dynamic>.from(json);
      pagadoJson['estado'] = 'Pagado';
      final cargoPagado = CargoModel.fromJson(pagadoJson);
      expect(cargoPagado.estaVencido, isFalse);
    });

    test('PagoModel parses and serializes correctly', () {
      final json = {
        'id': 'pago-333',
        'cargoId': 'cargo-1',
        'monto': 1250.0,
        'metodo': 'Transferencia',
        'fechaPago': '2026-10-22T14:30:00Z',
        'folioComprobante': 'TRF-882341',
        'rutaComprobante': 'comprobantes/test.jpg',
        'notas': 'Pago cuota',
        'estado': 'PendienteConfirmacion',
      };

      final pago = PagoModel.fromJson(json);
      expect(pago.id, 'pago-333');
      expect(pago.cargoId, 'cargo-1');
      expect(pago.monto, 1250.0);
      expect(pago.metodo, 'Transferencia');
      expect(pago.folioComprobante, 'TRF-882341');
      expect(pago.estado, 'PendienteConfirmacion');

      final serialized = pago.toJson();
      expect(serialized['id'], 'pago-333');
      expect(serialized['monto'], 1250.0);
    });

    test('MiSaldoResponse and SaldoViviendaResumen parse properly', () {
      final json = {
        'totalPendiente': 1500.0,
        'totalVencido': 500.0,
        'totalCargosAbiertos': 2,
        'saldoAFavor': 300.0,
        'viviendas': [
          {
            'viviendaId': 8,
            'numeroCasa': 'Casa 8-B',
            'totalPendiente': 1500.0,
            'totalVencido': 500.0,
            'totalCargosAbiertos': 2,
            'saldoAFavor': 300.0,
          }
        ]
      };

      final miSaldo = MiSaldoResponse.fromJson(json);
      expect(miSaldo.totalPendiente, 1500.0);
      expect(miSaldo.totalVencido, 500.0);
      expect(miSaldo.totalCargosAbiertos, 2);
      expect(miSaldo.saldoAFavor, 300.0);
      expect(miSaldo.viviendas.length, 1);
      expect(miSaldo.viviendas.first.viviendaId, 8);
      expect(miSaldo.viviendas.first.numeroCasa, 'Casa 8-B');
    });

    test('MovimientoSaldoModel parses correctly', () {
      final json = {
        'id': 'mov-1',
        'viviendaId': 8,
        'tipo': 'Abono',
        'monto': 200.0,
        'saldoAnterior': 100.0,
        'saldoNuevo': 300.0,
        'fecha': '2026-10-20T10:00:00Z',
        'concepto': 'Excedente de pago',
      };

      final mov = MovimientoSaldoModel.fromJson(json);
      expect(mov.id, 'mov-1');
      expect(mov.viviendaId, 8);
      expect(mov.tipo, 'Abono');
      expect(mov.monto, 200.0);
      expect(mov.saldoAnterior, 100.0);
      expect(mov.saldoNuevo, 300.0);
      expect(mov.concepto, 'Excedente de pago');
    });

    test('PaginatedResponse parses items with generic factory', () {
      final json = {
        'pagina': 1,
        'tamanoPagina': 20,
        'total': 45,
        'items': [
          {
            'id': 'cargo-1',
            'viviendaId': 12,
            'tipo': 'Multa',
            'concepto': 'Ruido',
            'monto': 500.0,
            'saldoPendiente': 500.0,
            'estado': 'Pendiente',
          }
        ]
      };

      final page = PaginatedResponse<CargoModel>.fromJson(
        json,
        (item) => CargoModel.fromJson(item),
      );

      expect(page.pagina, 1);
      expect(page.tamanoPagina, 20);
      expect(page.total, 45);
      expect(page.items.length, 1);
      expect(page.hasMore, isTrue);
      expect(page.items.first.concepto, 'Ruido');
    });
  });
}
