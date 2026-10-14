import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { Subject, of, throwError } from 'rxjs';
import { ReservasAdminService } from './reservas-admin.service';
import { ApiService } from './api.service';
import { AreaComun, Reserva } from '../models/reserva.model';

const reserva = (id: string, estado: string, extra: Partial<Reserva> = {}): Reserva => ({
  id, areaId: 'a1', areaNombre: 'Salón', tipo: 'RESERVA', estado: estado as Reserva['estado'],
  inicio: '2026-10-21T16:00:00Z', fin: '2026-10-21T18:00:00Z', ...extra
});
const area = (id: string, activo = true): AreaComun => ({ id, nombre: id, horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: 'America/Mexico_City', activo });

describe('ReservasAdminService', () => {
  let service: ReservasAdminService;
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post', 'patch']);
    TestBed.configureTestingModule({ providers: [ReservasAdminService, { provide: ApiService, useValue: api }] });
    service = TestBed.inject(ReservasAdminService);
  });

  describe('cargarReservas', () => {
    it('manda solo los filtros con valor y guarda la página con su total', async () => {
      api.get.and.returnValue(of({ items: [reserva('r1', 'pendiente_admin')], totalCount: 41, page: 2 }));

      await service.cargarReservas({ estado: 'PENDIENTE_ADMIN', areaId: 'a1' }, 2);

      const [endpoint, params, , microservicio] = api.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
      expect(endpoint).toBe('/api/admin/reservas');
      expect(microservicio).toBe('reservas');
      expect(params.get('page')).toBe('2');
      expect(params.get('pageSize')).toBe('20');
      expect(params.get('estado')).toBe('PENDIENTE_ADMIN');
      expect(params.get('areaId')).toBe('a1');
      expect(params.has('from')).toBeFalse();
      expect(service.total()).toBe(41);
      expect(service.page()).toBe(2);
      expect(service.reservas()[0].estado).toBe('PENDIENTE_ADMIN');
    });

    it('un filtro vacío no se envía', async () => {
      api.get.and.returnValue(of({ items: [], totalCount: 0 }));

      await service.cargarReservas({ estado: '', areaId: '' });

      const params = api.get.calls.mostRecent().args[1] as HttpParams;
      expect(params.has('estado')).toBeFalse();
      expect(params.has('areaId')).toBeFalse();
    });

    it('una respuesta lenta de otros filtros no pisa la más reciente', async () => {
      const lenta = new Subject<any>();
      api.get.and.returnValues(lenta, of({ items: [reserva('nueva', 'APROBADA')], totalCount: 1 }));

      const primera = service.cargarReservas({ estado: 'CANCELADA' });
      await service.cargarReservas({ estado: 'APROBADA' });
      lenta.next({ items: [reserva('vieja', 'CANCELADA')], totalCount: 1 });
      lenta.complete();
      await primera;

      expect(service.reservas().map(r => r.id)).toEqual(['nueva']);
      expect(service.isLoading()).toBeFalse();
    });

    it('un 403 explica que falta permiso y otro error usa el mensaje del backend', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 403 })));
      await service.cargarReservas();
      expect(service.errorMessage()).toBe('Tu cuenta no tiene permiso para administrar las reservas.');

      api.get.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Servicio no disponible' } })));
      await service.cargarReservas();
      expect(service.errorMessage()).toBe('Servicio no disponible');
    });
  });

  describe('áreas', () => {
    it('carga todas, también las dadas de baja', async () => {
      api.get.and.returnValue(of({ items: [area('a1'), area('a2', false)] }));

      await service.cargarAreas();

      expect(api.get.calls.mostRecent().args[0]).toBe('/api/areas');
      expect(service.areas().map(a => a.activo)).toEqual([true, false]);
    });

    it('crear suma el área; actualizar la corrige en la lista; baja y reactivar cambian su estado', async () => {
      service.areas.set([area('a1')]);
      api.post.and.returnValue(of(area('a2')));
      const dto = { nombre: 'Alberca', horaApertura: '08:00:00', horaCierre: '20:00:00' };

      await service.crearArea(dto);
      expect(api.post).toHaveBeenCalledWith('/api/areas', dto, undefined, 'reservas');
      expect(service.areas().map(a => a.id)).toEqual(['a1', 'a2']);

      api.patch.and.returnValue(of({ ...area('a1'), nombre: 'Salón nuevo' }));
      await service.actualizarArea('a1', { nombre: 'Salón nuevo' });
      expect(api.patch).toHaveBeenCalledWith('/api/areas/a1', { nombre: 'Salón nuevo' }, undefined, 'reservas');
      expect(service.areas()[0].nombre).toBe('Salón nuevo');

      api.post.and.returnValue(of(null));
      await service.darDeBaja('a1');
      expect(api.post).toHaveBeenCalledWith('/api/areas/a1/baja', {}, undefined, 'reservas');
      expect(service.areas()[0].activo).toBeFalse();

      await service.reactivar('a1');
      expect(api.post).toHaveBeenCalledWith('/api/areas/a1/reactivar', {}, undefined, 'reservas');
      expect(service.areas()[0].activo).toBeTrue();
    });

    it('si el backend falla propaga el error y deja la lista igual', async () => {
      service.areas.set([area('a1')]);
      api.post.and.returnValue(throwError(() => ({ status: 400, error: { error: 'La hora de apertura debe ser menor a la hora de cierre.' } })));

      await expectAsync(service.crearArea({ nombre: 'x', horaApertura: '10:00:00', horaCierre: '09:00:00' })).toBeRejectedWith(jasmine.objectContaining({ status: 400 }));
      expect(service.areas().length).toBe(1);
    });
  });

  describe('acciones sobre una reserva', () => {
    beforeEach(() => api.post.and.returnValue(of(null)));

    it('aprobar y marcar como no utilizada no llevan cuerpo', async () => {
      await service.aprobar('r1');
      expect(api.post).toHaveBeenCalledWith('/api/admin/reservas/r1/aprobar', {}, undefined, 'reservas');

      await service.marcarNoUtilizada('r1');
      expect(api.post).toHaveBeenCalledWith('/api/admin/reservas/r1/no-utilizada', {}, undefined, 'reservas');
    });

    it('rechazar y cancelar mandan el motivo sin espacios sobrantes', async () => {
      await service.rechazar('r1', '  Evento del condominio ');
      expect(api.post).toHaveBeenCalledWith('/api/admin/reservas/r1/rechazar', { motivo: 'Evento del condominio' }, undefined, 'reservas');

      await service.cancelar('r2', ' Contingencia ');
      expect(api.post).toHaveBeenCalledWith('/api/admin/reservas/r2/cancelar', { motivo: 'Contingencia' }, undefined, 'reservas');
    });

    it('si la reserva ya cambió el error se propaga', async () => {
      api.post.and.returnValue(throwError(() => ({ status: 409, error: { error: 'El estado de la reserva no permite esta operación.' } })));

      await expectAsync(service.aprobar('r1')).toBeRejectedWith(jasmine.objectContaining({ status: 409 }));
    });
  });

  describe('bloqueos', () => {
    it('crea el bloqueo y devuelve cuántas reservas se cancelaron', async () => {
      api.post.and.returnValue(of({ bloqueoId: 'b1', areaId: 'a1', inicio: 'i', fin: 'f', motivo: 'Mantenimiento', reservasAfectadas: 2 }));

      const resultado = await service.crearBloqueo({ areaId: 'a1', inicio: 'i', fin: 'f', motivo: '  Mantenimiento ' });

      expect(api.post).toHaveBeenCalledWith('/api/admin/bloqueos', { areaId: 'a1', inicio: 'i', fin: 'f', motivo: 'Mantenimiento' }, undefined, 'reservas');
      expect(resultado.reservasAfectadas).toBe(2);
    });
  });

  describe('inasistencias', () => {
    it('carga la página pedida con su total', async () => {
      api.get.and.returnValue(of({ items: [{ id: 'n1', numeroCasa: 'A-1' }], totalCount: 21, page: 2 }));

      await service.cargarNoShows(2);

      const [endpoint, params] = api.get.calls.mostRecent().args as [string, HttpParams];
      expect(endpoint).toBe('/api/admin/reservas/no-shows');
      expect(params.get('page')).toBe('2');
      expect(service.noShows().length).toBe(1);
      expect(service.noShowsTotal()).toBe(21);
    });

    it('un error deja un mensaje claro', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 0 })));

      await service.cargarNoShows();

      expect(service.errorNoShows()).toBe('No se pudo cargar el historial de inasistencias.');
      expect(service.isLoadingNoShows()).toBeFalse();
    });
  });
});
