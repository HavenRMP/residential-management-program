import { Injectable, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import { ActualizarVisitaDto, CrearVisitaDto, EstadoVisita, Visita } from '../models/visita.model';

@Injectable({
  providedIn: 'root'
})
export class VisitasService {
  private readonly apiService = inject(ApiService);

  readonly PAGE_SIZE = 10;

  readonly items = signal<Visita[]>([]);
  readonly totalCount = signal<number>(0);
  readonly page = signal<number>(1);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  /**
   * Carga las visitas de la vivienda del residente, de la más reciente a la más antigua
   * (GET /api/visitas/mis-visitas)
   */
  async cargar(estado?: EstadoVisita | null, page: number = 1): Promise<void> {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      let params = new HttpParams().set('page', page.toString()).set('pageSize', this.PAGE_SIZE.toString());
      if (estado) {
        params = params.set('estado', estado);
      }
      const response = await firstValueFrom(
        this.apiService.get<any>('/api/visitas/mis-visitas', params, undefined, 'visitas')
      );
      this.items.set(extractPagedItems<Visita>(response));
      this.totalCount.set(response?.totalCount ?? this.items().length);
      this.page.set(response?.page ?? page);
    } catch (err: any) {
      console.error('[VisitasService] Error al cargar visitas:', err);
      this.errorMessage.set(err?.error?.error || 'No se pudieron cargar las visitas.');
    } finally {
      this.isLoading.set(false);
    }
  }

  /**
   * Programa una visita y devuelve el código de acceso generado
   * (POST /api/visitas)
   */
  async crear(dto: CrearVisitaDto): Promise<Visita> {
    return firstValueFrom(this.apiService.post<Visita>('/api/visitas', dto, undefined, 'visitas'));
  }

  /**
   * Edita solo los campos enviados de una visita programada
   * (PUT /api/visitas/{id})
   */
  async actualizar(id: string, dto: ActualizarVisitaDto): Promise<Visita> {
    const actualizada = await firstValueFrom(
      this.apiService.put<Visita>(`/api/visitas/${id}`, dto, undefined, 'visitas')
    );
    this.items.update(lista => lista.map(v => (v.id === id ? { ...v, ...actualizada } : v)));
    return actualizada;
  }

  /**
   * Anula una visita programada
   * (POST /api/visitas/{id}/cancelar)
   */
  async cancelar(id: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/visitas/${id}/cancelar`, {}, undefined, 'visitas'));
    this.items.update(lista => lista.map(v => (v.id === id ? { ...v, estado: 'cancelada' as EstadoVisita } : v)));
  }
}
