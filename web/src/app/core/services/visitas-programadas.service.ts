import { Injectable, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import { ordenarVisitasProximasPrimero, VisitaVigilancia } from '../models/visita.model';

const POR_PAGINA = 50;
/** El backend atiende en "próximas" lo que llega dentro de esta ventana; aquí solo va lo posterior */
const VENTANA_PROXIMAS_MS = 24 * 3_600_000;
/** Tope de seguridad: 10 páginas son 500 visitas programadas a futuro */
const MAX_PAGINAS = 10;

@Injectable({
  providedIn: 'root'
})
export class VisitasProgramadasService {
  private readonly apiService = inject(ApiService);

  readonly items = signal<VisitaVigilancia[]>([]);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  private ultimaPeticion = 0;

  /**
   * Visitas programadas que llegan después de las próximas 24 horas, la más próxima primero.
   * Las que llegan antes se atienden en "Próximas 24 h". Se piden todas las páginas para poder ordenarlas completas.
   * (GET /api/visitas/historico?estado=programada&desde=ahora+24h)
   */
  async cargar(): Promise<void> {
    const peticion = ++this.ultimaPeticion;
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      const desde = new Date(Date.now() + VENTANA_PROXIMAS_MS).toISOString();
      const porId = new Map<string, VisitaVigilancia>();
      for (let page = 1; page <= MAX_PAGINAS; page++) {
        const params = new HttpParams()
          .set('page', page.toString())
          .set('pageSize', POR_PAGINA.toString())
          .set('estado', 'programada')
          .set('desde', desde);
        const response = await firstValueFrom(this.apiService.get<any>('/api/visitas/historico', params, undefined, 'visitas'));
        if (peticion !== this.ultimaPeticion) return;
        const pagina = extractPagedItems<VisitaVigilancia>(response);
        pagina.forEach(v => porId.set(v.id, v));
        const total = response?.totalCount ?? porId.size;
        if (pagina.length === 0 || porId.size >= total) break;
      }
      this.items.set(ordenarVisitasProximasPrimero([...porId.values()]));
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[VisitasProgramadasService] Error al cargar las visitas programadas:', err);
      this.errorMessage.set(err?.error?.error || 'No se pudieron cargar las visitas programadas.');
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }
}
