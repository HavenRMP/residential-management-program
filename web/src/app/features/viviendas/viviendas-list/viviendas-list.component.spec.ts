import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { ViviendasListComponent } from './viviendas-list.component';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { ResidentesService } from '../../../core/services/residentes.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { Vivienda, ViviendaConResidentes } from '../../../core/models/vivienda.model';

const viviendas: Vivienda[] = [
  { id: 1, numeroCasa: 'A-12', tipo: 'Casa' },
  { id: 2, numeroCasa: 'B-07', tipo: 'Casa' },
  { id: 3, numeroCasa: 'C-30', tipo: 'Departamento' }
];

const casas: ViviendaConResidentes[] = [
  { id: 1, numeroCasa: 'A-12', tipo: 'Casa', totalResidentes: 2, estaOcupada: true, residentes: [] },
  { id: 2, numeroCasa: 'B-07', tipo: 'Casa', totalResidentes: 0, estaOcupada: false, residentes: [] }
];

describe('ViviendasListComponent (ocupación)', () => {
  let fixture: ComponentFixture<ViviendasListComponent>;
  let component: ViviendasListComponent;
  let directorio: { casas: ReturnType<typeof signal<ViviendaConResidentes[]>>; isLoading: ReturnType<typeof signal<boolean>>; cargar: jasmine.Spy };
  let vivienda: string | null;

  const filas = () => Array.from(fixture.nativeElement.querySelectorAll('tbody tr') as NodeListOf<HTMLElement>);
  const textoFila = (i: number) => filas()[i].textContent!.replace(/\s+/g, ' ');

  async function crear() {
    fixture = TestBed.createComponent(ViviendasListComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    vivienda = null;
    directorio = {
      casas: signal(casas),
      isLoading: signal(false),
      cargar: jasmine.createSpy('cargar').and.returnValue(Promise.resolve())
    };
    TestBed.configureTestingModule({
      imports: [ViviendasListComponent],
      providers: [
        provideRouter([]),
        {
          provide: ViviendasService,
          useValue: { listar: () => Promise.resolve(viviendas), obtenerResidentesVivienda: () => Promise.resolve([]) }
        },
        { provide: ResidentesService, useValue: { listar: () => Promise.resolve([]) } },
        {
          provide: CondominiosService,
          useValue: {
            condominioActual: signal({ id: 'c1', nombre: 'Haven' }),
            listar: () => Promise.resolve([]),
            cargarCondominioUsuario: () => Promise.resolve()
          }
        },
        { provide: DirectorioCasasService, useValue: directorio },
        { provide: ActivatedRoute, useFactory: () => ({ snapshot: { queryParamMap: { get: () => vivienda, has: () => vivienda !== null } } }) }
      ]
    });
  });

  it('muestra si cada vivienda está ocupada (con sus residentes) o disponible', async () => {
    await crear();

    expect(textoFila(0)).toContain('Ocupada');
    expect(textoFila(0)).toContain('2 residentes');
    expect(textoFila(1)).toContain('Disponible');
    expect(textoFila(1)).not.toContain('residente');
  });

  it('mientras llega la ocupación muestra un marcador y no afirma nada', async () => {
    directorio.casas.set([]);
    directorio.isLoading.set(true);
    await crear();

    expect(fixture.nativeElement.querySelectorAll('tbody [aria-label="Cargando ocupación"]').length).toBe(3);
    expect(textoFila(0)).not.toContain('Disponible');
  });

  it('si no se pudo consultar la ocupación deja un guion en vez de decir disponible', async () => {
    directorio.casas.set([]);
    await crear();

    expect(textoFila(0)).not.toContain('Disponible');
    expect(textoFila(0)).toContain('—');
  });

  it('filtra por ocupadas y por disponibles', async () => {
    await crear();

    component.onOcupacionChange('ocupadas');
    fixture.detectChanges();
    expect(filas().length).toBe(1);
    expect(textoFila(0)).toContain('A-12');

    component.onOcupacionChange('disponibles');
    fixture.detectChanges();
    expect(filas().length).toBe(1);
    expect(textoFila(0)).toContain('B-07');
  });

  it('el enlace ?vivienda=ID abre el detalle de esa vivienda', async () => {
    vivienda = '2';
    await crear();

    expect(component.isDetalleOpen()).toBeTrue();
    expect(component.viviendaSeleccionada()?.numeroCasa).toBe('B-07');
  });

  it('un enlace con una vivienda que no existe no abre nada', async () => {
    vivienda = '999';
    const router = TestBed.inject(Router);
    spyOn(router, 'navigate').and.returnValue(Promise.resolve(true));
    await crear();

    expect(component.isDetalleOpen()).toBeFalse();
  });
});
