import { AfterViewInit, ChangeDetectionStrategy, Component, ElementRef, EventEmitter, HostListener, Input, OnInit, Output, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PagosService } from '../../../core/services/pagos.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import {
  Cargo,
  ETIQUETAS_TIPO_CARGO,
  FormularioCargo,
  LIMITES_PAGOS,
  RESPONSABLES_PAGO,
  ResponsablePago,
  SaldoVivienda,
  TIPOS_CARGO,
  cargoRequierePeriodo,
  formatearMonto,
  periodoActual,
  validarCargo
} from '../../../core/models/pagos.model';
import { Vivienda, ViviendaConResidentes } from '../../../core/models/vivienda.model';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';
import { RetornoFocoDirective } from '../../../core/directives/retorno-foco.directive';
import { SelectorViviendaComponent } from './selector-vivienda.component';

/**
 * Alta de un cargo suelto (una multa, un servicio, una cuota extraordinaria…) para una vivienda, en un panel lateral:
 * a la izquierda se busca la casa por su número o por quien vive ahí y a la derecha se ve quién es y cuánto debe
 * antes de llenar el cargo.
 */
@Component({
  selector: 'app-cargo-form',
  standalone: true,
  imports: [CommonModule, FormsModule, RetornoFocoDirective, SelectorViviendaComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div (click)="alClicFuera()" aria-hidden="true" class="fixed inset-x-0 bottom-0 top-16 lg:top-0 z-50 !m-0 bg-slate-900/50 backdrop-blur-xs animate-fade-in cursor-pointer"></div>

    <aside
      appRetornoFoco
      role="dialog"
      aria-modal="true"
      aria-labelledby="cargo-form-titulo"
      class="fixed top-16 bottom-0 lg:top-0 right-0 z-[60] !m-0 w-full lg:w-[80vw] lg:max-w-6xl bg-white shadow-2xl flex flex-col border-l border-slate-200 animate-slide-left"
    >
      <div class="flex items-center justify-between px-5 py-3.5 border-b border-slate-200 shrink-0">
        <h3 id="cargo-form-titulo" class="text-sm font-semibold text-slate-900">Nuevo cargo</h3>
        <button type="button" (click)="cerrar()" aria-label="Cerrar" class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="flex-1 min-h-0 overflow-y-auto lg:overflow-hidden grid grid-cols-1 lg:grid-cols-5">
        <!-- Casa: se busca por número o por residente -->
        <div class="lg:col-span-2 p-5 border-b lg:border-b-0 lg:border-r border-slate-200 flex flex-col min-h-0 h-80 lg:h-auto shrink-0 lg:shrink">
          <app-selector-vivienda [casas]="casas()" [seleccionada]="form.viviendaId" (elegida)="elegirVivienda($event)" />
        </div>

        <div class="lg:col-span-3 p-5 space-y-4 lg:overflow-y-auto">
          <!-- Quién es y cuánto debe -->
          @if (casaElegida(); as casa) {
            <section class="rounded-lg border border-slate-200 bg-slate-50 p-4 space-y-3" aria-label="Vivienda elegida" data-test="resumen-casa">
              <div>
                <p class="text-sm font-semibold text-slate-900">Casa {{ casa.numeroCasa }}</p>
                @if (casa.residentes.length > 0) {
                  <ul class="mt-1 space-y-0.5">
                    @for (r of casa.residentes; track r.id) {
                      <li class="text-xs text-slate-700">
                        {{ r.nombre }} {{ r.apellidos }}@if (r.telefono) {<span class="text-slate-500"> · {{ r.telefono }}</span>}
                      </li>
                    }
                  </ul>
                } @else {
                  <p class="mt-1 text-xs text-slate-500">Sin residentes registrados.</p>
                }
              </div>
              @if (saldo(); as s) {
                <dl class="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs" data-test="saldo-casa">
                  <div class="rounded-md bg-white border border-slate-200 p-2.5">
                    <dt class="text-slate-500">Por pagar</dt>
                    <dd class="font-semibold text-slate-900">{{ monto(s.totalPendiente) }}</dd>
                  </div>
                  <div class="rounded-md bg-white border p-2.5" [class]="s.totalVencido > 0 ? 'border-rose-200' : 'border-slate-200'">
                    <dt class="text-slate-500">Vencido</dt>
                    <dd class="font-semibold" [class]="s.totalVencido > 0 ? 'text-rose-700' : 'text-slate-900'">{{ monto(s.totalVencido) }}</dd>
                  </div>
                  <div class="rounded-md bg-white border border-slate-200 p-2.5">
                    <dt class="text-slate-500">Saldo a favor</dt>
                    <dd class="font-semibold text-emerald-700">{{ monto(s.saldoAFavor) }}</dd>
                  </div>
                  <div class="rounded-md bg-white border border-slate-200 p-2.5">
                    <dt class="text-slate-500">Cargos abiertos</dt>
                    <dd class="font-semibold text-slate-900">{{ s.totalCargosAbiertos }}</dd>
                  </div>
                </dl>
              } @else if (cargandoSaldo()) {
                <p class="text-xs text-slate-500" role="status">Consultando el saldo de la casa…</p>
              }
            </section>
          } @else {
            <p class="rounded-lg border border-dashed border-slate-300 p-4 text-xs text-slate-500" data-test="sin-casa">
              Elige una vivienda para ver quién vive ahí y cuánto debe.
            </p>
          }

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
        </div>
      </div>

      <div class="px-5 py-3 border-t border-slate-200 flex items-center justify-end gap-2 shrink-0">
        <button type="button" (click)="cerrar()" [disabled]="isSaving()"
          class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer disabled:opacity-50">Cancelar</button>
        <button type="button" (click)="guardar()" [disabled]="isSaving()"
          class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
          {{ isSaving() ? 'Guardando...' : 'Crear cargo' }}
        </button>
      </div>
    </aside>
  `
})
export class CargoFormComponent implements OnInit, AfterViewInit {
  private readonly pagosService = inject(PagosService);
  private readonly directorio = inject(DirectorioCasasService);
  private readonly elemento = inject(ElementRef<HTMLElement>);

  /** Respaldo si el directorio con residentes no carga: las casas se listan solo por su número */
  @Input() set viviendas(lista: Vivienda[]) {
    this.casasSinResidentes = lista.map(v => ({
      id: v.id, numeroCasa: v.numeroCasa, tipo: v.tipo, totalResidentes: 0, estaOcupada: false, residentes: []
    }));
  }
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
  readonly saldo = signal<SaldoVivienda | null>(null);
  readonly cargandoSaldo = signal<boolean>(false);
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

  private casasSinResidentes: ViviendaConResidentes[] = [];
  private ultimaConsultaSaldo = 0;

  ngOnInit(): void {
    void this.directorio.cargar();
    if (this.form.viviendaId) void this.cargarSaldo(this.form.viviendaId);
  }

  ngAfterViewInit(): void {
    (this.elemento.nativeElement as HTMLElement).querySelector<HTMLInputElement>('#selector-vivienda-buscar')?.focus();
  }

  casas(): ViviendaConResidentes[] {
    const directorio = this.directorio.casas();
    return directorio.length > 0 ? directorio : this.casasSinResidentes;
  }

  casaElegida(): ViviendaConResidentes | null {
    return this.casas().find(c => c.id === this.form.viviendaId) ?? null;
  }

  monto(valor: number): string {
    return formatearMonto(valor);
  }

  elegirVivienda(id: number): void {
    this.form.viviendaId = id;
    this.error.set(null);
    void this.cargarSaldo(id);
  }

  /** El saldo es solo contexto: si falla no se muestra y el cargo se puede crear igual */
  private async cargarSaldo(viviendaId: number): Promise<void> {
    const consulta = ++this.ultimaConsultaSaldo;
    this.saldo.set(null);
    this.cargandoSaldo.set(true);
    try {
      const saldo = await this.pagosService.obtenerSaldoVivienda(viviendaId);
      if (consulta === this.ultimaConsultaSaldo) this.saldo.set(saldo);
    } catch (err) {
      console.error('[CargoFormComponent] Error al consultar el saldo de la vivienda:', err);
    } finally {
      if (consulta === this.ultimaConsultaSaldo) this.cargandoSaldo.set(false);
    }
  }

  alClicFuera(): void {
    if (!this.isSaving()) this.cerrar();
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
