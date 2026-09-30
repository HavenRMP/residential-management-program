import { Injectable, inject, signal } from '@angular/core';
import { HttpParams } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import { ResidenteContacto, ViviendaConResidentes } from '../models/vivienda.model';
import { normalizarBusqueda } from '../utils/directorio-casas.util';

const POR_PAGINA = 100;
const MAX_PAGINAS = 20;

/**
 * Directorio de casas con sus residentes y teléfonos, para caseta (Administrador y Vigilancia).
 * Se carga completo una vez y se consulta en memoria.
 */
@Injectable({
  providedIn: 'root'
})
export class DirectorioCasasService {
  private readonly apiService = inject(ApiService);

  readonly casas = signal<ViviendaConResidentes[]>([]);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  private cargado = false;
  private enCurso: Promise<void> | null = null;

  /**
   * Carga todas las páginas de GET /api/viviendas/con-residentes.
   * Llamadas simultáneas comparten la misma petición; con `forzar` se vuelve a consultar.
   */
  cargar(forzar: boolean = false): Promise<void> {
    if (this.cargado && !forzar) return Promise.resolve();
    if (this.enCurso) return this.enCurso;

    this.enCurso = this.descargar().finally(() => (this.enCurso = null));
    return this.enCurso;
  }

  /** Residentes de una casa por su número, ya cargados. Vacío si el directorio aún no llega. */
  residentesDeCasa(numeroCasa: string): ResidenteContacto[] {
    const objetivo = normalizarBusqueda(numeroCasa);
    return this.casas().find(c => normalizarBusqueda(c.numeroCasa) === objetivo)?.residentes ?? [];
  }

  private async descargar(): Promise<void> {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      const todas: ViviendaConResidentes[] = [];
      const vistas = new Set<number>();

      for (let pagina = 1; pagina <= MAX_PAGINAS; pagina++) {
        const params = new HttpParams().set('page', pagina.toString()).set('pageSize', POR_PAGINA.toString());
        const respuesta = await firstValueFrom(
          this.apiService.get<any>('/api/viviendas/con-residentes', params)
        );
        const lote = extractPagedItems<any>(respuesta).map(this.mapear);
        const nuevas = lote.filter(c => !vistas.has(c.id));
        nuevas.forEach(c => vistas.add(c.id));
        todas.push(...nuevas);
        // Sin casas nuevas la API no está paginando de verdad: se corta para no repetir la misma página
        if (lote.length < POR_PAGINA || nuevas.length === 0) break;
      }

      todas.sort((a, b) => a.numeroCasa.localeCompare(b.numeroCasa, 'es', { numeric: true }));
      this.casas.set(todas);
      this.cargado = true;
    } catch (err: any) {
      console.error('[DirectorioCasasService] Error al cargar el directorio:', err);
      this.errorMessage.set(err?.error?.error || 'No se pudo cargar el directorio de casas.');
    } finally {
      this.isLoading.set(false);
    }
  }

  private mapear(item: any): ViviendaConResidentes {
    const residentes: ResidenteContacto[] = (item.residentes ?? []).map((r: any) => ({
      id: r.id,
      nombre: r.nombre ?? '',
      apellidos: r.apellidos ?? '',
      telefono: r.telefono || null
    }));
    return {
      id: item.id,
      numeroCasa: item.numeroCasa,
      tipo: item.tipo ?? null,
      totalResidentes: item.totalResidentes ?? residentes.length,
      estaOcupada: item.estaOcupada ?? residentes.length > 0,
      residentes
    };
  }
}
