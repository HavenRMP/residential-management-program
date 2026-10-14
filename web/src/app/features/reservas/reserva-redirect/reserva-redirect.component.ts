import { ChangeDetectionStrategy, Component, OnInit, inject } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';

/**
 * Puente para el `url_redireccion` que el backend manda en las notificaciones de reservas (`/reservas/{id}`),
 * que no tiene vista propia en el router. Lleva a la pantalla de reservas del rol de la persona; los roles que
 * todavía no tienen pantalla de reservas llegan a su panel.
 */
@Component({
  selector: 'app-reserva-redirect',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.Eager,
  template: ''
})
export class ReservaRedirectComponent implements OnInit {
  private readonly router = inject(Router);
  private readonly authService = inject(AuthService);

  ngOnInit(): void {
    const panel = this.authService.getDashboardRoute();
    const tienePantalla = panel.endsWith('/residente') || panel.endsWith('/admin');
    this.router.navigate(tienePantalla ? [panel, 'reservas'] : [panel], { replaceUrl: true });
  }
}
