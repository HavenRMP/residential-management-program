import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { Subject, of, throwError } from 'rxjs';
import { PaqueteriaService } from './paqueteria.service';
import { ApiService } from './api.service';
import { Paquete } from '../models/paquete.model';

const paquete = (id: string, extra: Partial<Paquete> = {}): Paquete => ({
  id,
  viviendaId: 33,
  destinatarioNombre: 'Angel Gómez',
  estado: 'esperado',
  creadoEn: '2026-10-10T10:00:00Z',
  ...extra
});

describe('PaqueteriaService', () => {
  let service: PaqueteriaService;
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post', 'put']);
    TestBed.configureTestingModule({
      providers: [PaqueteriaService, { provide: ApiService, useValue: api }]
    });
    service = TestBed.inject(PaqueteriaService);
  });

  describe('cargar', () => {
    it('pide los paquetes propios al microservicio de visitas', async () => {
      api.get.and.returnValue(of({ items: [], totalCount: 0 }));

      await service.cargar();

      const [endpoint, params, , servicio] = api.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
      expect(endpoint).toBe('/api/paqueteria/mis-paquetes');
      expect(params.get('page')).toBe('1');
      expect(params.has('estado')).toBeFalse();
      expect(servicio).toBe('visitas');
    });

    it('recorre todas las páginas sin duplicar paquetes', async () => {
      const pagina1 = Array.from({ length: 50 }, (_, i) => paquete(`p${i}`));
      const pagina2 = [paquete('p49'), paquete('p50')];
      api.get.and.returnValues(of({ items: pagina1, totalCount: 51 }), of({ items: pagina2, totalCount: 51 }));

      await service.cargar();

      expect(api.get).toHaveBeenCalledTimes(2);
      expect(service.items().length).toBe(51);
    });

    it('reparte los paquetes entre pendientes, en caseta e historial', async () => {
      api.get.and.returnValue(of({
        items: [
          paquete('e1'),
          paquete('r1', { estado: 'recibido', recibidoEn: '2026-10-11T08:00:00Z' }),
          paquete('h1', { estado: 'entregado', entregadoEn: '2026-10-11T09:00:00Z' }),
          paquete('c1', { estado: 'cancelado' }),
          paquete('v1', { fechaEsperadaHasta: '2020-01-01T00:00:00Z' })
        ],
        totalCount: 5
      }));

      await service.cargar();

      expect(service.pendientes().map(p => p.id)).toEqual(['r1', 'e1']);
      expect(service.enCaseta().map(p => p.id)).toEqual(['r1']);
      expect(service.historial().map(p => p.id)).toEqual(['h1', 'c1', 'v1']);
    });

    it('un error deja un mensaje y apaga la carga', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Fallo del servidor' } })));

      await service.cargar();

      expect(service.errorMessage()).toBe('Fallo del servidor');
      expect(service.isLoading()).toBeFalse();
    });

    it('sin mensaje del backend usa uno claro', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 0 })));

      await service.cargar();

      expect(service.errorMessage()).toBe('No se pudieron cargar tus paquetes.');
    });

    it('una respuesta lenta de una carga anterior no pisa la más reciente', async () => {
      const lenta = new Subject<any>();
      api.get.and.returnValues(lenta, of({ items: [paquete('nuevo')], totalCount: 1 }));

      const primera = service.cargar();
      await service.cargar();
      lenta.next({ items: [paquete('viejo')], totalCount: 1 });
      lenta.complete();
      await primera;

      expect(service.items().map(p => p.id)).toEqual(['nuevo']);
      expect(service.isLoading()).toBeFalse();
    });
  });

  describe('cargarServicios', () => {
    it('guarda solo las empresas activas', async () => {
      api.get.and.returnValue(of([
        { id: 1, nombre: 'Amazon', activo: true, esSistema: true },
        { id: 9, nombre: 'Vieja', activo: false, esSistema: false }
      ]));

      await service.cargarServicios();

      expect(api.get.calls.mostRecent().args[0]).toBe('/api/paqueteria/servicios');
      expect(service.servicios().map(s => s.nombre)).toEqual(['Amazon']);
    });

    it('si falla deja el catálogo vacío sin lanzar error', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 500 })));

      await service.cargarServicios();

      expect(service.servicios()).toEqual([]);
    });
  });

  describe('contarEnCaseta', () => {
    it('consulta un solo elemento del estado recibido y devuelve el total', async () => {
      api.get.and.returnValue(of({ items: [paquete('r1', { estado: 'recibido' })], totalCount: 3 }));

      expect(await service.contarEnCaseta()).toBe(3);

      const params = api.get.calls.mostRecent().args[1] as HttpParams;
      expect(params.get('estado')).toBe('recibido');
      expect(params.get('pageSize')).toBe('1');
    });

    it('si falla devuelve 0', async () => {
      api.get.and.returnValue(throwError(() => ({ status: 500 })));

      expect(await service.contarEnCaseta()).toBe(0);
    });
  });
});
