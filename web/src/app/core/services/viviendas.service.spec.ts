import { TestBed } from '@angular/core/testing';
import { ViviendasService } from './viviendas.service';
import { ApiService } from './api.service';
import { CacheService } from './cache.service';
import { of } from 'rxjs';

describe('ViviendasService', () => {
  let service: ViviendasService;
  let mockApiService: jasmine.SpyObj<ApiService>;
  let cacheService: CacheService;

  beforeEach(() => {
    mockApiService = jasmine.createSpyObj('ApiService', ['get', 'post', 'put', 'delete']);
    cacheService = new CacheService();

    TestBed.configureTestingModule({
      providers: [
        ViviendasService,
        { provide: ApiService, useValue: mockApiService },
        { provide: CacheService, useValue: cacheService }
      ]
    });

    service = TestBed.inject(ViviendasService);
  });

  it('debería crearse correctamente', () => {
    expect(service).toBeTruthy();
  });

  it('debería construir el mapa de viviendas agrupadas por residente procesando en lotes', async () => {
    // 7 viviendas para probar que procesa más de un lote (chunkSize = 6)
    const mockViviendas = Array.from({ length: 7 }, (_, i) => ({
      id: i + 1,
      numeroCasa: `Casa ${100 + i}`,
      condominioId: 'cond-1'
    }));

    (mockApiService.get as jasmine.Spy).and.callFake((url: string): any => {
      if (url === '/api/viviendas') {
        return of(mockViviendas);
      }
      if (url === '/api/viviendas/1/residentes') {
        return of([{ id: 'res-1', nombre: 'Juan' }]);
      }
      if (url === '/api/viviendas/2/residentes') {
        return of([{ id: 'res-1', nombre: 'Juan' }, { id: 'res-2', nombre: 'Pedro' }]);
      }
      return of([]);
    });

    const mapa = await service.obtenerMapaViviendasPorResidente(true);

    expect(mapa.has('res-1')).toBeTrue();
    expect(mapa.get('res-1')?.length).toBe(2);
    expect(mapa.has('res-2')).toBeTrue();
    expect(mapa.get('res-2')?.length).toBe(1);

    const vivsJuan = await service.obtenerViviendasDeResidente('res-1');
    expect(vivsJuan.length).toBe(2);
  });
});
