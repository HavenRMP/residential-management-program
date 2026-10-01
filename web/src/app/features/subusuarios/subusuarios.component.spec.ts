import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { signal } from '@angular/core';
import Swal from 'sweetalert2';
import { SubusuariosComponent } from './subusuarios.component';
import { SubusuariosService } from '../../core/services/subusuarios.service';
import { ViviendasService } from '../../core/services/viviendas.service';
import { AuthService } from '../../core/services/auth.service';
import { InvitacionRecibida } from '../../core/models/subusuario.model';

describe('SubusuariosComponent', () => {
  let component: SubusuariosComponent;
  let fixture: ComponentFixture<SubusuariosComponent>;
  let servicio: any;
  let usuario: ReturnType<typeof signal<any>>;

  beforeEach(() => {
    usuario = signal<any>(null);
    servicio = {
      MAX_SUBUSUARIOS: 2,
      items: signal([]),
      isLoading: signal(false),
      errorMessage: signal(null),
      invitacionesRecibidas: signal([]),
      isLoadingInvitaciones: signal(false),
      cuposDisponibles: signal(2),
      activos: signal([]),
      pendientes: signal([]),
      cargar: jasmine.createSpy('cargar').and.returnValue(Promise.resolve()),
      cargarInvitacionesRecibidas: jasmine.createSpy('cargarInvitacionesRecibidas').and.returnValue(Promise.resolve()),
      responderInvitacion: jasmine.createSpy('responderInvitacion'),
      revocar: jasmine.createSpy('revocar')
    };

    TestBed.configureTestingModule({
      imports: [SubusuariosComponent],
      providers: [
        provideRouter([]),
        { provide: SubusuariosService, useValue: servicio },
        { provide: ViviendasService, useValue: { obtenerMisViviendas: () => Promise.resolve([]) } },
        { provide: AuthService, useValue: { currentUser: usuario, logout: () => undefined } }
      ]
    });

    fixture = TestBed.createComponent(SubusuariosComponent);
    component = fixture.componentInstance;
  });

  describe('perfil de sub-usuario (solo consulta)', () => {
    const acceso = { id: 'sub-1', nombre: 'Luis Prueba', email: 'luis@example.com', telefono: '', parentesco: 'Familiar', activo: true, creadoEn: null };
    const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
    const botones = () => Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>);

    function mostrar(usuarioId: string): void {
      usuario.set({ id: usuarioId, nombre: 'Persona', rol: 'residente' });
      servicio.items.set([acceso]);
      servicio.cuposDisponibles.set(1);
      fixture.detectChanges();
      component.viviendaId.set(33);
      fixture.detectChanges();
    }

    it('el titular puede invitar y revocar', () => {
      mostrar('titular-1');

      expect(component.esSubusuario()).toBeFalse();
      expect(botones().some(b => b.textContent!.includes('Invitar'))).toBeTrue();
      expect(fixture.nativeElement.querySelector('button[title="Revocar"]')).not.toBeNull();
      expect(texto()).toContain('Hasta 2 accesos por vivienda');
    });

    it('un sub-usuario activo ve la lista pero no puede invitar ni revocar', () => {
      mostrar('sub-1');

      expect(component.esSubusuario()).toBeTrue();
      expect(botones().some(b => b.textContent!.includes('Invitar'))).toBeFalse();
      expect(fixture.nativeElement.querySelector('button[title="Revocar"]')).toBeNull();
      expect(texto()).toContain('Solo el titular puede invitar o revocar accesos.');
      expect(texto()).toContain('Luis Prueba');
      expect(texto()).not.toContain('Invitar sub-usuario');
    });

    it('un sub-usuario no abre el formulario de invitación ni revoca aunque lo intente', async () => {
      mostrar('sub-1');
      const fire = spyOn(Swal, 'fire').and.returnValue(Promise.resolve({ isConfirmed: true } as any));

      component.abrirModalInvitacion();
      await component.confirmarRevocar(acceso);

      expect(component.modalInvitarAbierto()).toBeFalse();
      expect(fire).not.toHaveBeenCalled();
      expect(servicio.revocar).not.toHaveBeenCalled();
    });

    it('una invitación pendiente con el mismo id no convierte a nadie en sub-usuario', () => {
      usuario.set({ id: 'sub-1', nombre: 'Persona', rol: 'residente' });
      servicio.items.set([{ ...acceso, activo: false }]);

      expect(component.esSubusuario()).toBeFalse();
    });
  });

  describe('validación de correo', () => {
    it('rechaza correos sin formato válido', () => {
      for (const malo of ['', 'abc', 'a@b', 'a b@c.com', '@c.com']) {
        component.nuevoSub = { email: malo, parentesco: 'Familiar' };
        expect(component.esFormularioValido()).withContext(malo).toBeFalse();
      }
    });

    it('acepta un correo válido con espacios alrededor', () => {
      component.nuevoSub = { email: '  hijo@example.com ', parentesco: 'Familiar' };

      expect(component.esFormularioValido()).toBeTrue();
    });
  });

  describe('errores al invitar', () => {
    it('si el backend devuelve el JSON técnico de Supabase muestra un mensaje claro', async () => {
      const fire = spyOn(Swal, 'fire').and.returnValue(Promise.resolve({} as any));
      servicio.invitar = jasmine.createSpy('invitar').and.returnValue(
        Promise.reject({ status: 400, error: { error: 'Error al generar invitación: {"code":"23505","details":null,"message":"duplicate key"}' } })
      );
      component.viviendaId.set(7);
      component.nuevoSub = { email: 'hijo@example.com', parentesco: 'Familiar' };

      await component.generarInvitacion();

      const aviso = fire.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('error');
      expect(aviso.text).not.toContain('23505');
      expect(aviso.text).toContain('no tenga ya una invitación pendiente');
    });

    it('conserva el mensaje claro del backend cuando lo hay', async () => {
      const fire = spyOn(Swal, 'fire').and.returnValue(Promise.resolve({} as any));
      servicio.invitar = jasmine.createSpy('invitar').and.returnValue(Promise.reject({ status: 400, error: { error: 'Ya alcanzaste el máximo de sub-usuarios.' } }));
      component.viviendaId.set(7);
      component.nuevoSub = { email: 'hijo@example.com', parentesco: 'Familiar' };

      await component.generarInvitacion();

      expect((fire.calls.mostRecent().args[0] as any).text).toBe('Ya alcanzaste el máximo de sub-usuarios.');
    });
  });

  describe('errores al responder una invitación', () => {
    const invitacion = { id: 'inv-1', titularNombre: 'Ana' } as InvitacionRecibida;
    let fire: jasmine.Spy;

    beforeEach(() => {
      component.viviendaId.set(7);
      fire = spyOn(Swal, 'fire').and.callFake(((opciones: any) =>
        Promise.resolve({ isConfirmed: !opciones.toast && opciones.showCancelButton === true })) as any);
    });

    const avisos = () => fire.calls.allArgs().map(a => a[0] as any).filter(o => !o.showCancelButton);

    it('si la invitación ya fue respondida, refresca las listas y avisa sin mostrar error', async () => {
      servicio.responderInvitacion.and.returnValue(Promise.reject({ status: 400, error: { error: 'Error desde Supabase: {"code":"SU004"}' } }));

      await component.confirmarResponderInvitacion(invitacion, 'RECHAZADA');

      expect(servicio.cargarInvitacionesRecibidas).toHaveBeenCalled();
      expect(servicio.cargar).toHaveBeenCalledWith(7);
      const aviso = avisos().at(-1);
      expect(aviso.icon).toBe('info');
      expect(aviso.title).toContain('Actualizamos tu lista');
      expect(JSON.stringify(avisos())).not.toContain('Supabase');
    });

    it('con un fallo del servidor no refresca y oculta el JSON técnico', async () => {
      servicio.responderInvitacion.and.returnValue(Promise.reject({ status: 500, error: { error: '{"code":"XX000"}' } }));

      await component.confirmarResponderInvitacion(invitacion, 'ACEPTADA');

      expect(servicio.cargar).not.toHaveBeenCalled();
      const aviso = avisos().at(-1);
      expect(aviso.icon).toBe('error');
      expect(aviso.text).toBe('Intenta de nuevo en unos segundos.');
    });

    it('al revocar un acceso que ya no existe también refresca la lista', async () => {
      servicio.revocar.and.returnValue(Promise.reject({ status: 404 }));

      await component.confirmarRevocar({ id: 'sub-1', activo: false, nombre: 'Luis' } as any);

      expect(servicio.cargar).toHaveBeenCalledWith(7);
      expect(avisos().at(-1).icon).toBe('info');
    });
  });
});
