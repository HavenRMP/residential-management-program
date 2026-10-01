import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import Swal from 'sweetalert2';
import { AvisosCasetaComponent } from './avisos-caseta.component';
import { AvisosService } from '../../../core/services/avisos.service';
import { AuthService } from '../../../core/services/auth.service';
import { Aviso, AvisoPrioridad } from '../../../core/models/aviso.model';

const aviso = (id: string, titulo: string, prioridad: AvisoPrioridad, dias: number): Aviso => ({
  id,
  condominioId: 'cond-1',
  titulo,
  contenido: `Contenido de ${titulo}`,
  fechaExpiracion: new Date(Date.now() + dias * 86_400_000).toISOString(),
  activo: true,
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
    spyOn(Swal, 'fire').and.returnValue(Promise.resolve({} as any));
    servicio = {
      vigentes: signal<Aviso[]>([
        aviso('1', 'Aviso general', 'informativo', 10),
        aviso('2', 'Corte de agua', 'urgente', 2),
        aviso('3', 'Fiesta en el salón', 'evento', 5)
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

  const texto = () => fixture.nativeElement.textContent as string;

  it('carga los avisos del condominio del vigilante al iniciar', () => {
    expect(servicio.cargarAvisos).toHaveBeenCalledOnceWith('cond-1');
  });

  it('muestra los avisos con el urgente primero y el conteo', () => {
    const titulos = Array.from(fixture.nativeElement.querySelectorAll('h3') as NodeListOf<HTMLElement>).map(h => h.textContent!.trim());

    expect(titulos).toEqual(['Corte de agua', 'Fiesta en el salón', 'Aviso general']);
    expect(texto()).toContain('3 vigentes');
    expect(texto()).toContain('Urgente');
  });

  it('es de solo lectura: no ofrece publicar, editar ni borrar', () => {
    const t = texto().toLowerCase();

    expect(t).not.toContain('nuevo aviso');
    expect(t).not.toContain('editar');
    expect(t).not.toContain('eliminar');
  });

  it('abre el detalle del aviso al hacer clic', () => {
    (fixture.nativeElement.querySelector('li button') as HTMLButtonElement).click();

    const opciones = (Swal.fire as unknown as jasmine.Spy).calls.mostRecent().args[0] as { title: string; text: string; icon: string };
    expect(opciones.title).toBe('Corte de agua');
    expect(opciones.text).toContain('Contenido de Corte de agua');
    expect(opciones.icon).toBe('warning');
  });

  it('muestra el estado vacío cuando no hay avisos', () => {
    servicio.vigentes.set([]);
    fixture.detectChanges();

    expect(texto()).toContain('No hay avisos vigentes en este momento.');
    expect(texto()).toContain('0 vigentes');
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
