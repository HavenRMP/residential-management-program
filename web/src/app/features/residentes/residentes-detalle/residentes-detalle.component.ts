import { Component, Input, Output, EventEmitter, HostListener, inject, OnChanges, SimpleChanges, signal } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { Residente } from '../../../core/models/residente.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { getInitials } from '../../../core/utils/iniciales.util';
import { formatearNumeroCasa } from '../../../core/utils/vivienda.util';

@Component({
  selector: 'app-residentes-detalle',
  standalone: true,
  imports: [CommonModule, DatePipe],
  template: `
    <!-- Sticky Drawer Top Bar -->
    <div class="sticky top-0 z-10 bg-white/95 backdrop-blur-md px-6 py-4 border-b border-slate-100 flex items-center justify-between">
      <div class="flex items-center gap-2.5">
        <div class="w-8 h-8 rounded-lg bg-[#111C99] text-white flex items-center justify-center font-bold text-xs shadow-2xs">
          {{ getInitials(residente?.nombre, residente?.apellidos) }}
        </div>
        <span id="detalle-residente-title" class="text-sm font-bold text-slate-900 tracking-tight">Detalle del Residente</span>
      </div>

      <!-- Close Button -->
      <button
        type="button"
        (click)="cerrar()"
        class="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-all cursor-pointer focus:outline-none focus:ring-2 focus:ring-[#111C99]/20"
        aria-label="Cerrar detalle del residente"
        title="Cerrar detalle (Esc)"
      >
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>

    <div class="p-4 sm:p-6 space-y-6 flex-1 flex flex-col justify-between">
      <div class="space-y-5">
        <!-- Hero Profile -->
        <div class="flex flex-col items-center text-center">
          <div class="w-20 h-20 sm:w-24 sm:h-24 rounded-full bg-[#111C99] text-white font-bold text-2xl sm:text-3xl flex items-center justify-center shadow-md ring-4 ring-slate-100">
            {{ getInitials(residente?.nombre, residente?.apellidos) }}
          </div>
          <h2 class="text-xl sm:text-2xl font-extrabold text-slate-900 mt-4 tracking-tight">
            {{ residente?.nombre }} {{ residente?.apellidos }}
          </h2>
          <div class="mt-2">
            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
              Residente Haven
            </span>
          </div>
        </div>

        <!-- Viviendas Asignadas -->
        <div class="bg-white border border-slate-200/80 rounded-xl p-4 sm:p-5 shadow-xs space-y-3">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <div class="w-7 h-7 rounded-lg bg-indigo-50 text-indigo-700 flex items-center justify-center border border-indigo-100">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
              </div>
              <h3 class="text-xs font-bold text-slate-900 uppercase tracking-wider">
                Vivienda{{ viviendasAsignadas().length > 1 ? 's' : '' }} Asignada{{ viviendasAsignadas().length > 1 ? 's' : '' }}
              </h3>
            </div>

            <span
              *ngIf="!cargandoViviendas()"
              class="text-[11px] font-semibold px-2.5 py-0.5 rounded-full"
              [ngClass]="viviendasAsignadas().length > 0 ? 'bg-indigo-50 text-indigo-700 border border-indigo-200' : 'bg-amber-50 text-amber-800 border border-amber-200'"
            >
              {{ viviendasAsignadas().length > 0 ? (viviendasAsignadas().length === 1 ? '1 vivienda' : viviendasAsignadas().length + ' viviendas') : 'Sin vivienda' }}
            </span>
          </div>

          <!-- Spinner durante carga reactiva -->
          <div *ngIf="cargandoViviendas()" class="flex items-center gap-2 py-3 justify-center text-xs text-slate-500 font-medium">
            <div class="w-4 h-4 border-2 border-slate-200 border-t-indigo-700 rounded-full animate-spin"></div>
            <span>Consultando viviendas...</span>
          </div>

          <!-- Lista de viviendas vinculadas -->
          <div *ngIf="!cargandoViviendas() && viviendasAsignadas().length > 0" class="space-y-2 pt-1">
            <div
              *ngFor="let v of viviendasAsignadas()"
              class="flex items-center justify-between p-3 rounded-lg bg-slate-50/80 border border-slate-200 hover:bg-slate-100/70 transition-colors"
            >
              <div class="flex items-center gap-3">
                <div class="w-8 h-8 rounded-lg bg-white border border-slate-200 text-indigo-700 flex items-center justify-center font-bold text-xs shadow-2xs">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                  </svg>
                </div>
                <div>
                  <p class="text-sm font-bold text-slate-900">{{ formatearNumeroCasa(v.numeroCasa) }}</p>
                  <p class="text-[11px] text-slate-600 font-medium">Tipo: {{ v.tipo || 'Residencial' }}</p>
                </div>
              </div>

              <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                Asignada
              </span>
            </div>
          </div>

          <!-- Estado vacío: Sin vivienda -->
          <div *ngIf="!cargandoViviendas() && viviendasAsignadas().length === 0" class="p-3 rounded-lg bg-amber-50/70 border border-amber-200 text-xs text-amber-900 space-y-1">
            <div class="flex items-center gap-1.5 font-semibold text-amber-900">
              <span class="w-2 h-2 rounded-full bg-amber-500"></span>
              <span>Sin vivienda vinculada</span>
            </div>
            <p class="text-amber-800 text-[11px] leading-relaxed">
              Este residente está registrado en el condominio pero aún no tiene una vivienda asignada.
            </p>
          </div>
        </div>

        <!-- Información de Contacto -->
        <div class="bg-white border border-slate-200/80 rounded-xl p-4 sm:p-5 shadow-xs divide-y divide-slate-100">
          <!-- Correo Electrónico -->
          <div class="pb-4">
            <span class="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5">
              Correo Electrónico
            </span>
            <div class="flex items-center gap-2.5 text-sm font-semibold text-slate-800">
              <svg class="w-4 h-4 text-[#111C99] shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              <span class="break-all">{{ residente?.email || '—' }}</span>
            </div>
          </div>

          <!-- Teléfono -->
          <div class="py-4">
            <span class="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5">
              Teléfono
            </span>
            <div class="flex items-center gap-2.5 text-sm font-semibold text-slate-800">
              <svg class="w-4 h-4 text-[#111C99] shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
              </svg>
              <span>{{ residente?.telefono || '—' }}</span>
            </div>
          </div>

          <!-- Fecha de Alta -->
          <div class="pt-4">
            <span class="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5">
              Fecha de Alta
            </span>
            <div class="flex items-center gap-2.5 text-sm font-semibold text-slate-800">
              <svg class="w-4 h-4 text-[#111C99] shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <span>{{ residente?.creadoEn ? (residente?.creadoEn | date:'dd/MM/yyyy') : '—' }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ID de Usuario (Soporte Admin) -->
      <div class="pt-6 border-t border-slate-100 flex items-center justify-between text-xs text-slate-400">
        <span class="font-medium">ID de referencia:</span>
        <span class="font-mono bg-slate-100 px-2 py-1 rounded-md text-slate-600 select-all">{{ residente?.id || '—' }}</span>
      </div>
    </div>
  `
})
export class ResidentesDetalleComponent implements OnChanges {
  @Input() residente: Residente | null = null;
  @Input() viviendas: Vivienda[] = [];
  @Output() cerrado = new EventEmitter<void>();

