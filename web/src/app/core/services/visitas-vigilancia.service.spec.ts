import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, throwError } from 'rxjs';
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

  it('carga las visitas de hoy y envía la búsqueda sin espacios sobrantes', async () => {
    mockApiService.get.and.returnValue(of({ items: [visitaBase], page: 1, totalCount: 1 }));

    await service.cargarHoy('  Perez ');

    const [endpoint, params, , servicio] = mockApiService.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
    expect(endpoint).toBe('/api/visitas/hoy');
    expect(params.get('busqueda')).toBe('Perez');
    expect(servicio).toBe('visitas');
    expect(service.items().length).toBe(1);
  });

  it('no envía el parámetro busqueda cuando está vacío', async () => {
    mockApiService.get.and.returnValue(of({ items: [], totalCount: 0 }));

    await service.cargarHoy('   ');

    const params = mockApiService.get.calls.mostRecent().args[1] as HttpParams;
    expect(params.has('busqueda')).toBeFalse();
  });

  it('expone el mensaje del backend cuando falla la carga', async () => {
    mockApiService.get.and.returnValue(throwError(() => ({ error: { error: 'Se requiere rol de administrador o vigilancia' } })));

    await service.cargarHoy();

    expect(service.errorMessage()).toBe('Se requiere rol de administrador o vigilancia');
  });

  it('codifica el código al validarlo', async () => {
    mockApiService.get.and.returnValue(of(visitaBase));

    await service.validarCodigo(' AB/12 ');

    expect(mockApiService.get.calls.mostRecent().args[0]).toBe('/api/visitas/codigo/AB%2F12');
  });

  it('actualiza la visita en la lista al registrar entrada y salida', async () => {
    mockApiService.get.and.returnValue(of({ items: [visitaBase], totalCount: 1 }));
    await service.cargarHoy();

    mockApiService.post.and.returnValue(of({ ...visitaBase, estado: 'en_curso', horaEntrada: '2026-10-01T15:05:00Z' }));
    await service.registrarEntrada('v-1');
    expect(mockApiService.post.calls.mostRecent().args[0]).toBe('/api/visitas/v-1/entrada');
    expect(service.items()[0].estado).toBe('en_curso');

    mockApiService.post.and.returnValue(of({ ...visitaBase, estado: 'finalizada', horaSalida: '2026-10-01T16:00:00Z' }));
    await service.registrarSalida('v-1');
    expect(mockApiService.post.calls.mostRecent().args[0]).toBe('/api/visitas/v-1/salida');
    expect(service.items()[0].estado).toBe('finalizada');
  });
});
