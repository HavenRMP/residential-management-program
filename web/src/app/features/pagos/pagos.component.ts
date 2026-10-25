import { Component, ChangeDetectionStrategy, Injector, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { AuthService } from '../../core/services/auth.service';
import { PagosService } from '../../core/services/pagos.service';
import {
  CLASES_ESTADO_CARGO,
  CLASES_ESTADO_PAGO,
  Cargo,
  ETIQUETAS_ESTADO_CARGO,
  ETIQUETAS_ESTADO_PAGO,
  ETIQUETAS_METODO_PAGO,
  ETIQUETAS_TIPO_CARGO,
  Pago,
  cargoAdmitePago,
  formatearFechaPago,
  formatearMonto,
  formatearPeriodo
} from '../../core/models/pagos.model';
import { abrirEnPestana } from '../../core/utils/abrir-comprobante.util';
import { mensajeAmigable } from '../../core/utils/api-errors.util';
import { autoActualizar } from '../../core/utils/auto-actualizar.util';
import { UserMenuComponent } from '../../core/components/user-menu/user-menu.component';
import { PagoFormComponent } from './pago-form/pago-form.component';
import { CargoPagosComponent } from './cargo-pagos/cargo-pagos.component';

type Pestana = 'porPagar' | 'historial' | 'pagos';

/** Portal del residente: lo que debe, lo que ha pagado y el reporte de pagos con comprobante */
@Component({
  selector: 'app-pagos',
  standalone: true,
  imports: [CommonModule, RouterLink, UserMenuComponent, PagoFormComponent, CargoPagosComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="min-h-screen bg-[#F8FAFC] text-slate-900 font-sans antialiased">

      <header class="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-2xs">
        <div class="w-full px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <a
              routerLink="/dashboard/residente"
              class="h-8 w-8 inline-flex items-center justify-center text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-md transition-colors cursor-pointer"
              title="Volver"
              aria-label="Volver al portal"
              >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
            </a>
            <div class="flex items-center gap-2">
              <span class="font-bold text-base tracking-tight text-slate-900">Pagos</span>
              <span class="text-[11px] font-medium px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 border border-slate-200">
                Mi vivienda
              </span>
            </div>
          </div>

          <app-user-menu [user]="currentUser()" (logout)="onLogout()" />
        </div>
      </header>

      <main class="w-full px-4 sm:px-6 lg:px-8 py-6 space-y-6">

        <nav aria-label="Ruta de navegación" class="flex items-center gap-2 text-xs text-slate-600 font-medium">
          <a routerLink="/dashboard/residente" class="hover:text-slate-900 transition-colors">Portal</a>
          <span>/</span>
          <span class="text-slate-900">Pagos</span>
        </nav>
        <h1 class="sr-only">Pagos</h1>

        <!-- Resumen -->
        <section aria-label="Resumen de tu cuenta" class="grid grid-cols-2 lg:grid-cols-4 gap-3" data-test="resumen">
          <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
            <p class="text-xs font-medium text-slate-500">Por pagar</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ monto(pagosService.miSaldo()?.totalPendiente) }}</p>
          </div>
          <div class="rounded-lg border bg-white p-4 shadow-2xs" [ngClass]="(pagosService.miSaldo()?.totalVencido ?? 0) > 0 ? 'border-rose-200' : 'border-slate-200'">
            <p class="text-xs font-medium text-slate-500">Vencido</p>
            <p class="mt-1 text-lg font-semibold" [ngClass]="(pagosService.miSaldo()?.totalVencido ?? 0) > 0 ? 'text-rose-700' : 'text-slate-900'">
              {{ monto(pagosService.miSaldo()?.totalVencido) }}
            </p>
          </div>
          <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
            <p class="text-xs font-medium text-slate-500">Saldo a favor</p>
            <p class="mt-1 text-lg font-semibold text-emerald-700">{{ monto(pagosService.miSaldo()?.saldoAFavor) }}</p>
          </div>
          <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs">
            <p class="text-xs font-medium text-slate-500">Cargos abiertos</p>
            <p class="mt-1 text-lg font-semibold text-slate-900">{{ pagosService.miSaldo()?.totalCargosAbiertos ?? 0 }}</p>
          </div>
        </section>

        <!-- Pagos que esperan confirmación -->
        @if (porConfirmar().length > 0) {
          <div class="rounded-lg border border-amber-200 bg-amber-50 p-4 flex items-start gap-3" role="status" data-test="aviso-por-confirmar">
            <svg class="w-5 h-5 text-amber-600 shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div>
              <p class="text-sm font-semibold text-amber-900">
                {{ porConfirmar().length === 1 ? 'Tienes 1 pago por confirmar' : 'Tienes ' + porConfirmar().length + ' pagos por confirmar' }}
              </p>
              <p class="text-xs text-amber-800 mt-0.5">La administración revisa tu comprobante y lo aplicará a tu cargo.</p>
            </div>
          </div>
        }

        <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Mis cargos y pagos</h2>
              <p class="text-xs text-slate-500 mt-0.5">Consulta lo que debes y reporta tus pagos con su comprobante.</p>
            </div>
            <button
              type="button"
              (click)="recargar()"
              [disabled]="pagosService.isLoading()"
              class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50 self-start sm:self-auto"
              >
              Actualizar
            </button>
          </div>

          <div class="flex items-center gap-1.5 flex-wrap" role="tablist" aria-label="Pagos">
            @for (p of pestanas; track p.id) {
              <button
                type="button"
                role="tab"
                [attr.aria-selected]="pestana() === p.id"
                (click)="cambiarPestana(p.id)"
                class="h-8 px-3 rounded-md text-xs font-medium border transition-colors cursor-pointer"
                [ngClass]="pestana() === p.id ? 'bg-slate-900 text-white border-slate-900' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'"
                >
                {{ p.texto }} @if (mostrarConteos()) {({{ conteo(p.id) }})}
              </button>
            }
          </div>

          @if (pagosService.isLoading() && pagosService.misCargos().length === 0 && pagosService.misPagos().length === 0) {
            <div class="space-y-2" aria-hidden="true">
              @for (s of [1, 2]; track s) {
                <div class="p-4 rounded-md bg-white border border-slate-200 animate-pulse h-24"></div>
              }
            </div>
          }

          @if (pagosService.errorMessage(); as msg) {
            <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
              <span>{{ msg }}</span>
              <button type="button" (click)="recargar()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">
                Reintentar
              </button>
            </div>
          }

          <!-- Cargos -->
          @if (pestana() !== 'pagos') {
            @if (!pagosService.isLoading() && !pagosService.errorMessage() && cargosVisibles().length === 0) {
              <div class="py-10 text-center text-xs text-slate-500 font-medium space-y-1" data-test="sin-cargos">
                @if (pestana() === 'porPagar') {
                  <p>No tienes cargos por pagar.</p>
                  <p class="text-slate-400">Cuando la administración genere uno, aparecerá aquí.</p>
                } @else {
                  <p>Todavía no hay cargos pagados o cancelados.</p>
                }
              </div>
            }

            @if (cargosVisibles().length > 0) {
              <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2.5 items-start">
                @for (c of cargosVisibles(); track c.id) {
                  <li class="p-4 rounded-md border bg-white space-y-2" [ngClass]="c.estadoEfectivo === 'Vencido' ? 'border-rose-200' : 'border-slate-200'" data-test="cargo">
                    <div class="flex flex-wrap items-center gap-2">
                      <p class="text-sm font-semibold text-slate-900">{{ c.concepto }}</p>
                      <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="claseCargo(c)">
                        {{ etiquetaCargo(c) }}
                      </span>
                      @if (variasViviendas() && c.numeroCasa) {
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">
                          Casa {{ c.numeroCasa }}
                        </span>
                      }
                    </div>
                    <p class="text-xs text-slate-600">
                      {{ tipos[c.tipo] }}@if (c.periodo) {<span> · {{ periodo(c.periodo) }}</span>} · Vence {{ fecha(c.fechaVencimiento) }}
                    </p>
                    <dl class="grid grid-cols-3 gap-2 text-xs">
                      <div>
                        <dt class="text-slate-500">Monto</dt>
                        <dd class="font-semibold text-slate-900">{{ monto(c.monto) }}</dd>
                      </div>
                      <div>
                        <dt class="text-slate-500">Pagado</dt>
                        <dd class="font-semibold text-slate-900">{{ monto(c.montoPagadoConfirmado) }}</dd>
                      </div>
                      <div>
                        <dt class="text-slate-500">Saldo</dt>
                        <dd class="font-semibold" [ngClass]="c.saldoPendiente > 0 ? 'text-slate-900' : 'text-emerald-700'">{{ monto(c.saldoPendiente) }}</dd>
                      </div>
                    </dl>
                    @if (c.motivoCancelacion) {
                      <p class="text-xs text-slate-500 italic">Cancelado: {{ c.motivoCancelacion }}</p>
                    }
                    @if (tienePagoPorConfirmar(c)) {
                      <p class="text-xs text-amber-700">Tienes un pago de este cargo esperando confirmación.</p>
                    }

                    <div class="flex flex-wrap items-center gap-1.5 pt-1">
                      @if (admitePago(c)) {
                        <button
                          type="button"
                          (click)="abrirPago(c)"
                          [attr.aria-label]="'Reportar un pago de ' + c.concepto"
                          class="h-7 px-2.5 text-[11px] font-medium rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white transition-colors cursor-pointer"
                          >
                          Reportar pago
                        </button>
                      }
                      <button
                        type="button"
                        (click)="alternarDetalle(c)"
                        [attr.aria-expanded]="estaAbierto(c)"
                        [attr.aria-label]="'Ver los pagos de ' + c.concepto"
                        class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
                        >
                        {{ estaAbierto(c) ? 'Ocultar pagos' : 'Ver pagos' }}
                      </button>
                    </div>

                    @if (estaAbierto(c)) {
                      <app-cargo-pagos [cargoId]="c.id" />
                    }
                  </li>
                }
              </ul>
            }
          }

          <!-- Pagos -->
          @if (pestana() === 'pagos') {
            @if (!pagosService.isLoading() && !pagosService.errorMessage() && pagos().length === 0) {
              <div class="py-10 text-center text-xs text-slate-500 font-medium space-y-1" data-test="sin-pagos">
                <p>Todavía no has reportado ningún pago.</p>
                <p class="text-slate-400">Reporta uno desde un cargo en «Por pagar».</p>
              </div>
            }

            @if (pagos().length > 0) {
              <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2.5 items-start">
                @for (p of pagos(); track p.id) {
                  <li class="p-4 rounded-md border border-slate-200 bg-white space-y-1.5" data-test="pago">
                    <div class="flex flex-wrap items-center gap-2">
                      <p class="text-sm font-semibold text-slate-900">{{ monto(p.monto) }}</p>
                      <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="clasePago(p)">
                        {{ etiquetaPago(p) }}
                      </span>
                      @if (p.esReversa) {
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">Reversa</span>
                      }
                      @if (variasViviendas() && p.numeroCasa) {
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">
                          Casa {{ p.numeroCasa }}
                        </span>
                      }
                    </div>
                    <p class="text-xs text-slate-600">{{ p.cargoConcepto }} · {{ fecha(p.fechaPago) }} · {{ metodos[p.metodo] }}@if (p.referencia) {<span> · Ref. {{ p.referencia }}</span>}</p>
                    @if (p.montoExcedente > 0) {
                      <p class="text-xs text-emerald-700">{{ monto(p.montoExcedente) }} pasaron a tu saldo a favor.</p>
                    }
                    @if (p.motivoRechazo) {
                      <p class="text-xs text-rose-700">Rechazado: {{ p.motivoRechazo }}</p>
                    }
                    @if (p.motivoAnulacion) {
                      <p class="text-xs text-slate-500 italic">Anulado: {{ p.motivoAnulacion }}</p>
                    }
                    @if (p.tieneComprobante) {
                      <div class="pt-1">
                        <button
                          type="button"
                          (click)="verComprobante(p)"
                          [attr.aria-label]="'Ver el comprobante del pago de ' + monto(p.monto)"
                          class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
                          >
                          Ver comprobante
                        </button>
                      </div>
                    }
                  </li>
                }
              </ul>
            }
          }
        </section>
      </main>
    </div>

    @if (cargoPagando(); as cargo) {
      <app-pago-form [cargo]="cargo" modo="residente" (cerrado)="cerrarPago()" (guardado)="alReportar()" />
    }
  `
})
export class PagosComponent implements OnInit {
  private readonly authService = inject(AuthService);
  readonly pagosService = inject(PagosService);
  private readonly injector = inject(Injector);

  readonly currentUser = this.authService.currentUser;

  readonly pestanas: { id: Pestana; texto: string }[] = [
    { id: 'porPagar', texto: 'Por pagar' },
    { id: 'historial', texto: 'Historial de cargos' },
    { id: 'pagos', texto: 'Mis pagos' }
  ];
  readonly tipos = ETIQUETAS_TIPO_CARGO;
  readonly metodos = ETIQUETAS_METODO_PAGO;

  readonly pestana = signal<Pestana>('porPagar');
  readonly cargoPagando = signal<Cargo | null>(null);
  /** Cargos cuyos pagos están desplegados, por id */
  readonly abiertos = signal<ReadonlySet<string>>(new Set());

  /** Los más urgentes primero: lo que vence antes */
  readonly porPagar = computed(() =>
    this.pagosService.misCargos()
      .filter(c => c.estado === 'Pendiente' || c.estado === 'Parcial')
      .sort((a, b) => a.fechaVencimiento.localeCompare(b.fechaVencimiento))
  );
  readonly historial = computed(() =>
    this.pagosService.misCargos()
      .filter(c => c.estado === 'Pagado' || c.estado === 'Cancelado')
      .sort((a, b) => b.fechaVencimiento.localeCompare(a.fechaVencimiento))
  );
  readonly pagos = computed(() =>
    [...this.pagosService.misPagos()].sort((a, b) => b.creadoEn.localeCompare(a.creadoEn))
  );
  readonly porConfirmar = computed(() => this.pagosService.misPagos().filter(p => p.estado === 'PendienteConfirmacion'));
  readonly cargosVisibles = computed(() => (this.pestana() === 'porPagar' ? this.porPagar() : this.historial()));
  readonly variasViviendas = computed(() => new Set(this.pagosService.misCargos().map(c => c.viviendaId)).size > 1);
  /** Mientras llegan los primeros datos los contadores dirían "(0)" sin ser cierto, así que se ocultan */
  readonly mostrarConteos = computed(
    () => !(this.pagosService.isLoading() && this.pagosService.misCargos().length === 0 && this.pagosService.misPagos().length === 0)
  );

  async ngOnInit(): Promise<void> {
    await this.pagosService.cargarResumen();
    // Lo que confirma o rechaza la administración aparece solo, sin tocar "Actualizar"
    autoActualizar(this.injector, () => void this.pagosService.cargarResumen(true));
  }

  onLogout(): void {
    this.authService.logout();
  }

  cambiarPestana(pestana: Pestana): void {
    this.pestana.set(pestana);
  }

  conteo(pestana: Pestana): number {
    if (pestana === 'porPagar') return this.porPagar().length;
    if (pestana === 'historial') return this.historial().length;
    return this.pagos().length;
  }

  async recargar(): Promise<void> {
    this.abiertos.set(new Set());
    await this.pagosService.cargarResumen();
  }

  // --- Reportar un pago ---

  admitePago(c: Cargo): boolean {
    return cargoAdmitePago(c);
  }

  abrirPago(c: Cargo): void {
    this.cargoPagando.set(c);
  }

  cerrarPago(): void {
    this.cargoPagando.set(null);
  }

  async alReportar(): Promise<void> {
    this.cerrarPago();
    this.pestana.set('pagos');
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Pago reportado, la administración lo confirmará', showConfirmButton: false, timer: 3500 });
    await this.recargar();
  }

  // --- Pagos de un cargo ---

  estaAbierto(c: Cargo): boolean {
    return this.abiertos().has(c.id);
  }

  alternarDetalle(c: Cargo): void {
    this.abiertos.update(abiertos => {
      const siguiente = new Set(abiertos);
      if (!siguiente.delete(c.id)) siguiente.add(c.id);
      return siguiente;
    });
  }

  tienePagoPorConfirmar(c: Cargo): boolean {
    return this.porConfirmar().some(p => p.cargoId === c.id);
  }

  async verComprobante(p: Pago): Promise<void> {
    try {
      await abrirEnPestana(() => this.pagosService.obtenerUrlComprobante(p.id));
    } catch (err: any) {
      console.error('[PagosComponent] Error al abrir el comprobante:', err);
      Swal.fire({
        icon: 'error',
        title: 'No se pudo abrir el comprobante',
        text: mensajeAmigable(err, 'El comprobante ya no está disponible o no se pudo consultar. Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#111C99'
      });
    }
  }

  // --- Presentación ---

  monto(valor: number | null | undefined): string {
    return formatearMonto(valor);
  }

  fecha(valor: string | null | undefined): string {
    return formatearFechaPago(valor);
  }

  periodo(valor: string | null | undefined): string {
    return formatearPeriodo(valor);
  }

  etiquetaCargo(c: Cargo): string {
    return ETIQUETAS_ESTADO_CARGO[c.estadoEfectivo] ?? c.estado;
  }

  claseCargo(c: Cargo): string {
    return CLASES_ESTADO_CARGO[c.estadoEfectivo] ?? 'bg-slate-100 text-slate-700 border-slate-200';
  }

  etiquetaPago(p: Pick<Pago, 'estado'>): string {
    return ETIQUETAS_ESTADO_PAGO[p.estado] ?? p.estado;
  }

  clasePago(p: Pick<Pago, 'estado'>): string {
    return CLASES_ESTADO_PAGO[p.estado] ?? 'bg-slate-100 text-slate-700 border-slate-200';
  }
}
