import { Component, ElementRef, HostListener, ViewChild, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AuthService } from '../../../core/services/auth.service';
import { AvisosService } from '../../../core/services/avisos.service';
import { Aviso, AvisoPrioridad } from '../../../core/models/aviso.model';
import {
  claseBadgePrioridad,
  etiquetaPrioridad,
  ordenarAvisosPorPrioridad,
  tiempoRestanteAviso
} from '../../../core/utils/aviso-prioridad.util';

/** Barra de color a la izquierda de cada aviso; la prioridad también se dice con ícono y etiqueta */
const ACENTO: Record<AvisoPrioridad, string> = {
  urgente: 'border-l-rose-500',
  mantenimiento: 'border-l-amber-500',
  evento: 'border-l-indigo-500',
  informativo: 'border-l-slate-300'
};

const ICONO: Record<AvisoPrioridad, string> = {
  urgente: 'M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z',
  mantenimiento: 'M21.75 6.75a4.5 4.5 0 01-4.884 4.484c-1.076-.091-2.264.071-2.95.904l-7.152 8.684a2.548 2.548 0 11-3.586-3.586l8.684-7.152c.833-.686.995-1.874.904-2.95a4.5 4.5 0 016.336-4.486l-3.276 3.276a3.004 3.004 0 002.25 2.25l3.276-3.276c.256.565.398 1.192.398 1.852z',
  evento: 'M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5',
  informativo: 'M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z'
};

/**
 * Avisos vigentes del condominio para el personal de caseta. Es de solo lectura:
 * el vigilante los consulta pero no puede publicarlos, editarlos ni borrarlos.
 * El detalle se abre en un panel lateral para no tapar la caseta.
 */
@Component({
  selector: 'app-avisos-caseta',
  standalone: true,
  imports: [CommonModule],
  styles: [`
    @keyframes avisos-panel-entrada { from { transform: translateX(1.5rem); opacity: 0; } to { transform: none; opacity: 1; } }
    .avisos-panel { animation: avisos-panel-entrada 160ms ease-out; }
    @media (prefers-reduced-motion: reduce) { .avisos-panel { animation: none; } }
  `],
  template: `
    <section class="rounded-xl border border-slate-200 bg-white shadow-xs" aria-labelledby="avisos-titulo">
      <div class="p-4 border-b border-slate-200 flex items-start justify-between gap-3">
        <div>
          <h2 id="avisos-titulo" class="text-sm font-semibold text-slate-900">Avisos del condominio</h2>
          <p class="text-xs text-slate-500 mt-0.5">Lo que la administración comunicó a los vecinos.</p>
        </div>
        <div class="shrink-0 flex flex-col items-end gap-1">
          <span class="text-xs font-semibold text-slate-600">{{ avisos().length }} vigente{{ avisos().length === 1 ? '' : 's' }}</span>
          <span
            *ngIf="urgentes() > 0"
            class="inline-flex items-center px-1.5 py-0.5 rounded-md text-[11px] font-semibold border bg-rose-50 text-rose-700 border-rose-200"
          >
            {{ urgentes() }} urgente{{ urgentes() === 1 ? '' : 's' }}
          </span>
        </div>
      </div>

      <div *ngIf="avisosService.isLoading()" class="divide-y divide-slate-100" aria-busy="true">
        <div *ngFor="let s of [1, 2]" class="p-4 animate-pulse space-y-2">
          <div class="h-4 w-20 bg-slate-200 rounded"></div>
          <div class="h-3.5 w-1/2 bg-slate-200 rounded"></div>
          <div class="h-3 w-3/4 bg-slate-100 rounded"></div>
        </div>
      </div>

      <div
        *ngIf="!avisosService.isLoading() && avisosService.errorMessage() as msg"
        class="m-4 rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium"
      >
        {{ msg }}
      </div>

      <ul *ngIf="!avisosService.isLoading() && avisos().length > 0" class="divide-y divide-slate-100">
        <li *ngFor="let a of avisos()">
          <button
            type="button"
            (click)="abrir(a, $event)"
            class="w-full text-left px-4 py-3 border-l-4 hover:bg-slate-50 transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#111C99]"
            [ngClass]="acento(a)"
          >
            <div class="flex items-center justify-between gap-2">
              <span class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-[11px] font-semibold border" [ngClass]="clase(a)">
                <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" [attr.d]="icono(a)" />
                </svg>
                {{ etiqueta(a) }}
              </span>
              <span class="text-[11px]" [ngClass]="venceProximo(a) ? 'font-semibold text-amber-700' : 'font-medium text-slate-500'">
                {{ tiempoRestante(a) }}
              </span>
            </div>
            <h3 class="mt-1.5 text-sm font-semibold text-slate-900 leading-snug">{{ a.titulo }}</h3>
            <p class="mt-0.5 text-xs text-slate-600 line-clamp-2 leading-relaxed">{{ a.contenido }}</p>
          </button>
        </li>
      </ul>

      <div
        *ngIf="!avisosService.isLoading() && !avisosService.errorMessage() && avisos().length === 0"
        class="px-4 py-6 text-center text-xs text-slate-500"
      >
        No hay avisos vigentes en este momento.
      </div>
    </section>

    <!-- Detalle del aviso en panel lateral -->
    <div *ngIf="seleccionado() as a" class="fixed inset-0 z-50">
      <div class="absolute inset-0 bg-slate-900/40" (click)="cerrar()" aria-hidden="true"></div>
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="aviso-detalle-titulo"
        class="avisos-panel absolute inset-y-0 right-0 w-full max-w-md bg-white border-l border-slate-200 shadow-2xl flex flex-col"
      >
        <div class="p-4 border-b border-slate-200 flex items-start justify-between gap-3">
          <div class="min-w-0">
            <span class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-[11px] font-semibold border" [ngClass]="clase(a)">
              <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" [attr.d]="icono(a)" />
              </svg>
              {{ etiqueta(a) }}
            </span>
            <h2 id="aviso-detalle-titulo" class="mt-2 text-base font-semibold text-slate-900 leading-snug">{{ a.titulo }}</h2>
          </div>
          <button
            #botonCerrar
            type="button"
            (click)="cerrar()"
            aria-label="Cerrar detalle del aviso"
            class="shrink-0 h-8 w-8 inline-flex items-center justify-center rounded-md text-slate-500 hover:text-slate-900 hover:bg-slate-100 transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="flex-1 overflow-y-auto p-4 space-y-4">
          <p class="text-sm text-slate-700 leading-relaxed whitespace-pre-line">{{ a.contenido }}</p>

          <dl class="grid grid-cols-3 gap-x-3 gap-y-2 text-xs border-t border-slate-100 pt-4">
            <ng-container *ngIf="a.fechaPublicacion">
              <dt class="text-slate-500">Publicado</dt>
              <dd class="col-span-2 font-mono text-slate-800">{{ fecha(a.fechaPublicacion) }}</dd>
            </ng-container>
            <dt class="text-slate-500">Vigente hasta</dt>
            <dd class="col-span-2 text-slate-800">
              <span class="font-mono">{{ fecha(a.fechaExpiracion) }}</span>
              <span class="ml-1.5" [ngClass]="venceProximo(a) ? 'font-semibold text-amber-700' : 'text-slate-500'">({{ tiempoRestante(a) }})</span>
            </dd>
            <ng-container *ngIf="a.creadoPorNombre">
              <dt class="text-slate-500">Publicado por</dt>
              <dd class="col-span-2 text-slate-800">{{ a.creadoPorNombre }}</dd>
            </ng-container>
          </dl>
        </div>

        <div class="p-4 border-t border-slate-200 flex justify-end">
          <button
            type="button"
            (click)="cerrar()"
            class="h-9 px-4 rounded-lg border border-slate-200 bg-white text-xs font-semibold text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
          >
            Cerrar
          </button>
        </div>
      </div>
    </div>
  `
})
export class AvisosCasetaComponent implements OnInit {
  private readonly authService = inject(AuthService);
  readonly avisosService = inject(AvisosService);

