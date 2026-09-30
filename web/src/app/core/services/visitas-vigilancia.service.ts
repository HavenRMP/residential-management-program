import { Injectable, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import { VisitaVigilancia } from '../models/visita.model';

@Injectable({
  providedIn: 'root'
})
export class VisitasVigilanciaService {
  private readonly apiService = inject(ApiService);

  readonly PAGE_SIZE = 20;

  readonly items = signal<VisitaVigilancia[]>([]);
  readonly totalCount = signal<number>(0);
  readonly page = signal<number>(1);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  /**
   * Visitas vigentes del día (programadas y en curso). Con `busqueda` filtra por nombre,
   * apellidos, código exacto o número de casa
   * (GET /api/visitas/hoy)
   */
  async cargarHoy(busqueda?: string, page: number = 1): Promise<void> {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      let params = new HttpParams().set('page', page.toString()).set('pageSize', this.PAGE_SIZE.toString());
      if (busqueda?.trim()) {
        params = params.set('busqueda', busqueda.trim());
      }
      const response = await firstValueFrom(
        this.apiService.get<any>('/api/visitas/hoy', params, undefined, 'visitas')
      );
      this.items.set(extractPagedItems<VisitaVigilancia>(response));
      this.totalCount.set(response?.totalCount ?? this.items().length);
      this.page.set(response?.page ?? page);
    } catch (err: any) {
      console.error('[VisitasVigilanciaService] Error al cargar visitas de hoy:', err);
      this.errorMessage.set(err?.error?.error || 'No se pudieron cargar las visitas de hoy.');
    } finally {
      this.isLoading.set(false);
    }
  }

  /**
   * Valida un código de acceso escaneado o digitado por el guardia
   * (GET /api/visitas/codigo/{codigo})
   */
  async validarCodigo(codigo: string): Promise<VisitaVigilancia> {
    return firstValueFrom(
      this.apiService.get<VisitaVigilancia>(`/api/visitas/codigo/${encodeURIComponent(codigo.trim())}`, undefined, undefined, 'visitas')
    );
  }

  /**
   * Registra la entrada de una visita y notifica al residente
   * (POST /api/visitas/{id}/entrada)
   */
  async registrarEntrada(id: string): Promise<VisitaVigilancia> {
    const actualizada = await firstValueFrom(
      this.apiService.post<VisitaVigilancia>(`/api/visitas/${id}/entrada`, {}, undefined, 'visitas')
    );
    this.reemplazar(id, actualizada);
    return actualizada;
  }

  /**
   * Registra la salida de una visita
   * (POST /api/visitas/{id}/salida)
   */
  async registrarSalida(id: string): Promise<VisitaVigilancia> {
    const actualizada = await firstValueFrom(
      this.apiService.post<VisitaVigilancia>(`/api/visitas/${id}/salida`, {}, undefined, 'visitas')
    );
    this.reemplazar(id, actualizada);
    return actualizada;
  }

  private reemplazar(id: string, actualizada: VisitaVigilancia): void {
    this.items.update(lista => lista.map(v => (v.id === id ? { ...v, ...actualizada } : v)));
  }
}