  private readonly viviendasService = inject(ViviendasService);

  readonly cargandoViviendas = signal<boolean>(false);
  readonly viviendasAsignadas = signal<Vivienda[]>([]);
  readonly getInitials = getInitials;
  readonly formatearNumeroCasa = formatearNumeroCasa;

  @HostListener('window:keydown.escape')
  handleEscape(): void {
    this.cerrar();
  }

  async ngOnChanges(changes: SimpleChanges): Promise<void> {
    if (changes['viviendas']) {
      this.viviendasAsignadas.set(this.viviendas || []);
    }

    if (changes['residente'] && this.residente) {
      // Si el componente padre ya suministró las viviendas (incluso si la lista está vacía []),
      // confiamos en ella y evitamos disparar una petición de red redundante.
      if (this.viviendas !== undefined && this.viviendas !== null) {
        this.viviendasAsignadas.set(this.viviendas);
      } else {
        await this.cargarViviendasResidente();
      }
    }
  }

  async cargarViviendasResidente(): Promise<void> {
    if (!this.residente || !this.residente.id) {
      this.viviendasAsignadas.set([]);
      return;
    }

    this.cargandoViviendas.set(true);
    try {
      const list = await this.viviendasService.obtenerViviendasDeResidente(this.residente.id);
      this.viviendasAsignadas.set(list);
    } catch {
      this.viviendasAsignadas.set([]);
    } finally {
      this.cargandoViviendas.set(false);
    }
  }

  cerrar(): void {
    this.cerrado.emit();
  }
}

