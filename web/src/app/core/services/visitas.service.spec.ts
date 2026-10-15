import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { VisitasService } from './visitas.service';
import { ApiService } from './api.service';
import { Visita } from '../models/visita.model';

const visitaBase: Visita = {
  id: 'v-1',
  viviendaId: 33,
  numeroCasa: 'PRUEBA-01',
  nombreVisitante: 'Juan',
  apellidosVisitante: 'Pérez',
  motivo: 'personal',
  numAcompanantes: 0,
  fechaLlegadaEsperada: '2026-10-01T15:00:00Z',
  vigenciaHasta: '2026-10-02T15:00:00Z',
  codigo: 'ABC123',
  estado: 'programada',
  creadoEn: '2026-09-30T10:00:00Z'
};

describe('VisitasService', () => {
  let service: VisitasService;
  let mockApiService: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    mockApiService = jasmine.createSpyObj('ApiService', ['get', 'post', 'put', 'delete']);

    TestBed.configureTestingModule({
      providers: [VisitasService, { provide: ApiService, useValue: mockApiService }]
    });

    service = TestBed.inject(VisitasService);
  });

  it('carga las visitas paginadas y envía el estado como filtro', async () => {
    mockApiService.get.and.returnValue(of({ items: [visitaBase], page: 2, pageSize: 10, totalCount: 11 }));

    await service.cargar('programada', 2);

    const [endpoint, params, , servicio] = mockApiService.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
    expect(endpoint).toBe('/api/visitas/mis-visitas');
    expect(params.get('page')).toBe('2');
    expect(params.get('estado')).toBe('programada');
    expect(servicio).toBe('visitas');
    expect(service.items().length).toBe(1);
    expect(service.totalCount()).toBe(11);
    expect(service.page()).toBe(2);
  });

  it('expone el mensaje del backend cuando falla la carga', async () => {
    mockApiService.get.and.returnValue(throwError(() => ({ error: { error: 'Token invalido' } })));

    await service.cargar();

    expect(service.errorMessage()).toBe('Token invalido');
    expect(service.isLoading()).toBeFalse();
  });

  it('marca la visita como cancelada localmente tras cancelar', async () => {
    mockApiService.get.and.returnValue(of({ items: [visitaBase], totalCount: 1 }));
    mockApiService.post.and.returnValue(of(undefined));
    await service.cargar();

    await service.cancelar('v-1');

    expect(mockApiService.post.calls.mostRecent().args[0]).toBe('/api/visitas/v-1/cancelar');
    expect(service.items()[0].estado).toBe('cancelada');
  });

  it('actualiza solo los campos enviados y conserva el resto de la visita', async () => {
    mockApiService.get.and.returnValue(of({ items: [visitaBase], totalCount: 1 }));
    mockApiService.put.and.returnValue(of({ ...visitaBase, nombreVisitante: 'Carlos' }));
    await service.cargar();

    await service.actualizar('v-1', { nombreVisitante: 'Carlos' });

    expect(mockApiService.put.calls.mostRecent().args[1]).toEqual({ nombreVisitante: 'Carlos' });
    expect(service.items()[0].nombreVisitante).toBe('Carlos');
    expect(service.items()[0].codigo).toBe('ABC123');
  });

  describe('modo silencioso (actualización automática)', () => {
    it('actualiza la lista sin encender "cargando"', async () => {
      mockApiService.get.and.returnValue(of({ items: [visitaBase], totalCount: 1, page: 1 }));

      const promesa = service.cargar(null, 1, true);

      expect(service.isLoading()).toBeFalse();
      await promesa;
      expect(service.items().length).toBe(1);
    });

    it('si falla, deja la lista como estaba y no muestra error', async () => {
      spyOn(console, 'error');
      mockApiService.get.and.returnValue(of({ items: [visitaBase], totalCount: 1, page: 1 }));
      await service.cargar();
      mockApiService.get.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Fallo del servidor' } })));

      await service.cargar(null, 1, true);

      expect(service.items().length).toBe(1);
      expect(service.errorMessage()).toBeNull();
      expect(service.isLoading()).toBeFalse();
    });
  });
});
