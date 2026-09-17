import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { AuthService } from '../../../core/services/auth.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { AvisosService } from '../../../core/services/avisos.service';
import { CacheService } from '../../../core/services/cache.service';
import { Vivienda } from '../../../core/models/vivienda.model';
import { Aviso, AvisoPrioridad } from '../../../core/models/aviso.model';
import { UserMenuComponent } from '../../../core/components/user-menu/user-menu.component';

@Component({
  selector: 'app-residente-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule, UserMenuComponent],
  template: `
    <div class="min-h-screen bg-slate-100 text-slate-900 font-sans antialiased">
      
      <!-- Top Navbar Spartan UI -->
      <header class="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-2xs">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <img src="/haven-logo.png" alt="Haven" class="w-7 h-7 rounded-lg object-contain" />
            <div class="flex items-center gap-2">
              <span class="font-bold text-base tracking-tight text-slate-900">Haven</span>
              <span class="text-[11px] font-semibold px-2 py-0.5 rounded-md bg-slate-200 text-slate-800 border border-slate-300">
                Residente
              </span>
              <span *ngIf="nombreCondominio()" class="hidden sm:inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-md text-[11px] font-semibold bg-indigo-50 text-indigo-800 border border-indigo-200">
                <svg class="w-3.5 h-3.5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                </svg>
                {{ nombreCondominio() }}
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
            <p class="text-xs text-slate-600 font-medium mt-0.5">
              Bienvenido, {{ currentUser()?.nombre || 'Residente' }}. Gestiona tu vivienda y comunicados.
            </p>
            <!-- Condominio en vista móvil -->
            <p *ngIf="nombreCondominio()" class="sm:hidden text-xs font-semibold text-indigo-700 mt-1 flex items-center gap-1">
              <span>Condominio:</span>
              <span>{{ nombreCondominio() }}</span>
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
        <div *ngIf="isLoadingVivienda()" class="rounded-xl border border-slate-200/90 bg-white p-6 shadow-xs animate-pulse">
          <div class="h-4 bg-slate-200 rounded w-1/4 mb-3"></div>
          <div class="h-16 bg-slate-100 rounded-md"></div>
        </div>

        <!-- Caso A: Si YA tiene viviendas asignadas -->
        <div *ngIf="!isLoadingVivienda() && misViviendas().length > 0" class="rounded-xl border border-slate-200/90 bg-white p-5 shadow-xs space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">
                {{ misViviendas().length === 1 ? 'Vivienda asignada' : 'Viviendas asignadas (' + misViviendas().length + ')' }}
              </h2>
              <p class="text-xs font-medium text-slate-600">
                Inmueble{{ misViviendas().length === 1 ? '' : 's' }} vinculado{{ misViviendas().length === 1 ? '' : 's' }} a tu cuenta
                <span *ngIf="nombreCondominio()"> · {{ nombreCondominio() }}</span>
              </p>
            </div>
            
            <div class="flex items-center gap-2 self-start sm:self-auto">
              <span class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-semibold bg-emerald-50 text-emerald-800 border border-emerald-300">
                Activa
              </span>
              <button
                type="button"
                (click)="toggleFormularioVinculacion()"
                [attr.aria-expanded]="mostrarFormularioVinculacion()"
                class="min-h-[32px] sm:min-h-[28px] h-8 sm:h-7 px-3 sm:px-2.5 inline-flex items-center gap-1.5 rounded-md border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-xs font-semibold transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
                aria-label="Vincular otra vivienda"
              >
                <svg class="w-3.5 h-3.5 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                <span>{{ mostrarFormularioVinculacion() ? 'Ocultar código' : 'Vincular otra vivienda' }}</span>
              </button>
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div *ngFor="let v of misViviendas()" class="p-4 rounded-lg bg-slate-50 border border-slate-200">
              <span class="text-[11px] uppercase font-bold text-slate-600 tracking-wider block">Unidad</span>
              <p class="text-xl font-bold text-slate-900 mt-0.5">{{ formatearIdentificador(v.numeroCasa) }}</p>
              <p class="text-xs text-slate-600 mt-1">Tipo: <span class="font-semibold text-slate-800">{{ v.tipo || 'Residencial' }}</span></p>
            </div>
          </div>
        </div>

        <!-- Caso B: Sin vivienda asignada -->
        <div *ngIf="!isLoadingVivienda() && misViviendas().length === 0" class="rounded-xl border border-slate-200/90 bg-white p-5 shadow-xs space-y-3">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold text-slate-900">Asignación de vivienda</h2>
            <span class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-semibold bg-amber-50 text-amber-800 border border-amber-300">
              {{ tieneCondominio() ? 'Pendiente de vivienda' : 'Sin condominio' }}
            </span>
          </div>
          
          <!-- B.1: Ya vinculado al condominio pero sin vivienda aún -->
          <div *ngIf="tieneCondominio()" class="space-y-1.5">
            <p class="text-xs text-slate-700 leading-relaxed font-medium">
              Tu cuenta está vinculada a <strong>{{ nombreCondominio() || 'tu condominio' }}</strong>. La administración asignará tu número de unidad próximamente.
            </p>
            <p class="text-xs text-slate-500">
              Si la administración te entregó un código específico para tu vivienda, puedes canjearlo a continuación.
            </p>
          </div>

          <!-- B.2: No vinculado a ningún condominio -->
          <div *ngIf="!tieneCondominio()">
            <p class="text-xs text-slate-700 leading-relaxed font-medium">
              Tu cuenta aún no está vinculada a ningún condominio ni vivienda. Ingresa el código de invitación proporcionado por tu administración para comenzar.
            </p>
          </div>
        </div>

        <!-- Card: Vinculación con Código Spartan UI (Visible si 0 viviendas o si solicitó vincular otra) -->
        <div *ngIf="misViviendas().length === 0 || mostrarFormularioVinculacion()" class="rounded-xl border border-slate-200/90 bg-white p-5 shadow-xs space-y-3 animate-in fade-in duration-150">
          <div>
            <h2 class="text-sm font-semibold text-slate-900">
              {{ misViviendas().length > 0 ? 'Vincular vivienda adicional' : 'Código de vinculación' }}
            </h2>
            <p class="text-xs font-medium text-slate-600">
              {{ misViviendas().length > 0 ? 'Ingresa el código proporcionado por la administración para asociar otra unidad a tu cuenta.' : 'Ingresa el código temporal proporcionado por la administración.' }}
            </p>
          </div>

          <div class="flex flex-col sm:flex-row gap-2">
            <input
              type="text"
              [(ngModel)]="codigoInput"
              (keyup.enter)="redimirCodigo()"
              placeholder="Ej. A1B2C3"
              maxlength="30"
              autocomplete="off"
              autocorrect="off"
              autocapitalize="characters"
              spellcheck="false"
              name="codigo_haven_vivienda"
              aria-label="Código temporal de vinculación"
              class="h-9 flex-1 text-xs font-mono uppercase font-bold rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
            />
            <button
              type="button"
              (click)="redimirCodigo()"
              [disabled]="isRedeeming() || !codigoInput.trim()"
              [attr.aria-busy]="isRedeeming()"
              class="h-9 px-4 inline-flex items-center justify-center rounded-lg bg-[#111C99] hover:bg-[#0d1577] focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#111C99] text-white text-xs font-semibold transition-colors shadow-2xs cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <span>{{ isRedeeming() ? 'Validando...' : 'Canjear código' }}</span>
            </button>
          </div>
        </div>

        <!-- Card: Avisos del Condominio Spartan UI (Solo visible si pertenece a un condominio) -->
        <div *ngIf="tieneCondominio()" class="rounded-xl border border-slate-200/90 bg-white shadow-xs">
          <div class="p-4 border-b border-slate-200 flex items-center justify-between">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Avisos del condominio</h2>
              <p class="text-xs font-medium text-slate-600">Comunicados oficiales activos</p>
            </div>
            <span class="text-xs font-semibold text-slate-600">
              {{ avisosService.vigentes().length }} activo{{ avisosService.vigentes().length === 1 ? '' : 's' }}
            </span>
          </div>

          <div *ngIf="avisosService.vigentes().length > 0; else noAvisos" class="divide-y divide-slate-100">
            <div
              *ngFor="let a of avisosService.vigentes()"
              (click)="verDetalleAviso(a)"
              class="p-4 hover:bg-slate-50/90 transition-colors cursor-pointer"
            >
              <div class="flex items-center justify-between gap-2 mb-1.5">
                <span
                  class="inline-flex items-center px-1.5 py-0.2 rounded text-[11px] font-semibold border"
                  [ngClass]="getBadgeClass(a.prioridad)"
                >
                  {{ getPrioridadLabel(a.prioridad) }}
                </span>
                <span class="text-[11px] font-medium text-slate-500">
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
            <div class="p-6 text-center text-xs text-slate-600 font-medium">
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
  private readonly cacheService = inject(CacheService);
  readonly avisosService = inject(AvisosService);

  readonly currentUser = this.authService.currentUser;
  readonly misViviendas = signal<Vivienda[]>([]);
  readonly isLoadingVivienda = signal<boolean>(true);
  readonly isRedeeming = signal<boolean>(false);
  readonly nombreCondominio = signal<string | null>(null);
  readonly mostrarFormularioVinculacion = signal<boolean>(false);

  readonly tieneCondominio = computed(() => {
    return !!this.nombreCondominio() || !!this.currentUser()?.condominioId || this.misViviendas().length > 0;
  });

  codigoInput = '';

  ngOnInit(): void {
    const condId = this.currentUser()?.condominioId;
    if (condId) {
      this.avisosService.cargarAvisos(condId);
    }
    this.cargarDatosResidente();
  }

  async cargarDatosResidente(): Promise<void> {
    this.isLoadingVivienda.set(true);
    try {
      const list = await this.viviendasService.obtenerMisViviendas();
      this.misViviendas.set(list);

      // 1. Resolver nombre e id del condominio
      let condId = this.currentUser()?.condominioId;
      let condNom = this.currentUser()?.condominioNombre;

      if (list.length > 0) {
        if (!condId && list[0].condominioId) condId = list[0].condominioId;
        if (!condNom && list[0].condominioNombre) condNom = list[0].condominioNombre;
      }

      if (condNom) {
        this.nombreCondominio.set(condNom);
      } else if (condId) {
        try {
          const cond = await this.condominiosService.obtenerPorId(condId);
          if (cond && cond.nombre) {
            this.nombreCondominio.set(cond.nombre);
          }
        } catch (err) {
          console.warn('[ResidenteDashboard] No se pudo obtener nombre de condominio por ID:', err);
        }
      }

      // 2. Si tiene condominio y no se había cargado aún, cargar sus avisos oficiales
      const finalCondId = condId || this.currentUser()?.condominioId;
      if (finalCondId && finalCondId !== this.currentUser()?.condominioId) {
        await this.avisosService.cargarAvisos(finalCondId);
      }
    } catch (err) {
      console.error('[ResidenteDashboard] Error al sincronizar datos del residente:', err);
    } finally {
      this.isLoadingVivienda.set(false);
    }
  }

  toggleFormularioVinculacion(): void {
    this.mostrarFormularioVinculacion.update(v => !v);
  }

  formatearIdentificador(numeroCasa: string): string {
    if (!numeroCasa) return 'Unidad';
    let clean = numeroCasa.trim();
    // Normaliza prefijos redundantes (ej. "Casa #Casa 204B", "Casa Casa 204B", "#Casa 204B")
    clean = clean.replace(/^#?\s*casa\s*#?\s*(casa)?\s*/i, 'Casa ');
    // Si todavía tiene un '#' inicial suelto (ej. '#204B' o '# 204B')
    clean = clean.replace(/^#\s*/, '');
    return clean.trim() || 'Unidad';
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
        const nombreUnidad = resViv.numeroCasa ? this.formatearIdentificador(resViv.numeroCasa) : 'la unidad';
        mensaje = `Vinculado correctamente a ${nombreUnidad}.`;
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
      this.mostrarFormularioVinculacion.set(false);
      this.cacheService.invalidateTag('viviendas');
      this.cacheService.invalidateTag('condominios');

      await this.authService.refreshProfile();
      await this.cargarDatosResidente();

      await Swal.fire({
        icon: 'success',
        title: 'Vinculación completada',
        text: mensaje,
        confirmButtonColor: '#111C99'
      });
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

