import { ChangeDetectionStrategy, Component, OnInit, computed, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { NoShow, nombreCompleto } from '../../../core/models/reserva.model';
import { rangoLegible } from '../../../core/utils/reservas.util';

@Component({
  selector: 'app-no-shows-admin',
  standalone: true,
  imports: [CommonModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="space-y-4">
      <p class="text-xs text-slate-600 max-w-2xl">
        Reservas aprobadas que no se usaron. Sirven para identificar a las viviendas que reservan y no asisten.
      </p>

      @if (servicio.errorNoShows(); as msg) {
        <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
          <span>{{ msg }}</span>
          <button type="button" (click)="servicio.cargarNoShows(servicio.noShowsPage())" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">Reintentar</button>
        </div>
      }

      @if (servicio.isLoadingNoShows()) {
        <div class="rounded-xl border border-slate-200 bg-white divide-y divide-slate-100" aria-busy="true">
          @for (s of [1, 2, 3]; track s) {
            <div class="p-4 animate-pulse space-y-1.5">
              <div class="h-3.5 w-1/3 bg-slate-200 rounded"></div>
              <div class="h-3 w-1/2 bg-slate-100 rounded"></div>
            </div>
          }
        </div>
      }

      @if (!servicio.isLoadingNoShows() && !servicio.errorNoShows()) {
        <div class="rounded-xl border border-slate-200 bg-white shadow-xs overflow-x-auto" tabindex="0" role="region" aria-label="Tabla desplazable">
          <table class="w-full text-left min-w-[680px]">
            <thead class="bg-slate-50 border-b border-slate-200">
              <tr>
                <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Área y horario</th>
                <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Vivienda</th>
                <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Titular</th>
                <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Solicitó</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              @for (n of servicio.noShows(); track n.id) {
                <tr class="hover:bg-slate-50/70 transition-colors">
                  <td class="px-4 py-3">
                    <p class="text-xs font-semibold text-slate-900">{{ n.areaNombre }}</p>
                    <p class="text-xs text-slate-700">{{ rango(n) }}</p>
                  </td>
                  <td class="px-4 py-3 text-xs font-semibold text-slate-900">{{ n.numeroCasa }}</td>
                  <td class="px-4 py-3 text-xs text-slate-700">{{ nombre(n.titularNombre, n.titularApellidos) }}</td>
                  <td class="px-4 py-3 text-xs text-slate-700">{{ nombre(n.solicitanteNombre, n.solicitanteApellidos) }}</td>
                </tr>
              }
            </tbody>
          </table>
          @if (servicio.noShows().length === 0) {
            <div class="p-8 text-center text-xs text-slate-500 font-medium">Ninguna reserva se ha marcado como no utilizada.</div>
          }
        </div>

        @if (totalPaginas() > 1) {
          <div class="flex items-center justify-between">
            <button type="button" (click)="irAPagina(servicio.noShowsPage() - 1)" [disabled]="servicio.noShowsPage() <= 1"
              class="h-8 px-3 text-xs font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer">Anterior</button>
            <span class="text-xs text-slate-500 font-medium">Página {{ servicio.noShowsPage() }} de {{ totalPaginas() }} · {{ servicio.noShowsTotal() }} en total</span>
            <button type="button" (click)="irAPagina(servicio.noShowsPage() + 1)" [disabled]="servicio.noShowsPage() >= totalPaginas()"
              class="h-8 px-3 text-xs font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer">Siguiente</button>
          </div>
        }
      }
    </div>
  `
})
export class NoShowsAdminComponent implements OnInit {
  readonly servicio = inject(ReservasAdminService);

  readonly totalPaginas = computed(() => Math.max(1, Math.ceil(this.servicio.noShowsTotal() / this.servicio.PAGE_SIZE)));

  ngOnInit(): void {
    void this.servicio.cargarNoShows(1);
  }

  async irAPagina(pagina: number): Promise<void> {
    if (pagina < 1 || pagina > this.totalPaginas()) return;
    await this.servicio.cargarNoShows(pagina);
  }

  private zonaDe(areaId: string): string {
    return this.servicio.areas().find(a => a.id === areaId)?.zonaHoraria ?? Intl.DateTimeFormat().resolvedOptions().timeZone;
  }

  rango(n: NoShow): string {
    return rangoLegible(n.inicio, n.fin, this.zonaDe(n.areaId));
  }

  nombre(nombre?: string | null, apellidos?: string | null): string {
    return nombreCompleto(nombre, apellidos) || 'Sin nombre';
  }
}
