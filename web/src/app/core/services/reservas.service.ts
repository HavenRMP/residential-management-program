import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import {
  AreaComun,
  CrearReservaDto,
  PendienteTitular,
  Reserva,
  ReservaCalendario,
  normalizarReserva,
  ordenarHistorial,
  ordenarProximas,
  reservaEsConfirmable,
  reservaEsProxima
} from '../models/reserva.model';

const POR_PAGINA = 50;
/** Tope de seguridad: 10 páginas son 500 reservas de una misma persona */
const MAX_PAGINAS = 10;

/**
 * Reservas de áreas comunes desde el portal del residente: ver áreas y disponibilidad, solicitar, confirmar asistencia,
 * cancelar y, si es titular, aprobar o rechazar las solicitudes de sus sub-usuarios.
 */
@Injectable({
  providedIn: 'root'
})
export class ReservasService {
  private readonly apiService = inject(ApiService);

  readonly areas = signal<AreaComun[]>([]);
  readonly isLoadingAreas = signal<boolean>(false);
  readonly errorAreas = signal<string | null>(null);

  readonly mias = signal<Reserva[]>([]);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  /** Solicitudes de sub-usuarios que este titular debe resolver */
  readonly porAprobar = signal<PendienteTitular[]>([]);

  /** Vivas y aún por venir: lo que hay que esperar o atender, la más cercana primero */
  readonly proximas = computed(() => ordenarProximas(this.mias().filter(r => reservaEsProxima(r))));
  /** Ya terminaron o se cerraron (rechazadas, canceladas, no utilizadas), la más reciente primero */
  readonly historial = computed(() => ordenarHistorial(this.mias().filter(r => !reservaEsProxima(r))));

  /** Lo que espera una acción de la persona: solicitudes por aprobar y reservas listas para confirmar asistencia */
  readonly accionesPendientes = computed(() => this.porAprobar().length + this.mias().filter(r => reservaEsConfirmable(r)).length);

  private ultimaPeticion = 0;

  /** Áreas activas del condominio (GET /api/areas) */
  async cargarAreas(): Promise<void> {
    this.isLoadingAreas.set(true);
    this.errorAreas.set(null);
    try {
      const params = new HttpParams().set('soloActivas', 'true').set('page', '1').set('pageSize', '100');
      const response = await firstValueFrom(this.apiService.get<any>('/api/areas', params, undefined, 'reservas'));
      this.areas.set(extractPagedItems<AreaComun>(response).filter(a => a.activo !== false));
    } catch (err: any) {
      console.error('[ReservasService] Error al cargar las áreas:', err);
      this.errorAreas.set(err?.error?.error || 'No se pudieron cargar las áreas comunes.');
    } finally {
      this.isLoadingAreas.set(false);
    }
  }

  /** Todas las reservas de la persona, de todas las páginas (GET /api/reservas/mias) */
  async cargarMias(): Promise<void> {
    // Una respuesta lenta de una carga anterior no debe pisar la más reciente
    const peticion = ++this.ultimaPeticion;
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      const porId = new Map<string, Reserva>();
      for (let page = 1; page <= MAX_PAGINAS; page++) {
        const params = new HttpParams().set('page', page.toString()).set('pageSize', POR_PAGINA.toString());
        const response = await firstValueFrom(this.apiService.get<any>('/api/reservas/mias', params, undefined, 'reservas'));
        if (peticion !== this.ultimaPeticion) return;
        const pagina = extractPagedItems<Reserva>(response).map(normalizarReserva);
        pagina.forEach(r => porId.set(r.id, r));
        const total = response?.totalCount ?? porId.size;
        if (pagina.length === 0 || porId.size >= total) break;
      }
      this.mias.set([...porId.values()]);
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[ReservasService] Error al cargar las reservas:', err);
      this.errorMessage.set(err?.error?.error || 'No se pudieron cargar tus reservas.');
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }

