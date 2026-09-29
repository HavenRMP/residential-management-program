import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { timeout, catchError } from 'rxjs/operators';
import { of } from 'rxjs';
import Swal from 'sweetalert2';
import { environment } from '../../../environments/environment';

export const PING_TIMEOUT = 7000;

export interface PingResponse {
  message?: string;
  timestamp?: string;
  dbVersion?: string;
}

@Injectable({
  providedIn: 'root'
})
export class PingService {
  private readonly http = inject(HttpClient);
  private retryCount = 0;
  private readonly maxRetries = 2;

  checkBackendConnection(): void {
    // 1. Despertar los microservicios de apoyo en paralelo (Viviendas, Condominios, Avisos)
    const pingViviendasUrl = `${environment.services.viviendas}/swagger/v1/swagger.json`;
    const pingCondominiosUrl = `${environment.services.condominios}/swagger/v1/swagger.json`;
    const pingAvisosUrl = `${environment.services.avisos}/swagger/v1/swagger.json`;

    this.http.get(pingViviendasUrl, { responseType: 'text' }).pipe(
      timeout(PING_TIMEOUT),
      catchError(() => of(null))
    ).subscribe();

    this.http.get(pingCondominiosUrl, { responseType: 'text' }).pipe(
      timeout(PING_TIMEOUT),
      catchError(() => of(null))
    ).subscribe();

    this.http.get(pingAvisosUrl, { responseType: 'text' }).pipe(
      timeout(PING_TIMEOUT),
      catchError(() => of(null))
    ).subscribe();

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

    this.http.get<PingResponse>(pingUrl).pipe(
      timeout(PING_TIMEOUT),
      catchError(error => {
        console.warn('Backend ping error details:', error);

        if (this.retryCount < this.maxRetries) {
          this.retryCount++;
          if (this.retryCount === 1) {
            Toast.fire({
              icon: 'info',
              title: 'Despertando servidor en Render...',
              background: '#fef3c7',
              color: '#92400e',
              timer: 3000
            });
          }
          setTimeout(() => this.checkBackendConnection(), 4000);
          return of(null);
        }

        let errorMsg = 'El backend no respondió a tiempo. Operando en modo seguro.';
        if (error.status === 0) {
          errorMsg = 'Servidor en Render iniciando o bloqueo de CORS.';
        }

        Toast.fire({
          icon: 'warning',
          title: errorMsg,
          background: '#fee2e2',
          color: '#991b1b',
          timer: 3500
        });
        return of(null);
      })
    ).subscribe(response => {
      if (response !== null) {
        const titleMsg = response.message || 'Backend conectado correctamente.';
        const dbVersionText = response.dbVersion ? response.dbVersion : 'No disponible';

        Toast.fire({
          html: `
            <div style="display: flex; flex-direction: column; gap: 2px; text-align: left; padding: 2px 0;">
              <span style="font-weight: 600; font-size: 0.95rem; line-height: 1.25;">${titleMsg}</span>
              <span style="font-size: 0.85rem; font-weight: 500; opacity: 0.9; line-height: 1.25;">Versión BD: <strong>${dbVersionText}</strong></span>
            </div>
          `,
          background: '#dcfce7',
          color: '#166534',
          timer: 4000
        });
      }
    });
  }
}

