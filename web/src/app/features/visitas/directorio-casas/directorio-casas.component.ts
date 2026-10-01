import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import Swal from 'sweetalert2';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { FilaDirectorio, filasDelDirectorio, telefonoParaLlamar } from '../../../core/utils/directorio-casas.util';

const POR_PAGINA = 30;

/**
 * Directorio de personas para caseta: cada residente con su casa y su teléfono en una misma fila.
 * Se puede buscar por casa, nombre o teléfono.
 */
@Component({
  selector: 'app-directorio-casas',
  standalone: true,
  imports: [CommonModule],
  template: `
    <section class="rounded-xl border border-slate-200 bg-white shadow-xs" aria-labelledby="directorio-titulo">
      <div class="p-4 border-b border-slate-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h2 id="directorio-titulo" class="text-sm font-semibold text-slate-900">Directorio de personas</h2>
          <p class="text-xs text-slate-500 mt-0.5">Cada residente con su casa y su teléfono.</p>
        </div>

        <div class="relative w-full sm:w-80">
          <svg class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-4.35-4.35M10.5 18a7.5 7.5 0 100-15 7.5 7.5 0 000 15z" />
          </svg>
          <input
            type="search"
            [value]="consulta()"
            (input)="alBuscar($any($event.target).value)"
            aria-label="Buscar en el directorio de personas"
            placeholder="Casa, nombre o teléfono"
            autocomplete="off"
            class="h-9 w-full pl-9 pr-9 text-sm rounded-lg border border-slate-200 bg-white text-slate-900 placeholder-slate-400 focus:outline-hidden focus:border-[#111C99] focus:ring-2 focus:ring-[#111C99]/15 [&::-webkit-search-cancel-button]:hidden"
          />
          <button
            *ngIf="consulta()"
            type="button"
            (click)="alBuscar('')"
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
        <div *ngFor="let s of [1, 2, 3]" class="px-4 py-3 flex items-center gap-4 animate-pulse">
          <div class="h-3.5 w-1/3 bg-slate-200 rounded"></div>
          <div class="h-6 w-14 rounded-md bg-slate-200"></div>
          <div class="h-3.5 w-1/4 bg-slate-100 rounded"></div>
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
        <!-- Encabezado de columnas (escritorio) -->
        <div *ngIf="mostradas().length > 0" class="hidden md:grid grid-cols-[minmax(0,2fr)_7rem_minmax(0,1.4fr)_9rem] gap-x-4 px-4 py-2 bg-slate-50/90 border-b border-slate-200 text-[11px] font-semibold text-slate-500 uppercase tracking-wide">
          <span>Persona</span>
          <span>Casa</span>
          <span>Teléfono</span>
          <span class="text-right">Contacto</span>
        </div>

        <ul *ngIf="mostradas().length > 0" class="divide-y divide-slate-100">
          <li *ngFor="let f of mostradas()" class="px-4 py-3">
            <!-- Escritorio: persona, casa y teléfono en columnas -->
            <div class="hidden md:grid grid-cols-[minmax(0,2fr)_7rem_minmax(0,1.4fr)_9rem] gap-x-4 items-center">
              <p class="text-sm truncate" [ngClass]="f.nombreCompleto ? 'font-semibold text-slate-900' : 'text-slate-400'">
                {{ f.nombreCompleto ?? 'Sin residentes registrados' }}
              </p>
              <span class="justify-self-start font-mono text-xs font-semibold text-slate-700 bg-slate-100 border border-slate-200 rounded-md px-2 py-1">{{ f.numeroCasa }}</span>
              <p class="font-mono text-xs" [ngClass]="f.telefono ? 'text-slate-700' : 'text-slate-400'">
                {{ f.telefono ?? (f.nombreCompleto ? 'Sin teléfono' : '') }}
              </p>
              <div class="justify-self-end">
                <ng-container *ngTemplateOutlet="contacto; context: { $implicit: f }"></ng-container>
              </div>
            </div>

            <!-- Móvil: se apila -->
            <div class="md:hidden flex items-center justify-between gap-3">
              <div class="min-w-0">
                <p class="text-sm truncate" [ngClass]="f.nombreCompleto ? 'font-semibold text-slate-900' : 'text-slate-400'">
                  {{ f.nombreCompleto ?? 'Sin residentes registrados' }}
                </p>
                <p class="mt-1 flex items-center gap-2 text-xs">
                  <span class="font-mono font-semibold text-slate-700 bg-slate-100 border border-slate-200 rounded-md px-1.5 py-0.5">{{ f.numeroCasa }}</span>
                  <span class="font-mono" [ngClass]="f.telefono ? 'text-slate-700' : 'text-slate-400'">{{ f.telefono ?? (f.nombreCompleto ? 'Sin teléfono' : '') }}</span>
                </p>
              </div>
              <ng-container *ngTemplateOutlet="contacto; context: { $implicit: f }"></ng-container>
            </div>
          </li>
        </ul>

        <p *ngIf="filas().length === 0 && !consultaActiva()" class="px-4 py-8 text-center text-xs text-slate-500">
          Todavía no hay residentes registrados en el condominio.
        </p>
        <p *ngIf="filas().length === 0 && consultaActiva()" class="px-4 py-8 text-center text-xs text-slate-500">
          No hay casas ni residentes que coincidan con "{{ consulta().trim() }}".
        </p>

        <div *ngIf="filas().length > 0" class="px-4 py-3 border-t border-slate-100 flex items-center justify-between gap-3">
          <p class="text-xs text-slate-500" aria-live="polite">
            {{ mostradas().length < filas().length
                ? 'Mostrando ' + mostradas().length + ' de ' + filas().length
                : filas().length + (filas().length === 1 ? ' resultado' : ' resultados') }}
          </p>
          <button
            *ngIf="mostradas().length < filas().length"
            type="button"
            (click)="mostrarMas()"
            class="h-8 px-3 rounded-md border border-slate-200 bg-white text-xs font-semibold text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
          >
            Mostrar más
          </button>
        </div>
      </ng-container>
    </section>

    <!-- Acciones de contacto: llamar y copiar el teléfono -->
    <ng-template #contacto let-f>
      <div *ngIf="f.telefono" class="flex items-center gap-1">
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
    </ng-template>
  `
})
export class DirectorioCasasComponent implements OnInit {
  readonly directorio = inject(DirectorioCasasService);

  readonly consulta = signal<string>('');
  readonly limite = signal<number>(POR_PAGINA);
  readonly consultaActiva = computed(() => this.consulta().trim().length > 0);
  readonly filas = computed<FilaDirectorio[]>(() => filasDelDirectorio(this.directorio.casas(), this.consulta()));
  readonly mostradas = computed(() => this.filas().slice(0, this.limite()));

  ngOnInit(): void {
    this.directorio.cargar();
  }

  alBuscar(valor: string): void {
    this.consulta.set(valor);
    this.limite.set(POR_PAGINA);
  }

  mostrarMas(): void {
    this.limite.update(l => l + POR_PAGINA);
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
