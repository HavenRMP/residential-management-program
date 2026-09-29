import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';

/**
 * Puente para el `url_redireccion` que el backend manda en las notificaciones
 * de aviso urgente (`/avisos/{id}`, sin ninguna vista propia en el router).
 * Reenvía al dashboard correcto según el rol, pasando el id como query param
 * para que ese dashboard pueda abrir el detalle una vez cargados los avisos.
 */
@Component({
  selector: 'app-aviso-redirect',
  standalone: true,
  template: ''
})
export class AvisoRedirectComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly authService = inject(AuthService);

  ngOnInit(): void {
    const avisoId = this.route.snapshot.paramMap.get('id');
    const destino = this.authService.getDashboardRoute();
    this.router.navigate([destino], {
      queryParams: avisoId ? { avisoId } : {},
      replaceUrl: true
    });
  }
}
