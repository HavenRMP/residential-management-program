import { Component, computed, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import Swal from 'sweetalert2';
import { AuthService } from '../../../core/services/auth.service';
import { AvisosService } from '../../../core/services/avisos.service';
import { Aviso } from '../../../core/models/aviso.model';
import {
  claseBadgePrioridad,
  etiquetaPrioridad,
  ordenarAvisosPorPrioridad,
  tiempoRestanteAviso
} from '../../../core/utils/aviso-prioridad.util';

/**
 * Avisos vigentes del condominio para el personal de caseta. Es de solo lectura:
 * el vigilante los consulta pero no puede publicarlos, editarlos ni borrarlos.
 */
@Component({
  selector: 'app-avisos-caseta',
  standalone: true,
  imports: [CommonModule],
  template: `
    <section class="rounded-xl border border-slate-200 bg-white shadow-xs">
      <div class="p-4 border-b border-slate-200 flex items-center justify-between gap-2">
        <div>
          <h2 class="text-sm font-semibold text-slate-900">Avisos del condominio</h2>
          <p class="text-xs text-slate-500 mt-0.5">Comunicados vigentes, los urgentes primero.</p>
        </div>
        <span class="text-xs font-semibold text-slate-600 shrink-0">
          {{ avisos().length }} vigente{{ avisos().length === 1 ? '' : 's' }}
        </span>
      </div>

      <div *ngIf="avisosService.isLoading()" class="divide-y divide-slate-100">
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
            (click)="verDetalle(a)"
            class="w-full text-left p-4 hover:bg-slate-50/90 transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#111C99]"
            [class.border-l-4]="a.prioridad === 'urgente'"
            [class.border-l-rose-500]="a.prioridad === 'urgente'"
          >
            <div class="flex items-center justify-between gap-2 mb-1.5">
              <span class="inline-flex items-center px-2 py-0.5 rounded-md text-[11px] font-semibold border" [ngClass]="clase(a)">
                {{ etiqueta(a) }}
              </span>
              <span class="text-[11px] font-medium text-slate-500">{{ tiempoRestante(a) }}</span>
            </div>
            <h3 class="text-xs font-semibold text-slate-900">{{ a.titulo }}</h3>
            <p class="text-xs text-slate-600 mt-1 line-clamp-2 leading-relaxed">{{ a.contenido }}</p>
          </button>
        </li>
      </ul>

      <div
        *ngIf="!avisosService.isLoading() && !avisosService.errorMessage() && avisos().length === 0"
        class="p-6 text-center text-xs text-slate-600 font-medium"
      >
        No hay avisos vigentes en este momento.
      </div>
    </section>
  `
})
export class AvisosCasetaComponent implements OnInit {
  private readonly authService = inject(AuthService);
  readonly avisosService = inject(AvisosService);

  readonly avisos = computed(() => ordenarAvisosPorPrioridad(this.avisosService.vigentes()));

  ngOnInit(): void {
    this.avisosService.cargarAvisos(this.authService.currentUser()?.condominioId);
  }

  clase(aviso: Aviso): string {
    return claseBadgePrioridad(aviso.prioridad);
  }

  etiqueta(aviso: Aviso): string {
    return etiquetaPrioridad(aviso.prioridad);
  }

  tiempoRestante(aviso: Aviso): string {
    return tiempoRestanteAviso(aviso);
  }

  verDetalle(aviso: Aviso): void {
    Swal.fire({
      icon: aviso.prioridad === 'urgente' ? 'warning' : undefined,
      title: aviso.titulo,
      text: aviso.contenido,
      footer: `${this.etiqueta(aviso)} · ${this.tiempoRestante(aviso)}`,
      confirmButtonColor: '#111C99',
      confirmButtonText: 'Cerrar'
    });
  }
}
