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
            <span *ngIf="condominioActual()" class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium bg-slate-100 text-slate-700 border border-slate-200">
              {{ condominioActual()?.nombre }}
            </span>
          </div>
          <p class="text-xs text-slate-500 mt-1">
            Resumen operativo y estado general de las viviendas y residentes.
          </p>
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <button
            type="button"
            (click)="cargarMetricas()"
            [disabled]="loading()"
            title="Actualizar datos"
            class="h-9 w-9 inline-flex items-center justify-center rounded-md border border-slate-200 bg-white text-slate-600 hover:bg-slate-50 hover:text-slate-900 transition-colors cursor-pointer disabled:opacity-50"
          >
            <svg [class.animate-spin]="loading()" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>

          <button
            type="button"
            (click)="generarCodigoCondominio()"
            [disabled]="isGeneratingCode()"
            class="h-9 px-3.5 inline-flex items-center gap-2 rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
            </svg>
            <span>{{ isGeneratingCode() ? 'Generando...' : 'Código de invitación' }}</span>
          </button>
        </div>
      </div>

      <!-- KPI Stat Cards (4 Clean Spartan Cards) -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        
        <!-- Total Viviendas -->
        <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-slate-500">Total viviendas</span>
            <svg class="w-4 h-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
            </svg>
          </div>
          <p class="text-2xl font-bold tracking-tight text-slate-900 mt-2">
            {{ loading() ? '—' : totalViviendas() }}
          </p>
          <p class="text-[11px] text-slate-500 mt-1">
            Inmuebles en catálogo
          </p>
        </div>

        <!-- Residentes -->
        <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-slate-500">Residentes</span>
            <svg class="w-4 h-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </div>
          <p class="text-2xl font-bold tracking-tight text-slate-900 mt-2">
            {{ loading() ? '—' : totalResidentes() }}
          </p>
          <p class="text-[11px] text-slate-500 mt-1">
            Padrón registrado
          </p>
        </div>

        <!-- Ocupación % -->
        <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-slate-500">Ocupación</span>
            <span class="text-xs font-mono font-semibold" [ngClass]="colorTextoOcupacion()">
              {{ loading() ? '—' : porcentajeOcupacion() + '%' }}
            </span>
          </div>
          <p class="text-2xl font-bold tracking-tight text-slate-900 mt-2">
            {{ loading() ? '—' : porcentajeOcupacion() + '%' }}
          </p>
          <div class="w-full h-1.5 bg-slate-100 rounded-full mt-2 overflow-hidden">
            <div class="h-full rounded-full transition-all duration-500" [ngClass]="colorBarraOcupacion()" [style.width.%]="porcentajeOcupacion()"></div>
          </div>
        </div>

        <!-- Viviendas Libres -->
        <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-slate-500">Disponibilidad</span>
            <span class="text-xs font-medium text-slate-600">
              {{ loading() ? '—' : viviendasAsignadas() + ' ocupadas' }}
            </span>
          </div>
          <p class="text-2xl font-bold tracking-tight text-slate-900 mt-2">
            {{ loading() ? '—' : viviendasDisponibles() }}
          </p>
          <p class="text-[11px] text-slate-500 mt-1">
            Viviendas disponibles
          </p>
        </div>

      </div>

      <!-- Main Section: Viviendas Summary & Accesos Directos (Sin sección de avisos) -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        
        <!-- Columna Principal (2/3): Resumen de Viviendas -->
        <div class="lg:col-span-2 rounded-lg border border-slate-200 bg-white shadow-2xs">
          <div class="p-4 border-b border-slate-100 flex items-center justify-between">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Estado de viviendas</h2>
              <p class="text-[11px] text-slate-500">Distribución de unidades habitacionales</p>
            </div>
            <a routerLink="/dashboard/admin/viviendas" class="text-xs font-medium text-[#111C99] hover:underline">
              Ver directorio completo
            </a>
          </div>

          <div *ngIf="viviendasResumen().length > 0; else sinViviendas" class="divide-y divide-slate-100">
            <div *ngFor="let v of viviendasResumen()" class="p-3.5 hover:bg-slate-50/70 transition-colors flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="h-8 min-w-8 px-2 rounded-md bg-slate-100 border border-slate-200 flex items-center justify-center text-xs font-mono font-bold text-slate-800">
                  {{ formatearBadge(v.numeroCasa) }}
                </div>
                <div>
                  <h3 class="text-xs font-semibold text-slate-900">
                    {{ formatearNombre(v.numeroCasa) }}
                  </h3>
                  <p class="text-[11px] text-slate-500">
                    {{ v.tipo || 'Residencial' }}
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-3">
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-medium border"
                  [class.bg-emerald-50]="v.asignada"
                  [class.text-emerald-700]="v.asignada"
                  [class.border-emerald-200]="v.asignada"
                  [class.bg-slate-50]="!v.asignada"
                  [class.text-slate-600]="!v.asignada"
                  [class.border-slate-200]="!v.asignada"
                >
                  {{ v.asignada ? 'Asignada' : 'Disponible' }}
                </span>

                <a
                  [routerLink]="['/dashboard/admin/viviendas']"
                  class="text-xs font-medium text-slate-400 hover:text-slate-800 transition-colors"
                >
                  →
                </a>
              </div>
            </div>
          </div>

          <ng-template #sinViviendas>
            <div class="p-6 text-center text-xs text-slate-500">
              No hay viviendas registradas aún.
            </div>
          </ng-template>
        </div>

        <!-- Columna Lateral (1/3): Accesos Directos -->
        <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs space-y-3 h-fit">
          <h2 class="text-sm font-semibold text-slate-900">Accesos directos</h2>
          
          <div class="space-y-1.5">
            <a
              routerLink="/dashboard/admin/viviendas"
              class="flex items-center justify-between p-2.5 rounded-md hover:bg-slate-50 border border-slate-100 text-xs font-medium text-slate-800 transition-colors cursor-pointer group"
            >
              <div class="flex items-center gap-2.5">
                <svg class="w-4 h-4 text-slate-400 group-hover:text-slate-900" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
                <span>Directorio de viviendas</span>
              </div>
              <span class="text-[11px] text-slate-400 font-mono">{{ totalViviendas() }}</span>
            </a>

            <a
              routerLink="/dashboard/admin/residentes"
              class="flex items-center justify-between p-2.5 rounded-md hover:bg-slate-50 border border-slate-100 text-xs font-medium text-slate-800 transition-colors cursor-pointer group"
            >
              <div class="flex items-center gap-2.5">
                <svg class="w-4 h-4 text-slate-400 group-hover:text-slate-900" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                <span>Directorio de residentes</span>
              </div>
              <span class="text-[11px] text-slate-400 font-mono">{{ totalResidentes() }}</span>
            </a>

            <a
              routerLink="/dashboard/admin/avisos"
              class="flex items-center justify-between p-2.5 rounded-md hover:bg-slate-50 border border-slate-100 text-xs font-medium text-slate-800 transition-colors cursor-pointer group"
            >
              <div class="flex items-center gap-2.5">
                <svg class="w-4 h-4 text-slate-400 group-hover:text-slate-900" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" />
                </svg>
                <span>Tablón de avisos</span>
              </div>
              <span class="text-xs text-slate-400">→</span>
            </a>
          </div>

          <div class="pt-2 border-t border-slate-100">
            <button
              type="button"
              (click)="generarCodigoCondominio()"
              class="w-full h-8 text-xs font-medium text-slate-700 bg-slate-50 hover:bg-slate-100 border border-slate-200 rounded-md transition-colors cursor-pointer"
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
  readonly isGeneratingCode = signal<boolean>(false);

  ngOnInit(): void {
    const user = this.currentUser();
    this.condominiosService.cargarCondominioUsuario(user?.condominioId);
    this.cargarMetricas();
  }

  async cargarMetricas(): Promise<void> {
    this.loading.set(true);
    try {
      const [viviendasRaw, residentesRaw] = await Promise.all([
        this.viviendasService.listar().catch(() => []),
        this.residentesService.listar().catch(() => [])
      ]);

      const viviendas = extractPagedItems<Vivienda>(viviendasRaw);
      const residentes = extractPagedItems<Residente>(residentesRaw);

      this.totalViviendas.set(viviendas.length);
      this.totalResidentes.set(residentes.length);

      if (viviendas.length > 0) {
        // Consultar residentes por vivienda para determinar con exactitud las asignadas
        const asignaciones = await Promise.all(
          viviendas.map(v => this.viviendasService.obtenerResidentesVivienda(v.id).catch(() => []))
        );

        let asignadasCount = 0;
        const resumen = viviendas.map((v, i) => {
          const res = asignaciones[i];
          const itemsRes = extractPagedItems<Residente>(res);
          const tieneResidentes = itemsRes.length > 0;
          if (tieneResidentes) {
            asignadasCount++;
          }
          return { ...v, asignada: tieneResidentes };
        });

        this.viviendasAsignadas.set(asignadasCount);
        this.viviendasResumen.set(resumen.slice(0, 5));
      } else {
        this.viviendasAsignadas.set(0);
        this.viviendasResumen.set([]);
      }
    } catch (err) {
      console.warn('[AdminDashboard] Error al cargar métricas:', err);
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
