import { Injectable, inject, signal, computed } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import {
  SubUsuarioItem,
  SubusuarioItemApi,
  InvitarSubusuarioDto,
  InvitacionRecibida,
  InvitacionRecibidaApi,
  RespuestaInvitacion,
  mapSubusuarioApiToItem,
  mapInvitacionApiToInvitacion
} from '../models/subusuario.model';

@Injectable({
  providedIn: 'root'
})
export class SubusuariosService {
  private readonly apiService = inject(ApiService);

  readonly MAX_SUBUSUARIOS = 2;
  readonly items = signal<SubUsuarioItem[]>([]);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  /** Invitaciones que el usuario actual recibió y todavía no responde */
  readonly invitacionesRecibidas = signal<InvitacionRecibida[]>([]);
  readonly isLoadingInvitaciones = signal<boolean>(false);

  private viviendaIdActual: number | null = null;

  /** Sub-usuarios activos o con invitación enviada pendiente (cuentan para el cupo) */
  readonly activos = computed(() => this.items().filter(i => i.activo));
  readonly pendientes = computed(() => this.items().filter(i => !i.activo));

  /** Cantidad de cupos libres (máximo 2 por vivienda) */
  readonly cuposDisponibles = computed(() => Math.max(0, this.MAX_SUBUSUARIOS - this.items().length));

  /**
   * Carga los sub-usuarios (activos e invitaciones enviadas pendientes) de una vivienda
   * (GET /api/subusuarios/mis-subusuarios)
   */
  async cargar(viviendaId: number): Promise<void> {
    this.viviendaIdActual = viviendaId;
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      const params = new HttpParams().set('viviendaId', viviendaId.toString());
      const response = await firstValueFrom(
        this.apiService.get<SubusuarioItemApi[]>('/api/subusuarios/mis-subusuarios', params, undefined, 'usuarios')
      );
      this.items.set((response || []).map(mapSubusuarioApiToItem));
    } catch (err: any) {
      console.error('[SubusuariosService] Error al cargar sub-usuarios:', err);
      this.errorMessage.set(err?.error?.error || 'No se pudieron cargar los sub-usuarios.');
    } finally {
      this.isLoading.set(false);
    }
  }

  /**
   * Genera una invitación de sub-usuario identificando al invitado por su correo
   * (POST /api/subusuarios/invitar)
   */
  async invitar(dto: InvitarSubusuarioDto): Promise<SubUsuarioItem> {
    if (this.cuposDisponibles() <= 0) {
      throw new Error('Has alcanzado el límite máximo de 2 sub-usuarios para esta vivienda.');
    }

    const body = {
      vivienda_id: dto.viviendaId,
      email: dto.email.trim(),
      parentesco: dto.parentesco.trim()
    };

    const response = await firstValueFrom(
      this.apiService.post<SubusuarioItemApi>('/api/subusuarios/invitar', body, undefined, 'usuarios')
    );
    const nuevo = mapSubusuarioApiToItem(response);
    this.items.update(lista => [nuevo, ...lista]);
    return nuevo;
  }

  /**
   * Revoca un sub-usuario activo o cancela una invitación enviada pendiente
   * (DELETE /api/subusuarios/{id})
   */
  async revocar(id: string, isInvitacion: boolean): Promise<void> {
    if (this.viviendaIdActual == null) {
      throw new Error('No se ha cargado la vivienda del sub-usuario a revocar.');
    }

    const params = new HttpParams()
      .set('viviendaId', this.viviendaIdActual.toString())
      .set('isInvitacion', isInvitacion.toString());

    await firstValueFrom(
      this.apiService.delete<void>(`/api/subusuarios/${id}?${params.toString()}`, undefined, 'usuarios')
    );

    this.items.update(lista => lista.filter(i => i.id !== id));
  }

  /**
   * Carga las invitaciones que otros titulares enviaron al usuario actual
   * (GET /api/subusuarios/mis-invitaciones). No depende de una vivienda:
   * el backend resuelve el destinatario a partir del token.
   */
  async cargarInvitacionesRecibidas(): Promise<void> {
    this.isLoadingInvitaciones.set(true);
    try {
      const response = await firstValueFrom(
        this.apiService.get<InvitacionRecibidaApi[]>('/api/subusuarios/mis-invitaciones', undefined, undefined, 'usuarios')
      );
      this.invitacionesRecibidas.set((response || []).map(mapInvitacionApiToInvitacion));
    } catch (err) {
      console.error('[SubusuariosService] Error al cargar invitaciones recibidas:', err);
    } finally {
      this.isLoadingInvitaciones.set(false);
    }
  }

  /**
   * Acepta o rechaza una invitación recibida
   * (POST /api/subusuarios/invitaciones/{id}/responder)
   */
  async responderInvitacion(id: string, respuesta: RespuestaInvitacion): Promise<void> {
    await firstValueFrom(
      this.apiService.post<{ message: string }>(`/api/subusuarios/invitaciones/${id}/responder`, { respuesta }, undefined, 'usuarios')
    );
    this.invitacionesRecibidas.update(lista => lista.filter(i => i.id !== id));
  }
}
