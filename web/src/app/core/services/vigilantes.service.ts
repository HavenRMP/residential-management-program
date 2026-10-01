import { Injectable, inject, signal, computed } from '@angular/core';
import { HttpParams } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';
import { extractPagedItems } from '../models/pagination.model';
import { Vigilante, CrearVigilanteDto, VigilanteRegistradoApi } from '../models/vigilante.model';

const POR_PAGINA = 100;
const MAX_PAGINAS = 20;

@Injectable({
  providedIn: 'root'
})
export class VigilantesService {
  private readonly apiService = inject(ApiService);

  readonly vigilantes = signal<Vigilante[]>([]);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  readonly activos = computed(() => this.vigilantes().filter(v => v.activo));
  readonly inactivos = computed(() => this.vigilantes().filter(v => !v.activo));

  /**
   * Vigilantes del condominio del administrador, activos y dados de baja
   * (GET /api/vigilantes, paginado)
   */
  async listar(): Promise<Vigilante[]> {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      const todos: Vigilante[] = [];
      const vistos = new Set<string>();

      for (let pagina = 1; pagina <= MAX_PAGINAS; pagina++) {
        const params = new HttpParams().set('page', pagina.toString()).set('pageSize', POR_PAGINA.toString());
        const respuesta = await firstValueFrom(
          this.apiService.get<any>('/api/vigilantes', params, undefined, 'usuarios')
        );
        const lote = extractPagedItems<any>(respuesta).map(this.mapear);
        const nuevos = lote.filter(v => !vistos.has(v.id));
        nuevos.forEach(v => vistos.add(v.id));
        todos.push(...nuevos);
        // Sin vigilantes nuevos la API no está paginando de verdad: se corta para no repetir la misma página
        if (lote.length < POR_PAGINA || nuevos.length === 0) break;
      }

      this.vigilantes.set(todos);
      return todos;
    } catch (err: any) {
      console.error('[VigilantesService] Error al listar vigilantes:', err);
      this.errorMessage.set(err?.error?.error || 'No se pudo cargar la lista de vigilantes.');
      return this.vigilantes();
    } finally {
      this.isLoading.set(false);
    }
  }

  /**
   * Registra un vigilante en el condominio del administrador
   * (POST /api/auth/register-vigilante)
   */
  async crear(dto: CrearVigilanteDto): Promise<Vigilante> {
    const body = {
      nombre: dto.nombre.trim(),
      apellidos: dto.apellidos.trim(),
      telefono: dto.telefono.trim(),
      email: dto.email.trim().toLowerCase(),
      password: dto.password
    };

    const response = await firstValueFrom(
      this.apiService.post<VigilanteRegistradoApi>('/api/auth/register-vigilante', body, undefined, 'usuarios')
    );

    const nuevo: Vigilante = {
      id: response.id,
      nombre: response.nombre,
      apellidos: response.apellidos,
      email: response.email,
      telefono: response.telefono,
      activo: true,
      creadoEn: response.creadoEn
    };

    this.vigilantes.update(lista => [nuevo, ...lista.filter(v => v.id !== nuevo.id)]);
    return nuevo;
  }

  /**
   * Da de baja (bloquea su inicio de sesión) o reactiva a un vigilante
   * (PATCH /api/vigilantes/{id}/baja o /reactivar)
   */
  async cambiarEstado(id: string, activo: boolean): Promise<void> {
    const accion = activo ? 'reactivar' : 'baja';
    await firstValueFrom(
      this.apiService.patch<void>(`/api/vigilantes/${id}/${accion}`, {}, undefined, 'usuarios')
    );
    this.vigilantes.update(lista => lista.map(v => (v.id === id ? { ...v, activo } : v)));
  }

  private mapear(item: any): Vigilante {
    return {
      id: item.id,
      nombre: item.nombre ?? '',
      apellidos: item.apellidos ?? '',
      email: item.email ?? '',
      telefono: item.telefono ?? '',
      activo: !!item.activo,
      creadoEn: item.creadoEn ?? ''
    };
  }
}
