import { ChangeDetectionStrategy, Component, EventEmitter, Input, OnInit, Output, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { PlantillasCargoService } from '../../../core/services/plantillas-cargo.service';
import {
  ETIQUETAS_TIPO_CARGO,
  Plantilla,
  TIPOS_CARGO,
  TipoCargo,
  formatearFechaPago,
  formatearMonto,
  formatearPeriodo,
  periodoActual
} from '../../../core/models/pagos.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';
import { PlantillaFormComponent } from './plantilla-form.component';

type FiltroActiva = 'todas' | 'activas' | 'inactivas';

/** Plantillas de cargos recurrentes y la generación de los cargos de cada mes */
@Component({
  selector: 'app-plantillas-admin',
  standalone: true,
  imports: [CommonModule, FormsModule, PlantillaFormComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-4">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
        <div>
          <h2 class="text-sm font-semibold text-slate-900">Plantillas de cargo</h2>
          <p class="text-xs text-slate-500 mt-0.5">Cobros que se repiten cada mes, como la cuota de mantenimiento. Al generar un periodo se crea un cargo por plantilla activa.</p>
        </div>
        <div class="flex items-center gap-2 self-start sm:self-auto">
          <button type="button" (click)="cargar()" [disabled]="isLoading()"
            class="h-8 px-3 inline-flex items-center rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50">
            Actualizar
          </button>
          <button type="button" (click)="abrirFormulario()"
            class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer">
            <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            <span>Nueva plantilla</span>
          </button>
        </div>
      </div>

      <!-- Generar los cargos de un mes -->
      <div class="rounded-md border border-indigo-100 bg-indigo-50/50 p-3 flex flex-col sm:flex-row sm:items-end gap-3" data-test="generar">
        <div>
          <label for="gen-periodo" class="block text-xs font-semibold text-slate-800 mb-1">Generar cargos del periodo</label>
          <input id="gen-periodo" type="month" [(ngModel)]="periodoGenerar"
            class="h-8 w-44 text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
        </div>
        <button type="button" (click)="generar()" [disabled]="generando() || !periodoGenerar"
          class="h-8 px-3 inline-flex items-center rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
          {{ generando() ? 'Generando...' : 'Generar cargos' }}
        </button>
        <p class="text-[11px] text-slate-500 sm:max-w-sm">Si ya existía el cargo de una vivienda en ese periodo se omite, así que puedes repetirlo sin duplicar nada.</p>
      </div>

      <div class="grid grid-cols-2 lg:grid-cols-3 gap-2" data-test="filtros">
        <div>
          <label for="fpl-vivienda" class="block text-[11px] font-semibold text-slate-700 mb-1">Vivienda</label>
          <select id="fpl-vivienda" [(ngModel)]="filtros.viviendaId" (ngModelChange)="aplicarFiltros()"
            class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
            <option [ngValue]="null">Todas</option>
            @for (v of viviendas; track v.id) {
              <option [ngValue]="v.id">{{ v.numeroCasa }}</option>
            }
          </select>
        </div>
        <div>
          <label for="fpl-tipo" class="block text-[11px] font-semibold text-slate-700 mb-1">Tipo</label>
          <select id="fpl-tipo" [(ngModel)]="filtros.tipo" (ngModelChange)="aplicarFiltros()"
            class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
            <option value="">Todos</option>
            @for (t of tipos; track t) {
              <option [value]="t">{{ etiquetasTipo[t] }}</option>
            }
          </select>
        </div>
        <div>
          <label for="fpl-activa" class="block text-[11px] font-semibold text-slate-700 mb-1">Estado</label>
          <select id="fpl-activa" [(ngModel)]="filtros.activa" (ngModelChange)="aplicarFiltros()"
            class="h-8 w-full text-xs rounded-md border border-slate-300 bg-white px-2 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
            <option value="activas">Activas</option>
            <option value="inactivas">Inactivas</option>
            <option value="todas">Todas</option>
          </select>
        </div>
      </div>

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
        <div class="py-10 text-center text-xs text-slate-500 font-medium space-y-1" data-test="sin-plantillas">
          <p>No hay plantillas con esos filtros.</p>
          <p class="text-slate-400">Crea una para dejar de capturar a mano la cuota de cada mes.</p>
        </div>
      }

      @if (items().length > 0) {
        <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2.5 items-start">
          @for (p of items(); track p.id) {
            <li class="p-4 rounded-md border border-slate-200 bg-white space-y-1.5" [ngClass]="{ 'opacity-70': !p.activa }" data-test="plantilla">
              <div class="flex flex-wrap items-center gap-2">
                <p class="text-sm font-semibold text-slate-900">{{ p.concepto }}</p>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border"
                  [ngClass]="p.activa ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-slate-100 text-slate-600 border-slate-200'">
                  {{ p.activa ? 'Activa' : 'Inactiva' }}
                </span>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">Casa {{ p.numeroCasa }}</span>
              </div>
              <p class="text-xs text-slate-600">
                {{ etiquetasTipo[p.tipo] }} · {{ monto(p.monto) }} · Vence el día {{ p.diaVencimiento }} · Paga: {{ p.responsablePago }}
              </p>
              <p class="text-xs text-slate-500">
                Desde {{ fecha(p.vigenciaInicio) }}{{ p.vigenciaFin ? ' hasta ' + fecha(p.vigenciaFin) : ' sin fecha de término' }}
              </p>
              <div class="flex flex-wrap items-center gap-1.5 pt-1">
                <button type="button" (click)="abrirFormulario(p)" [attr.aria-label]="'Editar la plantilla ' + p.concepto + ' de la casa ' + p.numeroCasa"
                  class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">Editar</button>
                <button type="button" (click)="cambiarActiva(p)" [disabled]="ocupado() === p.id"
                  [attr.aria-label]="(p.activa ? 'Desactivar' : 'Activar') + ' la plantilla ' + p.concepto + ' de la casa ' + p.numeroCasa"
                  class="h-7 px-2.5 text-[11px] font-medium rounded-md border transition-colors cursor-pointer disabled:opacity-50"
                  [ngClass]="p.activa ? 'border-rose-200 text-rose-700 hover:bg-rose-50' : 'border-emerald-200 text-emerald-700 hover:bg-emerald-50'">
                  {{ p.activa ? 'Desactivar' : 'Activar' }}
                </button>
              </div>
            </li>
          }
        </ul>

        <div class="flex items-center justify-between pt-1 text-xs text-slate-600">
          <span>{{ total() }} {{ total() === 1 ? 'plantilla' : 'plantillas' }} · Página {{ pagina() }} de {{ totalPaginas() }}</span>
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
      <app-plantilla-form [viviendas]="viviendas" [plantilla]="editando()" (cerrado)="cerrarFormulario()" (guardado)="alGuardar($event)" />
    }
  `
})
export class PlantillasAdminComponent implements OnInit {
  private readonly plantillasService = inject(PlantillasCargoService);

  @Input() viviendas: Vivienda[] = [];
  /** Se generaron cargos: la lista de cargos y los contadores deben refrescarse */
  @Output() cambio = new EventEmitter<void>();

  readonly tipos = TIPOS_CARGO;
  readonly etiquetasTipo = ETIQUETAS_TIPO_CARGO;

  readonly items = signal<Plantilla[]>([]);
  readonly total = signal<number>(0);
  readonly pagina = signal<number>(1);
  readonly isLoading = signal<boolean>(false);
  readonly error = signal<string | null>(null);
  readonly ocupado = signal<string | null>(null);
  readonly generando = signal<boolean>(false);
  readonly formularioAbierto = signal<boolean>(false);
  /** Plantilla que se corrige; null cuando el formulario da de alta plantillas nuevas */
  readonly editando = signal<Plantilla | null>(null);
  readonly totalPaginas = computed(() => Math.max(1, Math.ceil(this.total() / this.plantillasService.PAGE_SIZE)));

  filtros: { viviendaId: number | null; tipo: TipoCargo | ''; activa: FiltroActiva } = { viviendaId: null, tipo: '', activa: 'activas' };
  periodoGenerar = periodoActual();

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
      const activa = this.filtros.activa === 'todas' ? null : this.filtros.activa === 'activas';
      const r = await this.plantillasService.listar({ viviendaId: this.filtros.viviendaId, tipo: this.filtros.tipo, activa }, pagina);
      if (peticion !== this.ultimaPeticion) return;
      this.items.set(r.items);
      this.total.set(r.total);
      this.pagina.set(pagina);
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[PlantillasAdminComponent] Error al cargar las plantillas:', err);
      this.error.set(mensajeConValidacion(err, 'No se pudieron cargar las plantillas.'));
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }

  abrirFormulario(plantilla?: Plantilla): void {
    this.editando.set(plantilla ?? null);
    this.formularioAbierto.set(true);
  }

  cerrarFormulario(): void {
    this.formularioAbierto.set(false);
    this.editando.set(null);
  }

  async alGuardar(cantidad: number): Promise<void> {
    const edicion = !!this.editando();
    this.cerrarFormulario();
    this.avisar(edicion ? 'Plantilla actualizada' : cantidad === 1 ? 'Plantilla creada' : `${cantidad} plantillas creadas`);
    await this.cargar(edicion ? this.pagina() : 1);
  }

  async cambiarActiva(p: Plantilla): Promise<void> {
    if (p.activa) {
      const r = await Swal.fire({
        title: '¿Desactivar esta plantilla?',
        text: `«${p.concepto}» de la casa ${p.numeroCasa} dejará de generar cargos. Los que ya existen no cambian.`,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#EF4444',
        cancelButtonColor: '#64748B',
        confirmButtonText: 'Desactivar',
        cancelButtonText: 'Volver'
      });
      if (!r.isConfirmed) return;
    }
    this.ocupado.set(p.id);
    try {
      await this.plantillasService.cambiarActiva(p.id, !p.activa);
      this.avisar(p.activa ? 'Plantilla desactivada' : 'Plantilla activada');
    } catch (err: any) {
      console.error('[PlantillasAdminComponent] Error al cambiar el estado de la plantilla:', err);
      this.avisarError(p.activa ? 'No se pudo desactivar la plantilla' : 'No se pudo activar la plantilla', mensajeConValidacion(err, 'Intenta de nuevo en unos segundos.'));
    } finally {
      this.ocupado.set(null);
    }
    // También tras un error: si la plantilla ya cambió desde otro lado, la lista debe reflejarlo
    await this.cargar(this.pagina());
  }

  /** Crea los cargos del periodo elegido de todas las plantillas activas */
  async generar(): Promise<void> {
    if (!this.periodoGenerar || this.generando()) return;
    const nombre = formatearPeriodo(this.periodoGenerar) || this.periodoGenerar;
    const confirmacion = await Swal.fire({
      title: `¿Generar los cargos de ${nombre}?`,
      text: 'Se creará un cargo por cada plantilla activa. Los que ya existan en ese periodo se omiten.',
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#111C99',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Generar cargos',
      cancelButtonText: 'Volver'
    });
    if (!confirmacion.isConfirmed) return;

    this.generando.set(true);
    try {
      const r = await this.plantillasService.generarCargos(this.periodoGenerar);
      const omitidos = r.omitidosPorYaExistir + r.omitidosPorVigencia;
      const detalle = [
        r.omitidosPorYaExistir > 0 ? `${r.omitidosPorYaExistir} ya existían` : '',
        r.omitidosPorVigencia > 0 ? `${r.omitidosPorVigencia} quedaron fuera de su vigencia` : ''
      ].filter(Boolean).join(' y ');
      await Swal.fire({
        icon: r.creados > 0 ? 'success' : 'info',
        title: r.creados > 0 ? `${r.creados} ${r.creados === 1 ? 'cargo creado' : 'cargos creados'}` : 'No se creó ningún cargo',
        text: omitidos > 0 ? `Se omitieron ${omitidos}: ${detalle}.` : `Periodo ${nombre}.`,
        confirmButtonColor: '#111C99'
      });
      if (r.creados > 0) this.cambio.emit();
    } catch (err: any) {
      console.error('[PlantillasAdminComponent] Error al generar los cargos:', err);
      this.avisarError('No se pudieron generar los cargos', mensajeConValidacion(err, 'Intenta de nuevo en unos segundos.'));
    } finally {
      this.generando.set(false);
    }
  }

  private avisar(titulo: string): void {
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: titulo, showConfirmButton: false, timer: 3000 });
  }

  private avisarError(titulo: string, texto: string): void {
    Swal.fire({ icon: 'error', title: titulo, text: texto, confirmButtonColor: '#111C99' });
  }

  monto(valor: number): string {
    return formatearMonto(valor);
  }

  fecha(valor: string | null): string {
    return formatearFechaPago(valor);
  }
}
