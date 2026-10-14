import { Injectable, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import {
  AreaComun,
  CrearBloqueoDto,
  FiltrosReservasAdmin,
  GuardarAreaDto,
  NoShow,
  Reserva,
  ResultadoBloqueo,
  normalizarReserva
} from '../models/reserva.model';

/**
 * Administración de reservas: ver y resolver las solicitudes del condominio, dar de alta y mantener las áreas,
 * bloquear fechas y consultar las inasistencias. Solo para el administrador.
 */
@Injectable({
  providedIn: 'root'
})
export class ReservasAdminService {
  private readonly apiService = inject(ApiService);

  readonly PAGE_SIZE = 20;

  readonly reservas = signal<Reserva[]>([]);
  readonly total = signal<number>(0);
  readonly page = signal<number>(1);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  /** Todas las áreas, también las dadas de baja */
  readonly areas = signal<AreaComun[]>([]);
  readonly isLoadingAreas = signal<boolean>(false);
  readonly errorAreas = signal<string | null>(null);

  readonly noShows = signal<NoShow[]>([]);
  readonly noShowsTotal = signal<number>(0);
  readonly noShowsPage = signal<number>(1);
  readonly isLoadingNoShows = signal<boolean>(false);
  readonly errorNoShows = signal<string | null>(null);

  private ultimaPeticion = 0;
  private ultimaPeticionNoShows = 0;

  /** Reservas y bloqueos del condominio, filtrables por estado, área y fechas (GET /api/admin/reservas) */
  async cargarReservas(filtros: FiltrosReservasAdmin = {}, page: number = 1): Promise<void> {
    // Una respuesta lenta de otros filtros no debe pisar la de los más recientes
    const peticion = ++this.ultimaPeticion;
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      let params = new HttpParams().set('page', page.toString()).set('pageSize', this.PAGE_SIZE.toString());
      if (filtros.estado) params = params.set('estado', filtros.estado);
      if (filtros.areaId) params = params.set('areaId', filtros.areaId);
      if (filtros.from) params = params.set('from', filtros.from);
      if (filtros.to) params = params.set('to', filtros.to);
      const response = await firstValueFrom(this.apiService.get<any>('/api/admin/reservas', params, undefined, 'reservas'));
      if (peticion !== this.ultimaPeticion) return;
      const items = extractPagedItems<Reserva>(response).map(normalizarReserva);
      this.reservas.set(items);
      this.total.set(response?.totalCount ?? items.length);
      this.page.set(response?.page ?? page);
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[ReservasAdminService] Error al cargar las reservas:', err);
      this.errorMessage.set(
        err?.status === 403
          ? 'Tu cuenta no tiene permiso para administrar las reservas.'
          : err?.error?.error || 'No se pudieron cargar las reservas.'
      );
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }

  /** Todas las áreas del condominio, activas o no (GET /api/areas; el administrador las ve todas) */
  async cargarAreas(): Promise<void> {
    this.isLoadingAreas.set(true);
    this.errorAreas.set(null);
    try {
      const params = new HttpParams().set('page', '1').set('pageSize', '100');
      const response = await firstValueFrom(this.apiService.get<any>('/api/areas', params, undefined, 'reservas'));
      this.areas.set(extractPagedItems<AreaComun>(response));
    } catch (err: any) {
      console.error('[ReservasAdminService] Error al cargar las áreas:', err);
      this.errorAreas.set(err?.error?.error || 'No se pudieron cargar las áreas comunes.');
    } finally {
      this.isLoadingAreas.set(false);
    }
  }

  /** Reservas que se marcaron como no utilizadas (GET /api/admin/reservas/no-shows) */
  async cargarNoShows(page: number = 1): Promise<void> {
    const peticion = ++this.ultimaPeticionNoShows;
    this.isLoadingNoShows.set(true);
    this.errorNoShows.set(null);
    try {
      const params = new HttpParams().set('page', page.toString()).set('pageSize', this.PAGE_SIZE.toString());
      const response = await firstValueFrom(this.apiService.get<any>('/api/admin/reservas/no-shows', params, undefined, 'reservas'));
      if (peticion !== this.ultimaPeticionNoShows) return;
      const items = extractPagedItems<NoShow>(response);
      this.noShows.set(items);
      this.noShowsTotal.set(response?.totalCount ?? items.length);
      this.noShowsPage.set(response?.page ?? page);
    } catch (err: any) {
      if (peticion !== this.ultimaPeticionNoShows) return;
      console.error('[ReservasAdminService] Error al cargar las inasistencias:', err);
      this.errorNoShows.set(err?.error?.error || 'No se pudo cargar el historial de inasistencias.');
    } finally {
      if (peticion === this.ultimaPeticionNoShows) this.isLoadingNoShows.set(false);
    }
  }

  /** Aprueba una solicitud que espera al administrador (POST /api/admin/reservas/{id}/aprobar) */
  async aprobar(id: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/admin/reservas/${id}/aprobar`, {}, undefined, 'reservas'));
  }

  /** Rechaza una solicitud; el motivo es obligatorio (POST /api/admin/reservas/{id}/rechazar) */
  async rechazar(id: string, motivo: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/admin/reservas/${id}/rechazar`, { motivo: motivo.trim() }, undefined, 'reservas'));
  }

  /** Cancela una reserva pendiente o aprobada; el motivo es obligatorio (POST /api/admin/reservas/{id}/cancelar) */
  async cancelar(id: string, motivo: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/admin/reservas/${id}/cancelar`, { motivo: motivo.trim() }, undefined, 'reservas'));
  }

  /** Marca como no utilizada una reserva aprobada que ya terminó (POST /api/admin/reservas/{id}/no-utilizada) */
  async marcarNoUtilizada(id: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/admin/reservas/${id}/no-utilizada`, {}, undefined, 'reservas'));
  }

  /** Da de alta un área común (POST /api/areas) */
  async crearArea(dto: GuardarAreaDto): Promise<AreaComun> {
    const creada = await firstValueFrom(this.apiService.post<AreaComun>('/api/areas', dto, undefined, 'reservas'));
    this.areas.update(lista => [...lista.filter(a => a.id !== creada.id), creada]);
    return creada;
  }

  /** Corrige el nombre, la descripción o el horario de un área (PUT /api/areas/{id}) */
  async actualizarArea(id: string, dto: Partial<GuardarAreaDto>): Promise<AreaComun> {
    const actualizada = await firstValueFrom(this.apiService.put<AreaComun>(`/api/areas/${id}`, dto, undefined, 'reservas'));
    this.areas.update(lista => lista.map(a => (a.id === id ? { ...a, ...actualizada } : a)));
    return actualizada;
  }

  /** Da de baja un área: deja de poder reservarse (POST /api/areas/{id}/baja) */
  async darDeBaja(id: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/areas/${id}/baja`, {}, undefined, 'reservas'));
    this.areas.update(lista => lista.map(a => (a.id === id ? { ...a, activo: false } : a)));
  }

  /** Vuelve a habilitar un área dada de baja (POST /api/areas/{id}/reactivar) */
  async reactivar(id: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/areas/${id}/reactivar`, {}, undefined, 'reservas'));
    this.areas.update(lista => lista.map(a => (a.id === id ? { ...a, activo: true } : a)));
  }

  /**
   * Bloquea un área entre dos instantes (mantenimiento, evento del condominio…). Las reservas que caigan dentro se cancelan
   * y el resultado dice cuántas fueron. (POST /api/admin/bloqueos)
   */
  async crearBloqueo(dto: CrearBloqueoDto): Promise<ResultadoBloqueo> {
    return firstValueFrom(this.apiService.post<ResultadoBloqueo>('/api/admin/bloqueos', { ...dto, motivo: dto.motivo.trim() }, undefined, 'reservas'));
  }
}
