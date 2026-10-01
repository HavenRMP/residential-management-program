import { ComponentFixture, TestBed, fakeAsync, tick } from '@angular/core/testing';
import { signal } from '@angular/core';
import { AvisosCasetaComponent } from './avisos-caseta.component';
import { AvisosService } from '../../../core/services/avisos.service';
import { AuthService } from '../../../core/services/auth.service';
import { Aviso, AvisoPrioridad } from '../../../core/models/aviso.model';

const aviso = (id: string, titulo: string, prioridad: AvisoPrioridad, dias: number): Aviso => ({
  id,
  condominioId: 'cond-1',
  titulo,
  contenido: `Contenido de ${titulo}`,
  fechaPublicacion: '2026-09-30T00:00:00Z',
  fechaExpiracion: new Date(Date.now() + dias * 86_400_000).toISOString(),
  activo: true,
  creadoPorNombre: 'Administrador Gomez',
  creadoEn: '2026-09-30T00:00:00Z',
  prioridad
});

describe('AvisosCasetaComponent', () => {
  let fixture: ComponentFixture<AvisosCasetaComponent>;
  let servicio: {
    vigentes: ReturnType<typeof signal<Aviso[]>>;
    isLoading: ReturnType<typeof signal<boolean>>;
    errorMessage: ReturnType<typeof signal<string | null>>;
    cargarAvisos: jasmine.Spy;
  };

  beforeEach(() => {
    servicio = {
      vigentes: signal<Aviso[]>([
        aviso('1', 'Aviso general', 'informativo', 10),
        aviso('2', 'Corte de agua', 'urgente', 0.5),
        aviso('3', 'Fiesta en el salón', 'evento', 5),
        aviso('4', 'Reparación de bomba', 'urgente', 4)
      ]),
      isLoading: signal(false),
      errorMessage: signal<string | null>(null),
      cargarAvisos: jasmine.createSpy('cargarAvisos').and.returnValue(Promise.resolve([]))
    };

    TestBed.configureTestingModule({
      imports: [AvisosCasetaComponent],
      providers: [
        { provide: AvisosService, useValue: servicio },
        { provide: AuthService, useValue: { currentUser: signal({ condominioId: 'cond-1' }) } }
      ]
    });
    fixture = TestBed.createComponent(AvisosCasetaComponent);
    fixture.detectChanges();
  });

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const botonesAviso = () => Array.from(fixture.nativeElement.querySelectorAll('ul li button') as NodeListOf<HTMLButtonElement>);
  const panel = () => fixture.nativeElement.querySelector('[role="dialog"]') as HTMLElement | null;

  it('carga los avisos del condominio del vigilante al iniciar', () => {
    expect(servicio.cargarAvisos).toHaveBeenCalledOnceWith('cond-1');
  });

  it('muestra los urgentes primero (el que vence antes, primero) y el conteo con los urgentes aparte', () => {
    const titulos = Array.from(fixture.nativeElement.querySelectorAll('h3') as NodeListOf<HTMLElement>).map(h => h.textContent!.trim());

    expect(titulos).toEqual(['Corte de agua', 'Reparación de bomba', 'Fiesta en el salón', 'Aviso general']);
    expect(texto()).toContain('4 vigentes');
    expect(texto()).toContain('2 urgentes');
  });

  it('cada aviso lleva su prioridad como etiqueta e ícono, no solo como color', () => {
    const primero = botonesAviso()[0];

    expect(primero.textContent).toContain('Urgente');
    expect(primero.querySelector('svg')).not.toBeNull();
    expect(primero.className).toContain('border-l-rose-500');
    expect(botonesAviso()[2].className).toContain('border-l-indigo-500');
  });

  it('resalta el aviso que vence en un día o menos', () => {
    const vencePronto = botonesAviso()[0].querySelector('span.text-amber-700');
    const normal = botonesAviso()[1].querySelector('span.text-amber-700');

    expect(vencePronto).not.toBeNull();
    expect(normal).toBeNull();
  });

  it('es de solo lectura: no ofrece publicar, editar ni borrar', () => {
    const t = texto().toLowerCase();

    expect(t).not.toContain('nuevo aviso');
    expect(t).not.toContain('editar');
    expect(t).not.toContain('eliminar');
  });

  describe('panel de detalle', () => {
    it('al hacer clic abre un panel lateral accesible con el contenido, la vigencia y quién lo publicó', () => {
      botonesAviso()[0].click();
      fixture.detectChanges();

      const p = panel()!;
      expect(p).not.toBeNull();
      expect(p.getAttribute('aria-modal')).toBe('true');
      const t = p.textContent!.replace(/\s+/g, ' ');
      expect(t).toContain('Corte de agua');
      expect(t).toContain('Contenido de Corte de agua');
      expect(t).toContain('Vigente hasta');
      expect(t).toContain('Administrador Gomez');
      expect(document.getElementById(p.getAttribute('aria-labelledby')!)?.textContent).toContain('Corte de agua');
    });

    it('se cierra con el botón, con Escape y al hacer clic fuera', () => {
      const abrir = () => { botonesAviso()[0].click(); fixture.detectChanges(); };

      abrir();
      (panel()!.querySelector('button[aria-label="Cerrar detalle del aviso"]') as HTMLButtonElement).click();
      fixture.detectChanges();
      expect(panel()).toBeNull();

      abrir();
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      fixture.detectChanges();
      expect(panel()).toBeNull();

      abrir();
      (fixture.nativeElement.querySelector('[aria-hidden="true"].absolute') as HTMLElement).click();
      fixture.detectChanges();
      expect(panel()).toBeNull();
    });

    it('lleva el foco al botón de cerrar al abrir y lo devuelve al aviso al cerrar', fakeAsync(() => {
      const disparador = botonesAviso()[0];
      disparador.focus();
      disparador.click();
      fixture.detectChanges();
      tick();

      expect(document.activeElement?.getAttribute('aria-label')).toBe('Cerrar detalle del aviso');

      (document.activeElement as HTMLButtonElement).click();
      fixture.detectChanges();
      expect(document.activeElement).toBe(disparador);
    }));
  });

  it('muestra el estado vacío cuando no hay avisos', () => {
    servicio.vigentes.set([]);
    fixture.detectChanges();

    expect(texto()).toContain('No hay avisos vigentes en este momento.');
    expect(texto()).toContain('0 vigentes');
    expect(texto()).not.toContain('urgente');
  });

  it('muestra el error de carga en vez del estado vacío', () => {
    servicio.vigentes.set([]);
    servicio.errorMessage.set('No se pudieron cargar los avisos.');
    fixture.detectChanges();

    expect(texto()).toContain('No se pudieron cargar los avisos.');
    expect(texto()).not.toContain('No hay avisos vigentes en este momento.');
  });

  it('muestra el esqueleto mientras carga', () => {
    servicio.isLoading.set(true);
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelectorAll('.animate-pulse').length).toBeGreaterThan(0);
    expect(fixture.nativeElement.querySelector('ul')).toBeNull();
  });
});
