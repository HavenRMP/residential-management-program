import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { VisitasHistoricoService } from './visitas-historico.service';
import { ApiService } from './api.service';

describe('VisitasHistoricoService', () => {
  let service: VisitasHistoricoService;
  let mockApiService: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    mockApiService = jasmine.createSpyObj('ApiService', ['get']);
    TestBed.configureTestingModule({
      providers: [VisitasHistoricoService, { provide: ApiService, useValue: mockApiService }]
    });
    service = TestBed.inject(VisitasHistoricoService);
  });

  it('envía solo los filtros con valor', async () => {
    mockApiService.get.and.returnValue(of({ items: [], totalCount: 0 }));

    await service.cargar({ desde: '2026-10-01T06:00:00.000Z', estado: 'finalizada', viviendaId: 33 }, 2);

    const [endpoint, params] = mockApiService.get.calls.mostRecent().args as [string, HttpParams];
    expect(endpoint).toBe('/api/visitas/historico');
    expect(params.get('page')).toBe('2');
    expect(params.get('desde')).toBe('2026-10-01T06:00:00.000Z');
    expect(params.get('estado')).toBe('finalizada');
    expect(params.get('viviendaId')).toBe('33');
    expect(params.has('hasta')).toBeFalse();
  });

  it('expone el mensaje del backend cuando falla', async () => {
    mockApiService.get.and.returnValue(throwError(() => ({ error: { error: "La fecha 'desde' no puede ser posterior a la fecha 'hasta'." } })));

    await service.cargar();

    expect(service.errorMessage()).toBe("La fecha 'desde' no puede ser posterior a la fecha 'hasta'.");
  });

  it('explica con claridad cuando la cuenta no tiene permiso para consultar el historial (403)', async () => {
    mockApiService.get.and.returnValue(throwError(() => ({ status: 403, error: { error: 'Se requiere rol de administrador para consultar el histórico' } })));

    await service.cargar();

    expect(service.errorMessage()).toBe('Tu cuenta no tiene permiso para consultar el historial de visitas.');
  });
});
