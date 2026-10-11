import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { SubusuariosService } from './subusuarios.service';
import { ApiService } from './api.service';

describe('SubusuariosService (consulta por vivienda)', () => {
  let service: SubusuariosService;
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get']);
    TestBed.configureTestingModule({
      providers: [SubusuariosService, { provide: ApiService, useValue: api }]
    });
    service = TestBed.inject(SubusuariosService);
  });

  it('pide los sub-usuarios de la vivienda y los convierte al modelo interno', async () => {
    api.get.and.returnValue(of([
      { id: 'u1', nombre: 'Luis Prueba', email: 'luis@example.com', telefono: '55', parentesco: 'Familiar', estado: 'Activo', creado_en: null },
      { id: 'i1', nombre: 'Pendiente', email: 'ana@example.com', telefono: 'Pendiente', parentesco: 'Hijo/a', estado: 'Pendiente', creado_en: '2026-10-01T10:00:00Z' }
    ]));

    const lista = await service.listarPorVivienda(33);

    const [endpoint, params, , microservicio] = api.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
    expect(endpoint).toBe('/api/subusuarios/mis-subusuarios');
    expect(params.get('viviendaId')).toBe('33');
    expect(microservicio).toBe('usuarios');
    expect(lista.map(u => [u.id, u.activo])).toEqual([['u1', true], ['i1', false]]);
  });

  it('no toca el estado compartido de la pantalla del residente', async () => {
    api.get.and.returnValue(of([]));

    await service.listarPorVivienda(33);

    expect(service.items()).toEqual([]);
    expect(service.isLoading()).toBeFalse();
    expect(service.errorMessage()).toBeNull();
  });

  it('una respuesta vacía da una lista vacía y un fallo se propaga a quien llama', async () => {
    api.get.and.returnValue(of(null as any));
    expect(await service.listarPorVivienda(33)).toEqual([]);

    api.get.and.returnValue(throwError(() => ({ status: 500 })));
    await expectAsync(service.listarPorVivienda(33)).toBeRejected();
  });
});
