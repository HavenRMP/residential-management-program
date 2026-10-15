import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { timeout, catchError } from 'rxjs/operators';
import { of } from 'rxjs';
import Swal from 'sweetalert2';
import { environment } from '../../../environments/environment';

export const PING_TIMEOUT = 7000;
/**
 * Los servicios que solo se despiertan no bloquean nada: pueden tardar lo que tarde Render en arrancarlos
 * (el de reservas llega a tardar cerca de un minuto), así que su petición no se corta a los 7 s.
 */
export const WAKE_TIMEOUT = 90000;
/** `default` repite la URL de viviendas y `usuarios` tiene su propio ping más abajo */
const SERVICIOS_QUE_NO_SE_DESPIERTAN_AQUI = ['default', 'usuarios'];

@Injectable({
  providedIn: 'root'
})
export class PingService {
  private readonly http = inject(HttpClient);
  private retryCount = 0;
  private readonly maxRetries = 2;

  checkBackendConnection(): void {
    // 1. Despertar en paralelo todos los demás microservicios (Viviendas, Condominios, Avisos, Visitas, Reservas…).
    //    Se recorre `environment.services`, así un servicio nuevo queda incluido sin tocar este código.
    for (const [nombre, base] of Object.entries(environment.services)) {
      if (SERVICIOS_QUE_NO_SE_DESPIERTAN_AQUI.includes(nombre)) continue;
      this.http.get(`${base}/swagger/v1/swagger.json`, { responseType: 'text' }).pipe(
        timeout(WAKE_TIMEOUT),
        catchError(() => of(null))
      ).subscribe();
    }

    // 2. Despertar microservicio de Usuarios y validar conexion
    const pingUrl = `${environment.services.usuarios}/api/auth/ping`;

    const Toast = Swal.mixin({
      toast: true,
      position: 'bottom',
      showConfirmButton: false,
      timer: 4000,
      timerProgressBar: true,
      width: '100%'
    });

    this.http.get(pingUrl).pipe(
      timeout(PING_TIMEOUT),
      catchError(error => {
        console.warn('Backend ping error details:', error);

        if (this.retryCount < this.maxRetries) {
          this.retryCount++;
          if (this.retryCount === 1) {
            Toast.fire({
              icon: 'info',
              title: 'Conectando con el servidor. Puede tardar unos segundos...',
              background: '#fef3c7',
              color: '#92400e',
              timer: 3000
            });
          }
          setTimeout(() => this.checkBackendConnection(), 4000);
          return of(null);
        }

        Toast.fire({
          icon: 'warning',
          title: 'No pudimos conectar con el servidor. Revisa tu conexión o intenta de nuevo en unos minutos.',
          background: '#fee2e2',
          color: '#991b1b',
          timer: 3500
        });
        return of(null);
      })
    ).subscribe();
  }
}

