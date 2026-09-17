import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { AuthService } from '../../../core/services/auth.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { AvisosService } from '../../../core/services/avisos.service';
import { Vivienda } from '../../../core/models/vivienda.model';
import { Aviso, AvisoPrioridad } from '../../../core/models/aviso.model';
import { UserMenuComponent } from '../../../core/components/user-menu/user-menu.component';

@Component({
  selector: 'app-residente-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule, UserMenuComponent],
  template: `
    <div class="min-h-screen bg-[#F8FAFC] text-slate-900 font-sans antialiased">
      
      <!-- Top Navbar Spartan UI -->
      <header class="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-2xs">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <img src="/haven-logo.png" alt="Haven" class="w-7 h-7 rounded-lg object-contain" />
            <div class="flex items-center gap-2">
              <span class="font-bold text-base tracking-tight text-slate-900">Haven</span>
              <span class="text-[11px] font-medium px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 border border-slate-200">
                Residente
              </span>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <!-- Acceso a sub-usuarios/notificaciones temporalmente deshabilitado
            <a
              routerLink="/dashboard/residente/notificaciones"
              class="h-9 w-9 inline-flex items-center justify-center text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-md transition-colors relative cursor-pointer"
              title="Notificaciones y sub-usuarios"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
              </svg>
            </a>
            -->

            <app-user-menu [user]="currentUser()" (logout)="onLogout()" />
          </div>
        </div>
      </header>

      <!-- Main Container -->
      <main class="max-w-4xl mx-auto px-4 sm:px-6 py-6 space-y-5">
        
        <!-- Header Section -->
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-slate-200">
          <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900">
              Portal del residente
            </h1>
            <p class="text-xs text-slate-500 mt-0.5">
              Bienvenido, {{ currentUser()?.nombre || 'Residente' }}. Gestiona tu vivienda y comunicados.
            </p>
          </div>

          <!-- Acceso a Sub-usuarios temporalmente deshabilitado
          <a
            routerLink="/dashboard/residente/notificaciones"
            class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-2xs self-start sm:self-auto"
          >
            <svg class="w-3.5 h-3.5 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
            <span>Sub-usuarios</span>
          </a>
          -->
        </div>

        <!-- Estado de Carga -->
        <div *ngIf="isLoadingVivienda()" class="rounded-lg border border-slate-200 bg-white p-6 shadow-2xs animate-pulse">
          <div class="h-4 bg-slate-200 rounded w-1/4 mb-3"></div>
          <div class="h-16 bg-slate-100 rounded-md"></div>
        </div>

        <!-- Caso A: Si YA tiene viviendas asignadas -->
        <div *ngIf="!isLoadingVivienda() && misViviendas().length > 0" class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-4">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Vivienda asignada</h2>
              <p class="text-xs text-slate-500">Inmueble vinculado a tu cuenta</p>
            </div>
            <span class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium bg-emerald-50 text-emerald-700 border border-emerald-200">
              Activa
            </span>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div *ngFor="let v of misViviendas()" class="p-4 rounded-md bg-slate-50 border border-slate-200">
              <span class="text-[10px] uppercase font-bold text-slate-400 block">Número de unidad</span>
              <p class="text-xl font-bold text-slate-900 mt-0.5">Casa #{{ v.numeroCasa }}</p>
              <p class="text-xs text-slate-500 mt-1">Tipo: <span class="font-medium text-slate-700">{{ v.tipo || 'Residencial' }}</span></p>
            </div>
          </div>
        </div>

        <!-- Caso B: Sin vivienda asignada -->
        <div *ngIf="!isLoadingVivienda() && misViviendas().length === 0" class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-3">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold text-slate-900">Asignación de vivienda</h2>
            <span class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium bg-amber-50 text-amber-700 border border-amber-200">
              Pendiente
            </span>
          </div>
          <p class="text-xs text-slate-600 leading-relaxed">
            Tu cuenta aún no tiene una vivienda asociada. Puedes ingresar un código de vinculación o esperar a que la administración asigne tu número.
          </p>
        </div>

        <!-- Card: Vinculación con Código Spartan UI -->
        <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-3">
          <div>
            <h2 class="text-sm font-semibold text-slate-900">Código de vinculación</h2>
            <p class="text-xs text-slate-500">Ingresa el código temporal proporcionado por la administración.</p>
          </div>

          <div class="flex flex-col sm:flex-row gap-2">
            <input
              type="text"
              [(ngModel)]="codigoInput"
              (keyup.enter)="redimirCodigo()"
              placeholder="Ej. A1B2C3"
              maxlength="30"
              class="h-9 flex-1 text-xs font-mono uppercase font-bold rounded-md border border-slate-200 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
            />
            <button
              type="button"
              (click)="redimirCodigo()"
              [disabled]="isRedeeming() || !codigoInput.trim()"
              class="h-9 px-4 inline-flex items-center justify-center rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50"
            >
              <span>{{ isRedeeming() ? 'Validando...' : 'Canjear código' }}</span>
            </button>
          </div>
        </div>

        <!-- Card: Avisos del Condominio Spartan UI -->
        <div class="rounded-lg border border-slate-200 bg-white shadow-2xs">
          <div class="p-4 border-b border-slate-100 flex items-center justify-between">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Avisos del condominio</h2>
              <p class="text-xs text-slate-500">Comunicados oficiales activos</p>
            </div>
            <span class="text-xs font-medium text-slate-500">
              {{ avisosService.vigentes().length }} activo{{ avisosService.vigentes().length === 1 ? '' : 's' }}
            </span>
          </div>

          <div *ngIf="avisosService.vigentes().length > 0; else noAvisos" class="divide-y divide-slate-100">
            <div
              *ngFor="let a of avisosService.vigentes()"
              (click)="verDetalleAviso(a)"
              class="p-4 hover:bg-slate-50/70 transition-colors cursor-pointer"
            >
              <div class="flex items-center justify-between gap-2 mb-1.5">
                <span
                  class="inline-flex items-center px-1.5 py-0.2 rounded text-[11px] font-medium border"
                  [ngClass]="getBadgeClass(a.prioridad)"
                >
                  {{ getPrioridadLabel(a.prioridad) }}
                </span>
                <span class="text-[11px] text-slate-400">
                  {{ tiempoRestante(a) }}
                </span>
              </div>
              <h3 class="text-xs font-semibold text-slate-900">
                {{ a.titulo }}
              </h3>
              <p class="text-xs text-slate-600 mt-1 line-clamp-2 leading-relaxed">
                {{ a.contenido }}
              </p>
            </div>
          </div>

          <ng-template #noAvisos>
            <div class="p-6 text-center text-xs text-slate-500">
              No hay avisos vigentes en este momento.
            </div>
          </ng-template>
        </div>

      </main>
    </div>
  `
})
export class ResidenteDashboardComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly viviendasService = inject(ViviendasService);
  private readonly condominiosService = inject(CondominiosService);
  readonly avisosService = inject(AvisosService);

  readonly currentUser = this.authService.currentUser;
  readonly misViviendas = signal<Vivienda[]>([]);
  readonly isLoadingVivienda = signal<boolean>(true);
  readonly isRedeeming = signal<boolean>(false);
  codigoInput = '';

  async ngOnInit(): Promise<void> {
    await Promise.all([
      this.cargarMisViviendas(),
      this.avisosService.cargarAvisos(this.currentUser()?.condominioId)
    ]);
  }

  getBadgeClass(prioridad: AvisoPrioridad): string {
    switch (prioridad) {
      case 'urgente': return 'bg-rose-50 text-rose-700 border-rose-200';
      case 'mantenimiento': return 'bg-amber-50 text-amber-700 border-amber-200';
      case 'evento': return 'bg-indigo-50 text-indigo-700 border-indigo-200';
      case 'informativo':
      default: return 'bg-slate-100 text-slate-800 border-slate-200';
    }
  }

  getPrioridadLabel(prioridad: AvisoPrioridad): string {
    switch (prioridad) {
      case 'urgente': return 'Urgente';
      case 'mantenimiento': return 'Mantenimiento';
      case 'evento': return 'Evento';
      case 'informativo':
      default: return 'Informativo';
    }
  }

  tiempoRestante(aviso: Aviso): string {
    const diff = new Date(aviso.fechaExpiracion).getTime() - Date.now();
    if (diff <= 0) return 'Expirado';
    const dias = Math.ceil(diff / (1000 * 60 * 60 * 24));
    return dias === 1 ? '1 día restante' : `${dias} días restantes`;
  }

  verDetalleAviso(aviso: Aviso): void {
    Swal.fire({
      title: aviso.titulo,
      text: aviso.contenido,
      confirmButtonText: 'Cerrar',
      confirmButtonColor: '#111C99'
    });
  }

  async cargarMisViviendas(): Promise<void> {
    this.isLoadingVivienda.set(true);
    try {
      const list = await this.viviendasService.obtenerMisViviendas();
      this.misViviendas.set(list);
    } catch {
      this.misViviendas.set([]);
    } finally {
      this.isLoadingVivienda.set(false);
    }
  }

  async redimirCodigo(): Promise<void> {
    const raw = this.codigoInput.trim().toUpperCase();
    if (!raw) return;

    this.isRedeeming.set(true);
    let exitoso = false;
    let mensaje = '';

    try {
      const resViv = await this.viviendasService.redimirCodigo(raw);
      if (resViv) {
        exitoso = true;
        mensaje = resViv.numeroCasa ? `Vinculado a la Casa #${resViv.numeroCasa}.` : 'Código validado correctamente.';
      }
    } catch (errViv: any) {
      try {
        const resCond = await this.condominiosService.redimirCodigo(raw);
        if (resCond) {
          exitoso = true;
          mensaje = 'Vinculado al condominio correctamente.';
        }
      } catch (errCond: any) {
        mensaje = errCond?.error?.error || errViv?.error?.error || 'Código inválido o expirado.';
      }
    } finally {
      this.isRedeeming.set(false);
    }

    if (exitoso) {
      this.codigoInput = '';
      await Swal.fire({
        icon: 'success',
        title: 'Vinculación completada',
        text: mensaje,
        confirmButtonColor: '#111C99'
      });
      await this.cargarMisViviendas();
    } else {
      await Swal.fire({
        icon: 'error',
        title: 'No se pudo canjear',
        text: mensaje || 'Verifica el código e intenta de nuevo.',
        confirmButtonColor: '#111C99'
      });
    }
  }

  onLogout(): void {
    this.authService.logout();
  }
}
