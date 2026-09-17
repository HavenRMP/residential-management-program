import { Injectable, inject } from '@angular/core';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { CacheService } from './cache.service';
import { Vivienda } from '../models/vivienda.model';
import { Residente } from '../models/residente.model';
import { extractPagedItems } from '../models/pagination.model';
import { firstValueFrom } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class ViviendasService {
  private readonly apiService = inject(ApiService);
  private readonly cacheService = inject(CacheService);

  async listar(page?: number, pageSize?: number, forceRefresh: boolean = false): Promise<Vivienda[]> {
    const cacheKey = `viviendas_list_${page || 0}_${pageSize || 0}`;
    if (!forceRefresh) {
      const cached = this.cacheService.get<Vivienda[]>(cacheKey);
      if (cached) return cached;
    }

    try {
      let params: HttpParams | undefined;
      if (page || pageSize) {
        params = new HttpParams();
        if (page) params = params.set('page', page.toString());
        if (pageSize) params = params.set('pageSize', pageSize.toString());
      }
      const resp = await firstValueFrom(this.apiService.get<any>('/api/viviendas', params));
      const items = extractPagedItems<Vivienda>(resp);
      this.cacheService.set(cacheKey, items, 'viviendas');
      return items;
    } catch (err) {
      console.warn('[ViviendasService] Error al listar viviendas:', err);
      throw err;
    }
  }

  async crear(payload: { numeroCasa: string; tipo?: string | null; condominioId?: string }): Promise<Vivienda> {
    const result = await firstValueFrom(this.apiService.post<Vivienda>('/api/viviendas', payload));
    this.cacheService.invalidateTag('viviendas');
    return result;
  }

  async actualizar(id: number, payload: { numeroCasa: string; tipo?: string | null; condominioId?: string }): Promise<Vivienda> {
    const result = await firstValueFrom(this.apiService.put<Vivienda>(`/api/viviendas/${id}`, payload));
    this.cacheService.invalidateTag('viviendas');
    return result;
  }

  async eliminar(id: number): Promise<void> {
    await firstValueFrom(this.apiService.delete<void>(`/api/viviendas/${id}`));
    this.cacheService.invalidateTag('viviendas');
  }

  async obtenerResidentesVivienda(viviendaId: number, forceRefresh: boolean = false): Promise<Residente[]> {
    const cacheKey = `vivienda_${viviendaId}_residentes`;
    if (!forceRefresh) {
      const cached = this.cacheService.get<Residente[]>(cacheKey);
      if (cached) return cached;
    }

    try {
      const resp = await firstValueFrom(this.apiService.get<any>(`/api/viviendas/${viviendaId}/residentes`));
      const items = extractPagedItems<Residente>(resp);
      this.cacheService.set(cacheKey, items, 'viviendas');
      return items;
    } catch {
      return [];
    }
  }

  async vincularResidente(viviendaId: number, usuarioId: string): Promise<any> {
    const result = await firstValueFrom(this.apiService.post<any>(`/api/viviendas/${viviendaId}/residentes`, { usuarioId }));
    this.cacheService.invalidateTag('viviendas');
    this.cacheService.invalidateTag('residentes');
    return result;
  }

  async desvincularResidente(viviendaId: number, usuarioId: string): Promise<void> {
    await firstValueFrom(this.apiService.delete<void>(`/api/viviendas/${viviendaId}/residentes/${usuarioId}`));
    this.cacheService.invalidateTag('viviendas');
    this.cacheService.invalidateTag('residentes');
  }

  async obtenerMisViviendas(forceRefresh: boolean = false): Promise<Vivienda[]> {
    const cacheKey = 'viviendas_mis_viviendas';
    if (!forceRefresh) {
      const cached = this.cacheService.get<Vivienda[]>(cacheKey);
      if (cached) return cached;
    }
    try {
      const resp = await firstValueFrom(this.apiService.get<any>('/api/viviendas/mis-viviendas'));
      const items = extractPagedItems<any>(resp);
      const mapped = items.map(item => ({
        id: item.viviendaId ?? item.id,
        numeroCasa: item.numeroCasa,
        tipo: item.tipo,
        activo: item.activo,
        creadoEn: item.creadoEn
      }));
      this.cacheService.set(cacheKey, mapped, 'viviendas');
      return mapped;
    } catch (err) {
      console.warn('[ViviendasService] Error al obtener mis-viviendas:', err);
      return [];
    }
  }

  async obtenerMiVivienda(): Promise<Vivienda | null> {
    const viviendas = await this.obtenerMisViviendas();
    return viviendas.length > 0 ? viviendas[0] : null;
  }

  /**
   * Genera un código de vinculación para una vivienda específica (Admin).
   */
  async generarCodigo(viviendaId: number, minutosVigencia: number = 1440): Promise<{ codigo: string; expiraEn?: string } | null> {
    try {
      const payload = { minutosVigencia };
      return await firstValueFrom(
        this.apiService.post<{ codigo: string; expiraEn?: string }>(`/api/viviendas/${viviendaId}/codigo`, payload)
      );
    } catch (err) {
      console.error(`[ViviendasService] Error al generar código para vivienda ${viviendaId}:`, err);
      return null;
    }
  }

  /**
   * Redime un código de vinculación de vivienda para el residente actual.
   */
  async redimirCodigo(codigo: string): Promise<any | null> {
    const payload = { codigo: codigo.trim().toUpperCase() };
    return await firstValueFrom(
      this.apiService.post<any>('/api/codigos/vivienda/redimir', payload)
    );
  }

  /**
   * Obtiene el mapa de viviendas indexado por el ID del residente asignado.
   * Utiliza caché inteligente invalidada cuando cambian viviendas o residentes.
   */
  async obtenerMapaViviendasPorResidente(forceRefresh: boolean = false): Promise<Map<string, Vivienda[]>> {
    const cacheKey = 'mapa_viviendas_por_residente';
    if (!forceRefresh) {
      const cached = this.cacheService.get<Record<string, Vivienda[]>>(cacheKey);
      if (cached) {
        return new Map(Object.entries(cached));
      }
    }

    const mapa = new Map<string, Vivienda[]>();
    try {
      const viviendas = await this.listar(undefined, undefined, forceRefresh);
      if (viviendas && viviendas.length > 0) {
        // Ejecutar en lotes concurrentes (chunks de 6) para proteger el pool de red y evitar saturación
        const chunkSize = 6;
        const asignaciones: Residente[][] = [];
        for (let i = 0; i < viviendas.length; i += chunkSize) {
          const chunk = viviendas.slice(i, i + chunkSize);
          const chunkResults = await Promise.all(
            chunk.map(v => this.obtenerResidentesVivienda(v.id, forceRefresh).catch(() => []))
          );
          asignaciones.push(...chunkResults);
        }

        viviendas.forEach((v, index) => {
          const residentes = asignaciones[index] || [];
          residentes.forEach(r => {
            if (r && r.id) {
              const current = mapa.get(r.id) || [];
              current.push(v);
              mapa.set(r.id, current);
            }
          });
        });
      }

      const serializable: Record<string, Vivienda[]> = {};
      mapa.forEach((val, key) => { serializable[key] = val; });
      this.cacheService.set(cacheKey, serializable, 'viviendas');
      return mapa;
    } catch (err) {
      console.warn('[ViviendasService] Error al obtener mapa de viviendas por residente:', err);
      return mapa;
    }
  }

  /**
   * Obtiene las viviendas asignadas a un residente específico por su ID.
   */
  async obtenerViviendasDeResidente(residenteId: string, forceRefresh: boolean = false): Promise<Vivienda[]> {
    const mapa = await this.obtenerMapaViviendasPorResidente(forceRefresh);
    return mapa.get(residenteId) || [];
  }
}


