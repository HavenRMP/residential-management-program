import { Injectable, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';
import { AuthService } from './auth.service';
import {
  Aviso,
  AvisoApi,
  CrearAvisoDto,
  ActualizarAvisoDto,
  mapAvisoApiToAviso
} from '../models/aviso.model';

@Injectable({
  providedIn: 'root'
})
export class AvisosService {
  private readonly apiService = inject(ApiService);
  private readonly authService = inject(AuthService);

  readonly avisos = signal<Aviso[]>([]);
  readonly vigentes = signal<Aviso[]>([]);
  readonly expirados = signal<Aviso[]>([]);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  private currentCondominioId = signal<string | null>(null);

  /**
   * Consulta los avisos en el microservicio Avisos.Api.
   * Si es administrador, también consulta el histórico.
   */
  async cargarAvisos(condominioId?: string | null): Promise<Aviso[]> {
    const condId = condominioId || this.authService.currentUser()?.condominioId || 'global';
    this.currentCondominioId.set(condId);
    this.isLoading.set(true);
    this.errorMessage.set(null);

    const storageKey = `haven_avisos_${condId}`;

    try {
      // 1. Obtener avisos vigentes desde Avisos.Api (GET /api/avisos)
      const resVigentes = await firstValueFrom(
        this.apiService.get<AvisoApi[]>('/api/avisos')
      ).catch(err => {
        console.warn('[AvisosService] Error al obtener /api/avisos:', err);
        return null;
      });

      let itemsVigentes: Aviso[] = [];
      if (Array.isArray(resVigentes)) {
        itemsVigentes = resVigentes.map(a => mapAvisoApiToAviso(a));
        this.vigentes.set(itemsVigentes);
      }

      // 2. Si el usuario es administrador, consultar el histórico (GET /api/avisos/historico)
      const rol = this.authService.currentUser()?.rol;
      let itemsHistorico: Aviso[] = [];

      if (rol === 'administrador') {
        const resHistorico = await firstValueFrom(
          this.apiService.get<AvisoApi[]>('/api/avisos/historico')
        ).catch(err => {
          console.warn('[AvisosService] Error al obtener /api/avisos/historico:', err);
          return null;
        });

        if (Array.isArray(resHistorico)) {
          itemsHistorico = resHistorico.map(a => mapAvisoApiToAviso(a));
          const ahora = Date.now();
          const itemsExp = itemsHistorico.filter(a => {
            const expTime = new Date(a.fechaExpiracion).getTime();
            return !a.activo || expTime < ahora || a.estado === 'expirado' || a.estado === 'eliminado';
          });
          this.expirados.set(itemsExp);
          this.avisos.set(itemsHistorico);
        }
      }

      // Si obtuvimos datos del backend, guardamos respaldo en cache
      const todosAvisos = itemsHistorico.length > 0 ? itemsHistorico : itemsVigentes;
      if (todosAvisos.length > 0 || Array.isArray(resVigentes)) {
        this.guardarEnStorage(condId, todosAvisos);
        if (itemsHistorico.length === 0) {
          this.avisos.set(itemsVigentes);
        }
        return todosAvisos;
      }

      // Fallback a localStorage si el backend aún no responde o hay cold start
      return this.cargarDesdeStorage(storageKey);
    } catch (err: any) {
      console.error('[AvisosService] Fallo de conexión con Avisos.Api:', err);
      this.errorMessage.set('No se pudo sincronizar con el servicio de avisos.');
      return this.cargarDesdeStorage(storageKey);
    } finally {
      this.isLoading.set(false);
    }
  }

  /**
   * Publica un nuevo aviso en el condominio del administrador (POST /api/avisos)
   */
  async crear(dto: CrearAvisoDto, condominioId?: string | null): Promise<Aviso> {
    this.isLoading.set(true);
    this.errorMessage.set(null);

    const body: any = {
      titulo: dto.titulo.trim(),
      contenido: dto.contenido.trim()
    };

    if (dto.fecha_expiracion || dto.fechaExpiracion) {
      body.fecha_expiracion = dto.fecha_expiracion || dto.fechaExpiracion;
    } else {
      const dias = dto.duracion_dias || dto.diasVigencia || 7;
      body.duracion_dias = dias;
    }

    try {
      const response = await firstValueFrom(
        this.apiService.post<AvisoApi>('/api/avisos', body)
      );

      const nuevoAviso = mapAvisoApiToAviso(response);
      const actualizadosVigentes = [nuevoAviso, ...this.vigentes()];
      const actualizadosTodos = [nuevoAviso, ...this.avisos()];

      this.vigentes.set(actualizadosVigentes);
      this.avisos.set(actualizadosTodos);

      const condId = condominioId || this.currentCondominioId() || 'global';
      this.guardarEnStorage(condId, actualizadosTodos);

      return nuevoAviso;
    } catch (err: any) {
      console.error('[AvisosService] Error al crear aviso en Avisos.Api:', err);
      const msg = err?.error?.error || err?.error?.message || err?.message || 'Error al publicar aviso.';
      this.errorMessage.set(msg);
      throw err;
    } finally {
      this.isLoading.set(false);
    }
  }

  /**
   * Modifica un aviso existente (PUT /api/avisos/{id})
   */
  async actualizar(id: string, dto: ActualizarAvisoDto): Promise<Aviso | null> {
    this.isLoading.set(true);
    this.errorMessage.set(null);

    const body: any = {};
    if (dto.titulo !== undefined) body.titulo = dto.titulo.trim();
    if (dto.contenido !== undefined) body.contenido = dto.contenido.trim();

    if (dto.fecha_expiracion || dto.fechaExpiracion) {
      body.fecha_expiracion = dto.fecha_expiracion || dto.fechaExpiracion;
    } else if (dto.duracion_dias || dto.diasVigencia) {
      body.duracion_dias = dto.duracion_dias || dto.diasVigencia;
    }

    try {
      const response = await firstValueFrom(
        this.apiService.put<AvisoApi>(`/api/avisos/${id}`, body)
      );

      const modificado = mapAvisoApiToAviso(response);

      // Actualizar en listas en memoria
      const actualizarLista = (lista: Aviso[]) =>
        lista.map(a => (a.id === id ? { ...a, ...modificado } : a));

      this.vigentes.set(actualizarLista(this.vigentes()));
      this.expirados.set(actualizarLista(this.expirados()));
      const todos = actualizarLista(this.avisos());
      this.avisos.set(todos);

      const condId = this.currentCondominioId() || 'global';
      this.guardarEnStorage(condId, todos);

      return modificado;
    } catch (err: any) {
      console.error('[AvisosService] Error al actualizar aviso:', err);
      const msg = err?.error?.error || err?.error?.message || err?.message || 'Error al actualizar aviso.';
      this.errorMessage.set(msg);
      throw err;
    } finally {
      this.isLoading.set(false);
    }
  }

  /**
   * Da de baja lógica un aviso (DELETE /api/avisos/{id})
   */
  async eliminar(id: string): Promise<boolean> {
    this.isLoading.set(true);
    this.errorMessage.set(null);

    try {
      await firstValueFrom(
        this.apiService.delete<void>(`/api/avisos/${id}`)
      );

      // Remover de vigentes y marcar como inactivo
      const vigentesActualizados = this.vigentes().filter(a => a.id !== id);
      this.vigentes.set(vigentesActualizados);

      const avisoEliminado = this.avisos().find(a => a.id === id);
      if (avisoEliminado) {
        const inactivo: Aviso = { ...avisoEliminado, activo: false, estado: 'eliminado' };
        this.expirados.set([inactivo, ...this.expirados().filter(a => a.id !== id)]);
        this.avisos.set(this.avisos().map(a => (a.id === id ? inactivo : a)));
      }

      const condId = this.currentCondominioId() || 'global';
      this.guardarEnStorage(condId, this.avisos());

      return true;
    } catch (err: any) {
      console.error('[AvisosService] Error al eliminar aviso:', err);
      const msg = err?.error?.error || err?.error?.message || err?.message || 'Error al eliminar aviso.';
      this.errorMessage.set(msg);
      throw err;
    } finally {
      this.isLoading.set(false);
    }
  }

  private cargarDesdeStorage(storageKey: string): Aviso[] {
    const cached = localStorage.getItem(storageKey);
    if (cached) {
      try {
        const parsed = JSON.parse(cached);
        if (Array.isArray(parsed)) {
          const ahora = Date.now();
          const items: Aviso[] = parsed.map(a => mapAvisoApiToAviso(a));
          this.avisos.set(items);
          this.vigentes.set(items.filter(a => a.activo !== false && new Date(a.fechaExpiracion).getTime() >= ahora));
          this.expirados.set(items.filter(a => a.activo === false || new Date(a.fechaExpiracion).getTime() < ahora));
          return items;
        }
      } catch {
        // Ignorar error de parsing
      }
    }
    return [];
  }

  private guardarEnStorage(condominioId: string, lista: Aviso[]): void {
    try {
      localStorage.setItem(`haven_avisos_${condominioId}`, JSON.stringify(lista));
    } catch (err) {
      console.warn('[AvisosService] Error al guardar en localStorage:', err);
    }
  }
}
