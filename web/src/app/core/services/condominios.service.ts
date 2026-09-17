import { Injectable, inject, signal } from '@angular/core';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { Condominio } from '../models/condominio.model';
import { extractPagedItems } from '../models/pagination.model';
import { firstValueFrom } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class CondominiosService {
  private readonly apiService = inject(ApiService);

  /** Señal reactiva con el condominio actual del contexto del administrador */
  readonly condominioActual = signal<Condominio | null>(null);

  /**
   * Obtiene la lista de condominios desde el microservicio /api/condominios
   */
  async listar(nombre?: string): Promise<Condominio[]> {
    try {
      let params: HttpParams | undefined;
      if (nombre && nombre.trim().length > 0) {
        params = new HttpParams().set('nombre', nombre.trim());
      }
      const data = await firstValueFrom(this.apiService.get<any>('/api/condominios', params));
      return extractPagedItems<Condominio>(data);
    } catch (err) {
      console.warn('[CondominiosService] Error al listar condominios:', err);
      return [];
    }
  }

  /**
   * Obtiene un condominio por su ID
   */
  async obtenerPorId(id: string): Promise<Condominio | null> {
    try {
      return await firstValueFrom(this.apiService.get<Condominio>(`/api/condominios/${id}`));
    } catch (err) {
      console.warn(`[CondominiosService] Error al obtener condominio ${id}:`, err);
      return null;
    }
  }

  /**
   * Carga y resuelve el condominio que le corresponde al usuario actual.
   * Si el usuario tiene condominioId, lo busca; de lo contrario toma el primer condominio activo en Supabase.
   */
  async cargarCondominioUsuario(condominioId?: string | null): Promise<Condominio | null> {
    const actual = this.condominioActual();
    if (condominioId && actual?.id === condominioId) {
      return actual;
    }
    if (!condominioId && actual) {
      return actual;
    }

    // Si se especifica un ID de condominio, intentar buscarlo
    if (condominioId) {
      const cond = await this.obtenerPorId(condominioId);
      if (cond) {
        this.condominioActual.set(cond);
        return cond;
      }
    }

    // Si no hay ID o no se encontró, listar condominios disponibles
    const lista = await this.listar();
    const cond = lista.length > 0 ? lista[0] : null;

    if (cond) {
      this.condominioActual.set(cond);
      return cond;
    }

    // Fallback con el condominio estándar configurado en Supabase
    const fallback: Condominio = {
      id: 'a0000000-0000-0000-0000-000000000001',
      nombre: 'Condominio Residencial Principal',
      activo: true
    };
    this.condominioActual.set(fallback);
    return fallback;
  }

  /**
   * Genera un código de vinculación para un condominio (Admin).
   */
  async generarCodigo(condominioId: string, minutosVigencia: number = 1440): Promise<{ codigo: string; expiraEn?: string } | null> {
    try {
      const payload = { minutosVigencia };
      return await firstValueFrom(
        this.apiService.post<{ codigo: string; expiraEn?: string }>(`/api/condominios/${condominioId}/codigo`, payload)
      );
    } catch (err) {
      console.error(`[CondominiosService] Error al generar código para condominio ${condominioId}:`, err);
      return null;
    }
  }

  /**
   * Redime un código de invitación de condominio para el usuario actual.
   */
  async redimirCodigo(codigo: string): Promise<any | null> {
    const payload = { codigo: codigo.trim().toUpperCase() };
    return await firstValueFrom(
      this.apiService.post<any>('/api/codigos/condominio/redimir', payload)
    );
  }
}

