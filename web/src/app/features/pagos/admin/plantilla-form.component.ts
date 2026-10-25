import { AfterViewInit, ChangeDetectionStrategy, Component, ElementRef, EventEmitter, HostListener, Input, OnInit, Output, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PlantillasCargoService } from '../../../core/services/plantillas-cargo.service';
import {
  ETIQUETAS_TIPO_CARGO,
  FormularioPlantilla,
  LIMITES_PAGOS,
  Plantilla,
  RESPONSABLES_PAGO,
  ResponsablePago,
  TIPOS_CARGO,
  TipoCargo,
  fechaLocalIso,
  tieneMasDeDosDecimales,
  validarPlantilla
} from '../../../core/models/pagos.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';
import { RetornoFocoDirective } from '../../../core/directives/retorno-foco.directive';

/**
 * Alta de una plantilla recurrente para varias viviendas a la vez (cada una puede tener su propio monto) o
 * corrección de una plantilla existente. De la plantilla ya creada solo se corrigen el concepto, el monto, el día
 * de vencimiento, quién paga y cuándo termina.
 */
@Component({
  selector: 'app-plantilla-form',
  standalone: true,
  imports: [CommonModule, FormsModule, RetornoFocoDirective],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
      <div class="bg-white rounded-lg max-w-xl w-full p-5 shadow-lg border border-slate-200" appRetornoFoco role="dialog" aria-modal="true" aria-labelledby="plantilla-form-titulo">
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 id="plantilla-form-titulo" class="text-sm font-semibold text-slate-900">
            {{ plantilla ? 'Editar plantilla' : 'Nueva plantilla de cargo' }}
          </h3>
          <button type="button" (click)="cerrar()" aria-label="Cerrar" class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-3.5 space-y-3">
          @if (plantilla) {
            <p class="text-xs text-slate-600" data-test="resumen-plantilla">
              Casa {{ plantilla.numeroCasa }} · {{ etiquetasTipo[plantilla.tipo] }} · desde {{ plantilla.vigenciaInicio }}
            </p>
          }

          <div>
            <label for="plantilla-concepto" class="block text-xs font-semibold text-slate-800 mb-1">Concepto *</label>
            <input id="plantilla-concepto" type="text" [(ngModel)]="form.concepto" [attr.maxlength]="limites.concepto" placeholder="Ej. Cuota de mantenimiento"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            @if (!plantilla) {
              <div>
                <label for="plantilla-tipo" class="block text-xs font-semibold text-slate-800 mb-1">Tipo *</label>
                <select id="plantilla-tipo" [(ngModel)]="form.tipo"
                  class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
                  @for (t of tipos; track t) {
                    <option [ngValue]="t">{{ etiquetasTipo[t] }}</option>
                  }
                </select>
              </div>
            }
            <div>
              <label for="plantilla-responsable" class="block text-xs font-semibold text-slate-800 mb-1">Quién paga</label>
              <select id="plantilla-responsable" [(ngModel)]="responsable"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
                @for (r of responsables; track r) {
                  <option [ngValue]="r">{{ r }}</option>
                }
              </select>
            </div>
            <div>
              <label for="plantilla-monto" class="block text-xs font-semibold text-slate-800 mb-1">{{ plantilla ? 'Monto *' : 'Monto común *' }}</label>
              <input id="plantilla-monto" type="number" min="0.01" step="0.01" inputmode="decimal" [(ngModel)]="form.monto"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label for="plantilla-dia" class="block text-xs font-semibold text-slate-800 mb-1">Día de vencimiento *</label>
              <input id="plantilla-dia" type="number" min="1" max="31" step="1" inputmode="numeric" [(ngModel)]="form.diaVencimiento"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            @if (!plantilla) {
              <div>
                <label for="plantilla-inicio" class="block text-xs font-semibold text-slate-800 mb-1">Aplica desde *</label>
                <input id="plantilla-inicio" type="date" [(ngModel)]="form.vigenciaInicio"
                  class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
              </div>
            }
            <div>
              <label for="plantilla-fin" class="block text-xs font-semibold text-slate-800 mb-1">Termina el (opcional)</label>
              <input id="plantilla-fin" type="date" [(ngModel)]="form.vigenciaFin"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          </div>
          <p class="text-[11px] text-slate-500">En meses más cortos, un día 31 vence el último día del mes.</p>

          @if (!plantilla) {
            <fieldset class="space-y-2">
              <div class="flex flex-wrap items-center justify-between gap-2">
                <legend class="text-xs font-semibold text-slate-800">Viviendas * <span class="font-normal text-slate-500">({{ seleccionadas().size }} elegidas)</span></legend>
                <button type="button" (click)="alternarTodas()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">
                  {{ todasElegidas() ? 'Quitar todas' : 'Elegir todas' }}
                </button>
              </div>
              <div class="max-h-52 overflow-y-auto rounded-md border border-slate-200 divide-y divide-slate-100" data-test="viviendas">
                @for (v of viviendas; track v.id) {
                  <div class="flex items-center justify-between gap-3 px-3 py-1.5">
                    <label class="inline-flex items-center gap-2 text-xs text-slate-800 cursor-pointer">
                      <input type="checkbox" [checked]="seleccionadas().has(v.id)" (change)="alternar(v.id)" class="size-4 rounded border-slate-300 accent-[#111C99]" />
                      Casa {{ v.numeroCasa }}
                    </label>
                    @if (seleccionadas().has(v.id)) {
                      <input type="number" min="0.01" step="0.01" inputmode="decimal" [(ngModel)]="montosPropios[v.id]" placeholder="Monto propio"
                        [attr.aria-label]="'Monto propio de la casa ' + v.numeroCasa"
                        class="h-7 w-32 text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
                    }
                  </div>
                }
                @if (viviendas.length === 0) {
                  <p class="px-3 py-3 text-xs text-slate-500">No hay viviendas registradas.</p>
                }
              </div>
              <p class="text-[11px] text-slate-500">Deja vacío el monto propio para usar el monto común.</p>
            </fieldset>
          }

          @if (error(); as msg) {
            <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium" role="alert">{{ msg }}</div>
          }

          <div class="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
            <button type="button" (click)="cerrar()" [disabled]="isSaving()"
              class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer disabled:opacity-50">Cancelar</button>
            <button type="button" (click)="guardar()" [disabled]="isSaving()"
              class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
              {{ isSaving() ? 'Guardando...' : (plantilla ? 'Guardar cambios' : 'Crear plantilla') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
})
export class PlantillaFormComponent implements OnInit, AfterViewInit {
  private readonly plantillasService = inject(PlantillasCargoService);
  private readonly elemento = inject(ElementRef<HTMLElement>);

  @Input() viviendas: Vivienda[] = [];
  /** Plantilla que se corrige; sin ella el formulario da de alta plantillas nuevas */
  @Input() plantilla: Plantilla | null = null;

  @Output() cerrado = new EventEmitter<void>();
  /** Cuántas plantillas quedaron guardadas (una por vivienda al crear, una al editar) */
  @Output() guardado = new EventEmitter<number>();

  readonly tipos = TIPOS_CARGO;
  readonly etiquetasTipo = ETIQUETAS_TIPO_CARGO;
  readonly responsables = RESPONSABLES_PAGO;
  readonly limites = LIMITES_PAGOS;
  readonly isSaving = signal<boolean>(false);
  readonly error = signal<string | null>(null);
  readonly seleccionadas = signal<ReadonlySet<number>>(new Set());
  readonly todasElegidas = computed(() => this.viviendas.length > 0 && this.seleccionadas().size === this.viviendas.length);

  form: { concepto: string; tipo: TipoCargo; monto: number | null; diaVencimiento: number | null; vigenciaInicio: string; vigenciaFin: string } = {
    concepto: '',
    tipo: 'Mantenimiento',
    monto: null,
    diaVencimiento: 10,
    vigenciaInicio: fechaLocalIso(),
    vigenciaFin: ''
  };
  responsable: ResponsablePago = 'Residente';
  /** Monto propio de cada vivienda elegida, por id; vacío usa el monto común */
  montosPropios: Record<number, number | null> = {};

  ngOnInit(): void {
    const p = this.plantilla;
    if (!p) return;
    this.form = {
      concepto: p.concepto,
      tipo: p.tipo,
      monto: p.monto,
      diaVencimiento: p.diaVencimiento,
      vigenciaInicio: p.vigenciaInicio,
      vigenciaFin: p.vigenciaFin ?? ''
    };
    this.responsable = p.responsablePago;
  }

  ngAfterViewInit(): void {
    (this.elemento.nativeElement as HTMLElement).querySelector<HTMLInputElement>('#plantilla-concepto')?.focus();
  }

  @HostListener('document:keydown.escape')
  alPresionarEscape(): void {
    if (!this.isSaving()) this.cerrar();
  }

  cerrar(): void {
    this.cerrado.emit();
  }

  alternar(id: number): void {
    this.seleccionadas.update(actuales => {
      const siguiente = new Set(actuales);
      if (!siguiente.delete(id)) siguiente.add(id);
      return siguiente;
    });
  }

  alternarTodas(): void {
    this.seleccionadas.set(this.todasElegidas() ? new Set() : new Set(this.viviendas.map(v => v.id)));
  }

  /** Revisa los montos propios de las viviendas elegidas; devuelve el motivo si alguno no sirve */
  private validarMontosPropios(): string | null {
    for (const v of this.viviendas) {
      if (!this.seleccionadas().has(v.id)) continue;
      const propio = this.montosPropios[v.id];
      if (propio == null || (propio as unknown) === '') continue;
      if (!Number.isFinite(propio) || propio <= 0) return `El monto propio de la casa ${v.numeroCasa} debe ser mayor a cero.`;
      if (tieneMasDeDosDecimales(propio)) return `El monto propio de la casa ${v.numeroCasa} no puede tener más de dos decimales.`;
    }
    return null;
  }

  async guardar(): Promise<void> {
    if (this.isSaving()) return;
    const datos: FormularioPlantilla = { ...this.form, viviendasSeleccionadas: this.seleccionadas().size };
    const invalido = validarPlantilla(datos, !!this.plantilla) ?? (this.plantilla ? null : this.validarMontosPropios());
    if (invalido) {
      this.error.set(invalido);
      return;
    }

    this.isSaving.set(true);
    this.error.set(null);
    try {
      if (this.plantilla) {
        await this.plantillasService.actualizar(this.plantilla.id, {
          concepto: this.form.concepto,
          monto: this.form.monto as number,
          diaVencimiento: this.form.diaVencimiento as number,
          vigenciaFin: this.form.vigenciaFin || null,
          responsablePago: this.responsable
        });
        this.guardado.emit(1);
      } else {
        const creadas = await this.plantillasService.crear({
          concepto: this.form.concepto,
          tipo: this.form.tipo,
          monto: this.form.monto as number,
          diaVencimiento: this.form.diaVencimiento as number,
          vigenciaInicio: this.form.vigenciaInicio,
          vigenciaFin: this.form.vigenciaFin || null,
          responsablePago: this.responsable,
          viviendas: this.viviendas
            .filter(v => this.seleccionadas().has(v.id))
            .map(v => ({ viviendaId: v.id, monto: this.montosPropios[v.id] || null }))
        });
        this.guardado.emit(creadas.length);
      }
    } catch (err: any) {
      console.error('[PlantillaFormComponent] Error al guardar la plantilla:', err);
      this.error.set(mensajeConValidacion(err, 'No fue posible guardar la plantilla. Intenta de nuevo en unos segundos.'));
    } finally {
      this.isSaving.set(false);
    }
  }
}
