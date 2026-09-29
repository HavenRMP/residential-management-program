import { TestBed } from '@angular/core/testing';
import { CacheService } from './cache.service';

describe('CacheService', () => {
  let service: CacheService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CacheService]
    });
    service = TestBed.inject(CacheService);
  });

  it('debe crearse correctamente', () => {
    expect(service).toBeTruthy();
  });

  it('debe almacenar y recuperar un valor antes de que expire', () => {
    service.set('test_key', { nombre: 'Vivienda 101' }, 'viviendas', 5000);
    const cached = service.get<{ nombre: string }>('test_key');
    expect(cached).toEqual({ nombre: 'Vivienda 101' });
  });

  it('debe retornar null cuando la clave no existe', () => {
    expect(service.get('inexistente')).toBeNull();
  });

  it('debe retornar null y eliminar la entrada cuando ha expirado el TTL', (done) => {
    service.set('expiring_key', 'valor temporal', 'general', 50); // 50ms TTL
    expect(service.get('expiring_key')).toBe('valor temporal');

    setTimeout(() => {
      expect(service.get('expiring_key')).toBeNull();
      done();
    }, 70);
  });

  it('debe invalidar una clave específica', () => {
    service.set('k1', 'val1', 'viviendas');
    service.set('k2', 'val2', 'viviendas');

    service.invalidate('k1');

    expect(service.get('k1')).toBeNull();
    expect(service.get('k2')).toBe('val2');
  });

  it('debe invalidar todas las entradas asociadas a un tag con invalidateTag', () => {
    service.set('v1', { casa: '1' }, 'viviendas');
    service.set('v2', { casa: '2' }, 'viviendas');
    service.set('r1', { nombre: 'Juan' }, 'residentes');

    service.invalidateTag('viviendas');

    expect(service.get('v1')).toBeNull();
    expect(service.get('v2')).toBeNull();
    expect(service.get('r1')).toEqual({ nombre: 'Juan' });
  });

  describe('invalidateForEndpoint', () => {
    it('debe invalidar tag viviendas al mutar endpoint de vivienda', () => {
      service.set('v_list', ['casa 1'], 'viviendas');
      service.set('r_list', ['residente 1'], 'residentes');

      service.invalidateForEndpoint('/api/viviendas/5');

      expect(service.get('v_list')).toBeNull();
      expect(service.get('r_list')).toEqual(['residente 1']);
    });

    it('debe invalidar tag residentes y viviendas al registrar usuario o residente', () => {
      service.set('v_list', ['casa 1'], 'viviendas');
      service.set('r_list', ['residente 1'], 'residentes');

      service.invalidateForEndpoint('/api/auth/register');

      expect(service.get('r_list')).toBeNull();
      expect(service.get('v_list')).toBeNull();
    });

    it('debe invalidar tag avisos al mutar endpoint de avisos', () => {
      service.set('a_list', ['aviso 1'], 'avisos');
      service.set('v_list', ['casa 1'], 'viviendas');

      service.invalidateForEndpoint('/api/avisos/123');

      expect(service.get('a_list')).toBeNull();
      expect(service.get('v_list')).toEqual(['casa 1']);
    });

    it('debe invalidar tag condominios al mutar endpoint de condominio', () => {
      service.set('c_list', ['condo 1'], 'condominios');

      service.invalidateForEndpoint('/api/condominios/update');

      expect(service.get('c_list')).toBeNull();
    });
  });

  it('debe vaciar toda la caché con clear()', () => {
    service.set('a', 1, 'tag1');
    service.set('b', 2, 'tag2');

    service.clear();

    expect(service.get('a')).toBeNull();
    expect(service.get('b')).toBeNull();
  });
});
