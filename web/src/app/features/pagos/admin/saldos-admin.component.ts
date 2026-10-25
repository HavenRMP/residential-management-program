import { ChangeDetectionStrategy, Component, EventEmitter, Input, Output, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { PagosService } from '../../../core/services/pagos.service';
import {
  ETIQUETAS_TIPO_MOVIMIENTO,
  MovimientoSaldo,
  SaldoVivienda,
  TipoMovimientoSaldo,
  formatearFechaPago,
  formatearMonto,
  movimientoPuedeRevertirse,
  validarMotivo
} from '../../../core/models/pagos.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';

const TIPOS_MOVIMIENTO: TipoMovimientoSaldo[] = ['Abono', 'Aplicacion', 'ReversoAbono', 'ReversoAplicacion'];

/** Saldo de una vivienda: lo que debe, lo vencido y el saldo a favor con el historial de sus movimientos */
@Component({
  selector: 'app-saldos-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-4">
      <div class="pb-3 border-b border-slate-100">
        <h2 class="text-sm font-semibold text-slate-900">Saldos por vivienda</h2>
        <p class="text-xs text-slate-500 mt-0.5">Consulta lo que debe una vivienda y cómo se ha movido su saldo a favor.</p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 max-w-xl">
        <div>
          <label for="fs-vivienda" class="block text-[11px] font-semibold text-slate-700 mb-1">Vivienda</label>
          <select id="fs-vivienda" [ngModel]="viviendaId()" (ngModelChange)="elegirVivienda($event)"
            class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
            <option [ngValue]="null">Selecciona una vivienda</option>
            @for (v of viviendas; track v.id) {
              <option [ngValue]="v.id">{{ v.numeroCasa }}</option>
            }
          </select>
        </div>
        @if (viviendaId()) {
          <div>
            <label for="fs-tipo" class="block text-[11px] font-semibold text-slate-700 mb-1">Tipo de movimiento</label>
            <select id="fs-tipo" [ngModel]="tipo()" (ngModelChange)="elegirTipo($event)"
              class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option value="">Todos</option>
              @for (t of tiposMovimiento; track t) {
                <option [value]="t">{{ etiquetas[t] }}</option>
              }
            </select>
          </div>
        }
      </div>

      @if (!viviendaId()) {
        <div class="py-10 text-center text-xs text-slate-500 font-medium" data-test="sin-seleccion">
          <p>Elige una vivienda para ver su saldo.</p>
        </div>
      }

      @if (error(); as msg) {
        <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
          <span>{{ msg }}</span>
          <button type="button" (click)="cargar()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">Reintentar</button>
        </div>
      }

      @if (viviendaId() && isLoading() && !saldo()) {
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3" aria-hidden="true">
          @for (s of [1, 2, 3, 4]; track s) {
            <div class="rounded-lg bg-white border border-slate-200 animate-pulse h-20"></div>
          }
        </div>
      }

      @if (saldo(); as s) {
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3" data-test="saldo">
          <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
            <p class="text-xs font-medium text-slate-500">Por pagar</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ monto(s.totalPendiente) }}</p>
          </div>
          <div class="rounded-lg border bg-white p-4 shadow-2xs" [ngClass]="s.totalVencido > 0 ? 'border-rose-200' : 'border-slate-200'">
            <p class="text-xs font-medium text-slate-500">Vencido</p>
            <p class="mt-1 text-lg font-semibold" [ngClass]="s.totalVencido > 0 ? 'text-rose-700' : 'text-slate-900'">{{ monto(s.totalVencido) }}</p>
          </div>
          <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
            <p class="text-xs font-medium text-slate-500">Saldo a favor</p>
            <p class="mt-1 text-lg font-semibold text-emerald-700">{{ monto(s.saldoAFavor) }}</p>
          </div>
          <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
            <p class="text-xs font-medium text-slate-500">Cargos abiertos</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ s.totalCargosAbiertos }}</p>
          </div>
        </div>

        <div>
          <h3 class="text-xs font-semibold text-slate-900 mb-2">Movimientos del saldo a favor</h3>

          @if (!isLoading() && movimientos().length === 0) {
            <div class="py-8 text-center text-xs text-slate-500 font-medium" data-test="sin-movimientos">
              <p>Esta vivienda no tiene movimientos de saldo a favor.</p>
            </div>
          }

          @if (movimientos().length > 0) {
            <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2.5 items-start">
              @for (m of movimientos(); track m.id) {
                <li class="p-4 rounded-md border border-slate-200 bg-white space-y-1.5" data-test="movimiento">
                  <div class="flex flex-wrap items-center gap-2">
                    <p class="text-sm font-semibold" [ngClass]="signo(m) < 0 ? 'text-rose-700' : 'text-emerald-700'">
                      {{ signo(m) < 0 ? '−' : '+' }}{{ monto(m.monto) }}
                    </p>
                    <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">{{ etiquetas[m.tipo] }}</span>
                  </div>
                  @if (m.creadoEn) {
                    <p class="text-xs text-slate-600">{{ fecha(m.creadoEn) }}</p>
                  }
                  @if (m.motivo) {
                    <p class="text-xs text-slate-500 italic">{{ m.motivo }}</p>
                  }
                  @if (revertible(m)) {
                    <div class="pt-1">
                      <button type="button" (click)="revertir(m)" [disabled]="ocupado() === m.id" [attr.aria-label]="'Revertir la aplicación de ' + monto(m.monto)"
                        class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50">
                        Revertir aplicación
                      </button>
                    </div>
                  }
                </li>
              }
            </ul>

            <div class="flex items-center justify-between pt-3 text-xs text-slate-600">
              <span>{{ total() }} {{ total() === 1 ? 'movimiento' : 'movimientos' }} · Página {{ pagina() }} de {{ totalPaginas() }}</span>
              <div class="flex items-center gap-1.5">
                <button type="button" (click)="irAPagina(pagina() - 1)" [disabled]="pagina() <= 1 || isLoading()"
                  class="h-7 px-2.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-[11px] font-medium cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">Anterior</button>
                <button type="button" (click)="irAPagina(pagina() + 1)" [disabled]="pagina() >= totalPaginas() || isLoading()"
                  class="h-7 px-2.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-[11px] font-medium cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">Siguiente</button>
              </div>
            </div>
          }
        </div>
      }
    </section>
  `
})
export class SaldosAdminComponent {
  private readonly pagosService = inject(PagosService);

  @Input() viviendas: Vivienda[] = [];
  /** Se revirtió una aplicación: los cargos y contadores del encabezado deben refrescarse */
  @Output() cambio = new EventEmitter<void>();

  readonly tiposMovimiento = TIPOS_MOVIMIENTO;
  readonly etiquetas = ETIQUETAS_TIPO_MOVIMIENTO;

  readonly viviendaId = signal<number | null>(null);
  readonly tipo = signal<TipoMovimientoSaldo | ''>('');
  readonly saldo = signal<SaldoVivienda | null>(null);
  readonly movimientos = signal<MovimientoSaldo[]>([]);
  readonly total = signal<number>(0);
  readonly pagina = signal<number>(1);
  readonly isLoading = signal<boolean>(false);
  readonly error = signal<string | null>(null);
  readonly ocupado = signal<string | null>(null);
  readonly totalPaginas = computed(() => Math.max(1, Math.ceil(this.total() / this.pagosService.PAGE_SIZE)));

  private ultimaPeticion = 0;

  elegirVivienda(id: number | null): void {
    this.viviendaId.set(id);
    this.tipo.set('');
    this.saldo.set(null);
    this.movimientos.set([]);
    this.total.set(0);
    this.error.set(null);
    if (id) void this.cargar();
  }

  elegirTipo(tipo: TipoMovimientoSaldo | ''): void {
    this.tipo.set(tipo);
    void this.cargar(1, true);
  }

  async irAPagina(pagina: number): Promise<void> {
    if (pagina < 1 || pagina > this.totalPaginas()) return;
    await this.cargar(pagina, true);
  }

  /** Trae el saldo y los movimientos; al cambiar de página o de tipo el saldo no se vuelve a pedir */
  async cargar(pagina = 1, soloMovimientos = false): Promise<void> {
    const id = this.viviendaId();
    if (!id) return;
    // Una respuesta lenta de otra vivienda no debe pisar la de la que se eligió después
    const peticion = ++this.ultimaPeticion;
    this.isLoading.set(true);
    this.error.set(null);
    try {
      const [saldo, movimientos] = await Promise.all([
        soloMovimientos && this.saldo() ? Promise.resolve(this.saldo() as SaldoVivienda) : this.pagosService.obtenerSaldoVivienda(id),
        this.pagosService.listarMovimientos(id, pagina, this.tipo())
      ]);
      if (peticion !== this.ultimaPeticion) return;
      this.saldo.set(saldo);
      this.movimientos.set(movimientos.items);
      this.total.set(movimientos.total);
      this.pagina.set(pagina);
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[SaldosAdminComponent] Error al cargar el saldo:', err);
      this.error.set(mensajeConValidacion(err, 'No se pudo cargar el saldo de la vivienda.'));
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }

  revertible(m: MovimientoSaldo): boolean {
    return movimientoPuedeRevertirse(m);
  }

  /** Las aplicaciones y los reversos de abono restan del saldo a favor; los demás suman */
  signo(m: MovimientoSaldo): number {
    if (m.montoConSigno != null) return Math.sign(m.montoConSigno);
    return m.tipo === 'Aplicacion' || m.tipo === 'ReversoAbono' ? -1 : 1;
  }

  async revertir(m: MovimientoSaldo): Promise<void> {
    const r = await Swal.fire({
      title: '¿Revertir esta aplicación?',
      text: `Los ${this.monto(m.monto)} vuelven al saldo a favor y el cargo recupera su saldo pendiente.`,
      icon: 'warning',
      input: 'textarea',
      inputPlaceholder: 'Motivo',
      inputAttributes: { maxlength: '300', 'aria-label': 'Motivo' },
      inputValidator: (valor: string) => validarMotivo(valor) ?? undefined,
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Revertir',
      cancelButtonText: 'Volver'
    });
    if (!r.isConfirmed || typeof r.value !== 'string') return;

    this.ocupado.set(m.id);
    try {
      await this.pagosService.revertirMovimiento(m.id, r.value);
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Aplicación revertida', showConfirmButton: false, timer: 3000 });
    } catch (err: any) {
      console.error('[SaldosAdminComponent] Error al revertir la aplicación:', err);
      Swal.fire({ icon: 'error', title: 'No se pudo revertir la aplicación', text: mensajeConValidacion(err, 'Intenta de nuevo en unos segundos.'), confirmButtonColor: '#111C99' });
    } finally {
      this.ocupado.set(null);
    }
    // También tras un error: si el movimiento ya cambió desde otro lado, la lista debe reflejarlo
    await this.cargar(this.pagina());
    this.cambio.emit();
  }

  monto(valor: number): string {
    return formatearMonto(valor);
  }

  fecha(valor: string | null): string {
    return formatearFechaPago(valor);
  }
}
