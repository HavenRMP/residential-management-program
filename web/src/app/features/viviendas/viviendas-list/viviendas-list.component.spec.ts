import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { ViviendasListComponent } from './viviendas-list.component';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { ResidentesService } from '../../../core/services/residentes.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { SubusuariosService } from '../../../core/services/subusuarios.service';
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
          useValue: { listar: () => Promise.resolve(viviendas), obtenerResidentesVivienda: () => Promise.resolve([]), obtenerViviendasDeResidente: () => Promise.resolve([]) }
        },
        { provide: ResidentesService, useValue: { listar: () => Promise.resolve([]) } },
        { provide: SubusuariosService, useValue: { MAX_SUBUSUARIOS: 2, listarPorVivienda: () => Promise.resolve([]) } },
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

  it('los selectores de tipo, ocupación y viviendas por página tienen nombre accesible', async () => {
    await crear();

    const nombres = Array.from(fixture.nativeElement.querySelectorAll('select') as NodeListOf<HTMLSelectElement>).map(s => s.getAttribute('aria-label'));

    expect(nombres).toEqual(['Filtrar por tipo', 'Filtrar por ocupación', 'Viviendas por página']);
  });

  describe('abrir el residente desde el detalle de la vivienda', () => {
    const titular = { id: 'r1', nombre: 'Aisha', apellidos: 'Sánchez', email: 'aisha@example.com', telefono: '4151110993', rol: 'Residente' };
    const otraCasa: Vivienda = { id: 9, numeroCasa: 'Z-9', tipo: 'Casa' };
    const asideResidente = () => fixture.nativeElement.querySelector('aside[aria-labelledby="detalle-residente-title"]') as HTMLElement | null;

    async function abrirVivienda(): Promise<void> {
      await crear();
      component.abrirDetalle(viviendas[0]);
      fixture.detectChanges();
      await fixture.whenStable();
      fixture.detectChanges();
    }

    it('al tocar al residente se abre su detalle encima, con todas sus viviendas, y el de la vivienda queda inerte', async () => {
      (TestBed.inject(ViviendasService) as any).obtenerViviendasDeResidente = jasmine.createSpy('obtenerViviendasDeResidente').and.resolveTo([viviendas[0], otraCasa]);
      await abrirVivienda();
      expect(asideResidente()).toBeNull();

      await component.abrirResidenteCruzado(titular);
      fixture.detectChanges();
      await fixture.whenStable();
      fixture.detectChanges();

      expect(component.residenteCruzado()?.viviendas.map(v => v.id)).toEqual([1, 9]);
      expect(asideResidente()).not.toBeNull();
      expect((fixture.nativeElement.querySelector('app-viviendas-detalle') as HTMLElement).hasAttribute('inert')).toBeTrue();
    });

    it('si no se pueden consultar todas las viviendas, muestra al menos aquella desde la que se llegó', async () => {
      (TestBed.inject(ViviendasService) as any).obtenerViviendasDeResidente = jasmine.createSpy().and.rejectWith({ status: 500 });
      await abrirVivienda();

      await component.abrirResidenteCruzado(titular);

      expect(component.residenteCruzado()?.viviendas.map(v => v.id)).toEqual([1]);
    });

    it('la flecha regresa a la vivienda, quita al residente y devuelve el foco a su tarjeta', async () => {
      (TestBed.inject(ViviendasService) as any).obtenerViviendasDeResidente = jasmine.createSpy().and.resolveTo([viviendas[0]]);
      (TestBed.inject(ViviendasService) as any).obtenerResidentesVivienda = () => Promise.resolve([titular]);
      await abrirVivienda();
      await component.abrirResidenteCruzado(titular);
      fixture.detectChanges();
      await fixture.whenStable();
      fixture.detectChanges();

      (asideResidente()!.querySelector('[data-foco-inicial]') as HTMLButtonElement).click();
      fixture.detectChanges();
      await fixture.whenStable();
      fixture.detectChanges();

      expect(component.residenteCruzado()).toBeNull();
      expect(component.isDetalleOpen()).toBeTrue();
      expect(asideResidente()).toBeNull();
      expect(document.activeElement).toBe(fixture.nativeElement.querySelector('[data-origen-detalle="residente"]'));
    });

    it('Escape con el residente encima solo lo quita: el detalle de la vivienda sigue abierto', async () => {
      (TestBed.inject(ViviendasService) as any).obtenerViviendasDeResidente = jasmine.createSpy().and.resolveTo([viviendas[0]]);
      await abrirVivienda();
      await component.abrirResidenteCruzado(titular);

      component.onEscape();

      expect(component.isDetalleOpen()).toBeTrue();
    });

    it('cerrar con la X cierra los dos detalles', async () => {
      (TestBed.inject(ViviendasService) as any).obtenerViviendasDeResidente = jasmine.createSpy().and.resolveTo([viviendas[0]]);
      await abrirVivienda();
      await component.abrirResidenteCruzado(titular);

      component.cerrarDetalle();

      expect(component.residenteCruzado()).toBeNull();
      expect(component.isDetalleOpen()).toBeFalse();
    });

    it('si al residente se le quita una vivienda, se cierra su detalle y se refresca la lista', async () => {
      (TestBed.inject(ViviendasService) as any).obtenerViviendasDeResidente = jasmine.createSpy().and.resolveTo([viviendas[0]]);
      await abrirVivienda();
      await component.abrirResidenteCruzado(titular);
      const cargar = spyOn(component, 'cargarViviendas').and.resolveTo();

      await component.alDesvincularDesdeResidente();

      expect(component.residenteCruzado()).toBeNull();
      expect(cargar).toHaveBeenCalled();
    });
  });
});
