import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import {
  Paquete,
  ServicioPaqueteria,
  estadoEfectivoPaquete,
  ordenarPaquetesPendientes,
  ordenarPaquetesRecientesPrimero,
  paqueteEsPendiente
} from '../models/paquete.model';

const POR_PAGINA = 50;
/** Tope de seguridad: 10 páginas son 500 paquetes de una misma persona */
const MAX_PAGINAS = 10;

@Injectable({
  providedIn: 'root'
})
export class PaqueteriaService {
  private readonly apiService = inject(ApiService);

  readonly items = signal<Paquete[]>([]);
  readonly servicios = signal<ServicioPaqueteria[]>([]);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  /** Esperados y en caseta; los que ya están en caseta primero porque hay que ir por ellos */
  readonly pendientes = computed(() => ordenarPaquetesPendientes(this.items().filter(p => paqueteEsPendiente(p))));
  /** Entregados, cancelados, vencidos y devueltos, del más reciente al más antiguo */
  readonly historial = computed(() => ordenarPaquetesRecientesPrimero(this.items().filter(p => !paqueteEsPendiente(p))));
  /** Paquetes que ya llegaron a caseta y esperan a que los recojan */
  readonly enCaseta = computed(() => this.items().filter(p => estadoEfectivoPaquete(p) === 'recibido'));

  private ultimaPeticion = 0;

  /**
   * Todos los paquetes del residente. El backend solo filtra por un estado a la vez, así que se piden todas las
   * páginas y la pantalla los reparte entre pendientes e historial. (GET /api/paqueteria/mis-paquetes)
   */
  async cargar(): Promise<void> {
    // Una respuesta lenta de una carga anterior no debe pisar la más reciente
    const peticion = ++this.ultimaPeticion;
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      const porId = new Map<string, Paquete>();
      for (let page = 1; page <= MAX_PAGINAS; page++) {
        const params = new HttpParams().set('page', page.toString()).set('pageSize', POR_PAGINA.toString());
        const response = await firstValueFrom(
          this.apiService.get<any>('/api/paqueteria/mis-paquetes', params, undefined, 'visitas')
        );
        if (peticion !== this.ultimaPeticion) return;
        const pagina = extractPagedItems<Paquete>(response);
        pagina.forEach(p => porId.set(p.id, p));
        const total = response?.totalCount ?? porId.size;
        if (pagina.length === 0 || porId.size >= total) break;
      }
      this.items.set([...porId.values()]);
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[PaqueteriaService] Error al cargar los paquetes:', err);
      this.errorMessage.set(err?.error?.error || 'No se pudieron cargar tus paquetes.');
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }

  /** Empresas de paquetería disponibles para el aviso. Si falla queda vacío y el formulario deja escribir la empresa. */
  async cargarServicios(): Promise<void> {
    try {
      const response = await firstValueFrom(
        this.apiService.get<any>('/api/paqueteria/servicios', undefined, undefined, 'visitas')
      );
      this.servicios.set(extractPagedItems<ServicioPaqueteria>(response).filter(s => s.activo));
    } catch (err: any) {
      console.error('[PaqueteriaService] Error al cargar las empresas de paquetería:', err);
      this.servicios.set([]);
    }
  }

  /**
   * Cuántos paquetes esperan en caseta, sin traer la lista (una sola consulta de un elemento).
   * Devuelve 0 si falla: es solo un aviso y no debe romper el portal.
   */
  async contarEnCaseta(): Promise<number> {
    try {
      const params = new HttpParams().set('page', '1').set('pageSize', '1').set('estado', 'recibido');
      const response = await firstValueFrom(
        this.apiService.get<any>('/api/paqueteria/mis-paquetes', params, undefined, 'visitas')
      );
      return response?.totalCount ?? extractPagedItems<Paquete>(response).length;
    } catch {
      return 0;
    }
  }
}
