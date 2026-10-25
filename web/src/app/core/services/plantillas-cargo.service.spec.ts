import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of } from 'rxjs';
import { PlantillasCargoService } from './plantillas-cargo.service';
import { ApiService } from './api.service';

const plantillaCruda = (id: string, extra: Record<string, unknown> = {}) => ({
  id, vivienda_id: 3, numero_casa: '3', tipo: 'Mantenimiento', concepto: 'Cuota', monto: 1200, dia_vencimiento: 10,
  vigencia_inicio: '2026-11-01', vigencia_fin: null, responsable_pago: 'Residente', activa: true, ...extra
});

describe('PlantillasCargoService', () => {
  let service: PlantillasCargoService;
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post', 'put']);
    TestBed.configureTestingModule({ providers: [PlantillasCargoService, { provide: ApiService, useValue: api }] });
    service = TestBed.inject(PlantillasCargoService);
  });

  it('lista filtrando por activa, tipo y vivienda contra el microservicio de pagos', async () => {
    api.get.and.returnValue(of({ items: [plantillaCruda('t1')], total: 1 }));

    const r = await service.listar({ activa: false, tipo: 'Renta', viviendaId: 3 }, 2);

    const [endpoint, params, , microservicio] = api.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
    expect(endpoint).toBe('/api/plantillas-cargo');
    expect(microservicio).toBe('pagos');
    expect(params.get('activa')).toBe('false');
    expect(params.get('tipo')).toBe('Renta');
    expect(params.get('vivienda_id')).toBe('3');
    expect(params.get('page')).toBe('2');
    expect(r.items[0].diaVencimiento).toBe(10);
  });

  it('sin filtros no manda activa, tipo ni vivienda', async () => {
    api.get.and.returnValue(of({ items: [], total: 0 }));

    await service.listar();

    const params = (api.get.calls.mostRecent().args as [string, HttpParams])[1];
    expect(params.has('activa')).toBeFalse();
    expect(params.has('tipo')).toBeFalse();
    expect(params.has('vivienda_id')).toBeFalse();
  });

  it('crea una plantilla por vivienda y solo manda el monto propio de las que lo tienen', async () => {
    api.post.and.returnValue(of([plantillaCruda('t1'), plantillaCruda('t2', { vivienda_id: 4 })]));

    const creadas = await service.crear({
      concepto: '  Cuota  ', tipo: 'Mantenimiento', monto: 1200, diaVencimiento: 10, vigenciaInicio: '2026-11-01',
      viviendas: [{ viviendaId: 3 }, { viviendaId: 4, monto: 900 }]
    });

    const [endpoint, cuerpo] = api.post.calls.mostRecent().args as [string, any];
    expect(endpoint).toBe('/api/plantillas-cargo');
    expect(cuerpo).toEqual({
      concepto: 'Cuota', tipo: 'Mantenimiento', monto: 1200, dia_vencimiento: 10, vigencia_inicio: '2026-11-01',
      viviendas: [{ vivienda_id: 3 }, { vivienda_id: 4, monto: 900 }]
    });
    expect(creadas.length).toBe(2);
  });

  it('actualiza quitando la vigencia final cuando se deja vacía', async () => {
    api.put.and.returnValue(of(plantillaCruda('t1', { monto: 1500 })));

    const r = await service.actualizar('t1', { concepto: ' Cuota 2027 ', monto: 1500, diaVencimiento: 5, vigenciaFin: '' });

    const [endpoint, cuerpo] = api.put.calls.mostRecent().args as [string, any];
    expect(endpoint).toBe('/api/plantillas-cargo/t1');
    expect(cuerpo).toEqual({ concepto: 'Cuota 2027', monto: 1500, dia_vencimiento: 5, vigencia_fin: null });
    expect(r.monto).toBe(1500);
  });

  it('activa y desactiva por su ruta', async () => {
    api.post.and.returnValue(of(plantillaCruda('t1', { activa: false })));
    expect((await service.cambiarActiva('t1', false)).activa).toBeFalse();
    expect((api.post.calls.mostRecent().args as [string, unknown])[0]).toBe('/api/plantillas-cargo/t1/desactivar');

    api.post.and.returnValue(of(plantillaCruda('t1')));
    await service.cambiarActiva('t1', true);
    expect((api.post.calls.mostRecent().args as [string, unknown])[0]).toBe('/api/plantillas-cargo/t1/activar');
  });

  it('genera los cargos del periodo y resume cuántos creó y cuántos omitió', async () => {
    api.post.and.returnValue(of({ creados: 8, omitidos_por_ya_existir: 2, omitidos_por_vigencia: 1, cargos: [] }));

    const r = await service.generarCargos('2026-11');

    const [endpoint, cuerpo] = api.post.calls.mostRecent().args as [string, any];
    expect(endpoint).toBe('/api/plantillas-cargo/generar');
    expect(cuerpo).toEqual({ periodo: '2026-11' });
    expect(r).toEqual({ creados: 8, omitidosPorYaExistir: 2, omitidosPorVigencia: 1 });
  });

  it('puede limitar la generación a unas plantillas', async () => {
    api.post.and.returnValue(of({ creados: 1 }));

    await service.generarCargos('2026-11', ['t1', 't2']);

    expect((api.post.calls.mostRecent().args as [string, any])[1]).toEqual({ periodo: '2026-11', plantilla_ids: ['t1', 't2'] });
  });
});
