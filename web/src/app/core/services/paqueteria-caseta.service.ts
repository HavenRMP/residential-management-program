import { Injectable, computed, inject, signal } from '@angular/core';
import { HttpParams } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import {
  EstadoPaquete,
  Paquete,
  RecibirPaqueteDto,
  ordenarEsperadosParaCaseta,
  ordenarPaquetesEnCaseta,
  ordenarPaquetesRecientesPrimero
} from '../models/paquete.model';
import { mensajeAmigable } from '../utils/api-errors.util';

const POR_PAGINA = 100;
/** Tope de seguridad: 10 páginas son 1,000 paquetes en una misma lista */
const MAX_PAGINAS = 10;

/** Filtros del historial: un solo estado (el backend no admite varios) y un periodo opcional en ISO */
export interface FiltrosHistorialPaquetes {
  estado: EstadoPaquete;
  desde?: string;
  hasta?: string;
}

/** Una lista de la pantalla con su propio estado de carga, para que fallar una no tape a las demás */
export class ListaPaquetes {
  readonly items = signal<Paquete[]>([]);
  readonly cargando = signal<boolean>(false);
  readonly error = signal<string | null>(null);
  /** Solo la respuesta de la última petición se aplica: una lenta de antes no debe pisar a la nueva */
  ultimaPeticion = 0;
}

/**
 * Paquetería desde la caseta (Vigilancia y Administración): lo que se espera, lo que ya está en caseta
 * esperando a que lo recojan, el historial, y las acciones de recibir y entregar.
 */
@Injectable({
  providedIn: 'root'
})
export class PaqueteriaCasetaService {
  private readonly apiService = inject(ApiService);

  readonly esperados = new ListaPaquetes();
  readonly enCaseta = new ListaPaquetes();
  readonly historial = new ListaPaquetes();

  /** Los que llegan hoy primero */
  readonly esperadosOrdenados = computed(() => ordenarEsperadosParaCaseta(this.esperados.items()));
  /** Los que llevan más tiempo esperando primero */
  readonly enCasetaOrdenados = computed(() => ordenarPaquetesEnCaseta(this.enCaseta.items()));
  readonly historialOrdenado = computed(() => ordenarPaquetesRecientesPrimero(this.historial.items()));

  /** Avisos de los residentes que todavía no llegan (GET /api/paqueteria/esperados) */
  cargarEsperados(): Promise<void> {
    return this.cargarLista(this.esperados, '/api/paqueteria/esperados', new HttpParams(), 'No se pudieron cargar los paquetes esperados.');
  }

  /** Paquetes ya recibidos que nadie ha recogido (GET /api/paqueteria/inventario) */
  cargarEnCaseta(): Promise<void> {
    return this.cargarLista(this.enCaseta, '/api/paqueteria/inventario', new HttpParams(), 'No se pudieron cargar los paquetes que están en caseta.');
  }

  /** Paquetes de un estado (y periodo) ya resueltos (GET /api/paqueteria/historico) */
  cargarHistorial(filtros: FiltrosHistorialPaquetes): Promise<void> {
    let params = new HttpParams().set('estado', filtros.estado);
    if (filtros.desde) params = params.set('desde', filtros.desde);
    if (filtros.hasta) params = params.set('hasta', filtros.hasta);
    return this.cargarLista(this.historial, '/api/paqueteria/historico', params, 'No se pudo cargar el historial de paquetes.');
  }

  /**
   * Recibe un paquete en caseta (POST /api/paqueteria/recepcion). Con `paqueteId` es un aviso del residente;
   * sin él es un paquete que nadie avisó. El backend notifica al residente.
   */
  async recibir(dto: RecibirPaqueteDto): Promise<Paquete> {
    const recibido = await firstValueFrom(this.apiService.post<Paquete>('/api/paqueteria/recepcion', dto, undefined, 'visitas'));
    if (dto.paqueteId) this.esperados.items.update(lista => lista.filter(p => p.id !== dto.paqueteId));
    this.enCaseta.items.update(lista => [recibido, ...lista.filter(p => p.id !== recibido.id)]);
    return recibido;
  }

  /** Entrega un paquete a quien lo recoge y lo saca de caseta (POST /api/paqueteria/{id}/entrega) */
  async entregar(id: string, entregadoANombre: string): Promise<Paquete> {
    const entregado = await firstValueFrom(
      this.apiService.post<Paquete>(`/api/paqueteria/${id}/entrega`, { entregadoANombre: entregadoANombre.trim() }, undefined, 'visitas')
    );
    this.enCaseta.items.update(lista => lista.filter(p => p.id !== id));
    return entregado;
  }

  /** Quita un paquete que otra persona ya cambió, para que no se vuelva a intentar sobre él */
  quitarDeListas(id: string): void {
    this.esperados.items.update(lista => lista.filter(p => p.id !== id));
    this.enCaseta.items.update(lista => lista.filter(p => p.id !== id));
  }

  /** Recorre todas las páginas de una consulta y reemplaza la lista por lo recibido, sin repetir paquetes */
  private async cargarLista(lista: ListaPaquetes, ruta: string, base: HttpParams, mensajeError: string): Promise<void> {
    const peticion = ++lista.ultimaPeticion;
    lista.cargando.set(true);
    lista.error.set(null);
    try {
      const porId = new Map<string, Paquete>();
      for (let pagina = 1; pagina <= MAX_PAGINAS; pagina++) {
        const params = base.set('page', pagina.toString()).set('pageSize', POR_PAGINA.toString());
        const respuesta = await firstValueFrom(this.apiService.get<any>(ruta, params, undefined, 'visitas'));
        if (peticion !== lista.ultimaPeticion) return;
        const lote = extractPagedItems<Paquete>(respuesta);
        lote.forEach(p => porId.set(p.id, p));
        const total = respuesta?.totalCount ?? porId.size;
        if (lote.length === 0 || porId.size >= total) break;
      }
      lista.items.set([...porId.values()]);
    } catch (err: any) {
      if (peticion !== lista.ultimaPeticion) return;
      console.error(`[PaqueteriaCasetaService] Error al consultar ${ruta}:`, err);
      lista.error.set(mensajeAmigable(err, mensajeError));
    } finally {
      if (peticion === lista.ultimaPeticion) lista.cargando.set(false);
    }
  }
}
