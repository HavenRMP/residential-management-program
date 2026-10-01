import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import Swal from 'sweetalert2';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { filtrarDirectorio, telefonoParaLlamar } from '../../../core/utils/directorio-casas.util';

const MAX_RESULTADOS = 20;

/**
 * Directorio de caseta: quién vive en cada casa y a qué teléfono llamar.
 * Los teléfonos no se listan completos: aparecen al buscar por casa, nombre o teléfono.
 */
@Component({
  selector: 'app-directorio-casas',
  standalone: true,
  imports: [CommonModule],
  template: `
    <section class="rounded-xl border border-slate-200 bg-white shadow-xs" aria-labelledby="directorio-titulo">
      <div class="p-4 border-b border-slate-200">
        <h2 id="directorio-titulo" class="text-sm font-semibold text-slate-900">Directorio de casas</h2>
        <p class="text-xs text-slate-500 mt-0.5">Quién vive en cada casa y a qué teléfono llamar.</p>

        <div class="relative mt-3">
          <svg class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-4.35-4.35M10.5 18a7.5 7.5 0 100-15 7.5 7.5 0 000 15z" />
          </svg>
          <input
            type="search"
            [value]="consulta()"
            (input)="consulta.set($any($event.target).value)"
            aria-label="Buscar en el directorio de casas"
            placeholder="Casa, nombre o teléfono"
            autocomplete="off"
            class="h-9 w-full pl-9 pr-9 text-sm rounded-lg border border-slate-200 bg-white text-slate-900 placeholder-slate-400 focus:outline-hidden focus:border-[#111C99] focus:ring-2 focus:ring-[#111C99]/15"
          />
          <button
            *ngIf="consulta()"
            type="button"
            (click)="consulta.set('')"
            aria-label="Borrar búsqueda"
            class="absolute right-1.5 top-1/2 -translate-y-1/2 h-6 w-6 inline-flex items-center justify-center rounded-md text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
          >
            <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>

      <!-- Carga -->
      <div *ngIf="directorio.isLoading()" class="divide-y divide-slate-100" aria-busy="true">
        <div *ngFor="let s of [1, 2]" class="px-4 py-3 flex items-center gap-3 animate-pulse">
          <div class="h-6 w-12 rounded-md bg-slate-200"></div>
          <div class="flex-1 space-y-1.5">
            <div class="h-3.5 w-1/2 bg-slate-200 rounded"></div>
            <div class="h-3 w-1/3 bg-slate-100 rounded"></div>
          </div>
        </div>
      </div>

      <!-- Error de carga -->
      <div
        *ngIf="!directorio.isLoading() && directorio.errorMessage() as msg"
        class="m-4 rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex items-center justify-between gap-3"
      >
        <span>{{ msg }}</span>
        <button type="button" (click)="reintentar()" class="shrink-0 font-semibold underline cursor-pointer">Reintentar</button>
      </div>

      <ng-container *ngIf="!directorio.isLoading() && !directorio.errorMessage()">
        <!-- Sin búsqueda: invita a escribir -->
        <p *ngIf="!consultaActiva()" class="px-4 py-6 text-center text-xs text-slate-500">
          Escribe un número de casa o un nombre para ver quién vive ahí y su teléfono.
        </p>

        <!-- Sin coincidencias -->
        <p *ngIf="consultaActiva() && filas().length === 0" class="px-4 py-6 text-center text-xs text-slate-500">
          No hay casas ni residentes que coincidan con "{{ consulta().trim() }}".
        </p>

        <!-- Resultados: casa, residente y teléfono en una misma fila -->
        <ul *ngIf="mostradas().length > 0" class="divide-y divide-slate-100">
          <li *ngFor="let f of mostradas()" class="px-4 py-3 flex items-center gap-3">
            <span class="shrink-0 min-w-[3.5rem] text-center font-mono text-xs font-semibold text-slate-700 bg-slate-100 border border-slate-200 rounded-md px-2 py-1">
              {{ f.numeroCasa }}
            </span>

            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold truncate" [class.text-slate-900]="f.nombreCompleto" [class.text-slate-400]="!f.nombreCompleto" [class.font-normal]="!f.nombreCompleto">
                {{ f.nombreCompleto ?? 'Sin residentes registrados' }}
              </p>
              <p *ngIf="f.telefono" class="font-mono text-xs text-slate-600">{{ f.telefono }}</p>
              <p *ngIf="f.nombreCompleto && !f.telefono" class="text-xs text-slate-400">Sin teléfono registrado</p>
            </div>

            <div *ngIf="f.telefono" class="shrink-0 flex items-center gap-1">
              <a
                [href]="enlaceTelefono(f.telefono)"
                [attr.aria-label]="'Llamar a ' + f.nombreCompleto"
                class="h-8 px-2.5 inline-flex items-center rounded-md border border-slate-200 bg-white text-xs font-semibold text-slate-700 hover:bg-slate-50 transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
              >
                Llamar
              </a>
              <button
                type="button"
                (click)="copiarTelefono(f.telefono)"
                [attr.aria-label]="'Copiar el teléfono de ' + f.nombreCompleto"
                title="Copiar teléfono"
                class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-slate-200 bg-white text-slate-500 hover:text-slate-900 hover:bg-slate-50 transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
              >
                <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </button>
            </div>
          </li>
        </ul>

        <p *ngIf="consultaActiva() && filas().length > 0" class="px-4 py-2 border-t border-slate-100 text-xs text-slate-500" aria-live="polite">
          {{ filas().length > mostradas().length
              ? 'Mostrando ' + mostradas().length + ' de ' + filas().length + '. Afina la búsqueda para ver el resto.'
              : filas().length + (filas().length === 1 ? ' resultado' : ' resultados') }}
        </p>
      </ng-container>
    </section>
  `
})
export class DirectorioCasasComponent implements OnInit {
  readonly directorio = inject(DirectorioCasasService);

  readonly consulta = signal<string>('');
  readonly consultaActiva = computed(() => this.consulta().trim().length > 0);
  readonly filas = computed(() => filtrarDirectorio(this.directorio.casas(), this.consulta()));
  readonly mostradas = computed(() => this.filas().slice(0, MAX_RESULTADOS));

  ngOnInit(): void {
    this.directorio.cargar();
  }

  reintentar(): void {
    this.directorio.cargar(true);
  }

  enlaceTelefono(telefono: string): string {
    return `tel:${telefonoParaLlamar(telefono)}`;
  }

  async copiarTelefono(telefono: string): Promise<void> {
    try {
      await navigator.clipboard.writeText(telefono);
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Teléfono copiado', showConfirmButton: false, timer: 2000 });
    } catch (err) {
      console.error('[DirectorioCasasComponent] No se pudo copiar el teléfono:', err);
      Swal.fire({ icon: 'info', title: 'Teléfono', text: telefono, confirmButtonColor: '#111C99' });
    }
  }
}
