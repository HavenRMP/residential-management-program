import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { VigilantesService } from './vigilantes.service';
import { ApiService } from './api.service';

const vigilante = (id: string, activo = true) => ({
  id, nombre: 'Vigi', apellidos: id, telefono: '5512345678', email: `${id}@example.com`, activo, creadoEn: '2026-09-30T00:00:00Z'
});

describe('VigilantesService', () => {
  let service: VigilantesService;
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post', 'patch']);
    TestBed.configureTestingModule({
      providers: [VigilantesService, { provide: ApiService, useValue: api }]
    });
    service = TestBed.inject(VigilantesService);
  });

  it('lista los vigilantes del backend separando activos y dados de baja', async () => {
    api.get.and.returnValue(of({ items: [vigilante('a'), vigilante('b', false)], totalCount: 2 }));

    await service.listar();

    const [endpoint, params, , servicio] = api.get.calls.mostRecent().args as [string, HttpParams, unknown, string];
    expect(endpoint).toBe('/api/vigilantes');
    expect(params.get('page')).toBe('1');
    expect(servicio).toBe('usuarios');
    expect(service.activos().map(v => v.id)).toEqual(['a']);
    expect(service.inactivos().map(v => v.id)).toEqual(['b']);
  });

  it('pide páginas hasta que una llegue incompleta', async () => {
    const lote = (desde: number, n: number) => Array.from({ length: n }, (_, i) => vigilante(`v${desde + i}`));
    api.get.and.callFake(((_u: string, p: HttpParams) => of({ items: p.get('page') === '1' ? lote(0, 100) : lote(100, 5) })) as any);

    await service.listar();

    expect(api.get).toHaveBeenCalledTimes(2);
    expect(service.vigilantes().length).toBe(105);
  });

  it('expone el mensaje del backend si falla y conserva la lista anterior', async () => {
    api.get.and.returnValue(of({ items: [vigilante('a')] }));
    await service.listar();

    api.get.and.returnValue(throwError(() => ({ error: { error: 'Se requiere rol de administrador' } })));
    await service.listar();

    expect(service.errorMessage()).toBe('Se requiere rol de administrador');
    expect(service.vigilantes().length).toBe(1);
    expect(service.isLoading()).toBeFalse();
  });

  it('da de baja llamando al backend y actualiza la lista solo si responde bien', async () => {
    api.get.and.returnValue(of({ items: [vigilante('a')] }));
    await service.listar();
    api.patch.and.returnValue(of(undefined));

    await service.cambiarEstado('a', false);

    expect(api.patch.calls.mostRecent().args[0]).toBe('/api/vigilantes/a/baja');
    expect(service.vigilantes()[0].activo).toBeFalse();
  });

  it('reactiva con el endpoint de reactivar', async () => {
    api.get.and.returnValue(of({ items: [vigilante('a', false)] }));
    await service.listar();
    api.patch.and.returnValue(of(undefined));

    await service.cambiarEstado('a', true);

    expect(api.patch.calls.mostRecent().args[0]).toBe('/api/vigilantes/a/reactivar');
    expect(service.vigilantes()[0].activo).toBeTrue();
  });

  it('si el backend rechaza la baja no cambia el estado local', async () => {
    api.get.and.returnValue(of({ items: [vigilante('a')] }));
    await service.listar();
    api.patch.and.returnValue(throwError(() => ({ error: { error: 'Error al dar de baja al vigilante' } })));

    await expectAsync(service.cambiarEstado('a', false)).toBeRejected();

    expect(service.vigilantes()[0].activo).toBeTrue();
  });

  it('agrega al vigilante recién creado sin duplicarlo', async () => {
    api.get.and.returnValue(of({ items: [vigilante('a')] }));
    await service.listar();
    api.post.and.returnValue(of({ id: 'a', nombre: 'Nuevo', apellidos: 'X', email: 'n@example.com', telefono: '5512345678', creadoEn: '2026-09-30' }));

    await service.crear({ nombre: 'Nuevo', apellidos: 'X', email: 'N@Example.com', telefono: '5512345678', password: 'Prueba1234!' });

    expect(api.post.calls.mostRecent().args[1]).toEqual(jasmine.objectContaining({ email: 'n@example.com' }));
    expect(service.vigilantes().length).toBe(1);
  });
});
