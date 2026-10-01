import { Injectable, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import { FiltrosHistoricoVisitas, VisitaVigilancia } from '../models/visita.model';

@Injectable({
  providedIn: 'root'
})
export class VisitasHistoricoService {
  private readonly apiService = inject(ApiService);

  readonly PAGE_SIZE = 20;

  readonly items = signal<VisitaVigilancia[]>([]);
  readonly totalCount = signal<number>(0);
  readonly page = signal<number>(1);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  private ultimaPeticion = 0;

  /**
   * Histórico de visitas del condominio, filtrable por fechas, vivienda y estado (solo administrador)
   * (GET /api/visitas/historico)
   */
  async cargar(filtros: FiltrosHistoricoVisitas = {}, page: number = 1): Promise<void> {
    // Una respuesta lenta de una búsqueda anterior no debe pisar la de los filtros más recientes
    const peticion = ++this.ultimaPeticion;
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      let params = new HttpParams().set('page', page.toString()).set('pageSize', this.PAGE_SIZE.toString());
      if (filtros.desde) params = params.set('desde', filtros.desde);
      if (filtros.hasta) params = params.set('hasta', filtros.hasta);
      if (filtros.viviendaId) params = params.set('viviendaId', filtros.viviendaId.toString());
      if (filtros.estado) params = params.set('estado', filtros.estado);

      const response = await firstValueFrom(
        this.apiService.get<any>('/api/visitas/historico', params, undefined, 'visitas')
      );
      if (peticion !== this.ultimaPeticion) return;
      this.items.set(extractPagedItems<VisitaVigilancia>(response));
      this.totalCount.set(response?.totalCount ?? this.items().length);
      this.page.set(response?.page ?? page);
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[VisitasHistoricoService] Error al cargar el histórico:', err);
      this.errorMessage.set(
        err?.status === 403
          ? 'Tu cuenta no tiene permiso para consultar el historial de visitas.'
          : err?.error?.error || 'No se pudo cargar el histórico de visitas.'
      );
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }
}
