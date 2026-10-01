import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { VisitasProgramadasService } from './visitas-programadas.service';
import { ApiService } from './api.service';

const visita = (id: string, llegada: string) => ({ id, fechaLlegadaEsperada: llegada, estado: 'programada' });

describe('VisitasProgramadasService', () => {
  let service: VisitasProgramadasService;
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get']);
    TestBed.configureTestingModule({
      providers: [VisitasProgramadasService, { provide: ApiService, useValue: api }]
    });
    service = TestBed.inject(VisitasProgramadasService);
  });

  it('pide las programadas desde este momento y las ordena de la más próxima a la más lejana', async () => {
    api.get.and.returnValue(of({
      items: [visita('c', '2026-10-05T10:00:00Z'), visita('a', '2026-10-02T10:00:00Z'), visita('b', '2026-10-03T10:00:00Z')],
      totalCount: 3
    }));

    await service.cargar();

    const [endpoint, params] = api.get.calls.mostRecent().args as [string, HttpParams];
    expect(endpoint).toBe('/api/visitas/historico');
    expect(params.get('estado')).toBe('programada');
    expect(isNaN(Date.parse(params.get('desde')!))).toBeFalse();
    expect(service.items().map(v => v.id)).toEqual(['a', 'b', 'c']);
  });

  it('recorre todas las páginas sin duplicar visitas', async () => {
    api.get.and.returnValues(
      of({ items: [visita('b', '2026-10-03T10:00:00Z'), visita('c', '2026-10-05T10:00:00Z')], totalCount: 3 }),
      of({ items: [visita('a', '2026-10-02T10:00:00Z'), visita('b', '2026-10-03T10:00:00Z')], totalCount: 3 })
    );

    await service.cargar();

    expect(api.get).toHaveBeenCalledTimes(2);
    expect(service.items().map(v => v.id)).toEqual(['a', 'b', 'c']);
  });

  it('expone el mensaje del backend cuando falla', async () => {
    api.get.and.returnValue(throwError(() => ({ error: { error: 'Sin permiso.' } })));

    await service.cargar();

    expect(service.errorMessage()).toBe('Sin permiso.');
    expect(service.isLoading()).toBeFalse();
  });
});
