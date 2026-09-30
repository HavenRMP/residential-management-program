import { ComponentFixture, TestBed, fakeAsync, tick } from '@angular/core/testing';
import { signal } from '@angular/core';
import { CasetaVisitasComponent } from './caseta-visitas.component';
import { VisitasVigilanciaService } from '../../../core/services/visitas-vigilancia.service';
import { VisitaVigilancia } from '../../../core/models/visita.model';

const visita: VisitaVigilancia = {
  id: 'v-1',
  viviendaId: 33,
  numeroCasa: 'PRUEBA-01',
  nombreVisitante: 'Juan',
  apellidosVisitante: 'Pérez',
  motivo: 'personal',
  numAcompanantes: 0,
  fechaLlegadaEsperada: '2026-10-01T15:00:00Z',
  vigenciaHasta: '2026-10-02T15:00:00Z',
  estado: 'programada'
};

describe('CasetaVisitasComponent', () => {
  let fixture: ComponentFixture<CasetaVisitasComponent>;
  let component: CasetaVisitasComponent;
  let servicio: {
    PAGE_SIZE: number;
    items: ReturnType<typeof signal<VisitaVigilancia[]>>;
    totalCount: ReturnType<typeof signal<number>>;
    page: ReturnType<typeof signal<number>>;
    isLoading: ReturnType<typeof signal<boolean>>;
    errorMessage: ReturnType<typeof signal<string | null>>;
    cargarHoy: jasmine.Spy;
    registrarEntrada: jasmine.Spy;
  };

  beforeEach(() => {
    servicio = {
      PAGE_SIZE: 20,
      items: signal<VisitaVigilancia[]>([visita]),
      totalCount: signal(1),
      page: signal(1),
      isLoading: signal(false),
      errorMessage: signal<string | null>(null),
      cargarHoy: jasmine.createSpy('cargarHoy'),
      registrarEntrada: jasmine.createSpy('registrarEntrada').and.callFake(async () => ({ ...visita, estado: 'en_curso' }))
    };

    TestBed.configureTestingModule({
      imports: [CasetaVisitasComponent],
      providers: [{ provide: VisitasVigilanciaService, useValue: servicio }]
    });

    fixture = TestBed.createComponent(CasetaVisitasComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    servicio.cargarHoy.calls.reset();
  });

  it('espera a que el guardia deje de teclear y hace una sola búsqueda', fakeAsync(() => {
    component.busqueda = 'Pe';
    component.onBusquedaCambio();
    tick(200);
    component.busqueda = 'Perez';
    component.onBusquedaCambio();
    tick(349);
    expect(servicio.cargarHoy).not.toHaveBeenCalled();

    tick(1);
    expect(servicio.cargarHoy).toHaveBeenCalledOnceWith('Perez', 1);
  }));

  it('abre y cierra el modal de detalle mostrando los datos de la visita', () => {
    component.abrirDetalle(visita);
    fixture.detectChanges();
    expect(component.visitaDetalle()?.id).toBe('v-1');
    expect(fixture.nativeElement.textContent).toContain('Llegada esperada');

    component.cerrarDetalle();
    fixture.detectChanges();
    expect(component.visitaDetalle()).toBeNull();
    expect(fixture.nativeElement.textContent).not.toContain('Llegada esperada');
  });

  it('el detalle refleja los cambios de la lista sin cerrarse', () => {
    component.abrirDetalle(visita);
    servicio.items.set([{ ...visita, estado: 'en_curso' }]);
    fixture.detectChanges();

    expect(component.visitaDetalle()?.estado).toBe('en_curso');
  });

  it('muestra registrar entrada solo para visitas programadas', () => {
    const textoInicial = fixture.nativeElement.textContent as string;
    expect(textoInicial).toContain('Registrar entrada');

    servicio.items.set([{ ...visita, estado: 'en_curso' }]);
    fixture.detectChanges();
    const textoEnCurso = fixture.nativeElement.textContent as string;
    expect(textoEnCurso).toContain('Registrar salida');
    expect(textoEnCurso).not.toContain('Registrar entrada');
  });

  describe('captura de placas', () => {
    it('precarga las placas que indicó el residente y las muestra solo en visitas programadas', () => {
      component.abrirDetalle({ ...visita, vehiculoPlacas: 'ABC-123' });
      fixture.detectChanges();

      expect(component.placasEntrada).toBe('ABC-123');
      expect(fixture.nativeElement.querySelector('#placas-entrada')).not.toBeNull();

      servicio.items.set([{ ...visita, estado: 'en_curso' }]);
      fixture.detectChanges();
      expect(fixture.nativeElement.querySelector('#placas-entrada')).toBeNull();
    });

    it('registra la entrada desde el detalle con las placas capturadas', async () => {
      component.abrirDetalle(visita);
      component.placasEntrada = 'XYZ-789';

      await component.registrarEntrada(visita, component.placasEntrada);

      expect(servicio.registrarEntrada).toHaveBeenCalledOnceWith('v-1', 'XYZ-789');
    });

    it('la entrada rápida desde la lista no manda placas aunque el detalle haya guardado otras', async () => {
      component.abrirDetalle(visita);
      component.placasEntrada = 'VIEJAS-1';
      component.cerrarDetalle();
      fixture.detectChanges();

      const botones = Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>);
      botones.find(b => b.textContent?.includes('Registrar entrada'))!.click();

      expect(servicio.registrarEntrada).toHaveBeenCalledOnceWith('v-1', undefined);
    });
  });
});
