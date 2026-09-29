import { Injectable, inject, signal, computed } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';
import { AuthService } from './auth.service';
import { Vigilante, CrearVigilanteDto, VigilanteRegistradoApi } from '../models/vigilante.model';

/**
 * El alta ya usa el backend real (POST /api/auth/register-vigilante). Listar y dar de baja/reactivar
 * siguen en localStorage porque Usuarios.Api todavía no expone esos endpoints; cuando existan,
 * reemplazar el cuerpo de cada método manteniendo la misma forma pública (signals + métodos):
 *   listar()             -> GET   /api/vigilantes
 *   cambiarEstado(id, x) -> PATCH /api/vigilantes/{id}/estado
 */
@Injectable({
  providedIn: 'root'
})
export class VigilantesService {
  private readonly apiService = inject(ApiService);
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
