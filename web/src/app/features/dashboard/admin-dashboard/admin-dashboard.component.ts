import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { AuthService } from '../../../core/services/auth.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { ResidentesService } from '../../../core/services/residentes.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { Vivienda } from '../../../core/models/vivienda.model';
import { Residente } from '../../../core/models/residente.model';
import { extractPagedItems } from '../../../core/models/pagination.model';

@Component({
  selector: 'app-admin-dashboard',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <div class="p-4 sm:p-6 max-w-7xl mx-auto space-y-6">
      
      <!-- Top Header Spartan UI -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200">
        <div>
          <div class="flex items-center gap-2.5">
            <h1 class="text-2xl font-bold tracking-tight text-slate-900">
              Panel general
            </h1>
            <span *ngIf="condominioActual()" class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-semibold bg-slate-200 text-slate-800 border border-slate-300">
              {{ condominioActual()?.nombre }}
            </span>
          </div>
          <p class="text-xs text-slate-600 mt-1 font-medium">
            Resumen operativo y estado general de las viviendas y residentes.
          </p>
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <button
            type="button"
            (click)="cargarMetricas(true)"
            [disabled]="loading()"
            title="Actualizar datos"
            class="h-9 w-9 inline-flex items-center justify-center rounded-md border border-slate-300 bg-white text-slate-700 hover:bg-slate-50 hover:text-slate-900 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] transition-colors cursor-pointer disabled:opacity-50"
            aria-label="Actualizar datos del panel"
          >
            <svg [class.animate-spin]="loading()" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>

          <button
            type="button"
            (click)="generarCodigoCondominio()"
            [disabled]="isGeneratingCode()"
            class="h-9 px-3.5 inline-flex items-center gap-2 rounded-md bg-[#111C99] hover:bg-[#0d1577] focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#111C99] text-white text-xs font-semibold transition-colors shadow-2xs cursor-pointer disabled:opacity-50"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
            </svg>
            <span>{{ isGeneratingCode() ? 'Generando...' : 'Código de invitación' }}</span>
          </button>
        </div>
      </div>

      <!-- Error State Banner Spartan UI con Reintento -->
      <div
        *ngIf="!loading() && errorMessage()"
        class="p-4 rounded-lg bg-rose-50 border border-rose-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-rose-900 shadow-2xs"
      >
        <div class="flex items-start gap-3">
          <div class="p-1.5 bg-rose-100 rounded-md text-rose-600 shrink-0 mt-0.5 sm:mt-0">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <div>
            <h3 class="text-sm font-semibold text-rose-900">Error de conexión con el servidor</h3>
            <p class="text-xs text-rose-700 mt-0.5">{{ errorMessage() }}</p>
          </div>
        </div>
        <button
          type="button"
          (click)="cargarMetricas(true)"
          class="inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-md bg-rose-600 hover:bg-rose-700 text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer shrink-0"
        >
          <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          <span>Reintentar conexión</span>
        </button>
      </div>

      <!-- KPI Stat Cards (4 Clean Spartan Cards) -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        
        <!-- Total Viviendas -->
        <div class="rounded-xl border border-slate-200/90 bg-white p-4 shadow-xs">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold text-slate-600">Total viviendas</span>
            <svg class="w-4 h-4 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
            </svg>
          </div>
          <p class="text-2xl font-bold tracking-tight text-slate-900 mt-2">
            {{ (loading() || errorMessage()) ? '—' : totalViviendas() }}
          </p>
          <p class="text-[11px] font-medium text-slate-600 mt-1">
            Inmuebles en catálogo
          </p>
        </div>

        <!-- Residentes -->
        <div class="rounded-xl border border-slate-200/90 bg-white p-4 shadow-xs">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold text-slate-600">Residentes</span>
            <svg class="w-4 h-4 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </div>
          <p class="text-2xl font-bold tracking-tight text-slate-900 mt-2">
            {{ (loading() || errorMessage()) ? '—' : totalResidentes() }}
          </p>
          <p class="text-[11px] font-medium text-slate-600 mt-1">
            Padrón registrado
          </p>
        </div>

        <!-- Ocupación % -->
        <div class="rounded-xl border border-slate-200/90 bg-white p-4 shadow-xs">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold text-slate-600">Ocupación</span>
            <span class="text-xs font-mono font-bold" [ngClass]="colorTextoOcupacion()">
              {{ (loading() || errorMessage()) ? '—' : porcentajeOcupacion() + '%' }}
            </span>
          </div>
          <p class="text-2xl font-bold tracking-tight text-slate-900 mt-2">
            {{ (loading() || errorMessage()) ? '—' : porcentajeOcupacion() + '%' }}
          </p>
          <div class="w-full h-1.5 bg-slate-200 rounded-full mt-2 overflow-hidden">
            <div class="h-full rounded-full transition-all duration-500" [ngClass]="colorBarraOcupacion()" [style.width.%]="errorMessage() ? 0 : porcentajeOcupacion()"></div>
          </div>
        </div>

        <!-- Viviendas Libres -->
        <div class="rounded-xl border border-slate-200/90 bg-white p-4 shadow-xs">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold text-slate-600">Disponibilidad</span>
            <span class="text-xs font-semibold text-slate-700">
              {{ errorMessage() ? 'Sin conexión' : (loading() ? '—' : viviendasAsignadas() + ' ocupadas') }}
            </span>
          </div>
          <p class="text-2xl font-bold tracking-tight text-slate-900 mt-2">
            {{ (loading() || errorMessage()) ? '—' : viviendasDisponibles() }}
          </p>
          <p class="text-[11px] font-medium text-slate-600 mt-1">
            Viviendas disponibles
          </p>
        </div>

      </div>

      <!-- Main Section: Viviendas Summary & Accesos Directos (Sin sección de avisos) -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        
        <!-- Columna Principal (2/3): Resumen de Viviendas -->
        <div class="lg:col-span-2 rounded-xl border border-slate-200/90 bg-white shadow-xs">
          <div class="p-4 border-b border-slate-200 flex items-center justify-between">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Estado de viviendas</h2>
              <p class="text-[11px] font-medium text-slate-600">Distribución de unidades habitacionales</p>
            </div>
            <a routerLink="/dashboard/admin/viviendas" class="text-xs font-semibold text-[#111C99] hover:underline focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] rounded">
              Ver directorio completo
            </a>
          </div>

          <!-- Estado de carga -->
          <div *ngIf="loading()" class="p-8 text-center text-xs text-slate-600 flex flex-col items-center justify-center gap-2">
            <svg class="animate-spin w-5 h-5 text-[#111C99]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            <span class="font-medium">Sincronizando estado de viviendas...</span>
          </div>

          <!-- Estado de error -->
          <div *ngIf="!loading() && errorMessage()" class="p-8 text-center text-xs text-rose-600 space-y-1">
            <p class="font-semibold">No se pudo cargar el listado de viviendas.</p>
            <p class="text-[11px] text-slate-600">Comprueba la conexión con el servidor e intenta nuevamente.</p>
          </div>

          <!-- Lista de viviendas -->
          <div *ngIf="!loading() && !errorMessage() && viviendasResumen().length > 0" class="divide-y divide-slate-100">
            <div *ngFor="let v of viviendasResumen()" class="p-3.5 hover:bg-slate-50/90 transition-colors flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="h-8 min-w-8 px-2 rounded-md bg-slate-100 border border-slate-300 flex items-center justify-center text-xs font-mono font-bold text-slate-900">
                  {{ formatearBadge(v.numeroCasa) }}
                </div>
                <div>
                  <h3 class="text-xs font-semibold text-slate-900">
                    {{ formatearNombre(v.numeroCasa) }}
                  </h3>
                  <p class="text-[11px] font-medium text-slate-600">
                    {{ v.tipo || 'Residencial' }}
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-3">
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-semibold border"
                  [class.bg-emerald-50]="v.asignada"
                  [class.text-emerald-800]="v.asignada"
                  [class.border-emerald-300]="v.asignada"
                  [class.bg-slate-100]="!v.asignada"
                  [class.text-slate-700]="!v.asignada"
                  [class.border-slate-300]="!v.asignada"
                >
                  {{ v.asignada ? 'Asignada' : 'Disponible' }}
                </span>

                <a
                  [routerLink]="['/dashboard/admin/viviendas']"
                  class="text-xs font-bold text-slate-500 hover:text-slate-900 transition-colors p-1 rounded focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
                  aria-label="Ver detalles de la vivienda"
                >
                  →
                </a>
              </div>
            </div>
          </div>

          <!-- Empty State Legítimo (Catálogo vacío real) -->
          <div *ngIf="!loading() && !errorMessage() && viviendasResumen().length === 0" class="p-8 text-center text-xs text-slate-600 space-y-2">
            <svg class="w-8 h-8 text-slate-400 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
            </svg>
            <p class="font-semibold text-slate-700">No hay viviendas registradas aún.</p>
            <p class="text-[11px] text-slate-500">Puedes comenzar registrando la primera vivienda en el catálogo.</p>
          </div>
        </div>

        <!-- Columna Lateral (1/3): Accesos Directos -->
        <div class="rounded-xl border border-slate-200/90 bg-white p-4 shadow-xs space-y-3 h-fit">
          <h2 class="text-sm font-semibold text-slate-900">Accesos directos</h2>
          
          <div class="space-y-1.5">
            <a
              routerLink="/dashboard/admin/viviendas"
              class="flex items-center justify-between p-2.5 rounded-lg hover:bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-800 transition-colors cursor-pointer group focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
            >
              <div class="flex items-center gap-2.5">
                <svg class="w-4 h-4 text-slate-500 group-hover:text-slate-900" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
                <span>Directorio de viviendas</span>
              </div>
              <span class="text-[11px] text-slate-600 font-mono font-bold">{{ (loading() || errorMessage()) ? '—' : totalViviendas() }}</span>
            </a>

            <a
              routerLink="/dashboard/admin/residentes"
              class="flex items-center justify-between p-2.5 rounded-lg hover:bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-800 transition-colors cursor-pointer group focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
            >
              <div class="flex items-center gap-2.5">
                <svg class="w-4 h-4 text-slate-500 group-hover:text-slate-900" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                <span>Directorio de residentes</span>
              </div>
              <span class="text-[11px] text-slate-600 font-mono font-bold">{{ (loading() || errorMessage()) ? '—' : totalResidentes() }}</span>
            </a>

            <a
              routerLink="/dashboard/admin/avisos"
              class="flex items-center justify-between p-2.5 rounded-lg hover:bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-800 transition-colors cursor-pointer group focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
            >
              <div class="flex items-center gap-2.5">
                <svg class="w-4 h-4 text-slate-500 group-hover:text-slate-900" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" />
                </svg>
                <span>Tablón de avisos</span>
              </div>
              <span class="text-xs text-slate-500 font-bold">→</span>
            </a>
          </div>

          <div class="pt-2 border-t border-slate-100">
            <button
              type="button"
              (click)="generarCodigoCondominio()"
              class="w-full h-8 text-xs font-semibold text-slate-800 bg-slate-100 hover:bg-slate-200 border border-slate-300 rounded-lg transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
            >
              Nuevo código de acceso
            </button>
          </div>
        </div>

      </div>

    </div>
  `
})
export class AdminDashboardComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly condominiosService = inject(CondominiosService);
  private readonly viviendasService = inject(ViviendasService);
  private readonly residentesService = inject(ResidentesService);

  readonly currentUser = this.authService.currentUser;
  readonly condominioActual = this.condominiosService.condominioActual;

  readonly totalViviendas = signal<number>(0);
  readonly totalResidentes = signal<number>(0);
  readonly viviendasAsignadas = signal<number>(0);
  readonly viviendasResumen = signal<(Vivienda & { asignada?: boolean })[]>([]);
  readonly loading = signal<boolean>(true);
  readonly errorMessage = signal<string | null>(null);
  readonly isGeneratingCode = signal<boolean>(false);

  ngOnInit(): void {
    const user = this.currentUser();
    this.condominiosService.cargarCondominioUsuario(user?.condominioId);
    this.cargarMetricas();
  }

  async cargarMetricas(forceRefresh: boolean = false): Promise<void> {
    this.loading.set(true);
    this.errorMessage.set(null);
    try {
      const [viviendasRaw, residentesRaw] = await Promise.all([
        this.viviendasService.listar(undefined, undefined, forceRefresh),
        this.residentesService.listar(false, forceRefresh)
      ]);

      const viviendas = extractPagedItems<Vivienda>(viviendasRaw);
      const residentes = extractPagedItems<Residente>(residentesRaw);

      this.totalViviendas.set(viviendas.length);
      this.totalResidentes.set(residentes.length);

      if (viviendas.length > 0) {
        // Consultar el estado de asignación real de las viviendas en paralelo (aprovechando caché reactiva)
        const asignaciones = await Promise.all(
          viviendas.map(v => this.viviendasService.obtenerResidentesVivienda(v.id, forceRefresh).catch(() => []))
        );

        let totalOcupadas = 0;
        const viviendasConEstado = viviendas.map((v, i) => {
          const res = asignaciones[i];
          const itemsRes = extractPagedItems<Residente>(res);
          const tieneResidentes = itemsRes.length > 0;
          if (tieneResidentes) {
            totalOcupadas++;
          }
          return { ...v, asignada: tieneResidentes };
        });

        this.viviendasAsignadas.set(totalOcupadas);
        this.viviendasResumen.set(viviendasConEstado.slice(0, 5));
      } else {
        this.viviendasAsignadas.set(0);
        this.viviendasResumen.set([]);
      }
    } catch (err) {
      console.warn('[AdminDashboard] Error al cargar métricas:', err);
      this.errorMessage.set('No se pudo establecer conexión con los servicios del servidor. Por favor, reintenta en unos momentos.');
      this.totalViviendas.set(0);
      this.totalResidentes.set(0);
      this.viviendasAsignadas.set(0);
      this.viviendasResumen.set([]);
    } finally {
      this.loading.set(false);
    }
  }

  viviendasDisponibles(): number {
    const total = Number(this.totalViviendas()) || 0;
    const asignadas = Number(this.viviendasAsignadas()) || 0;
    return Math.max(0, total - asignadas);
  }

  formatearNombre(numeroCasa: string): string {
    if (!numeroCasa) return 'Unidad';
    return numeroCasa.toLowerCase().startsWith('casa') ? numeroCasa : `Casa #${numeroCasa}`;
  }

  formatearBadge(numeroCasa: string): string {
    if (!numeroCasa) return '-';
    return numeroCasa.replace(/^casa\s*#?/i, '').trim() || numeroCasa;
  }

  porcentajeOcupacion(): number {
    const total = Number(this.totalViviendas()) || 0;
    const asignadas = Number(this.viviendasAsignadas()) || 0;
    if (total <= 0) return 0;
    const ratio = Math.round((asignadas / total) * 100);
    return isNaN(ratio) ? 0 : Math.min(Math.max(ratio, 0), 100);
  }

  colorBarraOcupacion(): string {
    const p = this.porcentajeOcupacion();
    if (p >= 80) return 'bg-emerald-500';
    if (p >= 50) return 'bg-blue-600';
    if (p >= 25) return 'bg-amber-500';
    return 'bg-rose-500';
  }

  colorTextoOcupacion(): string {
    const p = this.porcentajeOcupacion();
    if (p >= 80) return 'text-emerald-600';
    if (p >= 50) return 'text-blue-600';
    if (p >= 25) return 'text-amber-600';
    return 'text-rose-600';
  }

  async generarCodigoCondominio(): Promise<void> {
    const cond = this.condominioActual();
    if (!cond || !cond.id) {
      await Swal.fire({
        icon: 'warning',
        title: 'Condominio no disponible',
        text: 'No se encontró un condominio asociado a tu cuenta.',
        confirmButtonColor: '#111C99'
      });
      return;
    }

    this.isGeneratingCode.set(true);
    try {
      const res = await this.condominiosService.generarCodigo(cond.id, 1440);
      if (res && res.codigo) {
        await Swal.fire({
          title: 'Código de invitación',
          html: `
            <div class="text-center space-y-3 p-2">
              <p class="text-xs text-slate-500">Comparte este código para vincularse a <strong>${cond.nombre}</strong>:</p>
              <div class="p-3 bg-slate-100 rounded-md border border-slate-200 inline-block tracking-widest font-mono text-2xl font-bold text-slate-900">
                ${res.codigo}
              </div>
              <p class="text-[11px] text-slate-400">Vigencia: 24 horas.</p>
            </div>
          `,
          icon: 'success',
          showCancelButton: true,
          confirmButtonText: 'Copiar',
          cancelButtonText: 'Cerrar',
          confirmButtonColor: '#111C99',
          cancelButtonColor: '#64748B'
        }).then((result) => {
          if (result.isConfirmed) {
            navigator.clipboard.writeText(res.codigo);
            Swal.fire({
              toast: true,
              position: 'top-end',
              icon: 'success',
              title: 'Copiado al portapapeles',
              showConfirmButton: false,
              timer: 2000
            });
          }
        });
      }
    } catch (err: any) {
      Swal.fire({
        icon: 'error',
        title: 'Error',
        text: err?.error?.error || 'No se pudo generar el código.',
        confirmButtonColor: '#111C99'
      });
    } finally {
      this.isGeneratingCode.set(false);
    }
  }
}
