import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { VisitasHistoricoService } from '../../../core/services/visitas-historico.service';
import { Vivienda } from '../../../core/models/vivienda.model';
import {
  CLASES_ESTADO_VISITA,
  ETIQUETAS_ESTADO_VISITA,
  EstadoVisita,
  FiltrosHistoricoVisitas,
  formatearFechaVisita,
  MOTIVOS_VISITA
} from '../../../core/models/visita.model';

const ESTADOS = Object.keys(ETIQUETAS_ESTADO_VISITA) as EstadoVisita[];

@Component({
  selector: 'app-visitas-historico',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <div class="p-4 sm:p-6 w-full space-y-4">

      <nav class="flex items-center gap-2 text-xs text-slate-600 font-semibold">
        <a routerLink="/dashboard/admin" class="hover:text-slate-900 transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] rounded">Panel</a>
        <span>/</span>
        <span class="text-slate-900">Visitas</span>
      </nav>

      <div class="pb-2 border-b border-slate-200">
        <h1 class="text-2xl font-bold tracking-tight text-slate-900">Histórico de visitas</h1>
        <p class="text-xs text-slate-600 mt-1 font-medium">Audita las visitas del condominio por fecha, vivienda o estado.</p>
      </div>

      <!-- Filtros -->
      <div class="rounded-xl border border-slate-200 bg-white p-4 shadow-xs">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3 items-end">
          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">Desde</label>
            <input type="date" [(ngModel)]="desde"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>
          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">Hasta</label>
            <input type="date" [(ngModel)]="hasta"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>
          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">Vivienda</label>
            <select [(ngModel)]="viviendaId"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option [ngValue]="null">Todas</option>
              <option *ngFor="let v of viviendas()" [ngValue]="v.id">{{ v.numeroCasa }}</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">Estado</label>
            <select [(ngModel)]="estado"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option [ngValue]="null">Todos</option>
              <option *ngFor="let e of estados" [ngValue]="e">{{ etiquetaEstado(e) }}</option>
            </select>
          </div>
          <div class="flex items-center gap-2">
            <button type="button" (click)="buscar()" [disabled]="rangoInvalido()"
              class="h-9 px-4 rounded-lg bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-semibold transition-colors cursor-pointer disabled:opacity-50">
              Buscar
            </button>
            <button type="button" (click)="limpiar()"
              class="h-9 px-3 rounded-lg border border-slate-200 text-xs font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">
              Limpiar
            </button>
          </div>
        </div>
        <p *ngIf="rangoInvalido()" class="mt-2 text-[11px] text-red-600 font-medium">La fecha "desde" no puede ser posterior a "hasta".</p>
      </div>

      <div *ngIf="historicoService.errorMessage() as msg" class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium">
        {{ msg }}
      </div>

      <div *ngIf="historicoService.isLoading()" class="rounded-xl border border-slate-200 bg-white divide-y divide-slate-100">
        <div *ngFor="let s of [1, 2, 3]" class="p-4 animate-pulse flex items-center gap-3">
          <div class="flex-1 space-y-1.5">
            <div class="h-3.5 w-1/3 bg-slate-200 rounded"></div>
            <div class="h-3 w-1/2 bg-slate-100 rounded"></div>
          </div>
        </div>
      </div>

      <div *ngIf="!historicoService.isLoading() && !historicoService.errorMessage()" class="rounded-xl border border-slate-200 bg-white shadow-xs overflow-x-auto">
        <table class="w-full text-left min-w-[720px]">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Llegada esperada</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Visitante</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Casa</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Motivo</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Estado</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Entrada</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Salida</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr *ngFor="let v of historicoService.items()" class="hover:bg-slate-50/70 transition-colors">
              <td class="px-4 py-3 text-xs text-slate-700">{{ formatearFecha(v.fechaLlegadaEsperada) }}</td>
              <td class="px-4 py-3 text-xs font-semibold text-slate-900">{{ v.nombreVisitante }} {{ v.apellidosVisitante }}</td>
              <td class="px-4 py-3 text-xs text-slate-700">{{ v.numeroCasa }}</td>
              <td class="px-4 py-3 text-xs text-slate-700">{{ etiquetaMotivo(v.motivo) }}</td>
              <td class="px-4 py-3">
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="claseEstado(v.estado)">
                  {{ etiquetaEstado(v.estado) }}
                </span>
              </td>
              <td class="px-4 py-3 text-xs text-slate-700">{{ formatearFecha(v.horaEntrada) || '—' }}</td>
              <td class="px-4 py-3 text-xs text-slate-700">{{ formatearFecha(v.horaSalida) || '—' }}</td>
            </tr>
          </tbody>
        </table>

        <div *ngIf="historicoService.items().length === 0" class="p-8 text-center text-xs text-slate-500 font-medium">
          No hay visitas con estos filtros.
        </div>
      </div>

      <div *ngIf="totalPaginas() > 1" class="flex items-center justify-between">
        <button type="button" (click)="irAPagina(historicoService.page() - 1)" [disabled]="historicoService.page() <= 1"
          class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer">
          Anterior
        </button>
        <span class="text-xs text-slate-500 font-medium">Página {{ historicoService.page() }} de {{ totalPaginas() }}</span>
        <button type="button" (click)="irAPagina(historicoService.page() + 1)" [disabled]="historicoService.page() >= totalPaginas()"
          class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer">
          Siguiente
        </button>
      </div>
    </div>
  `
})
export class VisitasHistoricoComponent implements OnInit {
  private readonly viviendasService = inject(ViviendasService);
  readonly historicoService = inject(VisitasHistoricoService);

  readonly estados = ESTADOS;
  readonly viviendas = signal<Vivienda[]>([]);

  desde = '';
  hasta = '';
  viviendaId: number | null = null;
  estado: EstadoVisita | null = null;

  /** Filtros aplicados en la última búsqueda, para que la paginación no use valores a medio editar */
  private filtrosAplicados: FiltrosHistoricoVisitas = {};

  readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.historicoService.totalCount() / this.historicoService.PAGE_SIZE))
  );

  async ngOnInit(): Promise<void> {
    this.historicoService.cargar();
    try {
      this.viviendas.set(await this.cargarTodasLasViviendas());
    } catch (err) {
      console.error('[VisitasHistoricoComponent] Error al cargar viviendas:', err);
    }
  }

  /** El listado viene paginado (100 por página): se piden páginas hasta que una llegue incompleta */
  private async cargarTodasLasViviendas(): Promise<Vivienda[]> {
    const POR_PAGINA = 100;
    const MAX_PAGINAS = 20;
    const todas: Vivienda[] = [];
    const vistas = new Set<number>();
    for (let pagina = 1; pagina <= MAX_PAGINAS; pagina++) {
      const lote = await this.viviendasService.listar(pagina, POR_PAGINA);
      const nuevas = lote.filter(v => !vistas.has(v.id));
      nuevas.forEach(v => vistas.add(v.id));
      todas.push(...nuevas);
      // Sin viviendas nuevas la API no está paginando de verdad: se corta para no repetir la misma página
      if (lote.length < POR_PAGINA || nuevas.length === 0) break;
    }
    return todas;
  }

  rangoInvalido(): boolean {
    return !!(this.desde && this.hasta && this.desde > this.hasta);
  }

  etiquetaEstado(estado: EstadoVisita): string {
    return ETIQUETAS_ESTADO_VISITA[estado] ?? estado;
  }

  claseEstado(estado: EstadoVisita): string {
    return CLASES_ESTADO_VISITA[estado] ?? 'bg-slate-100 text-slate-700 border-slate-200';
  }

  etiquetaMotivo(motivo: string): string {
    return MOTIVOS_VISITA.find(m => m.valor === motivo)?.etiqueta ?? motivo;
  }

  formatearFecha(iso: string | null | undefined): string {
    return formatearFechaVisita(iso);
  }

  buscar(): void {
    if (this.rangoInvalido()) return;

    const filtros: FiltrosHistoricoVisitas = {};
    // Los inputs de fecha traen yyyy-MM-dd en hora local: se cubre el día completo y se manda en UTC
    if (this.desde) filtros.desde = new Date(`${this.desde}T00:00:00`).toISOString();
    if (this.hasta) filtros.hasta = new Date(`${this.hasta}T23:59:59.999`).toISOString();
    if (this.viviendaId) filtros.viviendaId = this.viviendaId;
    if (this.estado) filtros.estado = this.estado;

    this.filtrosAplicados = filtros;
    this.historicoService.cargar(filtros, 1);
  }

  limpiar(): void {
    this.desde = '';
    this.hasta = '';
    this.viviendaId = null;
    this.estado = null;
    this.filtrosAplicados = {};
    this.historicoService.cargar({}, 1);
  }

  irAPagina(pagina: number): void {
    if (pagina < 1 || pagina > this.totalPaginas()) return;
    this.historicoService.cargar(this.filtrosAplicados, pagina);
  }
}
