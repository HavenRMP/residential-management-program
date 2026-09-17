import { Injectable, inject } from '@angular/core';
import { ApiService } from './api.service';
import { Vivienda } from '../models/vivienda.model';
import { Residente } from '../models/residente.model';
import { extractPagedItems } from '../models/pagination.model';
import { firstValueFrom } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class ViviendasService {
  private readonly apiService = inject(ApiService);

  async listar(): Promise<Vivienda[]> {
    try {
      const resp = await firstValueFrom(this.apiService.get<any>('/api/viviendas'));
      return extractPagedItems<Vivienda>(resp);
    } catch (err) {
      console.warn('[ViviendasService] Error al listar viviendas:', err);
      return [];
    }
  }

  crear(payload: { numeroCasa: string; tipo?: string | null; condominioId?: string }): Promise<Vivienda> {
    return firstValueFrom(this.apiService.post<Vivienda>('/api/viviendas', payload));
  }

  actualizar(id: number, payload: { numeroCasa: string; tipo?: string | null; condominioId?: string }): Promise<Vivienda> {
    return firstValueFrom(this.apiService.put<Vivienda>(`/api/viviendas/${id}`, payload));
  }

  eliminar(id: number): Promise<void> {
    return firstValueFrom(this.apiService.delete<void>(`/api/viviendas/${id}`));
  }

  async obtenerResidentesVivienda(viviendaId: number): Promise<Residente[]> {
    try {
      const resp = await firstValueFrom(this.apiService.get<any>(`/api/viviendas/${viviendaId}/residentes`));
      return extractPagedItems<Residente>(resp);
    } catch {
      return [];
    }
  }

  vincularResidente(viviendaId: number, usuarioId: string): Promise<any> {
    return firstValueFrom(this.apiService.post<any>(`/api/viviendas/${viviendaId}/residentes`, { usuarioId }));
  }

  desvincularResidente(viviendaId: number, usuarioId: string): Promise<void> {
    return firstValueFrom(this.apiService.delete<void>(`/api/viviendas/${viviendaId}/residentes/${usuarioId}`));
  }

  async obtenerMisViviendas(): Promise<Vivienda[]> {
    try {
      const resp = await firstValueFrom(this.apiService.get<any>('/api/viviendas/mis-viviendas'));
      const items = extractPagedItems<any>(resp);
      return items.map(item => ({
        id: item.viviendaId ?? item.id,
        numeroCasa: item.numeroCasa,
        tipo: item.tipo,
        activo: item.activo,
        creadoEn: item.creadoEn
      }));
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
}

