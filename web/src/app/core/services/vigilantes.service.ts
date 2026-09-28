import { Injectable, inject, signal, computed } from '@angular/core';
import { AuthService } from './auth.service';
import { Vigilante, CrearVigilanteDto } from '../models/vigilante.model';

/**
 * Persistencia temporal en localStorage mientras Usuarios.Api no expone endpoints de vigilantes.
 * Cuando existan, reemplazar el cuerpo de cada método por llamadas a ApiService manteniendo
 * la misma forma pública (signals + métodos) para no tener que tocar el componente:
 *   listar()            -> GET   /api/vigilantes
 *   crear(dto)           -> POST  /api/vigilantes
 *   cambiarEstado(id, x) -> PATCH /api/vigilantes/{id}/estado
 */
@Injectable({
  providedIn: 'root'
})
export class VigilantesService {
  private readonly authService = inject(AuthService);

  readonly vigilantes = signal<Vigilante[]>([]);
  readonly isLoading = signal<boolean>(false);

  readonly activos = computed(() => this.vigilantes().filter(v => v.activo));
  readonly inactivos = computed(() => this.vigilantes().filter(v => !v.activo));

  private storageKey(): string {
    const condId = this.authService.currentUser()?.condominioId || 'global';
    return `haven_vigilantes_${condId}`;
  }

  async listar(): Promise<Vigilante[]> {
    this.isLoading.set(true);
    try {
      const raw = localStorage.getItem(this.storageKey());
      const lista: Vigilante[] = raw ? JSON.parse(raw) : [];
      this.vigilantes.set(lista);
      return lista;
    } finally {
      this.isLoading.set(false);
    }
  }

  async crear(dto: CrearVigilanteDto): Promise<Vigilante> {
    const nuevo: Vigilante = {
      id: 'vig-' + Date.now() + '-' + Math.random().toString(36).substring(2, 6),
      nombre: dto.nombre.trim(),
      apellidos: dto.apellidos.trim(),
      email: dto.email.trim().toLowerCase(),
      telefono: dto.telefono.trim(),
      turno: dto.turno,
      activo: true,
      creadoEn: new Date().toISOString()
    };

    const lista = [nuevo, ...this.vigilantes()];
    this.vigilantes.set(lista);
    this.guardar(lista);
    return nuevo;
  }

  async cambiarEstado(id: string, activo: boolean): Promise<void> {
    const lista = this.vigilantes().map(v => (v.id === id ? { ...v, activo } : v));
    this.vigilantes.set(lista);
    this.guardar(lista);
  }

  private guardar(lista: Vigilante[]): void {
    try {
      localStorage.setItem(this.storageKey(), JSON.stringify(lista));
    } catch (err) {
      console.warn('[VigilantesService] Error al guardar:', err);
    }
  }
}
