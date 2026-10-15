import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { Subject, of, throwError } from 'rxjs';
import { PaqueteriaCasetaService } from './paqueteria-caseta.service';
import { ApiService } from './api.service';
import { Paquete } from '../models/paquete.model';

const paquete = (id: string, extra: Partial<Paquete> = {}): Paquete => ({
  id,
  viviendaId: 33,
  numeroCasa: 'PRUEBA-01',
  destinatarioNombre: 'Angel Gómez',
  estado: 'esperado',
  creadoEn: '2026-10-10T10:00:00Z',
  ...extra
});

describe('PaqueteriaCasetaService', () => {
  let service: PaqueteriaCasetaService;
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post']);
    TestBed.configureTestingModule({
      providers: [PaqueteriaCasetaService, { provide: ApiService, useValue: api }]
    });
    service = TestBed.inject(PaqueteriaCasetaService);
  });

  describe('consultas', () => {
    it('esperados pide el endpoint de esperados al microservicio de visitas', async () => {
      api.get.and.returnValue(of({ items: [paquete('p1')], totalCount: 1 }));

      await service.cargarEsperados();

      const [endpoint, params, , servicio] = api.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
      expect(endpoint).toBe('/api/paqueteria/esperados');
      expect(params.get('page')).toBe('1');
      expect(servicio).toBe('visitas');
      expect(service.esperados.items().map(p => p.id)).toEqual(['p1']);
    });

    it('en caseta pide el inventario', async () => {
      api.get.and.returnValue(of({ items: [paquete('p1', { estado: 'recibido' })], totalCount: 1 }));

      await service.cargarEnCaseta();

      expect(api.get.calls.mostRecent().args[0]).toBe('/api/paqueteria/inventario');
      expect(service.enCaseta.items().length).toBe(1);
    });

    it('el historial manda el estado y el periodo', async () => {
      api.get.and.returnValue(of({ items: [], totalCount: 0 }));

      await service.cargarHistorial({ estado: 'entregado', desde: '2026-10-01T06:00:00.000Z', hasta: '2026-10-31T05:59:59.999Z' });

      const [endpoint, params] = api.get.calls.mostRecent().args as [string, HttpParams];
      expect(endpoint).toBe('/api/paqueteria/historico');
      expect(params.get('estado')).toBe('entregado');
      expect(params.get('desde')).toBe('2026-10-01T06:00:00.000Z');
      expect(params.get('hasta')).toBe('2026-10-31T05:59:59.999Z');
    });

    it('el historial sin periodo no manda fechas', async () => {
      api.get.and.returnValue(of({ items: [], totalCount: 0 }));

      await service.cargarHistorial({ estado: 'cancelado' });

      const params = api.get.calls.mostRecent().args[1] as HttpParams;
      expect(params.has('desde')).toBeFalse();
      expect(params.has('hasta')).toBeFalse();
    });

    it('recorre todas las páginas sin duplicar paquetes', async () => {
      const pagina1 = Array.from({ length: 100 }, (_, i) => paquete(`p${i}`));
      const pagina2 = [paquete('p99'), paquete('p100')];
      api.get.and.returnValues(of({ items: pagina1, totalCount: 101 }), of({ items: pagina2, totalCount: 101 }));

      await service.cargarEsperados();

      expect(api.get).toHaveBeenCalledTimes(2);
      expect(service.esperados.items().length).toBe(101);
    });

    it('una página vacía corta el recorrido aunque el total prometa más', async () => {
      api.get.and.returnValues(of({ items: [paquete('p1')], totalCount: 500 }), of({ items: [], totalCount: 500 }));

      await service.cargarEsperados();

      expect(api.get).toHaveBeenCalledTimes(2);
      expect(service.esperados.items().length).toBe(1);
    });

    it('ordena: esperados de hoy primero, en caseta el más antiguo primero, historial el más reciente primero', async () => {
      const manana = new Date(Date.now() + 2 * 86_400_000).toISOString();
      api.get.and.returnValues(
        of({ items: [paquete('futuro', { fechaEsperadaDesde: manana, fechaEsperadaHasta: manana }), paquete('hoy')], totalCount: 2 }),
        of({ items: [paquete('nuevo', { estado: 'recibido', recibidoEn: '2026-10-12T10:00:00Z' }), paquete('viejo', { estado: 'recibido', recibidoEn: '2026-10-05T10:00:00Z' })], totalCount: 2 }),
        of({ items: [paquete('a', { estado: 'entregado', entregadoEn: '2026-10-05T10:00:00Z' }), paquete('b', { estado: 'entregado', entregadoEn: '2026-10-09T10:00:00Z' })], totalCount: 2 })
      );

      await service.cargarEsperados();
      await service.cargarEnCaseta();
      await service.cargarHistorial({ estado: 'entregado' });

      expect(service.esperadosOrdenados().map(p => p.id)).toEqual(['hoy', 'futuro']);
      expect(service.enCasetaOrdenados().map(p => p.id)).toEqual(['viejo', 'nuevo']);
      expect(service.historialOrdenado().map(p => p.id)).toEqual(['b', 'a']);
    });
  });

  describe('errores y estado de carga', () => {
    it('si falla muestra el mensaje del backend y deja de cargar', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 403, error: { error: 'Se requiere rol de administrador o vigilancia' } })));

      await service.cargarEsperados();

      expect(service.esperados.error()).toBe('Se requiere rol de administrador o vigilancia');
      expect(service.esperados.cargando()).toBeFalse();
    });

    it('oculta el JSON técnico con un mensaje claro', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } })));

      await service.cargarEnCaseta();

      expect(service.enCaseta.error()).toBe('No se pudieron cargar los paquetes que están en caseta.');
    });

    it('fallar una lista no toca a las demás', async () => {
      spyOn(console, 'error');
      api.get.and.returnValues(throwError(() => ({ status: 500 })), of({ items: [paquete('p1', { estado: 'recibido' })], totalCount: 1 }));

      await service.cargarEsperados();
      await service.cargarEnCaseta();

      expect(service.esperados.error()).not.toBeNull();
      expect(service.enCaseta.error()).toBeNull();
      expect(service.enCaseta.items().length).toBe(1);
    });

    it('una respuesta lenta anterior no pisa la más reciente', async () => {
      const lenta = new Subject<any>();
      api.get.and.returnValues(lenta, of({ items: [paquete('nuevo')], totalCount: 1 }));

      const primera = service.cargarEsperados();
      await service.cargarEsperados();
      lenta.next({ items: [paquete('viejo')], totalCount: 1 });
      lenta.complete();
      await primera;

      expect(service.esperados.items().map(p => p.id)).toEqual(['nuevo']);
      expect(service.esperados.cargando()).toBeFalse();
    });

    it('al empezar a cargar limpia el error anterior', async () => {
      spyOn(console, 'error');
      api.get.and.returnValues(throwError(() => ({ status: 500 })), of({ items: [], totalCount: 0 }));

      await service.cargarEsperados();
      expect(service.esperados.error()).not.toBeNull();
      await service.cargarEsperados();

      expect(service.esperados.error()).toBeNull();
    });
  });

  describe('recibir', () => {
    it('un aviso recibido sale de esperados y entra en caseta', async () => {
      api.get.and.returnValues(of({ items: [paquete('p1'), paquete('p2')], totalCount: 2 }), of({ items: [], totalCount: 0 }));
      await service.cargarEsperados();
      await service.cargarEnCaseta();
      api.post.and.returnValue(of(paquete('p1', { estado: 'recibido', ubicacionAlmacen: 'Estante 2' })));

      const recibido = await service.recibir({ paqueteId: 'p1', ubicacionAlmacen: 'Estante 2' });

      const [endpoint, cuerpo, , servicio] = api.post.calls.mostRecent().args as [string, any, unknown, string];
      expect(endpoint).toBe('/api/paqueteria/recepcion');
      expect(cuerpo).toEqual({ paqueteId: 'p1', ubicacionAlmacen: 'Estante 2' });
      expect(servicio).toBe('visitas');
      expect(recibido.estado).toBe('recibido');
      expect(service.esperados.items().map(p => p.id)).toEqual(['p2']);
      expect(service.enCaseta.items().map(p => p.id)).toEqual(['p1']);
    });

    it('un paquete sin aviso entra en caseta y no toca esperados', async () => {
      api.get.and.returnValue(of({ items: [paquete('p2')], totalCount: 1 }));
      await service.cargarEsperados();
      api.post.and.returnValue(of(paquete('nuevo', { estado: 'recibido', esInesperado: true })));

      await service.recibir({ viviendaId: 33, destinatarioNombre: 'Ana', servicioNombre: 'Amazon' });

      expect(service.esperados.items().map(p => p.id)).toEqual(['p2']);
      expect(service.enCaseta.items().map(p => p.id)).toEqual(['nuevo']);
    });

    it('si falla no cambia las listas y deja el error a quien llamó', async () => {
      api.get.and.returnValue(of({ items: [paquete('p1')], totalCount: 1 }));
      await service.cargarEsperados();
      api.post.and.returnValue(throwError(() => ({ status: 409 })));

      await expectAsync(service.recibir({ paqueteId: 'p1' })).toBeRejected();

      expect(service.esperados.items().map(p => p.id)).toEqual(['p1']);
      expect(service.enCaseta.items().length).toBe(0);
    });
  });

  describe('entregar', () => {
    it('manda el nombre sin espacios sobrantes y saca el paquete de caseta', async () => {
      api.get.and.returnValue(of({ items: [paquete('p1', { estado: 'recibido' }), paquete('p2', { estado: 'recibido' })], totalCount: 2 }));
      await service.cargarEnCaseta();
      api.post.and.returnValue(of(paquete('p1', { estado: 'entregado' })));

      await service.entregar('p1', '  Angel Gómez ');

      const [endpoint, cuerpo] = api.post.calls.mostRecent().args as [string, any];
      expect(endpoint).toBe('/api/paqueteria/p1/entrega');
      expect(cuerpo).toEqual({ entregadoANombre: 'Angel Gómez' });
      expect(service.enCaseta.items().map(p => p.id)).toEqual(['p2']);
    });

    it('si falla el paquete sigue en caseta', async () => {
      api.get.and.returnValue(of({ items: [paquete('p1', { estado: 'recibido' })], totalCount: 1 }));
      await service.cargarEnCaseta();
      api.post.and.returnValue(throwError(() => ({ status: 500 })));

      await expectAsync(service.entregar('p1', 'Ana')).toBeRejected();

      expect(service.enCaseta.items().length).toBe(1);
    });
  });

  it('quitarDeListas saca un paquete que otra persona ya cambió', async () => {
    api.get.and.returnValues(of({ items: [paquete('p1')], totalCount: 1 }), of({ items: [paquete('p2', { estado: 'recibido' })], totalCount: 1 }));
    await service.cargarEsperados();
    await service.cargarEnCaseta();

    service.quitarDeListas('p1');
    service.quitarDeListas('p2');

    expect(service.esperados.items().length).toBe(0);
    expect(service.enCaseta.items().length).toBe(0);
  });

  describe('modo silencioso (actualización automática)', () => {
    it('actualiza la lista sin encender "cargando"', async () => {
      api.get.and.returnValue(of({ items: [paquete('p1')], totalCount: 1 }));

      const promesa = service.cargarEsperados(true);

      expect(service.esperados.cargando()).toBeFalse();
      await promesa;
      expect(service.esperados.items().length).toBe(1);
    });

    it('si falla, deja la lista como estaba y no muestra error', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(of({ items: [paquete('p1')], totalCount: 1 }));
      await service.cargarEsperados();
      api.get.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Fallo del servidor' } })));

      await service.cargarEsperados(true);

      expect(service.esperados.items().length).toBe(1);
      expect(service.esperados.error()).toBeNull();
      expect(service.esperados.cargando()).toBeFalse();
    });
  });
});
