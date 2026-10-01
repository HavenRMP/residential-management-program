import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import Swal from 'sweetalert2';
import { AuthService } from '../../../core/services/auth.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { AvisosService } from '../../../core/services/avisos.service';
import { SubusuariosService } from '../../../core/services/subusuarios.service';
import { CacheService } from '../../../core/services/cache.service';
import { Vivienda } from '../../../core/models/vivienda.model';
import { Aviso, AvisoPrioridad } from '../../../core/models/aviso.model';
import { UserMenuComponent } from '../../../core/components/user-menu/user-menu.component';
import { NotificacionesPopoverComponent } from '../../../core/components/notificaciones-popover/notificaciones-popover.component';
import { formatearNumeroCasa } from '../../../core/utils/vivienda.util';
import { claseBadgePrioridad, etiquetaPrioridad, tiempoRestanteAviso } from '../../../core/utils/aviso-prioridad.util';

@Component({
  selector: 'app-residente-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, UserMenuComponent, NotificacionesPopoverComponent],
  template: `
    <div class="min-h-screen bg-slate-100 text-slate-900 font-sans antialiased">
      
      <!-- Top Navbar Spartan UI -->
      <header class="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-2xs">
        <div class="w-full px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
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
            <app-notificaciones-popover />
            <app-user-menu [user]="currentUser()" (logout)="onLogout()" />
          </div>
        </div>
      </header>

      <!-- Main Container -->
      <main class="w-full px-4 sm:px-6 lg:px-8 py-6 grid grid-cols-1 lg:grid-cols-3 gap-5 items-start">
        
        <!-- Header Section -->
        <div class="lg:col-span-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-slate-200">
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

          <div *ngIf="tieneCondominio()" class="flex items-center gap-2 self-start sm:self-auto">
          <a
            routerLink="/dashboard/residente/visitas"
            class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-2xs"
          >
            <svg class="w-3.5 h-3.5 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            <span>Visitas</span>
          </a>
          <a
            routerLink="/dashboard/residente/subusuarios"
            class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-2xs "
          >
            <svg class="w-3.5 h-3.5 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
            <span>Sub-usuarios</span>
          </a>
          </div>
        </div>

        <!-- Banner: invitaciones de sub-usuario pendientes (visible aunque aún no tenga vivienda propia) -->
        <a
          *ngIf="subusuariosService.invitacionesRecibidas().length > 0"
          routerLink="/dashboard/residente/subusuarios"
          class="lg:col-span-3 flex items-center justify-between gap-3 rounded-lg border border-indigo-200 bg-indigo-50 px-4 py-3 hover:bg-indigo-100/70 transition-colors"
        >
          <div class="flex items-center gap-3 min-w-0">
            <span class="shrink-0 h-8 w-8 inline-flex items-center justify-center rounded-full bg-indigo-600 text-white">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </span>
            <div class="min-w-0">
              <p class="text-sm font-semibold text-indigo-900">
                {{ subusuariosService.invitacionesRecibidas().length === 1 ? 'Tienes una invitación de sub-usuario pendiente' : 'Tienes ' + subusuariosService.invitacionesRecibidas().length + ' invitaciones de sub-usuario pendientes' }}
              </p>
              <p class="text-xs text-indigo-800/80 truncate">
                De {{ subusuariosService.invitacionesRecibidas()[0].titularNombre || 'un residente' }}<span *ngIf="subusuariosService.invitacionesRecibidas()[0].numeroCasa"> · Unidad {{ subusuariosService.invitacionesRecibidas()[0].numeroCasa }}</span>. Acéptala o recházala.
              </p>
            </div>
          </div>
          <span class="shrink-0 text-xs font-semibold text-indigo-700">Ver invitaciones →</span>
        </a>

        <!-- Columna principal: la vivienda y su vinculación -->
        <div class="space-y-5 min-w-0" [ngClass]="tieneCondominio() ? 'lg:col-span-2' : 'lg:col-span-3'">
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
              <p class="text-xl font-bold text-slate-900 mt-0.5">{{ formatearNumeroCasa(v.numeroCasa) }}</p>
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

        </div>

        <!-- Card: Avisos del Condominio Spartan UI (Solo visible si pertenece a un condominio) -->
        <div *ngIf="tieneCondominio()" class="lg:col-span-1 min-w-0 rounded-xl border border-slate-200/90 bg-white shadow-xs">
          <div class="p-4 border-b border-slate-200 flex items-center justify-between">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Avisos del condominio</h2>
              <p class="text-xs font-medium text-slate-600">Comunicados oficiales activos</p>
            </div>
            <span class="text-xs font-semibold text-slate-600">
              {{ avisosService.vigentes().length }} activo{{ avisosService.vigentes().length === 1 ? '' : 's' }}
            </span>
          </div>

          <!-- Loading State Skeletons -->
          <div *ngIf="avisosService.isLoading()" class="divide-y divide-slate-100">
            <div *ngFor="let s of [1, 2]" class="p-4 animate-pulse space-y-2">
              <div class="flex items-center justify-between">
                <div class="h-4 w-20 bg-slate-200 rounded"></div>
                <div class="h-3 w-16 bg-slate-100 rounded"></div>
              </div>
              <div class="h-3.5 w-1/2 bg-slate-200 rounded"></div>
              <div class="h-3 w-3/4 bg-slate-100 rounded"></div>
            </div>
          </div>

          <div *ngIf="!avisosService.isLoading() && avisosService.vigentes().length > 0" class="divide-y divide-slate-100">
            <div
              *ngFor="let a of avisosService.vigentes()"
              (click)="verDetalleAviso(a)"
              class="p-4 hover:bg-slate-50/90 transition-colors cursor-pointer"
            >
              <div class="flex items-center justify-between gap-2 mb-1.5">
                <span
                  class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-[11px] font-semibold border"
                  [ngClass]="getBadgeClass(a.prioridad)"
                >
                  <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" />
                  </svg>
                  <span>{{ getPrioridadLabel(a.prioridad) }}</span>
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

          <div *ngIf="!avisosService.isLoading() && avisosService.vigentes().length === 0" class="p-6 text-center text-xs text-slate-600 font-medium">
            No hay avisos vigentes en este momento.
          </div>
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
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  readonly avisosService = inject(AvisosService);
  readonly subusuariosService = inject(SubusuariosService);

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

  async ngOnInit(): Promise<void> {
    const condId = this.currentUser()?.condominioId;
    if (condId) {
      await this.avisosService.cargarAvisos(condId);
    }
    // Sin await: el banner de invitaciones no debe retrasar la carga del portal
    this.subusuariosService.cargarInvitacionesRecibidas();
    await this.cargarDatosResidente();
    this.abrirAvisoDesdeNotificacion();
  }

  /**
   * Cuando el usuario llega desde el clic en una notificación de aviso urgente
   * (redirigido vía AvisoRedirectComponent desde /avisos/:id), abre el detalle
   * de ese aviso si ya está en la lista de vigentes cargada.
   */
  private abrirAvisoDesdeNotificacion(): void {
    const avisoId = this.route.snapshot.queryParamMap.get('avisoId');
    if (!avisoId) return;

    const aviso = this.avisosService.vigentes().find(a => a.id === avisoId);
    if (aviso) {
      this.verDetalleAviso(aviso);
    } else {
      Swal.fire({
        icon: 'info',
        title: 'Aviso no disponible',
        text: 'Este aviso ya expiró o no está disponible.',
        confirmButtonColor: '#111C99'
      });
    }

    this.router.navigate([], { relativeTo: this.route, queryParams: {}, replaceUrl: true });
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

  readonly formatearNumeroCasa = formatearNumeroCasa;

  formatearIdentificador(numeroCasa: string): string {
    return formatearNumeroCasa(numeroCasa);
  }

  getBadgeClass(prioridad: AvisoPrioridad): string {
    return claseBadgePrioridad(prioridad);
  }

  getPrioridadLabel(prioridad: AvisoPrioridad): string {
    return etiquetaPrioridad(prioridad);
  }

  tiempoRestante(aviso: Aviso): string {
    return tiempoRestanteAviso(aviso);
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

