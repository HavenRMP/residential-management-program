import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { ReservaRedirectComponent } from './reserva-redirect.component';
import { AuthService } from '../../../core/services/auth.service';

describe('ReservaRedirectComponent', () => {
  let router: jasmine.SpyObj<Router>;

  function abrir(panel: string): void {
    router = jasmine.createSpyObj('Router', ['navigate']);
    TestBed.configureTestingModule({
      imports: [ReservaRedirectComponent],
      providers: [
        { provide: Router, useValue: router },
        { provide: AuthService, useValue: { getDashboardRoute: () => panel } }
      ]
    });
    TestBed.createComponent(ReservaRedirectComponent).detectChanges();
  }

  it('lleva al residente a su pantalla de reservas', () => {
    abrir('/dashboard/residente');

    expect(router.navigate).toHaveBeenCalledWith(['/dashboard/residente', 'reservas'], { replaceUrl: true });
  });

  it('lleva al administrador a la administración de reservas', () => {
    abrir('/dashboard/admin');

    expect(router.navigate).toHaveBeenCalledWith(['/dashboard/admin', 'reservas'], { replaceUrl: true });
  });

  it('un rol sin pantalla de reservas llega a su panel', () => {
    abrir('/dashboard/vigilante');

    expect(router.navigate).toHaveBeenCalledWith(['/dashboard/vigilante'], { replaceUrl: true });
  });
});