  @ViewChild('botonCerrar') private botonCerrar?: ElementRef<HTMLButtonElement>;

  readonly avisos = computed(() => ordenarAvisosPorPrioridad(this.avisosService.vigentes()));
  readonly urgentes = computed(() => this.avisos().filter(a => a.prioridad === 'urgente').length);
  readonly seleccionado = signal<Aviso | null>(null);

  /** Elemento que abrió el panel, para devolverle el foco al cerrarlo */
  private disparador: HTMLElement | null = null;

  ngOnInit(): void {
    this.avisosService.cargarAvisos(this.authService.currentUser()?.condominioId);
  }

  @HostListener('document:keydown.escape')
  alPresionarEscape(): void {
    if (this.seleccionado()) this.cerrar();
  }

  abrir(aviso: Aviso, evento?: Event): void {
    this.disparador = (evento?.currentTarget as HTMLElement | null) ?? null;
    this.seleccionado.set(aviso);
    // El botón de cerrar existe hasta que Angular pinta el panel
    setTimeout(() => this.botonCerrar?.nativeElement.focus());
  }

  cerrar(): void {
    this.seleccionado.set(null);
    this.disparador?.focus();
    this.disparador = null;
  }

  prioridad(aviso: Aviso): AvisoPrioridad {
    return aviso.prioridad ?? 'informativo';
  }

  clase(aviso: Aviso): string {
    return claseBadgePrioridad(aviso.prioridad);
  }

  etiqueta(aviso: Aviso): string {
    return etiquetaPrioridad(aviso.prioridad);
  }

  acento(aviso: Aviso): string {
    return ACENTO[this.prioridad(aviso)];
  }

  icono(aviso: Aviso): string {
    return ICONO[this.prioridad(aviso)];
  }

  tiempoRestante(aviso: Aviso): string {
    return tiempoRestanteAviso(aviso);
  }

  /** Falta un día o menos para que venza: se resalta para que el guardia lo note */
  venceProximo(aviso: Aviso): boolean {
    const restante = new Date(aviso.fechaExpiracion).getTime() - Date.now();
    return restante > 0 && restante <= 24 * 60 * 60 * 1000;
  }

  fecha(iso: string): string {
    return new Date(iso).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' });
  }
}
