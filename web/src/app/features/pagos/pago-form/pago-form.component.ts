import { AfterViewInit, ChangeDetectionStrategy, Component, ElementRef, EventEmitter, HostListener, Input, Output, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PagosService } from '../../../core/services/pagos.service';
import {
  Cargo,
  ETIQUETAS_METODO_PAGO,
  METODOS_PAGO,
  MetodoPago,
  ModoPago,
  NuevoPagoDto,
  Pago,
  fechaLocalIso,
  formatearMonto,
  metodoRequiereReferencia,
  validarArchivoComprobante,
  validarPago
} from '../../../core/models/pagos.model';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';
import { RetornoFocoDirective } from '../../../core/directives/retorno-foco.directive';

/**
 * Pago de un cargo. El residente lo reporta con su comprobante y el administrador lo confirma después; el
 * administrador, en cambio, registra pagos directos que quedan confirmados y no necesitan comprobante.
 */
@Component({
  selector: 'app-pago-form',
  standalone: true,
  imports: [CommonModule, FormsModule, RetornoFocoDirective],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
      <div
        class="bg-white rounded-lg max-w-lg w-full p-5 shadow-lg border border-slate-200"
        appRetornoFoco role="dialog"
        aria-modal="true"
        aria-labelledby="pago-form-titulo"
        >
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 id="pago-form-titulo" class="text-sm font-semibold text-slate-900">
            {{ modo === 'residente' ? 'Reportar un pago' : 'Registrar un pago' }}
          </h3>
          <button type="button" (click)="cerrar()" aria-label="Cerrar" class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-3.5 space-y-3">
          <div class="rounded-md border border-slate-200 bg-slate-50 p-3 text-xs space-y-0.5" data-test="resumen-cargo">
            <p class="font-semibold text-slate-900">{{ cargo.concepto }}</p>
            <p class="text-slate-600">
              Casa {{ cargo.numeroCasa }} · Saldo pendiente <span class="font-semibold text-slate-900">{{ monto(cargo.saldoPendiente) }}</span>
            </p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label for="pago-monto" class="block text-xs font-semibold text-slate-800 mb-1">Monto pagado *</label>
              <input id="pago-monto" type="number" min="0.01" step="0.01" inputmode="decimal" [(ngModel)]="form.monto"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label for="pago-fecha" class="block text-xs font-semibold text-slate-800 mb-1">Fecha del pago *</label>
              <input id="pago-fecha" type="date" [(ngModel)]="form.fechaPago" [max]="hoy"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          </div>
          @if (excedente() > 0) {
            <p class="text-[11px] text-slate-500" data-test="aviso-excedente">
              Pagas {{ monto(excedente()) }} más que el saldo: ese excedente queda como saldo a favor de la vivienda.
            </p>
          }

          <div>
            <label for="pago-metodo" class="block text-xs font-semibold text-slate-800 mb-1">Método de pago *</label>
            <select id="pago-metodo" [(ngModel)]="form.metodo"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              @for (m of metodos; track m) {
                <option [ngValue]="m">{{ etiquetas[m] }}</option>
              }
            </select>
          </div>

          @if (pideReferencia()) {
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label for="pago-referencia" class="block text-xs font-semibold text-slate-800 mb-1">Referencia *</label>
                <input id="pago-referencia" type="text" [(ngModel)]="form.referencia" maxlength="100" placeholder="Folio o clave de rastreo"
                  class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
              </div>
              <div>
                <label for="pago-banco" class="block text-xs font-semibold text-slate-800 mb-1">Banco de origen {{ modo === 'residente' ? '*' : '' }}</label>
                <input id="pago-banco" type="text" [(ngModel)]="form.bancoOrigen" maxlength="100" placeholder="Ej. BBVA"
                  class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
              </div>
            </div>
          }

          <div>
            <label for="pago-comprobante" class="block text-xs font-semibold text-slate-800 mb-1">
              Comprobante {{ modo === 'residente' ? '*' : '(opcional)' }}
            </label>
            <input id="pago-comprobante" type="file" accept="image/jpeg,image/png,application/pdf,.jpg,.jpeg,.png,.pdf" (change)="elegirArchivo($event)"
              class="block w-full text-xs text-slate-700 file:mr-3 file:h-8 file:px-3 file:rounded-md file:border file:border-slate-200 file:bg-white file:text-xs file:font-medium file:text-slate-700 hover:file:bg-slate-50 file:cursor-pointer" />
            <p class="mt-1 text-[11px] text-slate-500">Foto JPG o PNG de hasta 5 MB, o PDF de hasta 1 MB.</p>
          </div>

          @if (error(); as msg) {
            <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium" role="alert">{{ msg }}</div>
          }

          <div class="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
            <button type="button" (click)="cerrar()" [disabled]="isSaving()"
              class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer disabled:opacity-50">
              Cancelar
            </button>
            <button type="button" (click)="guardar()" [disabled]="isSaving()"
              class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
              {{ isSaving() ? 'Guardando...' : (modo === 'residente' ? 'Reportar pago' : 'Registrar pago') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
})
export class PagoFormComponent implements AfterViewInit {
  private readonly pagosService = inject(PagosService);
  private readonly elemento = inject(ElementRef<HTMLElement>);

  @Input({ required: true }) set cargo(valor: Cargo) {
    this._cargo = valor;
    this.form.monto = valor.saldoPendiente;
  }
  get cargo(): Cargo {
    return this._cargo;
  }
  private _cargo!: Cargo;

  @Input() modo: ModoPago = 'residente';

  @Output() cerrado = new EventEmitter<void>();
  /** El pago ya quedó guardado; quien abrió el formulario refresca sus listas */
  @Output() guardado = new EventEmitter<Pago>();

  readonly metodos = METODOS_PAGO;
  readonly etiquetas = ETIQUETAS_METODO_PAGO;
  readonly hoy = fechaLocalIso();
  readonly isSaving = signal<boolean>(false);
  readonly error = signal<string | null>(null);

  form: { monto: number | null; fechaPago: string; metodo: MetodoPago; referencia: string; bancoOrigen: string } = {
    monto: null,
    fechaPago: fechaLocalIso(),
    metodo: 'Transferencia',
    referencia: '',
    bancoOrigen: ''
  };

  private archivo: File | null = null;
  /** Si el pago falló después de subir el archivo, el reintento reutiliza ese mismo comprobante */
  private subido: { archivo: File; ruta: string; hash: string } | null = null;

  ngAfterViewInit(): void {
    (this.elemento.nativeElement as HTMLElement).querySelector<HTMLInputElement>('#pago-monto')?.focus();
  }

  @HostListener('document:keydown.escape')
  alPresionarEscape(): void {
    if (!this.isSaving()) this.cerrar();
  }

  monto(valor: number): string {
    return formatearMonto(valor);
  }

  pideReferencia(): boolean {
    return metodoRequiereReferencia(this.form.metodo);
  }

  /** Lo que se paga por encima del saldo pasa a ser saldo a favor */
  excedente(): number {
    const pagado = this.form.monto ?? 0;
    return pagado > this.cargo.saldoPendiente ? Math.round((pagado - this.cargo.saldoPendiente) * 100) / 100 : 0;
  }

  elegirArchivo(evento: Event): void {
    const input = evento.target as HTMLInputElement;
    const archivo = input.files?.[0] ?? null;
    this.error.set(null);
    if (archivo) {
      const motivo = validarArchivoComprobante(archivo);
      if (motivo) {
        input.value = '';
        this.archivo = null;
        this.error.set(motivo);
        return;
      }
    }
    this.archivo = archivo;
  }

  cerrar(): void {
    this.cerrado.emit();
  }

  async guardar(): Promise<void> {
    if (this.isSaving()) return;
    const motivoInvalido = validarPago({ ...this.form, hayComprobante: !!this.archivo }, this.modo, this.hoy);
    if (motivoInvalido) {
      this.error.set(motivoInvalido);
      return;
    }

    this.isSaving.set(true);
    this.error.set(null);
    try {
      const comprobante = await this.comprobanteListo();
      const dto: NuevoPagoDto = {
        cargoId: this.cargo.id,
        monto: this.form.monto as number,
        fechaPago: this.form.fechaPago,
        metodo: this.form.metodo,
        referencia: this.pideReferencia() ? this.form.referencia : null,
        bancoOrigen: this.pideReferencia() ? this.form.bancoOrigen : null,
        comprobante
      };
      const pago = this.modo === 'residente'
        ? await this.pagosService.reportarPago(dto)
        : (await this.pagosService.registrarPago(dto)).pago;
      this.guardado.emit(pago);
    } catch (err: any) {
      console.error('[PagoFormComponent] Error al guardar el pago:', err);
      this.error.set(mensajeConValidacion(err, 'No fue posible guardar el pago. Intenta de nuevo en unos segundos.'));
    } finally {
      this.isSaving.set(false);
    }
  }

  /** Sube el archivo (si hay) una sola vez, aunque se reintente el pago */
  private async comprobanteListo(): Promise<{ ruta: string; hash: string } | null> {
    if (!this.archivo) return null;
    if (this.subido?.archivo === this.archivo) return { ruta: this.subido.ruta, hash: this.subido.hash };
    const resultado = await this.pagosService.subirComprobante(this.archivo, this.cargo.viviendaId);
    this.subido = { archivo: this.archivo, ruta: resultado.ruta, hash: resultado.hash };
    return { ruta: resultado.ruta, hash: resultado.hash };
  }
}
