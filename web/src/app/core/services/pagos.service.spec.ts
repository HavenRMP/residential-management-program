import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { PagosService } from './pagos.service';
import { ApiService } from './api.service';

const cargoCrudo = (id: string, extra: Record<string, unknown> = {}) => ({
  id, vivienda_id: 3, numero_casa: '3', tipo: 'Mantenimiento', concepto: 'Cuota', monto: 1000,
  monto_pagado_confirmado: 0, saldo_pendiente: 1000, estado: 'Pendiente', estado_efectivo: 'Pendiente',
  fecha_vencimiento: '2026-10-10', responsable_pago: 'Residente', creado_en: '2026-10-01T00:00:00Z', ...extra
});

const pagoCrudo = (id: string, extra: Record<string, unknown> = {}) => ({
  id, cargo_id: 'c1', vivienda_id: 3, numero_casa: '3', cargo_tipo: 'Mantenimiento', cargo_concepto: 'Cuota', monto: 1000,
  monto_cubierto: 1000, monto_excedente: 0, fecha_pago: '2026-10-05', metodo: 'Efectivo', estado: 'Confirmado',
  origen: 'Admin', tiene_comprobante: false, es_reversa: false, creado_en: '2026-10-05T00:00:00Z', ...extra
});

describe('PagosService', () => {
  let service: PagosService;
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post']);
    TestBed.configureTestingModule({ providers: [PagosService, { provide: ApiService, useValue: api }] });
    service = TestBed.inject(PagosService);
  });

  const ultimaGet = () => api.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
  const ultimaPost = () => api.post.calls.mostRecent().args as [string, any, unknown, string];

  describe('cargos', () => {
    it('lista con los filtros en snake_case y siempre contra el microservicio de pagos', async () => {
      api.get.and.returnValue(of({ items: [cargoCrudo('c1')], total: 1, pagina: 1, tamanoPagina: 20 }));

      const r = await service.listarCargos({ viviendaId: 3, estado: 'Pendiente', vencido: true, periodo: '2026-10', desde: '2026-10-01' }, 2);

      const [endpoint, params, , microservicio] = ultimaGet();
      expect(endpoint).toBe('/api/cargos');
      expect(microservicio).toBe('pagos');
      expect(params.get('page')).toBe('2');
      expect(params.get('vivienda_id')).toBe('3');
      expect(params.get('estado')).toBe('Pendiente');
      expect(params.get('vencido')).toBe('true');
      expect(params.get('periodo')).toBe('2026-10');
      expect(params.get('vencimiento_desde')).toBe('2026-10-01');
      expect(params.has('tipo')).toBeFalse();
      expect(r.items[0].saldoPendiente).toBe(1000);
    });

    it('crea un cargo enviando solo el periodo y el responsable cuando vienen', async () => {
      api.post.and.returnValue(of(cargoCrudo('c9', { tipo: 'Multa' })));

      await service.crearCargo({ viviendaId: 3, tipo: 'Multa', concepto: '  Ruido  ', monto: 300, fechaVencimiento: '2026-11-01' });

      const [endpoint, cuerpo] = ultimaPost();
      expect(endpoint).toBe('/api/cargos');
      expect(cuerpo).toEqual({ vivienda_id: 3, tipo: 'Multa', concepto: 'Ruido', monto: 300, fecha_vencimiento: '2026-11-01' });

      await service.crearCargo({ viviendaId: 3, tipo: 'Renta', concepto: 'Renta', monto: 5000, periodo: '2026-11', fechaVencimiento: '2026-11-05', responsablePago: 'Propietario' });
      expect(ultimaPost()[1]).toEqual(jasmine.objectContaining({ periodo: '2026-11', responsable_pago: 'Propietario' }));
    });

    it('cancela con el motivo recortado', async () => {
      api.post.and.returnValue(of(cargoCrudo('c1', { estado: 'Cancelado', motivo_cancelacion: 'Error de captura' })));

      const cargo = await service.cancelarCargo('c1', '  Error de captura ');

      expect(ultimaPost()[0]).toBe('/api/cargos/c1/cancelar');
      expect(ultimaPost()[1]).toEqual({ motivo: 'Error de captura' });
      expect(cargo.estado).toBe('Cancelado');
    });

    it('aplica saldo a favor y devuelve el movimiento, el cargo y el saldo que queda', async () => {
      api.post.and.returnValue(of({
        movimiento: { id: 'm1', tipo: 'Aplicacion', monto: 200 },
        cargo: cargoCrudo('c1', { saldo_pendiente: 800 }),
        saldo_a_favor: 50
      }));

      const r = await service.aplicarSaldo('c1', 200);

      expect(ultimaPost()[0]).toBe('/api/cargos/c1/aplicar-saldo');
      expect(ultimaPost()[1]).toEqual({ monto: 200 });
      expect(r.cargo.saldoPendiente).toBe(800);
      expect(r.saldoAFavor).toBe(50);
    });

    it('el detalle trae los pagos del cargo', async () => {
      api.get.and.returnValue(of({ ...cargoCrudo('c1'), pagos: [{ id: 'p1', monto: 100, estado: 'Confirmado', metodo: 'Efectivo' }] }));

      const detalle = await service.obtenerCargo('c1');

      expect(ultimaGet()[0]).toBe('/api/cargos/c1');
      expect(detalle.pagos.length).toBe(1);
    });
  });

  describe('pagos', () => {
    it('lista con los filtros en snake_case', async () => {
      api.get.and.returnValue(of({ items: [pagoCrudo('p1')], total: 1 }));

      await service.listarPagos({ estado: 'PendienteConfirmacion', cargoId: 'c1', desde: '2026-10-01', hasta: '2026-10-31', metodo: 'Transferencia' });

      const [endpoint, params] = ultimaGet();
      expect(endpoint).toBe('/api/pagos');
      expect(params.get('estado')).toBe('PendienteConfirmacion');
      expect(params.get('cargo_id')).toBe('c1');
      expect(params.get('fecha_pago_desde')).toBe('2026-10-01');
      expect(params.get('fecha_pago_hasta')).toBe('2026-10-31');
      expect(params.get('metodo')).toBe('Transferencia');
    });

    it('el residente reporta un pago con su comprobante, sin campos vacíos', async () => {
      api.post.and.returnValue(of(pagoCrudo('p2', { estado: 'PendienteConfirmacion', origen: 'Inquilino' })));

      const pago = await service.reportarPago({
        cargoId: 'c1', monto: 1000, fechaPago: '2026-10-05', metodo: 'Transferencia',
        referencia: ' ABC123 ', bancoOrigen: 'BBVA', comprobante: { ruta: 'cond/3/a.jpg', hash: 'f'.repeat(64) }
      });

      const [endpoint, cuerpo] = ultimaPost();
      expect(endpoint).toBe('/api/pagos/reportar');
      expect(cuerpo).toEqual({
        cargo_id: 'c1', monto: 1000, fecha_pago: '2026-10-05', metodo: 'Transferencia', referencia: 'ABC123',
        banco_origen: 'BBVA', comprobante: { ruta: 'cond/3/a.jpg', hash: 'f'.repeat(64) }
      });
      expect(pago.estado).toBe('PendienteConfirmacion');
    });

    it('el administrador registra un pago en efectivo sin referencia ni comprobante', async () => {
      api.post.and.returnValue(of({ pago: pagoCrudo('p3'), cargo: cargoCrudo('c1', { estado: 'Pagado', saldo_pendiente: 0 }), saldo_a_favor: 0 }));

      const r = await service.registrarPago({ cargoId: 'c1', monto: 1000, fechaPago: '2026-10-05', metodo: 'Efectivo', referencia: '  ' });

      expect(ultimaPost()[0]).toBe('/api/pagos');
      expect(ultimaPost()[1]).toEqual({ cargo_id: 'c1', monto: 1000, fecha_pago: '2026-10-05', metodo: 'Efectivo' });
      expect(r.cargo.estado).toBe('Pagado');
    });

    it('confirma, rechaza y anula contra la ruta del pago', async () => {
      api.post.and.returnValue(of({ pago: pagoCrudo('p1'), cargo: cargoCrudo('c1'), saldo_a_favor: 25 }));
      expect((await service.confirmarPago('p1')).saldoAFavor).toBe(25);
      expect(ultimaPost()[0]).toBe('/api/pagos/p1/confirmar');

      api.post.and.returnValue(of({ pago: pagoCrudo('p1', { estado: 'Rechazado', motivo_rechazo: 'Borroso' }) }));
      const rechazado = await service.rechazarPago('p1', ' Borroso ');
      expect(ultimaPost()[0]).toBe('/api/pagos/p1/rechazar');
      expect(ultimaPost()[1]).toEqual({ motivo: 'Borroso' });
      expect(rechazado.motivoRechazo).toBe('Borroso');

      api.post.and.returnValue(of({
        pago_anulado: pagoCrudo('p1', { estado: 'Anulado' }), pago_reversa: pagoCrudo('p9', { es_reversa: true, pago_original_id: 'p1' }),
        cargo: cargoCrudo('c1'), movimiento_saldo: null, saldo_a_favor: 0
      }));
      const anulacion = await service.anularPago('p1', 'Pago duplicado');
      expect(ultimaPost()[0]).toBe('/api/pagos/p1/anular');
      expect(anulacion.pagoReversa?.esReversa).toBeTrue();
      expect(anulacion.pagoAnulado.estado).toBe('Anulado');
    });

    it('anular un pago sin pago de reversa en la respuesta no falla', async () => {
      api.post.and.returnValue(of({
        pago_anulado: pagoCrudo('p1', { estado: 'Anulado' }), pago_reversa: null,
        cargo: cargoCrudo('c1'), movimiento_saldo: null, saldo_a_favor: 0
      }));

      const anulacion = await service.anularPago('p1', 'Pago duplicado');

      expect(anulacion.pagoAnulado.estado).toBe('Anulado');
      expect(anulacion.pagoReversa).toBeNull();
    });

    it('obtiene el enlace temporal del comprobante', async () => {
      api.get.and.returnValue(of({ url: 'https://storage/firmada', expira_en: '2026-10-05T12:00:00Z' }));

      expect(await service.obtenerUrlComprobante('p1')).toBe('https://storage/firmada');
      expect(ultimaGet()[0]).toBe('/api/pagos/p1/comprobante-url');
    });

    it('sube el comprobante como formulario con el archivo y la vivienda', async () => {
      api.post.and.returnValue(of({ ruta: 'cond/3/a.jpg', hash: 'ab', tamano_bytes: 1234, content_type: 'image/jpeg' }));
      const archivo = new File(['x'], 'recibo.jpg', { type: 'image/jpeg' });

      const r = await service.subirComprobante(archivo, 3);

      const [endpoint, cuerpo, , microservicio] = ultimaPost();
      expect(endpoint).toBe('/api/comprobantes');
      expect(microservicio).toBe('pagos');
      expect(cuerpo instanceof FormData).toBeTrue();
      expect((cuerpo as FormData).get('vivienda_id')).toBe('3');
      expect(((cuerpo as FormData).get('archivo') as File).name).toBe('recibo.jpg');
      expect(r).toEqual({ ruta: 'cond/3/a.jpg', hash: 'ab', tamanoBytes: 1234, contentType: 'image/jpeg' });
    });
  });

  describe('saldos', () => {
    it('lista los movimientos de una vivienda, filtrando por tipo cuando se pide', async () => {
      api.get.and.returnValue(of({ items: [{ id: 'm1', tipo: 'Abono', monto: 50 }], total: 1 }));

      const r = await service.listarMovimientos(7, 2, 'Abono');

      const [endpoint, params] = ultimaGet();
      expect(endpoint).toBe('/api/saldos/viviendas/7/movimientos');
      expect(params.get('page')).toBe('2');
      expect(params.get('tipo')).toBe('Abono');
      expect(r.items[0].tipo).toBe('Abono');
    });

    it('revierte un movimiento con su motivo', async () => {
      api.post.and.returnValue(of({ movimiento: { id: 'm2', tipo: 'ReversoAplicacion', monto: 200 }, cargo: cargoCrudo('c1'), saldo_a_favor: 200 }));

      const r = await service.revertirMovimiento('m1', ' Se aplicó al cargo equivocado ');

      expect(ultimaPost()[0]).toBe('/api/saldos/movimientos/m1/revertir');
      expect(ultimaPost()[1]).toEqual({ motivo: 'Se aplicó al cargo equivocado' });
      expect(r.saldoAFavor).toBe(200);
    });
  });

  describe('resumen del residente', () => {
    const respuestas = (url: string) => {
      if (url === '/api/saldos/mi-saldo') return of({ total_pendiente: 1000, total_vencido: 0, total_cargos_abiertos: 1, saldo_a_favor: 0, viviendas: [] });
      if (url === '/api/cargos') return of({ items: [cargoCrudo('c1')], total: 1 });
      return of({ items: [pagoCrudo('p1')], total: 1 });
    };

    it('carga saldo, cargos y pagos', async () => {
      api.get.and.callFake(((url: string) => respuestas(url)) as any);

      await service.cargarResumen();

      expect(service.miSaldo()?.totalPendiente).toBe(1000);
      expect(service.misCargos().length).toBe(1);
      expect(service.misPagos().length).toBe(1);
      expect(service.isLoading()).toBeFalse();
      expect(service.errorMessage()).toBeNull();
    });

    it('pide la página siguiente mientras falten cargos', async () => {
      const paginas: number[] = [];
      api.get.and.callFake(((url: string, params?: HttpParams) => {
        if (url === '/api/cargos') {
          const page = Number(params?.get('page'));
          paginas.push(page);
          return of({ items: [cargoCrudo(`c${page}`)], total: 2 });
        }
        return respuestas(url);
      }) as any);

      await service.cargarResumen();

      expect(paginas).toEqual([1, 2]);
      expect(service.misCargos().map(c => c.id)).toEqual(['c1', 'c2']);
    });

    it('si falla deja el mensaje del backend', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 404, error: { error: 'Vivienda no encontrada.' } })));

      await service.cargarResumen();

      expect(service.errorMessage()).toBe('Vivienda no encontrada.');
      expect(service.isLoading()).toBeFalse();
    });

    it('en modo silencioso un fallo no muestra error y deja los datos como estaban', async () => {
      spyOn(console, 'error');
      service.misCargos.set([{ id: 'previo' } as any]);
      api.get.and.returnValue(throwError(() => ({ status: 500 })));

      await service.cargarResumen(true);

      expect(service.errorMessage()).toBeNull();
      expect(service.misCargos()[0].id).toBe('previo');
    });

    it('contar cargos abiertos devuelve 0 si el servicio falla', async () => {
      api.get.and.returnValue(of({ total_cargos_abiertos: 3 }));
      expect(await service.contarCargosAbiertos()).toBe(3);

      api.get.and.returnValue(throwError(() => ({ status: 503 })));
      expect(await service.contarCargosAbiertos()).toBe(0);
    });
  });
});
