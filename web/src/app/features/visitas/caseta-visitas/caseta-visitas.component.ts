import { Component, inject, signal, computed, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { VisitasVigilanciaService } from '../../../core/services/visitas-vigilancia.service';
import {
  CLASES_ESTADO_VISITA,
  ETIQUETAS_ESTADO_VISITA,
  EstadoVisita,
  formatearFechaVisita,
  fusionarSinVacios,
  MOTIVOS_VISITA,
  VisitaVigilancia
} from '../../../core/models/visita.model';

const BUSQUEDA_DEBOUNCE_MS = 350;

@Component({
  selector: 'app-caseta-visitas',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="space-y-6">

      <!-- Validar código de acceso -->
      <section class="rounded-xl border border-slate-200 bg-white p-5 shadow-xs space-y-3">
        <div>
          <h2 class="text-sm font-semibold text-slate-900">Validar código de acceso</h2>
          <p class="text-xs text-slate-500 mt-0.5">Digita el código que presenta el visitante para confirmar sus datos.</p>
        </div>

        <div class="flex flex-col sm:flex-row gap-2">
          <input
            type="text"
            [(ngModel)]="codigo"
            (keyup.enter)="validarCodigo()"
            maxlength="20"
            placeholder="Código de la visita"
            autocomplete="off"
            class="h-10 flex-1 text-sm font-mono uppercase tracking-widest rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 placeholder:normal-case placeholder:tracking-normal focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
          />
          <button
            type="button"
            (click)="validarCodigo()"
            [disabled]="isValidando() || !codigo.trim()"
            class="h-10 px-4 rounded-lg bg-[#111C99] hover:bg-[#0d1577] text-white text-sm font-medium transition-colors cursor-pointer disabled:opacity-50"
          >
            {{ isValidando() ? 'Validando...' : 'Validar' }}
          </button>
        </div>

        <div *ngIf="errorCodigo()" class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium">
          {{ errorCodigo() }}
        </div>

        <div *ngIf="visitaValidada() as v" class="rounded-lg border border-emerald-200 bg-emerald-50/50 p-4 flex flex-col sm:flex-row sm:items-start justify-between gap-3">
          <div class="space-y-1 min-w-0">
            <p class="text-xs font-semibold text-emerald-700 uppercase tracking-wide">Código válido</p>
            <p class="text-base font-semibold text-slate-900">{{ v.nombreVisitante }} {{ v.apellidosVisitante }}</p>
            <p class="text-xs text-slate-600">
              Casa {{ v.numeroCasa }} · {{ etiquetaMotivo(v.motivo) }} · Registrada por {{ v.creadoPorNombre || 'el residente' }}
            </p>
            <p class="text-xs text-slate-500">
              <span *ngIf="v.numAcompanantes > 0">{{ v.numAcompanantes }} acompañante(s) · </span>
              <span *ngIf="v.vehiculoPlacas">Placas {{ v.vehiculoPlacas }}</span>
            </p>
          </div>
          <div class="shrink-0 flex items-center gap-2">
            <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="claseEstado(v.estado)">
              {{ etiquetaEstado(v.estado) }}
            </span>
            <ng-container *ngTemplateOutlet="acciones; context: { $implicit: v }"></ng-container>
          </div>
        </div>
      </section>

      <!-- Visitas de hoy -->
      <section class="rounded-xl border border-slate-200 bg-white p-5 shadow-xs space-y-4">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
          <div>
            <h2 class="text-sm font-semibold text-slate-900">Visitas de hoy</h2>
            <p class="text-xs text-slate-500 mt-0.5">Programadas y en curso. La lista se filtra mientras escribes.</p>
          </div>

          <div class="flex items-center gap-2">
            <input
              type="text"
              [(ngModel)]="busqueda"
              (ngModelChange)="onBusquedaCambio()"
              placeholder="Nombre, código o casa..."
              class="h-8 w-56 text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
            />
            <button
              type="button"
              (click)="recargar()"
              title="Actualizar"
              class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-slate-200 text-slate-600 hover:bg-slate-50 transition-colors cursor-pointer"
            >
              <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
            </button>
          </div>
        </div>

        <div *ngIf="visitasService.isLoading()" class="space-y-2">
          <div *ngFor="let s of [1, 2, 3]" class="p-4 rounded-md bg-white border border-slate-200 animate-pulse h-16"></div>
        </div>

        <div *ngIf="visitasService.errorMessage() as msg" class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium">
          {{ msg }}
        </div>

        <div
          *ngIf="!visitasService.isLoading() && !visitasService.errorMessage() && visitasService.items().length === 0"
          class="py-10 text-center text-xs text-slate-500 font-medium"
        >
          No hay visitas vigentes para hoy.
        </div>

        <ul *ngIf="!visitasService.isLoading()" class="space-y-2">
          <li
            *ngFor="let v of visitasService.items()"
            class="p-4 rounded-md border border-slate-200 bg-white flex flex-col sm:flex-row sm:items-center justify-between gap-3"
          >
            <div class="min-w-0 space-y-1">
              <div class="flex flex-wrap items-center gap-2">
                <p class="text-sm font-semibold text-slate-900">{{ v.nombreVisitante }} {{ v.apellidosVisitante }}</p>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="claseEstado(v.estado)">
                  {{ etiquetaEstado(v.estado) }}
                </span>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">
                  Casa {{ v.numeroCasa }}
                </span>
              </div>
              <p class="text-xs text-slate-600">
                {{ etiquetaMotivo(v.motivo) }} · Llegada {{ formatearFecha(v.fechaLlegadaEsperada) }}
                <span *ngIf="v.horaEntrada"> · Entró {{ formatearFecha(v.horaEntrada) }}</span>
              </p>
              <p class="text-xs text-slate-500">
                <span *ngIf="v.numAcompanantes > 0">{{ v.numAcompanantes }} acompañante(s) · </span>
                <span *ngIf="v.vehiculoPlacas">Placas {{ v.vehiculoPlacas }} · </span>
                <span>Registrada por {{ v.creadoPorNombre || 'el residente' }}</span>
              </p>
            </div>

            <div class="shrink-0 flex items-center gap-2">
              <button
                type="button"
                (click)="abrirDetalle(v)"
                class="h-8 px-3 rounded-md border border-slate-200 text-xs font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
              >
                Detalle
              </button>
              <ng-container *ngTemplateOutlet="acciones; context: { $implicit: v }"></ng-container>
            </div>
          </li>
        </ul>

        <div *ngIf="totalPaginas() > 1" class="flex items-center justify-between pt-2 border-t border-slate-100">
          <button
            type="button"
            (click)="irAPagina(visitasService.page() - 1)"
            [disabled]="visitasService.page() <= 1"
            class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer"
          >
            Anterior
          </button>
          <span class="text-xs text-slate-500 font-medium">Página {{ visitasService.page() }} de {{ totalPaginas() }}</span>
          <button
            type="button"
            (click)="irAPagina(visitasService.page() + 1)"
            [disabled]="visitasService.page() >= totalPaginas()"
            class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer"
          >
            Siguiente
          </button>
        </div>
      </section>
    </div>

    <!-- Modal de detalle de visita -->
    <div
      *ngIf="visitaDetalle() as d"
      class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4"
      (click)="cerrarDetalle()"
    >
      <div class="bg-white rounded-lg max-w-md w-full p-5 shadow-lg border border-slate-200" (click)="$event.stopPropagation()">
        <div class="flex items-start justify-between pb-3 border-b border-slate-100">
          <div>
            <h3 class="text-sm font-semibold text-slate-900">{{ d.nombreVisitante }} {{ d.apellidosVisitante }}</h3>
            <span class="mt-1 inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="claseEstado(d.estado)">
              {{ etiquetaEstado(d.estado) }}
            </span>
          </div>
          <button type="button" (click)="cerrarDetalle()" class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer" title="Cerrar">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <dl class="mt-3 grid grid-cols-3 gap-x-3 gap-y-2 text-xs">
          <dt class="text-slate-500">Casa</dt><dd class="col-span-2 font-medium text-slate-900">{{ d.numeroCasa }}</dd>
          <dt class="text-slate-500">Motivo</dt><dd class="col-span-2 font-medium text-slate-900">{{ etiquetaMotivo(d.motivo) }}</dd>
          <dt class="text-slate-500">Teléfono</dt><dd class="col-span-2 font-medium text-slate-900">{{ d.telefonoVisitante || '—' }}</dd>
          <dt class="text-slate-500">Acompañantes</dt><dd class="col-span-2 font-medium text-slate-900">{{ d.numAcompanantes }}</dd>
          <dt class="text-slate-500">Placas</dt><dd class="col-span-2 font-medium text-slate-900">{{ d.vehiculoPlacas || '—' }}</dd>
          <dt class="text-slate-500">Notas</dt><dd class="col-span-2 font-medium text-slate-900">{{ d.notas || '—' }}</dd>
          <dt class="text-slate-500">Llegada esperada</dt><dd class="col-span-2 font-medium text-slate-900">{{ formatearFecha(d.fechaLlegadaEsperada) }}</dd>
          <dt class="text-slate-500">Vigente hasta</dt><dd class="col-span-2 font-medium text-slate-900">{{ formatearFecha(d.vigenciaHasta) || '—' }}</dd>
          <dt class="text-slate-500">Entrada</dt><dd class="col-span-2 font-medium text-slate-900">{{ formatearFecha(d.horaEntrada) || '—' }}</dd>
          <dt class="text-slate-500">Salida</dt><dd class="col-span-2 font-medium text-slate-900">{{ formatearFecha(d.horaSalida) || '—' }}</dd>
          <dt class="text-slate-500">Registrada por</dt><dd class="col-span-2 font-medium text-slate-900">{{ d.creadoPorNombre || 'el residente' }}</dd>
        </dl>

        <!-- Captura de placas al dar ingreso -->
        <div *ngIf="d.estado === 'programada'" class="mt-3">
          <label class="block text-xs font-semibold text-slate-800 mb-1" for="placas-entrada">Placas del vehículo (opcional)</label>
          <input
            id="placas-entrada"
            type="text"
            [(ngModel)]="placasEntrada"
            maxlength="15"
            autocomplete="off"
            placeholder="Ej. ABC-123"
            class="h-9 w-full text-xs uppercase rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 placeholder:normal-case focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
          />
        </div>

        <div class="mt-4 pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
          <button type="button" (click)="cerrarDetalle()"
            class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer">
            Cerrar
          </button>
          <ng-container *ngTemplateOutlet="acciones; context: { $implicit: d, conPlacas: true }"></ng-container>
        </div>
      </div>
    </div>

    <!-- Botón de acción según el estado de la visita -->
    <ng-template #acciones let-v let-conPlacas="conPlacas">
      <button
        *ngIf="v.estado === 'programada'"
        type="button"
        (click)="registrarEntrada(v, conPlacas ? placasEntrada : undefined)"
        [disabled]="visitaEnProceso() === v.id"
        class="h-8 px-3 rounded-md bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50"
      >
        {{ visitaEnProceso() === v.id ? 'Registrando...' : 'Registrar entrada' }}
      </button>
      <button
        *ngIf="v.estado === 'en_curso'"
        type="button"
        (click)="registrarSalida(v)"
        [disabled]="visitaEnProceso() === v.id"
        class="h-8 px-3 rounded-md bg-slate-800 hover:bg-slate-900 text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50"
      >
        {{ visitaEnProceso() === v.id ? 'Registrando...' : 'Registrar salida' }}
      </button>
    </ng-template>
  `
})
export class CasetaVisitasComponent implements OnInit, OnDestroy {
  readonly visitasService = inject(VisitasVigilanciaService);

  codigo = '';
  busqueda = '';
  /** Placas que el guardia captura en el detalle al dar ingreso */
  placasEntrada = '';
  private temporizadorBusqueda?: ReturnType<typeof setTimeout>;

  readonly isValidando = signal<boolean>(false);
  readonly visitaValidada = signal<VisitaVigilancia | null>(null);
  readonly errorCodigo = signal<string | null>(null);
  /** Id de la visita a la que se le está registrando entrada o salida */
  readonly visitaEnProceso = signal<string | null>(null);

  private readonly detalleId = signal<string | null>(null);
  /** Se deriva de la lista para que el modal refleje entrada y salida registradas sin cerrarse */
  readonly visitaDetalle = computed(() =>
    this.visitasService.items().find(v => v.id === this.detalleId()) ?? null
  );

  readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.visitasService.totalCount() / this.visitasService.PAGE_SIZE))
  );

  ngOnInit(): void {
    this.visitasService.cargarHoy();
  }

  ngOnDestroy(): void {
    clearTimeout(this.temporizadorBusqueda);
  }

  etiquetaEstado(estado: EstadoVisita): string {
    return ETIQUETAS_ESTADO_VISITA[estado] ?? estado;
  }

  claseEstado(estado: EstadoVisita): string {
    return CLASES_ESTADO_VISITA[estado] ?? 'bg-slate-100 text-slate-700 border-slate-200';
  }

  etiquetaMotivo(motivo: string): string {
    return MOTIVOS_VISITA.find(m => m.valor === motivo)?.etiqueta ?? motivo;
  }

  formatearFecha(iso: string | null | undefined): string {
    return formatearFechaVisita(iso);
  }

  abrirDetalle(v: VisitaVigilancia): void {
    this.detalleId.set(v.id);
    // Si el residente ya indicó las placas al programar, se precargan para confirmarlas o corregirlas
    this.placasEntrada = v.vehiculoPlacas ?? '';
  }

  cerrarDetalle(): void {
    this.detalleId.set(null);
  }

  /** Espera a que el guardia deje de teclear para no disparar una petición por letra */
  onBusquedaCambio(): void {
    clearTimeout(this.temporizadorBusqueda);
    this.temporizadorBusqueda = setTimeout(() => this.visitasService.cargarHoy(this.busqueda, 1), BUSQUEDA_DEBOUNCE_MS);
  }

  recargar(): void {
    this.visitasService.cargarHoy(this.busqueda, this.visitasService.page());
  }

  irAPagina(pagina: number): void {
    if (pagina < 1 || pagina > this.totalPaginas()) return;
    this.visitasService.cargarHoy(this.busqueda, pagina);
  }

  async validarCodigo(): Promise<void> {
    const codigo = this.codigo.trim();
    if (!codigo || this.isValidando()) return;

    this.isValidando.set(true);
    this.errorCodigo.set(null);
    this.visitaValidada.set(null);
    try {
      this.visitaValidada.set(await this.visitasService.validarCodigo(codigo));
    } catch (err: any) {
      console.error('[CasetaVisitasComponent] Error al validar código:', err);
      this.errorCodigo.set(this.mensajeError(err));
    } finally {
      this.isValidando.set(false);
    }
  }

  async registrarEntrada(v: VisitaVigilancia, vehiculoPlacas?: string): Promise<void> {
    await this.ejecutarAccion(v, () => this.visitasService.registrarEntrada(v.id, vehiculoPlacas), 'Entrada registrada', 'No se pudo registrar la entrada');
  }

  async registrarSalida(v: VisitaVigilancia): Promise<void> {
    await this.ejecutarAccion(v, () => this.visitasService.registrarSalida(v.id), 'Salida registrada', 'No se pudo registrar la salida');
  }

  private async ejecutarAccion(
    v: VisitaVigilancia,
    accion: () => Promise<VisitaVigilancia>,
    exito: string,
    fallo: string
  ): Promise<void> {
    if (this.visitaEnProceso()) return;

    this.visitaEnProceso.set(v.id);
    try {
      const actualizada = await accion();
      if (this.visitaValidada()?.id === v.id) {
        this.visitaValidada.set(fusionarSinVacios(this.visitaValidada()!, actualizada));
      }
      Swal.fire({
        toast: true,
        position: 'top-end',
        icon: 'success',
        title: exito,
        text: `${v.nombreVisitante} ${v.apellidosVisitante}`,
        showConfirmButton: false,
        timer: 2500
      });
    } catch (err: any) {
      console.error('[CasetaVisitasComponent] Error en la acción de caseta:', err);
      Swal.fire({
        icon: 'error',
        title: fallo,
        text: this.mensajeError(err),
        confirmButtonColor: '#111C99'
      });
    } finally {
      this.visitaEnProceso.set(null);
    }
  }

  private mensajeError(err: any): string {
    return err?.error?.error || 'Ocurrió un error inesperado. Intenta de nuevo.';
  }
}
