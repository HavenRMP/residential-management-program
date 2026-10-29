import { ChangeDetectionStrategy, Component, EventEmitter, Input, Output, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ViviendaConResidentes } from '../../../core/models/vivienda.model';
import { filtrarCasas } from '../../../core/utils/directorio-casas.util';

/** Elegir una vivienda buscando por su número o por el nombre de quien vive ahí */
@Component({
  selector: 'app-selector-vivienda',
  standalone: true,
  imports: [FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="flex flex-col min-h-0 h-full">
      <label for="selector-vivienda-buscar" class="block text-xs font-semibold text-slate-800 mb-1">Vivienda *</label>
      <input
        id="selector-vivienda-buscar"
        type="search"
        autocomplete="off"
        placeholder="Buscar por casa o por nombre"
        [ngModel]="consulta()"
        (ngModelChange)="consulta.set($event)"
        class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
      />

      <ul class="mt-2 flex-1 min-h-0 overflow-y-auto space-y-1.5 pr-1" aria-label="Viviendas" data-test="viviendas">
        @for (c of visibles(); track c.id) {
          <li>
            <button
              type="button"
              (click)="elegida.emit(c.id)"
              [attr.aria-pressed]="c.id === seleccionada"
              class="w-full text-left rounded-md border px-3 py-2 transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
              [class]="c.id === seleccionada ? 'border-[#111C99] bg-indigo-50' : 'border-slate-200 bg-white hover:bg-slate-50'"
              data-test="vivienda"
            >
              <span class="block text-sm font-semibold text-slate-900">Casa {{ c.numeroCasa }}</span>
              <span class="block text-xs" [class]="c.residentes.length ? 'text-slate-600' : 'text-slate-400'">
                {{ residentes(c) }}
              </span>
            </button>
          </li>
        } @empty {
          <li class="py-6 text-center text-xs text-slate-500 font-medium" data-test="sin-resultados">
            {{ consulta().trim() ? 'Ninguna vivienda coincide con la búsqueda.' : 'No hay viviendas registradas.' }}
          </li>
        }
      </ul>
    </div>
  `
})
export class SelectorViviendaComponent {
  @Input() casas: ViviendaConResidentes[] = [];
  /** Id de la vivienda elegida */
  @Input() seleccionada: number | null = null;
  @Output() elegida = new EventEmitter<number>();

  readonly consulta = signal<string>('');

  visibles(): ViviendaConResidentes[] {
    return filtrarCasas(this.casas, this.consulta());
  }

  residentes(c: ViviendaConResidentes): string {
    return c.residentes.length
      ? c.residentes.map(r => `${r.nombre} ${r.apellidos}`.trim()).join(' · ')
      : 'Sin residentes registrados';
  }
}
