import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { AuthService } from '../../core/services/auth.service';
import { SubusuariosService } from '../../core/services/subusuarios.service';
import { SubUsuarioInvitacion } from '../../core/models/subusuario.model';
import { UserMenuComponent } from '../../core/components/user-menu/user-menu.component';

@Component({
  selector: 'app-notificaciones',
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

        <!-- Sección 1: Sub-usuarios Autorizados -->
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
                {{ 2 - subusuariosService.cuposDisponibles() }} de 2 asignados
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

          <!-- Grid de Sub-usuarios -->
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div
              *ngFor="let item of subusuariosService.activas()"
              class="p-4 rounded-md bg-slate-50 border border-slate-200 flex flex-col justify-between"
            >
              <div>
                <div class="flex items-center justify-between gap-2 mb-2">
                  <span
                    class="px-2 py-0.5 rounded text-[10px] font-medium border"
                    [class.bg-emerald-50]="item.estado === 'activa'"
                    [class.text-emerald-700]="item.estado === 'activa'"
                    [class.border-emerald-200]="item.estado === 'activa'"
                    [class.bg-amber-50]="item.estado === 'pendiente'"
                    [class.text-amber-700]="item.estado === 'pendiente'"
                    [class.border-amber-200]="item.estado === 'pendiente'"
                  >
                    {{ item.estado === 'activa' ? 'Activo' : 'Pendiente' }}
                  </span>

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

                <h3 class="text-sm font-semibold text-slate-900">{{ item.nombreInvitado }}</h3>
                <p class="text-xs text-slate-500 mt-0.5">{{ item.emailInvitado || item.telefonoInvitado || 'Sin contacto' }}</p>

                <!-- Código -->
                <div class="mt-3 p-2 bg-white border border-slate-200 rounded flex items-center justify-between">
                  <div>
                    <span class="text-[9px] uppercase font-bold text-slate-400 block">Código temporal</span>
                    <span class="text-xs font-mono font-bold text-slate-900">{{ item.codigoInvitacion }}</span>
                  </div>
                  <button
                    type="button"
                    (click)="copiarCodigo(item.codigoInvitacion)"
                    class="h-6 px-2 text-[11px] font-medium text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded transition-colors cursor-pointer"
                  >
                    Copiar
                  </button>
                </div>
              </div>

              <div class="mt-3 pt-2 border-t border-slate-200 text-[10px] text-slate-400 flex items-center justify-between">
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
          </div>
        </section>

        <!-- Sección 2: Permisos de Sub-usuarios -->
        <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-3">
          <div>
            <h2 class="text-sm font-semibold text-slate-900">Permisos habilitados</h2>
            <p class="text-xs text-slate-500">Funcionalidades a las que tendrán acceso los sub-usuarios de tu vivienda.</p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
            
            <div
              (click)="verDetalleAccion('Registro de visitas', 'Los sub-usuarios pueden generar códigos de acceso para visitantes a tu vivienda.')"
              class="p-3.5 rounded-md border border-slate-200 hover:bg-slate-50 transition-colors cursor-pointer space-y-1.5"
            >
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

            <div
              (click)="verDetalleAccion('Reservación de áreas', 'Permite apartar amenidades comunes según la disponibilidad y reglamento interno.')"
              class="p-3.5 rounded-md border border-slate-200 hover:bg-slate-50 transition-colors cursor-pointer space-y-1.5"
            >
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

            <div
              (click)="verDetalleAccion('Autorización de servicios', 'Permite el paso a repartidores de mensajería, paquetería y servicios a domicilio.')"
              class="p-3.5 rounded-md border border-slate-200 hover:bg-slate-50 transition-colors cursor-pointer space-y-1.5"
            >
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
              <label class="block text-xs font-medium text-slate-700 mb-1">
                Nombre completo *
              </label>
              <input
                type="text"
                [(ngModel)]="nuevoSub.nombreInvitado"
                (keypress)="permitirSoloLetras($event)"
                (input)="filtrarSoloTextoNombre($event)"
                name="nombreInvitado"
                required
                placeholder="Nombre y apellido"
                class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-slate-700 mb-1">
                Correo (opcional)
              </label>
              <input
                type="email"
                [(ngModel)]="nuevoSub.emailInvitado"
                name="emailInvitado"
                placeholder="correo@ejemplo.com"
                class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-slate-700 mb-1">
                Teléfono (opcional)
              </label>
              <input
                type="tel"
                [(ngModel)]="nuevoSub.telefonoInvitado"
                name="telefonoInvitado"
                placeholder="10 dígitos"
                class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
              />
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
                [disabled]="!nuevoSub.nombreInvitado.trim()"
                class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50"
              >
                Generar código
              </button>
            </div>
          </form>
        </div>
      </div>

    </div>
  `
})
export class NotificacionesComponent implements OnInit {
  private readonly authService = inject(AuthService);
  readonly subusuariosService = inject(SubusuariosService);

  readonly currentUser = this.authService.currentUser;
  modalInvitarAbierto = signal<boolean>(false);

  nuevoSub = {
    nombreInvitado: '',
    emailInvitado: '',
    telefonoInvitado: ''
  };

  ngOnInit(): void {
    this.subusuariosService.cargar();
  }

  abrirModalInvitacion(): void {
    this.nuevoSub = {
      nombreInvitado: '',
      emailInvitado: '',
      telefonoInvitado: ''
    };
    this.modalInvitarAbierto.set(true);
  }

  cerrarModalInvitacion(): void {
    this.modalInvitarAbierto.set(false);
  }

  async generarInvitacion(): Promise<void> {
    if (!this.nuevoSub.nombreInvitado.trim()) return;

    try {
      const inv = this.subusuariosService.crearInvitacion(this.nuevoSub);
      this.cerrarModalInvitacion();

      await Swal.fire({
        title: 'Código de acceso generado',
        html: `
          <div class="text-center space-y-3 p-2">
            <p class="text-xs text-slate-500">Comparte este código con <strong>${inv.nombreInvitado}</strong>:</p>
            <div class="p-3 bg-slate-100 rounded-md border border-slate-200 inline-block font-mono text-2xl font-bold text-slate-900 tracking-widest">
              ${inv.codigoInvitacion}
            </div>
            <p class="text-[11px] text-slate-400">Vigencia: 24 horas.</p>
          </div>
        `,
        icon: 'success',
        confirmButtonText: 'Copiar y cerrar',
        confirmButtonColor: '#111C99'
      });

      this.copiarCodigo(inv.codigoInvitacion);
    } catch (err: any) {
      Swal.fire({
        icon: 'error',
        title: 'Límite alcanzado',
        text: err.message || 'No es posible crear más sub-usuarios.',
        confirmButtonColor: '#111C99'
      });
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

  async confirmarRevocar(item: SubUsuarioInvitacion): Promise<void> {
    const res = await Swal.fire({
      title: '¿Revocar acceso?',
      text: item.nombreInvitado,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Revocar',
      cancelButtonText: 'Cancelar'
    });

    if (res.isConfirmed) {
      this.subusuariosService.revocar(item.id);
    }
  }

  verDetalleAccion(titulo: string, descripcion: string): void {
    Swal.fire({
      title: titulo,
      text: descripcion,
      confirmButtonText: 'Cerrar',
      confirmButtonColor: '#111C99'
    });
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

  permitirSoloLetras(event: KeyboardEvent): void {
    if (['Backspace', 'Tab', 'ArrowLeft', 'ArrowRight', 'Delete', 'Enter'].includes(event.key)) {
      return;
    }
    if (event.ctrlKey || event.metaKey) {
      return;
    }
    const regex = /^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]$/;
    if (!regex.test(event.key)) {
      event.preventDefault();
    }
  }

  filtrarSoloTextoNombre(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input) {
      const limpio = input.value.replace(/[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]/g, '');
      if (input.value !== limpio) {
        input.value = limpio;
      }
      this.nuevoSub.nombreInvitado = limpio;
    }
  }
}
