import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export type MicroserviceName = 'usuarios' | 'viviendas' | 'condominios' | 'avisos' | 'default';

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private readonly http = inject(HttpClient);

  /**
   * Resuelve automáticamente el endpoint contra el microservicio correspondiente
   * según la convención de ruta o el microservicio especificado explícitamente.
   */
  resolveUrl(endpoint: string, service?: MicroserviceName): string {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return endpoint;
    }

    const services = environment.services;

    // 1. Servicio explícito
    if (service && (services as any)[service]) {
      return `${(services as any)[service]}${endpoint}`;
    }

    // 2. Enrutamiento automático por convención de ruta
    const lower = endpoint.toLowerCase();
    if (lower.startsWith('/api/auth') || lower.startsWith('/api/usuarios')) {
      return `${services.usuarios}${endpoint}`;
    }
    if (lower.startsWith('/api/viviendas') || lower.startsWith('/api/codigos/vivienda')) {
      return `${services.viviendas}${endpoint}`;
    }
    if (lower.startsWith('/api/condominios') || lower.startsWith('/api/codigos/condominio')) {
      return `${services.condominios}${endpoint}`;
    }
    if (lower.startsWith('/api/avisos')) {
      return `${(services as any).avisos}${endpoint}`;
    }

    // 3. Fallback al servicio default (monolito)
    return `${services.default}${endpoint}`;
  }

  get<T>(endpoint: string, params?: HttpParams, headers?: HttpHeaders, service?: MicroserviceName): Observable<T> {
    return this.http.get<T>(this.resolveUrl(endpoint, service), { params, headers });
  }

  post<T>(endpoint: string, body: any, headers?: HttpHeaders, service?: MicroserviceName): Observable<T> {
    return this.http.post<T>(this.resolveUrl(endpoint, service), body, { headers });
  }

  put<T>(endpoint: string, body: any, headers?: HttpHeaders, service?: MicroserviceName): Observable<T> {
    return this.http.put<T>(this.resolveUrl(endpoint, service), body, { headers });
  }

  patch<T>(endpoint: string, body: any, headers?: HttpHeaders, service?: MicroserviceName): Observable<T> {
    return this.http.patch<T>(this.resolveUrl(endpoint, service), body, { headers });
  }

  delete<T>(endpoint: string, headers?: HttpHeaders, service?: MicroserviceName): Observable<T> {
    return this.http.delete<T>(this.resolveUrl(endpoint, service), { headers });
  }
}

