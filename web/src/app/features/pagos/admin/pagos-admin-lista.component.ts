import { ChangeDetectionStrategy, Component, EventEmitter, Injector, Input, OnInit, Output, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { PagosService } from '../../../core/services/pagos.service';
import {
  CLASES_ESTADO_PAGO,
  ESTADOS_PAGO,
  ETIQUETAS_ESTADO_PAGO,
  ETIQUETAS_METODO_PAGO,
  FiltrosPagos,
  METODOS_PAGO,
  Pago,
  formatearFechaPago,
  formatearMonto,
  pagoEstaPorConfirmar,
  pagoPuedeAnularse,
  validarMotivo
} from '../../../core/models/pagos.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { abrirEnPestana } from '../../../core/utils/abrir-comprobante.util';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';
import { autoActualizar } from '../../../core/utils/auto-actualizar.util';

export type ModoListaPagos = 'por-confirmar' | 'historial';

/**
 * Pagos del condominio. «Por confirmar» son los que reportaron los residentes y esperan una decisión; el historial
 * muestra todos, con filtros, y permite anular un pago ya confirmado.
 */
@Component({
  selector: 'app-pagos-admin-lista',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-4">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
        <div>
          <h2 class="text-sm font-semibold text-slate-900">{{ modo === 'por-confirmar' ? 'Pagos por confirmar' : 'Historial de pagos' }}</h2>
          <p class="text-xs text-slate-500 mt-0.5">
            {{ modo === 'por-confirmar'
              ? 'Revisa el comprobante de cada pago que reportaron los residentes y confírmalo o recházalo.'
              : 'Todos los pagos del condominio. Un pago confirmado se puede anular si hubo un error.' }}
          </p>
        </div>
        <button type="button" (click)="cargar()" [disabled]="isLoading()"
          class="h-8 px-3 inline-flex items-center rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50 self-start sm:self-auto">
          Actualizar
        </button>
      </div>

      @if (modo === 'historial') {
        <div class="grid grid-cols-2 lg:grid-cols-5 gap-2" data-test="filtros">
          <div>
            <label for="fp-vivienda" class="block text-[11px] font-semibold text-slate-700 mb-1">Vivienda</label>
            <select id="fp-vivienda" [(ngModel)]="filtros.viviendaId" (ngModelChange)="aplicarFiltros()"
              class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option [ngValue]="null">Todas</option>
              @for (v of viviendas; track v.id) {
                <option [ngValue]="v.id">{{ v.numeroCasa }}</option>
              }
            </select>
          </div>
          <div>
            <label for="fp-estado" class="block text-[11px] font-semibold text-slate-700 mb-1">Estado</label>
            <select id="fp-estado" [(ngModel)]="filtros.estado" (ngModelChange)="aplicarFiltros()"
              class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option value="">Todos</option>
              @for (e of estados; track e) {
                <option [value]="e">{{ etiquetasEstado[e] }}</option>
              }
            </select>
          </div>
          <div>
            <label for="fp-metodo" class="block text-[11px] font-semibold text-slate-700 mb-1">Método</label>
            <select id="fp-metodo" [(ngModel)]="filtros.metodo" (ngModelChange)="aplicarFiltros()"
              class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option value="">Todos</option>
              @for (m of metodos; track m) {
                <option [value]="m">{{ etiquetasMetodo[m] }}</option>
              }
            </select>
          </div>
          <div>
            <label for="fp-desde" class="block text-[11px] font-semibold text-slate-700 mb-1">Pagado desde</label>
            <input id="fp-desde" type="date" [(ngModel)]="filtros.desde" (ngModelChange)="aplicarFiltros()"
              class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>
          <div>
            <label for="fp-hasta" class="block text-[11px] font-semibold text-slate-700 mb-1">Hasta</label>
            <input id="fp-hasta" type="date" [(ngModel)]="filtros.hasta" (ngModelChange)="aplicarFiltros()"
              class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>
        </div>
        @if (fechasInvertidas()) {
          <p class="text-[11px] text-red-600 font-medium" role="alert">La fecha inicial no puede ser posterior a la final.</p>
        }
      }

      @if (isLoading() && items().length === 0) {
        <div class="space-y-2" aria-hidden="true">
          @for (s of [1, 2]; track s) {
            <div class="p-4 rounded-md bg-white border border-slate-200 animate-pulse h-20"></div>
          }
        </div>
      }

      @if (error(); as msg) {
        <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
          <span>{{ msg }}</span>
          <button type="button" (click)="cargar()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">Reintentar</button>
        </div>
      }

      @if (!isLoading() && !error() && items().length === 0) {
        <div class="py-10 text-center text-xs text-slate-500 font-medium space-y-1" data-test="sin-pagos">
          @if (modo === 'por-confirmar') {
            <p>No hay pagos por confirmar.</p>
            <p class="text-slate-400">Los pagos que reporten los residentes aparecerán aquí.</p>
          } @else {
            <p>No hay pagos con esos filtros.</p>
          }
        </div>
      }

      @if (items().length > 0) {
        <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2.5 items-start">
          @for (p of items(); track p.id) {
            <li class="p-4 rounded-md border border-slate-200 bg-white space-y-1.5" data-test="pago">
              <div class="flex flex-wrap items-center gap-2">
                <p class="text-sm font-semibold text-slate-900">{{ monto(p.monto) }}</p>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="clases[p.estado]">{{ etiquetasEstado[p.estado] }}</span>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">Casa {{ p.numeroCasa }}</span>
                @if (p.esReversa) {
                  <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">Reversa</span>
                }
              </div>
              <p class="text-xs text-slate-600">{{ p.cargoConcepto }} · {{ fecha(p.fechaPago) }} · {{ etiquetasMetodo[p.metodo] }}</p>
              @if (p.referencia || p.bancoOrigen) {
                <p class="text-xs text-slate-500">
                  @if (p.referencia) {<span>Ref. {{ p.referencia }}</span>}@if (p.referencia && p.bancoOrigen) {<span> · </span>}@if (p.bancoOrigen) {<span>{{ p.bancoOrigen }}</span>}
                </p>
              }
              <p class="text-xs text-slate-500">{{ p.origen === 'Inquilino' ? 'Reportado por el residente' : 'Registrado por la administración' }}</p>
              @if (p.montoExcedente > 0) {
                <p class="text-xs text-emerald-700">{{ monto(p.montoExcedente) }} pasaron a saldo a favor.</p>
              }
              @if (p.motivoRechazo) {
                <p class="text-xs text-rose-700">Rechazado: {{ p.motivoRechazo }}</p>
              }
              @if (p.motivoAnulacion) {
                <p class="text-xs text-slate-500 italic">Anulado: {{ p.motivoAnulacion }}</p>
              }
              <div class="flex flex-wrap items-center gap-1.5 pt-1">
                @if (p.tieneComprobante) {
                  <button type="button" (click)="verComprobante(p)" [attr.aria-label]="'Ver el comprobante del pago de ' + monto(p.monto) + ' de la casa ' + p.numeroCasa"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">
                    Ver comprobante
                  </button>
                }
                @if (porConfirmar(p)) {
                  <button type="button" (click)="confirmar(p)" [disabled]="ocupado() === p.id" [attr.aria-label]="'Confirmar el pago de ' + monto(p.monto) + ' de la casa ' + p.numeroCasa"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md bg-emerald-600 hover:bg-emerald-700 text-white transition-colors cursor-pointer disabled:opacity-50">
                    Confirmar
                  </button>
                  <button type="button" (click)="rechazar(p)" [disabled]="ocupado() === p.id" [attr.aria-label]="'Rechazar el pago de ' + monto(p.monto) + ' de la casa ' + p.numeroCasa"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50">
                    Rechazar
                  </button>
                }
                @if (anulable(p)) {
                  <button type="button" (click)="anular(p)" [disabled]="ocupado() === p.id" [attr.aria-label]="'Anular el pago de ' + monto(p.monto) + ' de la casa ' + p.numeroCasa"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50">
                    Anular
                  </button>
                }
              </div>
            </li>
          }
        </ul>

        <div class="flex items-center justify-between pt-1 text-xs text-slate-600">
          <span>{{ total() }} {{ total() === 1 ? 'pago' : 'pagos' }} · Página {{ pagina() }} de {{ totalPaginas() }}</span>
          <div class="flex items-center gap-1.5">
            <button type="button" (click)="irAPagina(pagina() - 1)" [disabled]="pagina() <= 1 || isLoading()"
              class="h-7 px-2.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-[11px] font-medium cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">Anterior</button>
            <button type="button" (click)="irAPagina(pagina() + 1)" [disabled]="pagina() >= totalPaginas() || isLoading()"
              class="h-7 px-2.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-[11px] font-medium cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">Siguiente</button>
          </div>
        </div>
      }
    </section>
  `
})
export class PagosAdminListaComponent implements OnInit {
  private readonly pagosService = inject(PagosService);
  private readonly injector = inject(Injector);

  @Input() modo: ModoListaPagos = 'historial';
  /** Para el filtro por vivienda del historial */
  @Input() viviendas: Vivienda[] = [];
  /** Un pago cambió de estado: el contador de «Por confirmar» del encabezado debe recontarse */
  @Output() cambio = new EventEmitter<void>();

  readonly estados = ESTADOS_PAGO;
  readonly metodos = METODOS_PAGO;
  readonly etiquetasEstado = ETIQUETAS_ESTADO_PAGO;
  readonly etiquetasMetodo = ETIQUETAS_METODO_PAGO;
  readonly clases = CLASES_ESTADO_PAGO;

  readonly items = signal<Pago[]>([]);
  readonly total = signal<number>(0);
  readonly pagina = signal<number>(1);
  readonly isLoading = signal<boolean>(false);
  readonly error = signal<string | null>(null);
  /** Pago sobre el que hay una acción en curso */
  readonly ocupado = signal<string | null>(null);
  readonly totalPaginas = computed(() => Math.max(1, Math.ceil(this.total() / this.pagosService.PAGE_SIZE)));

  filtros: { viviendaId: number | null; estado: Pago['estado'] | ''; metodo: Pago['metodo'] | ''; desde: string; hasta: string } = {
    viviendaId: null, estado: '', metodo: '', desde: '', hasta: ''
  };

  private ultimaPeticion = 0;

  async ngOnInit(): Promise<void> {
    await this.cargar();
    // Los pagos que reportan los residentes aparecen solos, sin tocar "Actualizar"
    if (this.modo === 'por-confirmar') autoActualizar(this.injector, () => void this.cargar(true));
  }

  fechasInvertidas(): boolean {
    return !!this.filtros.desde && !!this.filtros.hasta && this.filtros.desde > this.filtros.hasta;
  }

  private filtrosActivos(): FiltrosPagos {
    if (this.modo === 'por-confirmar') return { estado: 'PendienteConfirmacion' };
    return { ...this.filtros };
  }

  aplicarFiltros(): void {
    if (this.fechasInvertidas()) return;
    void this.cargar();
  }

  async irAPagina(pagina: number): Promise<void> {
    if (pagina < 1 || pagina > this.totalPaginas()) return;
    await this.cargar(false, pagina);
  }

  async cargar(silencioso = false, pagina?: number): Promise<void> {
    // Una respuesta lenta de otros filtros no debe pisar la de los más recientes
    const peticion = ++this.ultimaPeticion;
    const destino = pagina ?? (silencioso ? this.pagina() : 1);
    if (!silencioso) {
      this.isLoading.set(true);
      this.error.set(null);
    }
    try {
      const r = await this.pagosService.listarPagos(this.filtrosActivos(), destino);
      if (peticion !== this.ultimaPeticion) return;
      // Si se vació la última página (se confirmaron todos los de ella), se vuelve a la anterior
      if (r.items.length === 0 && r.total > 0 && destino > 1) {
        await this.cargar(silencioso, destino - 1);
        return;
      }
      this.items.set(r.items);
      this.total.set(r.total);
      this.pagina.set(destino);
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[PagosAdminListaComponent] Error al cargar los pagos:', err);
      if (!silencioso) this.error.set(mensajeConValidacion(err, 'No se pudieron cargar los pagos.'));
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }

  porConfirmar(p: Pago): boolean {
    return pagoEstaPorConfirmar(p);
  }

  anulable(p: Pago): boolean {
    return pagoPuedeAnularse(p);
  }

  async verComprobante(p: Pago): Promise<void> {
    try {
      await abrirEnPestana(() => this.pagosService.obtenerUrlComprobante(p.id));
    } catch (err: any) {
      console.error('[PagosAdminListaComponent] Error al abrir el comprobante:', err);
      this.avisarError('No se pudo abrir el comprobante', mensajeConValidacion(err, 'El comprobante ya no está disponible o no se pudo consultar.'));
    }
  }

  async confirmar(p: Pago): Promise<void> {
    const r = await Swal.fire({
      title: '¿Confirmar este pago?',
      html: `Se aplicarán <strong>${this.monto(p.monto)}</strong> al cargo «${this.escapar(p.cargoConcepto)}» de la casa ${this.escapar(p.numeroCasa)}.`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#059669',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Confirmar pago',
      cancelButtonText: 'Volver'
    });
    if (!r.isConfirmed) return;
    await this.ejecutar(p, async () => {
      const { pago } = await this.pagosService.confirmarPago(p.id);
      return pago.montoExcedente > 0 ? `Pago confirmado. ${this.monto(pago.montoExcedente)} pasaron a saldo a favor` : 'Pago confirmado';
    }, 'No se pudo confirmar el pago');
  }

  async rechazar(p: Pago): Promise<void> {
    const motivo = await this.pedirMotivo('¿Rechazar este pago?', 'El residente verá el motivo para poder corregirlo.', 'Rechazar pago');
    if (motivo === null) return;
    await this.ejecutar(p, async () => {
      await this.pagosService.rechazarPago(p.id, motivo);
      return 'Pago rechazado';
    }, 'No se pudo rechazar el pago');
  }

  async anular(p: Pago): Promise<void> {
    const motivo = await this.pedirMotivo(
      '¿Anular este pago?',
      'El cargo recupera su saldo. Quedará un registro de reversa y esta acción no se deshace.',
      'Anular pago'
    );
    if (motivo === null) return;
    await this.ejecutar(p, async () => {
      await this.pagosService.anularPago(p.id, motivo);
      return 'Pago anulado';
    }, 'No se pudo anular el pago');
  }

  /** Pide el motivo (5 a 300 caracteres); null si la persona se arrepiente */
  private async pedirMotivo(titulo: string, texto: string, boton: string): Promise<string | null> {
    const r = await Swal.fire({
      title: titulo,
      text: texto,
      icon: 'warning',
      input: 'textarea',
      inputPlaceholder: 'Motivo',
      inputAttributes: { maxlength: '300', 'aria-label': 'Motivo' },
      inputValidator: (valor: string) => validarMotivo(valor) ?? undefined,
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: boton,
      cancelButtonText: 'Volver'
    });
    return r.isConfirmed && typeof r.value === 'string' ? r.value : null;
  }

  /** Corre una acción sobre un pago, avisa el resultado y refresca la lista y el contador */
  private async ejecutar(p: Pago, accion: () => Promise<string>, tituloError: string): Promise<void> {
    this.ocupado.set(p.id);
    try {
      const mensaje = await accion();
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: mensaje, showConfirmButton: false, timer: 3000 });
    } catch (err: any) {
      console.error(`[PagosAdminListaComponent] ${tituloError}:`, err);
      this.avisarError(tituloError, mensajeConValidacion(err, 'Intenta de nuevo en unos segundos.'));
    } finally {
      this.ocupado.set(null);
    }
    // También tras un error: si el pago ya cambió desde otro lado, la lista debe reflejarlo
    await this.cargar(true);
    this.cambio.emit();
  }

  private avisarError(titulo: string, texto: string): void {
    Swal.fire({ icon: 'error', title: titulo, text: texto, confirmButtonColor: '#111C99' });
  }

  private escapar(texto: string): string {
    return texto.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c] as string));
  }

  monto(valor: number): string {
    return formatearMonto(valor);
  }

  fecha(valor: string): string {
    return formatearFechaPago(valor);
  }
}
