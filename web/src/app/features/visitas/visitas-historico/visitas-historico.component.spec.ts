import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { signal } from '@angular/core';
import { VisitasHistoricoComponent } from './visitas-historico.component';
import { VisitasHistoricoService } from '../../../core/services/visitas-historico.service';
import { ViviendasService } from '../../../core/services/viviendas.service';

const lote = (desde: number, cantidad: number) =>
  Array.from({ length: cantidad }, (_, i) => ({ id: desde + i, numeroCasa: `Casa ${desde + i}` }));

describe('VisitasHistoricoComponent (viviendas del filtro)', () => {
  let listar: jasmine.Spy;

  function crear() {
    TestBed.configureTestingModule({
      imports: [VisitasHistoricoComponent],
      providers: [
        provideRouter([]),
        {
          provide: VisitasHistoricoService,
          useValue: {
            PAGE_SIZE: 20, items: signal([]), totalCount: signal(0), page: signal(1),
            isLoading: signal(false), errorMessage: signal(null), cargar: jasmine.createSpy('cargar')
          }
        },
        { provide: ViviendasService, useValue: { listar } }
      ]
    });
    return TestBed.createComponent(VisitasHistoricoComponent).componentInstance;
  }

  it('pide páginas hasta que una llegue incompleta y junta todas las viviendas', async () => {
    listar = jasmine.createSpy('listar').and.callFake(async (pagina: number) =>
      pagina === 1 ? lote(1, 100) : pagina === 2 ? lote(101, 100) : lote(201, 30)
    );
    const componente = crear();

    await componente.ngOnInit();

    expect(listar).toHaveBeenCalledTimes(3);
    expect(componente.viviendas().length).toBe(230);
  });

  it('no repite viviendas si la API ignora la página', async () => {
    listar = jasmine.createSpy('listar').and.callFake(async () => lote(1, 100));
    const componente = crear();

    await componente.ngOnInit();

    expect(listar).toHaveBeenCalledTimes(2);
    expect(componente.viviendas().length).toBe(100);
  });

  it('con pocas viviendas hace una sola petición', async () => {
    listar = jasmine.createSpy('listar').and.callFake(async () => lote(1, 5));
    const componente = crear();

    await componente.ngOnInit();

    expect(listar).toHaveBeenCalledTimes(1);
    expect(componente.viviendas().length).toBe(5);
  });
});
