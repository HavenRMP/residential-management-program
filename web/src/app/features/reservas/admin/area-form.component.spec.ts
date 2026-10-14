import { ComponentFixture, TestBed } from '@angular/core/testing';
import Swal from 'sweetalert2';
import { AreaFormComponent } from './area-form.component';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { AreaComun } from '../../../core/models/reserva.model';

const salon: AreaComun = {
  id: 's1', nombre: 'Salón de usos múltiples', descripcion: 'Para fiestas', horaApertura: '08:00:00', horaCierre: '22:00:00',
  zonaHoraria: 'America/Mexico_City', activo: true
};

describe('AreaFormComponent', () => {
  let fixture: ComponentFixture<AreaFormComponent>;
  let component: AreaFormComponent;
  let servicio: { crearArea: jasmine.Spy; actualizarArea: jasmine.Spy };
  let swal: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const guardarBoton = () =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => /Crear área|Guardar cambios|Guardando/.test(b.textContent!))!;

  function abrir(area: AreaComun | null = null): void {
    fixture = TestBed.createComponent(AreaFormComponent);
    component = fixture.componentInstance;
    fixture.componentRef.setInput('area', area);
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = {
      crearArea: jasmine.createSpy('crearArea').and.callFake(async (dto: any) => ({ id: 'nueva', activo: true, zonaHoraria: 'America/Mexico_City', ...dto, descripcion: dto.descripcion ?? null })),
      actualizarArea: jasmine.createSpy('actualizarArea').and.resolveTo(salon)
    };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({ imports: [AreaFormComponent], providers: [{ provide: ReservasAdminService, useValue: servicio }] });
  });

  describe('alta', () => {
    it('propone un horario de 08:00 a 22:00 y no deja crear sin nombre', () => {
      abrir();

      expect(texto()).toContain('Nueva área común');
      expect(component.form.horaApertura).toBe('08:00');
      expect(component.form.horaCierre).toBe('22:00');
      expect(component.esValido()).toBeFalse();
      expect(guardarBoton().disabled).toBeTrue();
    });

    it('manda el horario con segundos y omite la descripción si está vacía', () => {
      abrir();
      component.form.nombre = '  Alberca ';
      component.form.descripcion = '   ';

      expect(component.esValido()).toBeTrue();
      expect(component.armarAlta()).toEqual({ nombre: 'Alberca', horaApertura: '08:00:00', horaCierre: '22:00:00' });
    });

    it('incluye la descripción cuando se escribió', () => {
      abrir();
      component.form.nombre = 'Alberca';
      component.form.descripcion = ' Con camastros ';

      expect(component.armarAlta().descripcion).toBe('Con camastros');
    });

    it('rechaza una apertura igual o posterior al cierre y lo explica', () => {
      abrir();
      component.form.nombre = 'Alberca';
      component.form.horaApertura = '20:00';
      component.form.horaCierre = '09:00';
      fixture.detectChanges();

      expect(component.esValido()).toBeFalse();
      expect(texto()).toContain('La hora de apertura debe ser anterior a la de cierre.');

      component.form.horaCierre = '20:00';
      expect(component.horarioInvalido()).toBeTrue();
    });

    it('respeta el largo máximo del nombre y de la descripción', () => {
      abrir();
      component.form.nombre = 'x'.repeat(101);
      expect(component.esValido()).toBeFalse();
      component.form.nombre = 'x'.repeat(100);
      expect(component.esValido()).toBeTrue();
      component.form.descripcion = 'd'.repeat(501);
      expect(component.esValido()).toBeFalse();
    });

    it('al guardar crea el área, avisa al padre y confirma con un aviso breve', async () => {
      abrir();
      component.form.nombre = 'Alberca';
      const guardadas: AreaComun[] = [];
      component.guardado.subscribe(a => guardadas.push(a));

      await component.guardar();

      expect(servicio.crearArea).toHaveBeenCalledOnceWith({ nombre: 'Alberca', horaApertura: '08:00:00', horaCierre: '22:00:00' });
      expect(guardadas.map(a => a.id)).toEqual(['nueva']);
      expect((swal.calls.mostRecent().args[0] as any).title).toBe('Área creada');
      expect(component.isSaving()).toBeFalse();
    });

    it('si el backend la rechaza muestra su motivo y no cierra', async () => {
      spyOn(console, 'error');
      servicio.crearArea.and.rejectWith({ status: 400, error: { errors: { Nombre: ['El nombre es obligatorio'] } } });
      abrir();
      component.form.nombre = 'Alberca';
      const guardadas: AreaComun[] = [];
      component.guardado.subscribe(a => guardadas.push(a));

      await component.guardar();

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('error');
      expect(aviso.text).toBe('El nombre es obligatorio');
      expect(guardadas).toEqual([]);
    });

    it('oculta el JSON técnico con un mensaje claro', async () => {
      spyOn(console, 'error');
      servicio.crearArea.and.rejectWith({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } });
      abrir();
      component.form.nombre = 'Alberca';

      await component.guardar();

      expect((swal.calls.mostRecent().args[0] as any).text).toBe('No fue posible guardar el área. Intenta de nuevo en unos segundos.');
    });

    it('no envía nada si el formulario no es válido', async () => {
      abrir();

      await component.guardar();

      expect(servicio.crearArea).not.toHaveBeenCalled();
    });
  });

  describe('edición', () => {
    it('rellena los datos del área y no deja guardar sin cambios', () => {
      abrir(salon);

      expect(texto()).toContain('Editar área');
      expect(component.form).toEqual({ nombre: 'Salón de usos múltiples', descripcion: 'Para fiestas', horaApertura: '08:00', horaCierre: '22:00' });
      expect(component.hayCambios()).toBeFalse();
      expect(guardarBoton().disabled).toBeTrue();
      expect(guardarBoton().textContent).toContain('Guardar cambios');
    });

    it('envía solo lo que cambió, con el horario en segundos', () => {
      abrir(salon);
      component.form.nombre = ' Salón principal ';
      component.form.horaCierre = '23:30';

      expect(component.armarCambios()).toEqual({ nombre: 'Salón principal', horaCierre: '23:30:00' });
      expect(component.hayCambios()).toBeTrue();
    });

    it('al guardar actualiza el área con los cambios', async () => {
      abrir(salon);
      component.form.descripcion = 'Con cocineta';

      await component.guardar();

      expect(servicio.actualizarArea).toHaveBeenCalledOnceWith('s1', { descripcion: 'Con cocineta' });
      expect(servicio.crearArea).not.toHaveBeenCalled();
      expect((swal.calls.mostRecent().args[0] as any).title).toBe('Área actualizada');
    });
  });

  it('Escape y Cancelar cierran sin guardar', () => {
    abrir();
    let cierres = 0;
    component.cerrado.subscribe(() => cierres++);

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    component.cerrar();

    expect(cierres).toBe(2);
    expect(servicio.crearArea).not.toHaveBeenCalled();
  });
});
