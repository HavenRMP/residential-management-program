import { AfterViewInit, ChangeDetectionStrategy, Component, ElementRef, EventEmitter, HostListener, Input, Output, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PagosService } from '../../../core/services/pagos.service';
import {
  Cargo,
  ETIQUETAS_TIPO_CARGO,
  FormularioCargo,
  LIMITES_PAGOS,
  RESPONSABLES_PAGO,
  ResponsablePago,
  TIPOS_CARGO,
  cargoRequierePeriodo,
  periodoActual,
  validarCargo
} from '../../../core/models/pagos.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';
import { RetornoFocoDirective } from '../../../core/directives/retorno-foco.directive';

/** Alta de un cargo suelto (una multa, un servicio, una cuota extraordinaria…) para una vivienda */
@Component({
  selector: 'app-cargo-form',
  standalone: true,
  imports: [CommonModule, FormsModule, RetornoFocoDirective],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
      <div class="bg-white rounded-lg max-w-lg w-full p-5 shadow-lg border border-slate-200" appRetornoFoco role="dialog" aria-modal="true" aria-labelledby="cargo-form-titulo">
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 id="cargo-form-titulo" class="text-sm font-semibold text-slate-900">Nuevo cargo</h3>
          <button type="button" (click)="cerrar()" aria-label="Cerrar" class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-3.5 space-y-3">
          <div>
            <label for="cargo-vivienda" class="block text-xs font-semibold text-slate-800 mb-1">Vivienda *</label>
            <select id="cargo-vivienda" [(ngModel)]="form.viviendaId"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option [ngValue]="null">Selecciona una vivienda</option>
              @for (v of viviendas; track v.id) {
                <option [ngValue]="v.id">{{ v.numeroCasa }}</option>
              }
            </select>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label for="cargo-tipo" class="block text-xs font-semibold text-slate-800 mb-1">Tipo *</label>
              <select id="cargo-tipo" [(ngModel)]="form.tipo"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
                @for (t of tipos; track t) {
                  <option [ngValue]="t">{{ etiquetasTipo[t] }}</option>
                }
              </select>
            </div>
            <div>
              <label for="cargo-responsable" class="block text-xs font-semibold text-slate-800 mb-1">Quién paga</label>
              <select id="cargo-responsable" [(ngModel)]="responsable"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
                @for (r of responsables; track r) {
                  <option [ngValue]="r">{{ r }}</option>
                }
              </select>
            </div>
          </div>

          <div>
            <label for="cargo-concepto" class="block text-xs font-semibold text-slate-800 mb-1">Concepto *</label>
            <input id="cargo-concepto" type="text" [(ngModel)]="form.concepto" [attr.maxlength]="limites.concepto" placeholder="Ej. Cuota extraordinaria de pintura"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label for="cargo-monto" class="block text-xs font-semibold text-slate-800 mb-1">Monto *</label>
              <input id="cargo-monto" type="number" min="0.01" step="0.01" inputmode="decimal" [(ngModel)]="form.monto"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label for="cargo-vencimiento" class="block text-xs font-semibold text-slate-800 mb-1">Vence el *</label>
              <input id="cargo-vencimiento" type="date" [(ngModel)]="form.fechaVencimiento"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          </div>

          <div>
            <label for="cargo-periodo" class="block text-xs font-semibold text-slate-800 mb-1">Periodo {{ requierePeriodo() ? '*' : '(opcional)' }}</label>
            <input id="cargo-periodo" type="month" [(ngModel)]="form.periodo"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            @if (requierePeriodo()) {
              <p class="mt-1 text-[11px] text-slate-500">La renta y el mantenimiento se cobran por mes.</p>
            }
          </div>

          @if (error(); as msg) {
            <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium" role="alert">{{ msg }}</div>
          }

          <div class="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
            <button type="button" (click)="cerrar()" [disabled]="isSaving()"
              class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer disabled:opacity-50">Cancelar</button>
            <button type="button" (click)="guardar()" [disabled]="isSaving()"
              class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
              {{ isSaving() ? 'Guardando...' : 'Crear cargo' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
})
export class CargoFormComponent implements AfterViewInit {
  private readonly pagosService = inject(PagosService);
  private readonly elemento = inject(ElementRef<HTMLElement>);

  @Input() viviendas: Vivienda[] = [];
  /** Vivienda que se propone al abrir el formulario desde su ficha o su filtro */
  @Input() set viviendaInicial(id: number | null) {
    if (id) this.form.viviendaId = id;
  }

  @Output() cerrado = new EventEmitter<void>();
  @Output() guardado = new EventEmitter<Cargo>();

  readonly tipos = TIPOS_CARGO;
  readonly etiquetasTipo = ETIQUETAS_TIPO_CARGO;
  readonly responsables = RESPONSABLES_PAGO;
  readonly limites = LIMITES_PAGOS;
  readonly isSaving = signal<boolean>(false);
  readonly error = signal<string | null>(null);

  form: FormularioCargo = {
    viviendaId: null,
    tipo: 'Mantenimiento',
    concepto: '',
    monto: null,
    periodo: periodoActual(),
    fechaVencimiento: ''
  };
  responsable: ResponsablePago = 'Residente';

  ngAfterViewInit(): void {
    (this.elemento.nativeElement as HTMLElement).querySelector<HTMLSelectElement>('#cargo-vivienda')?.focus();
  }

  @HostListener('document:keydown.escape')
  alPresionarEscape(): void {
    if (!this.isSaving()) this.cerrar();
  }

  requierePeriodo(): boolean {
    return cargoRequierePeriodo(this.form.tipo);
  }

  cerrar(): void {
    this.cerrado.emit();
  }

  async guardar(): Promise<void> {
    if (this.isSaving()) return;
    const invalido = validarCargo(this.form);
    if (invalido) {
      this.error.set(invalido);
      return;
    }

    this.isSaving.set(true);
    this.error.set(null);
    try {
      const cargo = await this.pagosService.crearCargo({
        viviendaId: this.form.viviendaId as number,
        tipo: this.form.tipo,
        concepto: this.form.concepto,
        monto: this.form.monto as number,
        periodo: this.form.periodo || null,
        fechaVencimiento: this.form.fechaVencimiento,
        responsablePago: this.responsable
      });
      this.guardado.emit(cargo);
    } catch (err: any) {
      console.error('[CargoFormComponent] Error al crear el cargo:', err);
      this.error.set(mensajeConValidacion(err, 'No fue posible crear el cargo. Intenta de nuevo en unos segundos.'));
    } finally {
      this.isSaving.set(false);
    }
  }
}
