import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, Subject, throwError } from 'rxjs';
import { VisitasVigilanciaService } from './visitas-vigilancia.service';
import { ApiService } from './api.service';
import { VisitaVigilancia } from '../models/visita.model';

const visitaBase: VisitaVigilancia = {
  id: 'v-1',
  viviendaId: 33,
  numeroCasa: 'PRUEBA-01',
  nombreVisitante: 'Juan',
  apellidosVisitante: 'Pérez',
  motivo: 'personal',
  numAcompanantes: 0,
  fechaLlegadaEsperada: '2026-10-01T15:00:00Z',
  vigenciaHasta: '2026-10-02T15:00:00Z',
  estado: 'programada'
};

describe('VisitasVigilanciaService', () => {
  let service: VisitasVigilanciaService;
  let mockApiService: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    mockApiService = jasmine.createSpyObj('ApiService', ['get', 'post']);

    TestBed.configureTestingModule({
      providers: [VisitasVigilanciaService, { provide: ApiService, useValue: mockApiService }]
    });

    service = TestBed.inject(VisitasVigilanciaService);
  });

  it('carga las visitas próximas y envía la búsqueda sin espacios sobrantes', async () => {
    mockApiService.get.and.returnValue(of({ items: [visitaBase], page: 1, totalCount: 1 }));

    await service.cargarProximas('  Perez ');

    const [endpoint, params, , servicio] = mockApiService.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
    expect(endpoint).toBe('/api/visitas/proximas');
    expect(params.get('busqueda')).toBe('Perez');
    expect(servicio).toBe('visitas');
    expect(service.items().length).toBe(1);
  });

  it('muestra las visitas de la más reciente a la más antigua aunque el backend las entregue al revés', async () => {
    mockApiService.get.and.returnValue(of({
      items: [
        { ...visitaBase, id: 'v-vieja', fechaLlegadaEsperada: '2026-10-01T08:00:00Z' },
        { ...visitaBase, id: 'v-nueva', fechaLlegadaEsperada: '2026-10-01T20:00:00Z' },
        { ...visitaBase, id: 'v-media', fechaLlegadaEsperada: '2026-10-01T14:00:00Z' }
      ],
      totalCount: 3
    }));

    await service.cargarProximas();

    expect(service.items().map(v => v.id)).toEqual(['v-nueva', 'v-media', 'v-vieja']);
  });

  it('no envía el parámetro busqueda cuando está vacío', async () => {
    mockApiService.get.and.returnValue(of({ items: [], totalCount: 0 }));

    await service.cargarProximas('   ');

    const params = mockApiService.get.calls.mostRecent().args[1] as HttpParams;
    expect(params.has('busqueda')).toBeFalse();
  });

  it('expone el mensaje del backend cuando falla la carga', async () => {
    mockApiService.get.and.returnValue(throwError(() => ({ error: { error: 'Se requiere rol de administrador o vigilancia' } })));

    await service.cargarProximas();

    expect(service.errorMessage()).toBe('Se requiere rol de administrador o vigilancia');
  });

  it('codifica el código al validarlo', async () => {
    mockApiService.get.and.returnValue(of(visitaBase));

    await service.validarCodigo(' AB/12 ');

    expect(mockApiService.get.calls.mostRecent().args[0]).toBe('/api/visitas/codigo/AB%2F12');
  });

  it('completa el estado vacío de la validación con la visita de la lista de próximas', async () => {
    mockApiService.get.and.returnValue(of({ items: [{ ...visitaBase, estado: 'programada', vehiculoPlacas: 'ABC-123' }], totalCount: 1 }));
    await service.cargarProximas();
    mockApiService.get.and.returnValue(of({ ...visitaBase, estado: '', vigenciaHasta: '0001-01-01T00:00:00+00:00' }));

    const validada = await service.validarCodigo('AB12');

    expect(validada.estado).toBe('programada');
    expect(validada.vehiculoPlacas).toBe('ABC-123');
  });

  it('si la visita no está en la lista de próximas deja el estado vacío', async () => {
    mockApiService.get.and.returnValue(of({ ...visitaBase, estado: '' }));

    const validada = await service.validarCodigo('AB12');

    expect(validada.estado).toBe('');
  });

  it('actualiza la visita en la lista al registrar entrada y salida', async () => {
    mockApiService.get.and.returnValue(of({ items: [visitaBase], totalCount: 1 }));
    await service.cargarProximas();

    mockApiService.post.and.returnValue(of({ ...visitaBase, estado: 'en_curso', horaEntrada: '2026-10-01T15:05:00Z' }));
    await service.registrarEntrada('v-1');
    expect(mockApiService.post.calls.mostRecent().args[0]).toBe('/api/visitas/v-1/entrada');
    expect(service.items()[0].estado).toBe('en_curso');

    mockApiService.post.and.returnValue(of({ ...visitaBase, estado: 'finalizada', horaSalida: '2026-10-01T16:00:00Z' }));
    await service.registrarSalida('v-1');
    expect(mockApiService.post.calls.mostRecent().args[0]).toBe('/api/visitas/v-1/salida');
    expect(service.items()[0].estado).toBe('finalizada');
  });

  it('no borra estado, casa ni vigencia cuando el backend responde la entrada con campos vacíos', async () => {
    mockApiService.get.and.returnValue(of({ items: [visitaBase], totalCount: 1 }));
    await service.cargarProximas();

    // Respuesta real observada: estado '', numeroCasa '', vigenciaHasta 0001-01-01, viviendaId 0
    mockApiService.post.and.returnValue(of({
      ...visitaBase, estado: '', numeroCasa: '', viviendaId: 0, horaEntrada: '2026-10-01T15:05:00Z'
    } as unknown as VisitaVigilancia));
    const resultado = await service.registrarEntrada('v-1');

    expect(resultado.estado).toBe('en_curso');
    expect(service.items()[0].estado).toBe('en_curso');
    expect(service.items()[0].numeroCasa).toBe('PRUEBA-01');
    expect(service.items()[0].viviendaId).toBe(33);
    expect(service.items()[0].horaEntrada).toBe('2026-10-01T15:05:00Z');
  });

  it('envía las placas en mayúsculas al registrar la entrada y nada si no se capturan', async () => {
    mockApiService.get.and.returnValue(of({ items: [visitaBase], totalCount: 1 }));
    await service.cargarProximas();
    mockApiService.post.and.returnValue(of({ ...visitaBase, estado: 'en_curso' }));

    await service.registrarEntrada('v-1', '  abc-123 ');
    expect(mockApiService.post.calls.mostRecent().args[1]).toEqual({ vehiculoPlacas: 'ABC-123' });

    await service.registrarEntrada('v-1', '   ');
    expect(mockApiService.post.calls.mostRecent().args[1]).toEqual({});

    await service.registrarEntrada('v-1');
    expect(mockApiService.post.calls.mostRecent().args[1]).toEqual({});
  });

  it('descarta la respuesta atrasada de una búsqueda anterior', async () => {
    const lenta = new Subject<any>();
    mockApiService.get.and.returnValues(lenta.asObservable(), of({ items: [{ ...visitaBase, id: 'v-2' }], totalCount: 1 }));

    const primera = service.cargarProximas('Pe');
    const segunda = service.cargarProximas('Perez');
    await segunda;
    lenta.next({ items: [visitaBase], totalCount: 1 });
    lenta.complete();
    await primera;

    expect(service.items().map(v => v.id)).toEqual(['v-2']);
    expect(service.isLoading()).toBeFalse();
  });
});
