import { Injectable, inject, signal, computed } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';
import { Notificacion, NotificacionApi, mapNotificacionApiToNotificacion } from '../models/notificacion.model';

@Injectable({
  providedIn: 'root'
})
export class NotificacionesService {
  private readonly apiService = inject(ApiService);

  readonly notificaciones = signal<Notificacion[]>([]);
  readonly contadorNoLeidas = signal<number>(0);
  readonly isLoading = signal<boolean>(false);

  readonly hayNoLeidas = computed(() => this.contadorNoLeidas() > 0);

  /**
   * Carga las últimas notificaciones del usuario (GET /api/notificaciones)
   */
  async cargarNotificaciones(): Promise<void> {
    this.isLoading.set(true);
    try {
      const response = await firstValueFrom(
        this.apiService.get<NotificacionApi[]>('/api/notificaciones', undefined, undefined, 'usuarios')
      );
      this.notificaciones.set((response || []).map(mapNotificacionApiToNotificacion));
    } catch (err) {
      console.error('[NotificacionesService] Error al cargar notificaciones:', err);
    } finally {
      this.isLoading.set(false);
    }
  }

  /**
   * Carga el contador de notificaciones no leídas (GET /api/notificaciones/contador-no-leidas)
   */
  async cargarContador(): Promise<void> {
    try {
      const response = await firstValueFrom(
        this.apiService.get<{ count: number }>('/api/notificaciones/contador-no-leidas', undefined, undefined, 'usuarios')
      );
      this.contadorNoLeidas.set(response?.count ?? 0);
    } catch (err) {
      console.error('[NotificacionesService] Error al cargar contador de no leídas:', err);
    }
  }

  /**
   * Marca una notificación individual como leída (PATCH /api/notificaciones/{id}/leer)
   * Actualización optimista: refleja el cambio de inmediato en la UI.
   */
  async marcarComoLeida(id: string): Promise<void> {
    const yaEstabaLeida = this.notificaciones().find(n => n.id === id)?.leida;
    this.notificaciones.update(lista => lista.map(n => n.id === id ? { ...n, leida: true } : n));
    if (!yaEstabaLeida) {
      this.contadorNoLeidas.update(c => Math.max(0, c - 1));
    }

    try {
      await firstValueFrom(
        this.apiService.patch<void>(`/api/notificaciones/${id}/leer`, {}, undefined, 'usuarios')
      );
    } catch (err) {
      console.error('[NotificacionesService] Error al marcar notificación como leída:', err);
    }
  }

  /**
   * Marca todas las notificaciones del usuario como leídas (POST /api/notificaciones/marcar-todas)
   * Actualización optimista: refleja el cambio de inmediato en la UI.
   */
  async marcarTodasComoLeidas(): Promise<void> {
    this.notificaciones.update(lista => lista.map(n => ({ ...n, leida: true })));
    this.contadorNoLeidas.set(0);

    try {
      await firstValueFrom(
        this.apiService.post<void>('/api/notificaciones/marcar-todas', {}, undefined, 'usuarios')
      );
    } catch (err) {
      console.error('[NotificacionesService] Error al marcar todas las notificaciones como leídas:', err);
    }
  }
}
