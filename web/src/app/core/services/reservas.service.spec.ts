import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { Subject, of, throwError } from 'rxjs';
import { ReservasService } from './reservas.service';
import { ApiService } from './api.service';
import { Reserva } from '../models/reserva.model';

const manana = Date.now() + 2 * 86_400_000;
const reserva = (id: string, estado: string, inicioMs = manana, extra: Partial<Reserva> = {}): Reserva => ({
  id, areaId: 'a1', areaNombre: 'Salón', tipo: 'RESERVA', estado: estado as Reserva['estado'],
  inicio: new Date(inicioMs).toISOString(), fin: new Date(inicioMs + 2 * 3_600_000).toISOString(), ...extra
});

describe('ReservasService', () => {
  let service: ReservasService;
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post']);
    TestBed.configureTestingModule({ providers: [ReservasService, { provide: ApiService, useValue: api }] });
    service = TestBed.inject(ReservasService);
  });

  it('cuenta como acciones pendientes las solicitudes por aprobar y las reservas listas para confirmar', () => {
    const enDias = (d: number) => Date.now() + d * 86_400_000;
    service.mias.set([
      reserva('lista', 'APROBADA', enDias(5)),
      reserva('lejana', 'APROBADA', enDias(20)),
      reserva('pendiente', 'PENDIENTE_ADMIN', enDias(5)),
      reserva('confirmada', 'CONFIRMADA', enDias(5))
    ]);
    service.porAprobar.set([{ id: 'p1' } as any, { id: 'p2' } as any]);

    expect(service.accionesPendientes()).toBe(3);

    service.porAprobar.set([]);
    expect(service.accionesPendientes()).toBe(1);
  });

  describe('cargarAreas', () => {
    it('pide solo las activas al microservicio de reservas', async () => {
      api.get.and.returnValue(of({ items: [{ id: 'a1', nombre: 'Salón', horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: 'America/Mexico_City', activo: true }] }));

      await service.cargarAreas();

      const [endpoint, params, , microservicio] = api.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
      expect(endpoint).toBe('/api/areas');
      expect(params.get('soloActivas')).toBe('true');
      expect(microservicio).toBe('reservas');
      expect(service.areas().map(a => a.nombre)).toEqual(['Salón']);
    });

    it('un error deja el mensaje del backend y apaga la carga', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 403, error: { error: 'El usuario no pertenece a un condominio' } })));

      await service.cargarAreas();

      expect(service.errorAreas()).toBe('El usuario no pertenece a un condominio');
      expect(service.isLoadingAreas()).toBeFalse();
    });
  });

  describe('cargarMias', () => {
    it('recorre las páginas sin duplicar y normaliza el estado', async () => {
      const pagina1 = Array.from({ length: 50 }, (_, i) => reserva(`r${i}`, 'aprobada'));
      api.get.and.returnValues(
        of({ items: pagina1, totalCount: 51 }),
        of({ items: [reserva('r49', 'APROBADA'), reserva('r50', 'PENDIENTE_ADMIN')], totalCount: 51 })
      );

      await service.cargarMias();

      expect(api.get).toHaveBeenCalledTimes(2);
      expect(service.mias().length).toBe(51);
      expect(service.mias()[0].estado).toBe('APROBADA');
    });

    it('reparte entre próximas e historial', async () => {
      const ayer = Date.now() - 2 * 86_400_000;
      api.get.and.returnValue(of({
        items: [
          reserva('p1', 'PENDIENTE_ADMIN', manana + 3 * 86_400_000),
          reserva('a1', 'APROBADA', manana),
          reserva('f1', 'APROBADA', ayer),
          reserva('c1', 'CANCELADA', manana),
          reserva('r1', 'RECHAZADA_ADMIN', manana)
        ],
        totalCount: 5
      }));

      await service.cargarMias();

      expect(service.proximas().map(r => r.id)).toEqual(['a1', 'p1']);
      expect(service.historial().map(r => r.id).sort()).toEqual(['c1', 'f1', 'r1']);
    });

    it('una respuesta lenta de una carga anterior no pisa la más reciente', async () => {
      const lenta = new Subject<any>();
      api.get.and.returnValues(lenta, of({ items: [reserva('nueva', 'APROBADA')], totalCount: 1 }));

      const primera = service.cargarMias();
      await service.cargarMias();
      lenta.next({ items: [reserva('vieja', 'APROBADA')], totalCount: 1 });
      lenta.complete();
      await primera;

      expect(service.mias().map(r => r.id)).toEqual(['nueva']);
    });

    it('un error deja un mensaje claro', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 0 })));

      await service.cargarMias();

      expect(service.errorMessage()).toBe('No se pudieron cargar tus reservas.');
      expect(service.isLoading()).toBeFalse();
    });
  });

  describe('cargarPorAprobar', () => {
    it('guarda las solicitudes del titular', async () => {
      api.get.and.returnValue(of({ items: [{ id: 'p1', areaId: 'a1', areaNombre: 'Salón', inicio: 'x', fin: 'y', viviendaId: 1, numeroCasa: '1', solicitanteId: 's', solicitanteNombre: 'Ana', solicitanteApellidos: 'L', solicitanteEmail: 'a@x.com', parentesco: 'Hijo/a' }] }));

      await service.cargarPorAprobar();

      expect(api.get.calls.mostRecent().args[0]).toBe('/api/reservas/por-aprobar-titular');
      expect(service.porAprobar().length).toBe(1);
    });

    it('para quien no es titular (error) queda vacío sin lanzar', async () => {
      service.porAprobar.set([{ id: 'x' } as any]);
      api.get.and.returnValue(throwError(() => ({ status: 403 })));

      await service.cargarPorAprobar();

      expect(service.porAprobar()).toEqual([]);
    });
  });

  describe('calendario', () => {
    it('pide el rango y el área sin tocar el estado compartido', async () => {
      api.get.and.returnValue(of({ items: [{ id: 'c1', areaId: 'a1', areaNombre: 'Salón', tipo: 'bloqueo', estado: 'aprobada', inicio: 'i', fin: 'f' }] }));

      const lista = await service.calendario('a1', '2026-10-21T00:00:00Z', '2026-10-22T00:00:00Z');

      const params = api.get.calls.mostRecent().args[1] as HttpParams;
      expect(params.get('areaId')).toBe('a1');
      expect(params.get('from')).toBe('2026-10-21T00:00:00Z');
      expect(params.get('to')).toBe('2026-10-22T00:00:00Z');
      expect(lista[0].tipo).toBe('BLOQUEO');
      expect(lista[0].estado).toBe('APROBADA');
      expect(service.mias()).toEqual([]);
    });

    it('sin área pide el calendario de todas las áreas', async () => {
      api.get.and.returnValue(of({ items: [] }));

      await service.calendario(null, '2026-10-21T00:00:00Z', '2026-10-22T00:00:00Z');

      expect((api.get.calls.mostRecent().args[1] as HttpParams).has('areaId')).toBeFalse();
    });

    it('si el error es del backend se propaga a quien llama', async () => {
      api.get.and.returnValue(throwError(() => ({ status: 400, error: { error: 'El rango de fechas no puede exceder los 62 días.' } })));

      await expectAsync(service.calendario('a1', 'x', 'y')).toBeRejectedWith(jasmine.objectContaining({ status: 400 }));
    });
  });

  describe('solicitar', () => {
    it('envía la solicitud y suma la reserva arriba de la lista', async () => {
      service.mias.set([reserva('vieja', 'APROBADA')]);
      api.post.and.returnValue(of(reserva('nueva', 'PENDIENTE_ADMIN')));
      const dto = { areaId: 'a1', inicio: '2026-10-21T16:00:00.000Z', fin: '2026-10-21T18:00:00.000Z' };

      const creada = await service.solicitar(dto);

      expect(api.post).toHaveBeenCalledWith('/api/reservas', dto, undefined, 'reservas');
      expect(creada.id).toBe('nueva');
      expect(service.mias().map(r => r.id)).toEqual(['nueva', 'vieja']);
    });

    it('si el backend la rechaza propaga el error y deja la lista igual', async () => {
      service.mias.set([reserva('vieja', 'APROBADA')]);
      api.post.and.returnValue(throwError(() => ({ status: 409, error: { error: 'Ya tienes una reserva para ese día.' } })));

      await expectAsync(service.solicitar({ areaId: 'a', inicio: 'i', fin: 'f' })).toBeRejectedWith(jasmine.objectContaining({ status: 409 }));
      expect(service.mias().length).toBe(1);
    });
  });

  describe('confirmar y cancelar', () => {
    it('confirmar registra la confirmación sin cambiar el estado, como lo hace el backend', async () => {
      service.mias.set([reserva('r1', 'APROBADA')]);
      api.post.and.returnValue(of(null));

      await service.confirmar('r1');

      expect(api.post).toHaveBeenCalledWith('/api/reservas/r1/confirmar', {}, undefined, 'reservas');
      expect(service.mias()[0].estado).toBe('APROBADA');
      expect(service.mias()[0].confirmadaEn).toBeTruthy();
    });

    it('una reserva ya confirmada deja de contar como acción pendiente', async () => {
      service.mias.set([reserva('r1', 'APROBADA', Date.now() + 5 * 86_400_000)]);
      expect(service.accionesPendientes()).toBe(1);
      api.post.and.returnValue(of(null));

      await service.confirmar('r1');

      expect(service.accionesPendientes()).toBe(0);
    });

    it('cancelar manda el motivo sin espacios y marca la reserva como cancelada', async () => {
      service.mias.set([reserva('r1', 'PENDIENTE_ADMIN')]);
      api.post.and.returnValue(of(null));

      await service.cancelar('r1', '  Cambio de planes ');

      expect(api.post).toHaveBeenCalledWith('/api/reservas/r1/cancelar', { motivo: 'Cambio de planes' }, undefined, 'reservas');
      expect(service.mias()[0].estado).toBe('CANCELADA');
    });

    it('cancelar sin motivo manda un cuerpo vacío', async () => {
      api.post.and.returnValue(of(null));

      await service.cancelar('r1', '  ');

      expect(api.post.calls.mostRecent().args[1]).toEqual({});
    });

    it('si el backend falla propaga el error y no cambia el estado', async () => {
      service.mias.set([reserva('r1', 'APROBADA')]);
      api.post.and.returnValue(throwError(() => ({ status: 409 })));

      await expectAsync(service.confirmar('r1')).toBeRejectedWith(jasmine.objectContaining({ status: 409 }));
      expect(service.mias()[0].confirmadaEn).toBeFalsy();
    });
  });

  describe('como titular', () => {
    const pendiente = { id: 'p1' } as any;

    it('aprobar quita la solicitud de la lista', async () => {
      service.porAprobar.set([pendiente, { id: 'p2' } as any]);
      api.post.and.returnValue(of(null));

      await service.aprobarComoTitular('p1');

      expect(api.post).toHaveBeenCalledWith('/api/reservas/p1/aprobar-titular', {}, undefined, 'reservas');
      expect(service.porAprobar().map(p => p.id)).toEqual(['p2']);
    });

    it('rechazar manda el motivo opcional y quita la solicitud', async () => {
      service.porAprobar.set([pendiente]);
      api.post.and.returnValue(of(null));

      await service.rechazarComoTitular('p1', 'No estaré en casa');

      expect(api.post).toHaveBeenCalledWith('/api/reservas/p1/rechazar-titular', { motivo: 'No estaré en casa' }, undefined, 'reservas');
      expect(service.porAprobar()).toEqual([]);
    });
  });
});
