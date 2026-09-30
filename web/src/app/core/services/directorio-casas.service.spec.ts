import { TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, Subject, throwError } from 'rxjs';
import { DirectorioCasasService } from './directorio-casas.service';
import { ApiService } from './api.service';

const casa = (id: number, numeroCasa: string, residentes: any[] = []) => ({
  id, numeroCasa, tipo: 'Casa', totalResidentes: residentes.length, estaOcupada: residentes.length > 0, residentes
});
const lote = (desde: number, cantidad: number) =>
  Array.from({ length: cantidad }, (_, i) => casa(desde + i, `Casa ${desde + i}`));

describe('DirectorioCasasService', () => {
  let service: DirectorioCasasService;
  let get: jasmine.Spy;

  function crear(respuestas: (pagina: number) => any) {
    get = jasmine.createSpy('get').and.callFake((_url: string, params: HttpParams) => {
      const r = respuestas(Number(params.get('page')));
      return r instanceof Subject ? r.asObservable() : of(r);
    });
    TestBed.configureTestingModule({
      providers: [DirectorioCasasService, { provide: ApiService, useValue: { get } }]
    });
    service = TestBed.inject(DirectorioCasasService);
  }

  it('consulta el endpoint de viviendas con residentes y normaliza los datos', async () => {
    crear(() => ({
      items: [casa(1, 'B-02'), casa(2, 'A-10', [{ id: 'r1', nombre: 'Ana', apellidos: 'López', telefono: '' }])],
      totalCount: 2
    }));

    await service.cargar();

    expect(get.calls.mostRecent().args[0]).toBe('/api/viviendas/con-residentes');
    // ordenadas por número de casa y con el teléfono vacío convertido en null
    expect(service.casas().map(c => c.numeroCasa)).toEqual(['A-10', 'B-02']);
    expect(service.casas()[0].residentes[0].telefono).toBeNull();
  });

  it('pide páginas hasta que una llegue incompleta', async () => {
    crear(pagina => ({ items: pagina === 1 ? lote(1, 100) : lote(101, 30) }));

    await service.cargar();

    expect(get).toHaveBeenCalledTimes(2);
    expect(service.casas().length).toBe(130);
  });

  it('no repite casas si la API ignora la página', async () => {
    crear(() => ({ items: lote(1, 100) }));

    await service.cargar();

    expect(get).toHaveBeenCalledTimes(2);
    expect(service.casas().length).toBe(100);
  });

  it('no vuelve a consultar una vez cargado, salvo que se fuerce', async () => {
    crear(() => ({ items: lote(1, 3) }));

    await service.cargar();
    await service.cargar();
    expect(get).toHaveBeenCalledTimes(1);

    await service.cargar(true);
    expect(get).toHaveBeenCalledTimes(2);
  });

  it('las cargas simultáneas comparten una sola petición', async () => {
    const pendiente = new Subject<any>();
    crear(() => pendiente);

    const a = service.cargar();
    const b = service.cargar();
    pendiente.next({ items: lote(1, 2) });
    pendiente.complete();
    await Promise.all([a, b]);

    expect(get).toHaveBeenCalledTimes(1);
  });

  it('expone el mensaje del backend si falla y permite reintentar', async () => {
    get = jasmine.createSpy('get').and.returnValue(throwError(() => ({ error: { error: 'Se requiere rol de administrador o vigilancia' } })));
    TestBed.configureTestingModule({ providers: [DirectorioCasasService, { provide: ApiService, useValue: { get } }] });
    service = TestBed.inject(DirectorioCasasService);

    await service.cargar();
    expect(service.errorMessage()).toBe('Se requiere rol de administrador o vigilancia');
    expect(service.isLoading()).toBeFalse();

    await service.cargar();
    expect(get).toHaveBeenCalledTimes(2);
  });

  it('encuentra los residentes de una casa por su número sin importar mayúsculas', async () => {
    crear(() => ({ items: [casa(1, 'A-10', [{ id: 'r1', nombre: 'Ana', apellidos: 'López', telefono: '5511' }])] }));
    await service.cargar();

    expect(service.residentesDeCasa('a-10').map(r => r.nombre)).toEqual(['Ana']);
    expect(service.residentesDeCasa('Z-99')).toEqual([]);
  });
});
