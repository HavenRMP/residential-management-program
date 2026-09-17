import { Injectable, inject, signal, computed } from '@angular/core';
import { SubUsuarioInvitacion, CrearInvitacionSubUsuarioDto } from '../models/subusuario.model';
import { AuthService } from './auth.service';

@Injectable({
  providedIn: 'root'
})
export class SubusuariosService {
  private readonly authService = inject(AuthService);

  readonly MAX_SUBUSUARIOS = 2;
  readonly invitaciones = signal<SubUsuarioInvitacion[]>([]);
  readonly isLoading = signal<boolean>(false);

  /** Invitaciones activas o pendientes no expiradas */
  readonly activas = computed(() => {
    const now = Date.now();
    return this.invitaciones().filter(i => {
      const expTime = new Date(i.expiraEn).getTime();
      return expTime > now && i.estado !== 'expirada';
    });
  });

  /** Cantidad de cupos libres (máximo 2) */
  readonly cuposDisponibles = computed(() => {
    return Math.max(0, this.MAX_SUBUSUARIOS - this.activas().length);
  });

  /**
   * Carga las invitaciones del usuario actual desde localStorage
   */
  cargar(): SubUsuarioInvitacion[] {
    const userId = this.authService.currentUser()?.id || 'residente-local';
    const storageKey = `haven_subusuarios_${userId}`;

    try {
      const raw = localStorage.getItem(storageKey);
      if (raw) {
        const parsed: SubUsuarioInvitacion[] = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          // Actualizar estados si alguna ya expiró
          const now = Date.now();
          const actualizadas = parsed.map(inv => {
            if (new Date(inv.expiraEn).getTime() <= now && inv.estado === 'pendiente') {
              return { ...inv, estado: 'expirada' as const };
            }
            return inv;
          });
          this.invitaciones.set(actualizadas);
          return actualizadas;
        }
      }

      // Semilla inicial amigable: 1 cupo ocupado/activo para demostrar cómo se ve
      const now = new Date();
      const seed: SubUsuarioInvitacion[] = [
        {
          id: 'sub-seed-1',
          nombreInvitado: 'Sofía Gómez (Familiar)',
          emailInvitado: 'sofia.g@ejemplo.com',
          telefonoInvitado: '5512345678',
          codigoInvitacion: 'SUB-' + Math.random().toString(36).substring(2, 8).toUpperCase(),
          creadoEn: new Date(now.getTime() - 2 * 3600000).toISOString(),
          expiraEn: new Date(now.getTime() + 22 * 3600000).toISOString(), // Expira en 22 horas
          estado: 'activa'
        }
      ];

      localStorage.setItem(storageKey, JSON.stringify(seed));
      this.invitaciones.set(seed);
      return seed;
    } catch {
      this.invitaciones.set([]);
      return [];
    }
  }

  /**
   * Genera una nueva invitación para sub-usuario con vigencia exacta de 1 día (24 horas)
   */
  crearInvitacion(dto: CrearInvitacionSubUsuarioDto): SubUsuarioInvitacion {
    if (this.cuposDisponibles() <= 0) {
      throw new Error('Has alcanzado el límite máximo de 2 sub-usuarios para esta vivienda.');
    }

    const userId = this.authService.currentUser()?.id || 'residente-local';
    const now = new Date();
    // 1 día de vigencia (24 horas)
    const expira = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const codigo = 'SUB-' + Math.random().toString(36).substring(2, 8).toUpperCase();

    const nueva: SubUsuarioInvitacion = {
      id: 'sub-' + Date.now() + '-' + Math.random().toString(36).substring(2, 6),
      nombreInvitado: dto.nombreInvitado.trim(),
      emailInvitado: dto.emailInvitado?.trim(),
      telefonoInvitado: dto.telefonoInvitado?.trim(),
      codigoInvitacion: codigo,
      creadoEn: now.toISOString(),
      expiraEn: expira.toISOString(),
      estado: 'pendiente'
    };

    const lista = [nueva, ...this.invitaciones()];
    this.invitaciones.set(lista);
    this.guardar(userId, lista);
    return nueva;
  }

  /**
   * Revoca o elimina una invitación
   */
  revocar(id: string): boolean {
    const userId = this.authService.currentUser()?.id || 'residente-local';
    const lista = this.invitaciones().filter(i => i.id !== id);
    this.invitaciones.set(lista);
    this.guardar(userId, lista);
    return true;
  }

  private guardar(userId: string, lista: SubUsuarioInvitacion[]): void {
    try {
      localStorage.setItem(`haven_subusuarios_${userId}`, JSON.stringify(lista));
    } catch (err) {
      console.warn('[SubusuariosService] Error al guardar:', err);
    }
  }
}
