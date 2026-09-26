import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { AuthService } from '../../core/services/auth.service';
import { ViviendasService } from '../../core/services/viviendas.service';
import { SubusuariosService } from '../../core/services/subusuarios.service';
import { SubUsuarioItem } from '../../core/models/subusuario.model';
import { UserMenuComponent } from '../../core/components/user-menu/user-menu.component';

const PARENTESCOS = ['Familiar', 'Empleado doméstico', 'Inquilino', 'Otro'];

@Component({
  selector: 'app-subusuarios',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, UserMenuComponent],
  template: `
    <div class="min-h-screen bg-[#F8FAFC] text-slate-900 font-sans antialiased">

      <!-- Top Bar Spartan UI -->
      <header class="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-2xs">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <a
              routerLink="/dashboard/residente"
              class="h-8 w-8 inline-flex items-center justify-center text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-md transition-colors cursor-pointer"
              title="Volver"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
            </a>
            <div class="flex items-center gap-2">
              <span class="font-bold text-base tracking-tight text-slate-900">Sub-usuarios</span>
              <span class="text-[11px] font-medium px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 border border-slate-200">
                Gestión
              </span>
            </div>
          </div>

          <app-user-menu [user]="currentUser()" (logout)="onLogout()" />
        </div>
      </header>

      <!-- Main Container -->
      <main class="max-w-4xl mx-auto px-4 sm:px-6 py-6 space-y-6">

        <!-- Breadcrumb -->
        <nav class="flex items-center gap-2 text-xs text-slate-500 font-medium">
          <a routerLink="/dashboard/residente" class="hover:text-slate-900 transition-colors">Portal</a>
          <span>/</span>
          <span class="text-slate-900">Sub-usuarios</span>
        </nav>

        <!-- Sin vivienda asignada -->
        <div *ngIf="!isLoadingVivienda() && !viviendaId()" class="rounded-lg border border-slate-200 bg-white p-8 text-center shadow-2xs space-y-2">
          <h2 class="text-base font-semibold text-slate-900">Necesitas una vivienda asignada</h2>
          <p class="text-xs text-slate-500 max-w-md mx-auto">
            Vincula tu cuenta a una vivienda desde el portal para poder invitar sub-usuarios.
          </p>
          <a routerLink="/dashboard/residente" class="h-8 px-4 inline-flex items-center justify-center rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs mt-2">
            Volver al portal
          </a>
        </div>

        <ng-container *ngIf="viviendaId()">
          <!-- Sección: Sub-usuarios Autorizados -->
          <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-4">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
              <div>
                <h2 class="text-sm font-semibold text-slate-900">Sub-usuarios autorizados</h2>
                <p class="text-xs text-slate-500 mt-0.5">
                  Hasta 2 accesos por vivienda. Las invitaciones tienen una vigencia de 24 horas.
                </p>
              </div>

              <div class="flex items-center gap-2 self-start sm:self-auto">
                <span class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium bg-slate-100 text-slate-700 border border-slate-200">
                  {{ subusuariosService.items().length }} de {{ subusuariosService.MAX_SUBUSUARIOS }} asignados
                </span>

                <button
                  *ngIf="subusuariosService.cuposDisponibles() > 0"
                  type="button"
                  (click)="abrirModalInvitacion()"
                  class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer"
                >
                  <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  <span>Invitar</span>
                </button>
              </div>
            </div>

            <!-- Loading skeleton -->
            <div *ngIf="subusuariosService.isLoading()" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div *ngFor="let s of [1, 2]" class="p-4 rounded-md bg-slate-50 border border-slate-200 animate-pulse space-y-2">
                <div class="h-3 w-16 bg-slate-200 rounded"></div>
                <div class="h-4 w-2/3 bg-slate-200 rounded"></div>
                <div class="h-3 w-1/2 bg-slate-100 rounded"></div>
              </div>
            </div>

            <!-- Grid de Sub-usuarios -->
            <div *ngIf="!subusuariosService.isLoading()" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div
                *ngFor="let item of subusuariosService.items()"
                class="p-4 rounded-md bg-slate-50 border border-slate-200 flex flex-col justify-between"
              >
                <div>
                  <div class="flex items-center justify-between gap-2 mb-2">
                    <div class="flex items-center gap-1.5">
                      <span
                        class="px-2 py-0.5 rounded text-[10px] font-medium border"
                        [class.bg-emerald-50]="item.activo"
                        [class.text-emerald-700]="item.activo"
                        [class.border-emerald-200]="item.activo"
                        [class.bg-amber-50]="!item.activo"
                        [class.text-amber-700]="!item.activo"
                        [class.border-amber-200]="!item.activo"
                      >
                        {{ item.activo ? 'Activo' : 'Pendiente' }}
                      </span>
                      <span class="px-2 py-0.5 rounded text-[10px] font-medium border bg-slate-100 text-slate-600 border-slate-200">
                        {{ item.parentesco }}
                      </span>
                    </div>

                    <button
                      type="button"
                      (click)="confirmarRevocar(item)"
                      class="p-1 text-slate-400 hover:text-rose-600 rounded transition-colors cursor-pointer"
                      title="Revocar"
                    >
                      <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </div>

                  <h3 class="text-sm font-semibold text-slate-900">{{ item.nombre || 'Invitación pendiente' }}</h3>
                  <p class="text-xs text-slate-500 mt-0.5">{{ item.email || item.telefono || 'Sin contacto' }}</p>

                  <!-- Código (solo pendientes) -->
                  <div *ngIf="!item.activo && item.codigo" class="mt-3 p-2 bg-white border border-slate-200 rounded flex items-center justify-between">
                    <div>
                      <span class="text-[9px] uppercase font-bold text-slate-400 block">Código temporal</span>
                      <span class="text-xs font-mono font-bold text-slate-900">{{ item.codigo }}</span>
                    </div>
                    <button
                      type="button"
                      (click)="copiarCodigo(item.codigo!)"
                      class="h-6 px-2 text-[11px] font-medium text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded transition-colors cursor-pointer"
                    >
                      Copiar
                    </button>
                  </div>
                </div>

                <div *ngIf="!item.activo && item.expiraEn" class="mt-3 pt-2 border-t border-slate-200 text-[10px] text-slate-400 flex items-center justify-between">
                  <span>Vigencia</span>
                  <span class="font-medium text-slate-600">{{ tiempoRestante(item.expiraEn) }}</span>
                </div>
              </div>

              <!-- Empty slot if available -->
              <div
                *ngIf="subusuariosService.cuposDisponibles() > 0"
                (click)="abrirModalInvitacion()"
                class="p-4 rounded-md border border-dashed border-slate-200 hover:border-slate-400 hover:bg-slate-50 transition-colors flex flex-col items-center justify-center text-center cursor-pointer min-h-[140px]"
              >
                <svg class="w-5 h-5 text-slate-400 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                <span class="text-xs font-medium text-slate-700">Invitar sub-usuario</span>
                <span class="text-[11px] text-slate-400 mt-0.5">{{ subusuariosService.cuposDisponibles() }} cupo libre</span>
              </div>

              <div *ngIf="!subusuariosService.isLoading() && subusuariosService.items().length === 0" class="sm:col-span-2 p-6 text-center text-xs text-slate-500 font-medium">
                Todavía no has invitado a ningún sub-usuario.
              </div>
            </div>
          </section>

          <!-- Sección: Permisos de Sub-usuarios -->
          <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-3">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Permisos habilitados</h2>
              <p class="text-xs text-slate-500">Funcionalidades a las que tendrán acceso los sub-usuarios de tu vivienda.</p>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
              <div class="p-3.5 rounded-md border border-slate-200 space-y-1.5">
                <div class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7a4 4 0 11-8 0 4 4 0 018 0zM9 14a6 6 0 00-6 6v1h12v-1a6 6 0 00-6-6zM21 12h-6m3-3v6" />
                  </svg>
                  <h3 class="text-xs font-semibold text-slate-900">Registrar visitas</h3>
                </div>
                <p class="text-[11px] text-slate-500 leading-relaxed">
                  Autorización de acceso para invitados y familiares.
                </p>
              </div>

              <div class="p-3.5 rounded-md border border-slate-200 space-y-1.5">
                <div class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <h3 class="text-xs font-semibold text-slate-900">Reservar áreas</h3>
                </div>
                <p class="text-[11px] text-slate-500 leading-relaxed">
                  Apartado de amenidades y zonas de uso común.
                </p>
              </div>

              <div class="p-3.5 rounded-md border border-slate-200 space-y-1.5">
                <div class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                  </svg>
                  <h3 class="text-xs font-semibold text-slate-900">Autorizar servicios</h3>
                </div>
                <p class="text-[11px] text-slate-500 leading-relaxed">
                  Entrada para repartidores y servicios a domicilio.
                </p>
              </div>
            </div>
          </section>
        </ng-container>

      </main>

      <!-- Modal Invitar Spartan UI Dialog -->
      <div
        *ngIf="modalInvitarAbierto()"
        class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4"
      >
        <div class="bg-white rounded-lg max-w-sm w-full p-5 shadow-lg border border-slate-200">
          <div class="flex items-center justify-between pb-3 border-b border-slate-100">
            <h3 class="text-sm font-semibold text-slate-900">Invitar sub-usuario</h3>
            <button
              type="button"
              (click)="cerrarModalInvitacion()"
              class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <form (ngSubmit)="generarInvitacion()" class="mt-3.5 space-y-3">
            <div>
              <label class="block text-xs font-medium text-slate-700 mb-1">Nombre *</label>
              <input
                type="text"
                [(ngModel)]="nuevoSub.nombre"
                name="nombre"
                required
                placeholder="Nombre"
                class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-slate-700 mb-1">Apellidos *</label>
              <input
                type="text"
                [(ngModel)]="nuevoSub.apellidos"
                name="apellidos"
                required
                placeholder="Apellidos"
                class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-slate-700 mb-1">Correo *</label>
              <input
                type="email"
                [(ngModel)]="nuevoSub.email"
                name="email"
                required
                placeholder="correo@ejemplo.com"
                class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-slate-700 mb-1">Teléfono *</label>
              <input
                type="tel"
                [(ngModel)]="nuevoSub.telefono"
                name="telefono"
                required
                placeholder="10 dígitos"
                class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-slate-700 mb-1">Parentesco *</label>
              <select
                [(ngModel)]="nuevoSub.parentesco"
                name="parentesco"
                required
                class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-3 text-slate-900 focus:outline-none focus:ring-1 focus:ring-slate-900"
              >
                <option *ngFor="let p of parentescos" [value]="p">{{ p }}</option>
              </select>
            </div>

            <div class="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
              <button
                type="button"
                (click)="cerrarModalInvitacion()"
                class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer"
              >
                Cancelar
              </button>
              <button
                type="submit"
                [disabled]="isInvitando() || !esFormularioValido()"
                class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50"
              >
                {{ isInvitando() ? 'Generando...' : 'Generar código' }}
              </button>
            </div>
          </form>
        </div>
      </div>

    </div>
  `
})
export class SubusuariosComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly viviendasService = inject(ViviendasService);
  readonly subusuariosService = inject(SubusuariosService);

  readonly currentUser = this.authService.currentUser;
  readonly parentescos = PARENTESCOS;

  modalInvitarAbierto = signal<boolean>(false);
  isInvitando = signal<boolean>(false);
  isLoadingVivienda = signal<boolean>(true);
  viviendaId = signal<number | null>(null);

  nuevoSub = {
    nombre: '',
    apellidos: '',
    email: '',
    telefono: '',
    parentesco: PARENTESCOS[0]
  };

  async ngOnInit(): Promise<void> {
    this.isLoadingVivienda.set(true);
    try {
      const viviendas = await this.viviendasService.obtenerMisViviendas();
      const id = viviendas[0]?.id ?? null;
      this.viviendaId.set(id);
      if (id) {
        await this.subusuariosService.cargar(id);
      }
    } finally {
      this.isLoadingVivienda.set(false);
    }
  }

  esFormularioValido(): boolean {
    const s = this.nuevoSub;
    return !!(s.nombre.trim() && s.apellidos.trim() && s.email.trim() && s.telefono.trim() && s.parentesco);
  }

  abrirModalInvitacion(): void {
    this.nuevoSub = { nombre: '', apellidos: '', email: '', telefono: '', parentesco: PARENTESCOS[0] };
    this.modalInvitarAbierto.set(true);
  }

  cerrarModalInvitacion(): void {
    this.modalInvitarAbierto.set(false);
  }

  async generarInvitacion(): Promise<void> {
    if (!this.esFormularioValido() || this.isInvitando()) return;
    const viviendaId = this.viviendaId();
    if (!viviendaId) return;

    this.isInvitando.set(true);
    try {
      const inv = await this.subusuariosService.invitar({ viviendaId, ...this.nuevoSub });
      this.cerrarModalInvitacion();

      await Swal.fire({
        title: 'Código de acceso generado',
        html: `
          <div class="text-center space-y-3 p-2">
            <p class="text-xs text-slate-500">Comparte este código con <strong>${inv.nombre}</strong>:</p>
            <div class="p-3 bg-slate-100 rounded-md border border-slate-200 inline-block font-mono text-2xl font-bold text-slate-900 tracking-widest">
              ${inv.codigo || ''}
            </div>
            <p class="text-[11px] text-slate-400">Vigencia: 24 horas.</p>
          </div>
        `,
        icon: 'success',
        confirmButtonText: 'Copiar y cerrar',
        confirmButtonColor: '#111C99'
      });

      if (inv.codigo) {
        this.copiarCodigo(inv.codigo);
      }
    } catch (err: any) {
      Swal.fire({
        icon: 'error',
        title: 'No se pudo invitar',
        text: err?.error?.error || err?.message || 'No es posible crear más sub-usuarios.',
        confirmButtonColor: '#111C99'
      });
    } finally {
      this.isInvitando.set(false);
    }
  }

  copiarCodigo(codigo: string): void {
    navigator.clipboard.writeText(codigo).then(() => {
      Swal.fire({
        toast: true,
        position: 'top-end',
        icon: 'success',
        title: 'Copiado al portapapeles',
        showConfirmButton: false,
        timer: 1800
      });
    });
  }

  async confirmarRevocar(item: SubUsuarioItem): Promise<void> {
    const res = await Swal.fire({
      title: item.activo ? '¿Revocar acceso?' : '¿Cancelar invitación?',
      text: item.nombre || 'Invitación pendiente',
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: item.activo ? 'Revocar' : 'Cancelar invitación',
      cancelButtonText: 'Volver'
    });

    if (res.isConfirmed) {
      try {
        await this.subusuariosService.revocar(item.id, !item.activo);
      } catch (err: any) {
        Swal.fire({
          icon: 'error',
          title: 'No se pudo completar',
          text: err?.error?.error || 'Intenta de nuevo en unos segundos.',
          confirmButtonColor: '#111C99'
        });
      }
    }
  }

  tiempoRestante(expiraEn: string): string {
    const diff = new Date(expiraEn).getTime() - Date.now();
    if (diff <= 0) return 'Expirado';
    const horas = Math.ceil(diff / (1000 * 60 * 60));
    return horas <= 1 ? 'Menos de 1 h' : `${horas} horas restantes`;
  }

  onLogout(): void {
    this.authService.logout();
  }
}
