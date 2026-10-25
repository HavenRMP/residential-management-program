import { ChangeDetectionStrategy, Component, EventEmitter, Input, OnInit, Output, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { PagosService } from '../../../core/services/pagos.service';
import {
  CLASES_ESTADO_CARGO,
  Cargo,
  ESTADOS_CARGO,
  ETIQUETAS_ESTADO_CARGO,
  ETIQUETAS_TIPO_CARGO,
  FiltrosCargos,
  TIPOS_CARGO,
  cargoAdmitePago,
  cargoPuedeCancelarse,
  formatearFechaPago,
  formatearMonto,
  formatearPeriodo,
  redondearMonto,
  tieneMasDeDosDecimales,
  validarMotivo
} from '../../../core/models/pagos.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';
import { CargoFormComponent } from './cargo-form.component';
import { CargoPagosComponent } from '../cargo-pagos/cargo-pagos.component';
import { PagoFormComponent } from '../pago-form/pago-form.component';

/** Cargos del condominio: consulta con filtros, alta, pagos directos, saldo a favor y cancelación */
@Component({
  selector: 'app-cargos-admin',
  standalone: true,
  imports: [CommonModule, FormsModule, CargoFormComponent, CargoPagosComponent, PagoFormComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-4">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
        <div>
          <h2 class="text-sm font-semibold text-slate-900">Cargos</h2>
          <p class="text-xs text-slate-500 mt-0.5">Lo que se cobra a cada vivienda. Registra pagos, aplica saldo a favor o cancela un cargo.</p>
        </div>
        <div class="flex items-center gap-2 self-start sm:self-auto">
          <button type="button" (click)="cargar()" [disabled]="isLoading()"
            class="h-8 px-3 inline-flex items-center rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50">
            Actualizar
          </button>
          <button type="button" (click)="formularioAbierto.set(true)"
            class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer">
            <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            <span>Nuevo cargo</span>
          </button>
        </div>
      </div>

      <div class="grid grid-cols-2 lg:grid-cols-5 gap-2" data-test="filtros">
        <div>
          <label for="fc-vivienda" class="block text-[11px] font-semibold text-slate-700 mb-1">Vivienda</label>
          <select id="fc-vivienda" [(ngModel)]="filtros.viviendaId" (ngModelChange)="aplicarFiltros()"
            class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
            <option [ngValue]="null">Todas</option>
            @for (v of viviendas; track v.id) {
              <option [ngValue]="v.id">{{ v.numeroCasa }}</option>
            }
          </select>
        </div>
        <div>
          <label for="fc-estado" class="block text-[11px] font-semibold text-slate-700 mb-1">Estado</label>
          <select id="fc-estado" [(ngModel)]="filtros.estado" (ngModelChange)="aplicarFiltros()"
            class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
            <option value="">Todos</option>
            @for (e of estados; track e) {
              <option [value]="e">{{ etiquetasEstado[e] }}</option>
            }
          </select>
        </div>
        <div>
          <label for="fc-tipo" class="block text-[11px] font-semibold text-slate-700 mb-1">Tipo</label>
          <select id="fc-tipo" [(ngModel)]="filtros.tipo" (ngModelChange)="aplicarFiltros()"
            class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
            <option value="">Todos</option>
            @for (t of tipos; track t) {
              <option [value]="t">{{ etiquetasTipo[t] }}</option>
            }
          </select>
        </div>
        <div>
          <label for="fc-periodo" class="block text-[11px] font-semibold text-slate-700 mb-1">Periodo</label>
          <input id="fc-periodo" type="month" [(ngModel)]="filtros.periodo" (ngModelChange)="aplicarFiltros()"
            class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
        </div>
        <div class="flex items-end">
          <label class="inline-flex items-center gap-2 h-8 text-xs font-medium text-slate-700 cursor-pointer">
            <input type="checkbox" [(ngModel)]="soloVencidos" (ngModelChange)="aplicarFiltros()" class="size-4 rounded border-slate-300 accent-[#111C99]" />
            Solo vencidos
          </label>
        </div>
      </div>

      @if (isLoading() && items().length === 0) {
        <div class="space-y-2" aria-hidden="true">
          @for (s of [1, 2]; track s) {
            <div class="p-4 rounded-md bg-white border border-slate-200 animate-pulse h-24"></div>
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
        <div class="py-10 text-center text-xs text-slate-500 font-medium" data-test="sin-cargos">
          <p>No hay cargos con esos filtros.</p>
        </div>
      }

      @if (items().length > 0) {
        <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2.5 items-start">
          @for (c of items(); track c.id) {
            <li class="p-4 rounded-md border bg-white space-y-2" [ngClass]="c.estadoEfectivo === 'Vencido' ? 'border-rose-200' : 'border-slate-200'" data-test="cargo">
              <div class="flex flex-wrap items-center gap-2">
                <p class="text-sm font-semibold text-slate-900">{{ c.concepto }}</p>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="clases[c.estadoEfectivo]">{{ etiquetasEstado[c.estadoEfectivo] }}</span>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">Casa {{ c.numeroCasa }}</span>
              </div>
              <p class="text-xs text-slate-600">
                {{ etiquetasTipo[c.tipo] }}@if (c.periodo) {<span> · {{ periodo(c.periodo) }}</span>} · Vence {{ fecha(c.fechaVencimiento) }} · Paga: {{ c.responsablePago }}
              </p>
              <dl class="grid grid-cols-3 gap-2 text-xs">
                <div><dt class="text-slate-500">Monto</dt><dd class="font-semibold text-slate-900">{{ monto(c.monto) }}</dd></div>
                <div><dt class="text-slate-500">Pagado</dt><dd class="font-semibold text-slate-900">{{ monto(c.montoPagadoConfirmado) }}</dd></div>
                <div><dt class="text-slate-500">Saldo</dt><dd class="font-semibold" [ngClass]="c.saldoPendiente > 0 ? 'text-slate-900' : 'text-emerald-700'">{{ monto(c.saldoPendiente) }}</dd></div>
              </dl>
              @if (c.motivoCancelacion) {
                <p class="text-xs text-slate-500 italic">Cancelado: {{ c.motivoCancelacion }}</p>
              }
              <div class="flex flex-wrap items-center gap-1.5 pt-1">
                @if (admitePago(c)) {
                  <button type="button" (click)="cargoPagando.set(c)" [attr.aria-label]="'Registrar un pago de ' + c.concepto + ' de la casa ' + c.numeroCasa"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white transition-colors cursor-pointer">Registrar pago</button>
                  <button type="button" (click)="aplicarSaldo(c)" [disabled]="ocupado() === c.id" [attr.aria-label]="'Aplicar saldo a favor a ' + c.concepto + ' de la casa ' + c.numeroCasa"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer disabled:opacity-50">Aplicar saldo a favor</button>
                }
                <button type="button" (click)="alternarPagos(c)" [attr.aria-expanded]="estaAbierto(c)" [attr.aria-label]="'Ver los pagos de ' + c.concepto + ' de la casa ' + c.numeroCasa"
                  class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">
                  {{ estaAbierto(c) ? 'Ocultar pagos' : 'Ver pagos' }}
                </button>
                @if (cancelable(c)) {
                  <button type="button" (click)="cancelar(c)" [disabled]="ocupado() === c.id" [attr.aria-label]="'Cancelar el cargo ' + c.concepto + ' de la casa ' + c.numeroCasa"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50">Cancelar cargo</button>
                }
              </div>
              @if (estaAbierto(c)) {
                <app-cargo-pagos [cargoId]="c.id" />
              }
            </li>
          }
        </ul>

        <div class="flex items-center justify-between pt-1 text-xs text-slate-600">
          <span>{{ total() }} {{ total() === 1 ? 'cargo' : 'cargos' }} · Página {{ pagina() }} de {{ totalPaginas() }}</span>
          <div class="flex items-center gap-1.5">
            <button type="button" (click)="irAPagina(pagina() - 1)" [disabled]="pagina() <= 1 || isLoading()"
              class="h-7 px-2.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-[11px] font-medium cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">Anterior</button>
            <button type="button" (click)="irAPagina(pagina() + 1)" [disabled]="pagina() >= totalPaginas() || isLoading()"
              class="h-7 px-2.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-[11px] font-medium cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">Siguiente</button>
          </div>
        </div>
      }
    </section>

    @if (formularioAbierto()) {
      <app-cargo-form [viviendas]="viviendas" [viviendaInicial]="filtros.viviendaId" (cerrado)="formularioAbierto.set(false)" (guardado)="alCrear()" />
    }
    @if (cargoPagando(); as cargo) {
      <app-pago-form [cargo]="cargo" modo="admin" (cerrado)="cargoPagando.set(null)" (guardado)="alRegistrarPago()" />
    }
  `
})
export class CargosAdminComponent implements OnInit {
  private readonly pagosService = inject(PagosService);

  @Input() viviendas: Vivienda[] = [];
  /** Un cargo o su saldo cambió: los demás contadores del encabezado deben recontarse */
  @Output() cambio = new EventEmitter<void>();

  readonly estados = ESTADOS_CARGO;
  readonly tipos = TIPOS_CARGO;
  readonly etiquetasEstado = ETIQUETAS_ESTADO_CARGO;
  readonly etiquetasTipo = ETIQUETAS_TIPO_CARGO;
  readonly clases = CLASES_ESTADO_CARGO;

  readonly items = signal<Cargo[]>([]);
  readonly total = signal<number>(0);
  readonly pagina = signal<number>(1);
  readonly isLoading = signal<boolean>(false);
  readonly error = signal<string | null>(null);
  readonly ocupado = signal<string | null>(null);
  readonly formularioAbierto = signal<boolean>(false);
  readonly cargoPagando = signal<Cargo | null>(null);
  readonly abiertos = signal<ReadonlySet<string>>(new Set());
  readonly totalPaginas = computed(() => Math.max(1, Math.ceil(this.total() / this.pagosService.PAGE_SIZE)));

  filtros: { viviendaId: number | null; estado: FiltrosCargos['estado']; tipo: FiltrosCargos['tipo']; periodo: string } = {
    viviendaId: null, estado: '', tipo: '', periodo: ''
  };
  soloVencidos = false;

  private ultimaPeticion = 0;

  ngOnInit(): void {
    void this.cargar();
  }

  aplicarFiltros(): void {
    void this.cargar();
  }

  async irAPagina(pagina: number): Promise<void> {
    if (pagina < 1 || pagina > this.totalPaginas()) return;
    await this.cargar(pagina);
  }

  async cargar(pagina = 1): Promise<void> {
    // Una respuesta lenta de otros filtros no debe pisar la de los más recientes
    const peticion = ++this.ultimaPeticion;
    this.isLoading.set(true);
    this.error.set(null);
    try {
      const filtros: FiltrosCargos = { ...this.filtros, vencido: this.soloVencidos ? true : null };
      const r = await this.pagosService.listarCargos(filtros, pagina);
      if (peticion !== this.ultimaPeticion) return;
      this.items.set(r.items);
      this.total.set(r.total);
      this.pagina.set(pagina);
      this.abiertos.set(new Set());
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[CargosAdminComponent] Error al cargar los cargos:', err);
      this.error.set(mensajeConValidacion(err, 'No se pudieron cargar los cargos.'));
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }

  admitePago(c: Cargo): boolean {
    return cargoAdmitePago(c);
  }

  cancelable(c: Cargo): boolean {
    return cargoPuedeCancelarse(c);
  }

  estaAbierto(c: Cargo): boolean {
    return this.abiertos().has(c.id);
  }

  alternarPagos(c: Cargo): void {
    this.abiertos.update(abiertos => {
      const siguiente = new Set(abiertos);
      if (!siguiente.delete(c.id)) siguiente.add(c.id);
      return siguiente;
    });
  }

  async alCrear(): Promise<void> {
    this.formularioAbierto.set(false);
    this.avisar('Cargo creado');
    await this.cargar();
    this.cambio.emit();
  }

  async alRegistrarPago(): Promise<void> {
    this.cargoPagando.set(null);
    this.avisar('Pago registrado');
    await this.cargar(this.pagina());
    this.cambio.emit();
  }

  async cancelar(c: Cargo): Promise<void> {
    const r = await Swal.fire({
      title: '¿Cancelar este cargo?',
      text: `«${c.concepto}» de la casa ${c.numeroCasa} dejará de cobrarse.`,
      icon: 'warning',
      input: 'textarea',
      inputPlaceholder: 'Motivo',
      inputAttributes: { maxlength: '300', 'aria-label': 'Motivo de la cancelación' },
      inputValidator: (valor: string) => validarMotivo(valor) ?? undefined,
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Cancelar cargo',
      cancelButtonText: 'Volver'
    });
    if (!r.isConfirmed || typeof r.value !== 'string') return;
    await this.ejecutar(c, async () => {
      await this.pagosService.cancelarCargo(c.id, r.value);
      return 'Cargo cancelado';
    }, 'No se pudo cancelar el cargo');
  }

  /** Usa el saldo a favor de la vivienda para cubrir parte o todo el cargo */
  async aplicarSaldo(c: Cargo): Promise<void> {
    let disponible: number;
    try {
      disponible = (await this.pagosService.obtenerSaldoVivienda(c.viviendaId)).saldoAFavor;
    } catch (err: any) {
      console.error('[CargosAdminComponent] Error al consultar el saldo a favor:', err);
      this.avisarError('No se pudo consultar el saldo a favor', mensajeConValidacion(err, 'Intenta de nuevo en unos segundos.'));
      return;
    }
    if (disponible <= 0) {
      await Swal.fire({ icon: 'info', title: 'Sin saldo a favor', text: `La casa ${c.numeroCasa} no tiene saldo a favor para aplicar.`, confirmButtonColor: '#111C99' });
      return;
    }

    const tope = redondearMonto(Math.min(disponible, c.saldoPendiente));
    const r = await Swal.fire({
      title: 'Aplicar saldo a favor',
      html: `La casa ${this.escapar(c.numeroCasa)} tiene <strong>${this.monto(disponible)}</strong> a favor y este cargo debe <strong>${this.monto(c.saldoPendiente)}</strong>.`,
      input: 'number',
      inputValue: tope,
      inputAttributes: { min: '0.01', max: String(tope), step: '0.01', 'aria-label': 'Monto a aplicar' },
      inputValidator: (valor: string) => {
        const n = Number(valor);
        if (!Number.isFinite(n) || n <= 0) return 'Escribe un monto mayor a cero.';
        if (tieneMasDeDosDecimales(n)) return 'El monto no puede tener más de dos decimales.';
        if (n > tope) return `No puedes aplicar más de ${formatearMonto(tope)}.`;
        return undefined;
      },
      showCancelButton: true,
      confirmButtonColor: '#111C99',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Aplicar',
      cancelButtonText: 'Volver'
    });
    if (!r.isConfirmed) return;
    const montoAplicado = Number(r.value);
    await this.ejecutar(c, async () => {
      await this.pagosService.aplicarSaldo(c.id, montoAplicado);
      return `Se aplicaron ${this.monto(montoAplicado)} de saldo a favor`;
    }, 'No se pudo aplicar el saldo');
  }

  /** Corre una acción sobre un cargo, avisa el resultado y refresca la lista */
  private async ejecutar(c: Cargo, accion: () => Promise<string>, tituloError: string): Promise<void> {
    this.ocupado.set(c.id);
    try {
      this.avisar(await accion());
    } catch (err: any) {
      console.error(`[CargosAdminComponent] ${tituloError}:`, err);
      this.avisarError(tituloError, mensajeConValidacion(err, 'Intenta de nuevo en unos segundos.'));
    } finally {
      this.ocupado.set(null);
    }
    // También tras un error: si el cargo ya cambió desde otro lado, la lista debe reflejarlo
    await this.cargar(this.pagina());
    this.cambio.emit();
  }

  private avisar(titulo: string): void {
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: titulo, showConfirmButton: false, timer: 3000 });
  }

  private avisarError(titulo: string, texto: string): void {
    Swal.fire({ icon: 'error', title: titulo, text: texto, confirmButtonColor: '#111C99' });
  }

  private escapar(texto: string): string {
    return texto.replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch] as string));
  }

  monto(valor: number): string {
    return formatearMonto(valor);
  }

  fecha(valor: string): string {
    return formatearFechaPago(valor);
  }

  periodo(valor: string | null): string {
    return formatearPeriodo(valor);
  }
}