  /**
   * Solicitudes de sub-usuarios por resolver (GET /api/reservas/por-aprobar-titular).
   * Solo el titular tiene; para cualquier otra persona queda vacío sin molestar con un error.
   */
  async cargarPorAprobar(): Promise<void> {
    try {
      const params = new HttpParams().set('page', '1').set('pageSize', POR_PAGINA.toString());
      const response = await firstValueFrom(this.apiService.get<any>('/api/reservas/por-aprobar-titular', params, undefined, 'reservas'));
      this.porAprobar.set(extractPagedItems<PendienteTitular>(response));
    } catch {
      this.porAprobar.set([]);
    }
  }

  /**
   * Lo que ocupa un área entre dos instantes: reservas pendientes y aprobadas de cualquier casa y bloqueos.
   * No toca el estado compartido; el backend admite hasta 62 días por consulta.
   * (GET /api/reservas/calendario)
   */
  async calendario(areaId: string, desde: string, hasta: string): Promise<ReservaCalendario[]> {
    const todos: ReservaCalendario[] = [];
    for (let page = 1; page <= MAX_PAGINAS; page++) {
      const params = new HttpParams()
        .set('from', desde)
        .set('to', hasta)
        .set('areaId', areaId)
        .set('page', page.toString())
        .set('pageSize', '100');
      const response = await firstValueFrom(this.apiService.get<any>('/api/reservas/calendario', params, undefined, 'reservas'));
      const lote = extractPagedItems<ReservaCalendario>(response).map(normalizarReserva);
      todos.push(...lote);
      if (lote.length < 100) break;
    }
    return todos;
  }

  /**
   * Pide una reserva. El backend decide a quién le toca aprobarla (al titular si la pide un sub-usuario, si no al administrador)
   * y valida horario, anticipación, duración y choques. (POST /api/reservas)
   */
  async solicitar(dto: CrearReservaDto): Promise<Reserva> {
    const creada = normalizarReserva(await firstValueFrom(this.apiService.post<Reserva>('/api/reservas', dto, undefined, 'reservas')));
    this.mias.update(lista => [creada, ...lista.filter(r => r.id !== creada.id)]);
    return creada;
  }

  /** Confirma la asistencia; si luego no se asiste cuenta como inasistencia (POST /api/reservas/{id}/confirmar) */
  async confirmar(id: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/reservas/${id}/confirmar`, {}, undefined, 'reservas'));
    // El backend deja la reserva "aprobada" y solo registra cuándo se confirmó
    this.mias.update(lista => lista.map(r => (r.id === id ? { ...r, confirmadaEn: new Date().toISOString() } : r)));
  }

  /** Cancela una reserva que aún no empieza; el motivo es opcional (POST /api/reservas/{id}/cancelar) */
  async cancelar(id: string, motivo?: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/reservas/${id}/cancelar`, this.cuerpoMotivo(motivo), undefined, 'reservas'));
    this.cambiarEstado(id, 'CANCELADA');
  }

  /** El titular aprueba la solicitud de un sub-usuario; pasa a esperar al administrador (POST /api/reservas/{id}/aprobar-titular) */
  async aprobarComoTitular(id: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/reservas/${id}/aprobar-titular`, {}, undefined, 'reservas'));
    this.porAprobar.update(lista => lista.filter(p => p.id !== id));
  }

  /** El titular rechaza la solicitud de un sub-usuario; el motivo es opcional (POST /api/reservas/{id}/rechazar-titular) */
  async rechazarComoTitular(id: string, motivo?: string): Promise<void> {
    await firstValueFrom(this.apiService.post<void>(`/api/reservas/${id}/rechazar-titular`, this.cuerpoMotivo(motivo), undefined, 'reservas'));
    this.porAprobar.update(lista => lista.filter(p => p.id !== id));
  }

  private cuerpoMotivo(motivo?: string): { motivo?: string } {
    return motivo?.trim() ? { motivo: motivo.trim() } : {};
  }

  private cambiarEstado(id: string, estado: Reserva['estado']): void {
    this.mias.update(lista => lista.map(r => (r.id === id ? { ...r, estado } : r)));
  }
}
