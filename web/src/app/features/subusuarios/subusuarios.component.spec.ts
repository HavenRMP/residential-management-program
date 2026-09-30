import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { signal } from '@angular/core';
import { SubusuariosComponent } from './subusuarios.component';
import { SubusuariosService } from '../../core/services/subusuarios.service';
import { ViviendasService } from '../../core/services/viviendas.service';
import { AuthService } from '../../core/services/auth.service';

describe('SubusuariosComponent (validación de correo)', () => {
  let component: SubusuariosComponent;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [SubusuariosComponent],
      providers: [
        provideRouter([]),
        {
          provide: SubusuariosService,
          useValue: {
            MAX_SUBUSUARIOS: 2,
            items: signal([]),
            isLoading: signal(false),
            errorMessage: signal(null),
            invitacionesRecibidas: signal([]),
            isLoadingInvitaciones: signal(false),
            cuposDisponibles: signal(2),
            activos: signal([]),
            pendientes: signal([]),
            cargar: () => Promise.resolve(),
            cargarInvitacionesRecibidas: () => Promise.resolve()
          }
        },
        { provide: ViviendasService, useValue: { obtenerMisViviendas: () => Promise.resolve([]) } },
        { provide: AuthService, useValue: { currentUser: signal(null), logout: () => undefined } }
      ]
    });

    component = TestBed.createComponent(SubusuariosComponent).componentInstance;
  });

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
