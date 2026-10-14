import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ReservasService } from '../../../core/services/reservas.service';
import { ReservaCalendario, nombreCompleto, normalizarEstado } from '../../../core/models/reserva.model';
import { diaLegible, fechaEnZona, horaEnZona, instanteEnZona } from '../../../core/utils/reservas.util';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';

type Rango = 'hoy' | 'manana' | 'semana' | 'mes';

const DIA_MS = 86_400_000;

/** Qué días cubre cada opción, contados desde hoy (el fin no se incluye) */
const RANGOS: { valor: Rango; etiqueta: string; desde: number; hasta: number; vacio: string }[] = [
  { valor: 'hoy', etiqueta: 'Hoy', desde: 0, hasta: 1, vacio: 'Hoy no hay áreas reservadas ni bloqueadas.' },
  { valor: 'manana', etiqueta: 'Mañana', desde: 1, hasta: 2, vacio: 'Mañana no hay áreas reservadas ni bloqueadas.' },
  { valor: 'semana', etiqueta: '7 días', desde: 0, hasta: 7, vacio: 'En los próximos 7 días no hay áreas reservadas ni bloqueadas.' },
  { valor: 'mes', etiqueta: '30 días', desde: 0, hasta: 30, vacio: 'En los próximos 30 días no hay áreas reservadas ni bloqueadas.' }
];

interface GrupoDia {
  fecha: string;
  titulo: string;
  items: ReservaCalendario[];
}

/**
 * Agenda de las áreas comunes para la caseta: qué casa tiene reservada cada área y a qué hora, y qué áreas están bloqueadas.
 * Es de solo consulta. El backend le entrega al vigilante únicamente las reservas ya aprobadas.
 */
@Component({
  selector: 'app-reservas-caseta',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <section class="rounded-xl border border-slate-200 bg-white p-5 shadow-xs space-y-4" aria-labelledby="reservas-caseta-titulo">
      <div class="flex flex-col lg:flex-row lg:items-end justify-between gap-3 pb-3 border-b border-slate-100">
        <div>
          <h2 id="reservas-caseta-titulo" class="text-sm font-semibold text-slate-900">Reservas de áreas comunes</h2>
          <p class="text-xs text-slate-500 mt-0.5">Qué casa usará cada área y cuándo, para saber quién espera ingresar. Solo se muestran las reservas aprobadas y los bloqueos.</p>
        </div>
        <div class="flex flex-wrap items-end gap-2">
          <div class="flex items-center gap-1.5" role="group" aria-label="Periodo">
            @for (r of rangos; track r.valor) {
              <button
                type="button"
                (click)="elegirRango(r.valor)"
                [attr.aria-pressed]="rango() === r.valor"
                class="h-8 px-3 rounded-md text-xs font-medium border transition-colors cursor-pointer"
                [ngClass]="rango() === r.valor ? 'bg-slate-900 text-white border-slate-900' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'"
                >
                {{ r.etiqueta }}
              </button>
            }
          </div>
          <div>
            <label for="caseta-res-area" class="sr-only">Área</label>
            <select id="caseta-res-area" [ngModel]="areaId()" (ngModelChange)="elegirArea($event)"
              class="h-8 text-xs rounded-md border border-slate-300 bg-white px-2.5 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option [ngValue]="''">Todas las áreas</option>
              @for (a of servicio.areas(); track a.id) {
                <option [ngValue]="a.id">{{ a.nombre }}</option>
              }
            </select>
          </div>
          <button type="button" (click)="cargar()" [disabled]="cargando()"
            class="h-8 px-3 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors cursor-pointer disabled:opacity-50">
            Actualizar
          </button>
        </div>
      </div>

      @if (error(); as msg) {
        <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
          <span>{{ msg }}</span>
          <button type="button" (click)="cargar()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">Reintentar</button>
        </div>
      }

      @if (cargando() && items().length === 0) {
        <div class="space-y-2" aria-busy="true">
          @for (s of [1, 2]; track s) {
            <div class="h-14 rounded-md bg-slate-100 animate-pulse"></div>
          }
        </div>
      }

      @if (sinAreas()) {
        <p class="py-8 text-center text-xs text-slate-500 font-medium">El condominio aún no tiene áreas comunes.</p>
      } @else if (!cargando() && !error() && grupos().length === 0) {
        <p class="py-8 text-center text-xs text-slate-500 font-medium">{{ textoVacio() }}</p>
      }

      @for (g of grupos(); track g.fecha) {
        <div class="space-y-2">
          <h3 class="text-xs font-bold text-slate-700 uppercase tracking-wide">{{ g.titulo }}</h3>
          <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2">
            @for (o of g.items; track o.id) {
              <li
                class="p-3 rounded-md border flex items-start justify-between gap-3"
                [ngClass]="o.tipo === 'BLOQUEO' ? 'border-slate-300 bg-slate-100' : estado(o) === 'terminada' ? 'border-slate-200 bg-slate-50 opacity-70' : 'border-slate-200 bg-white'"
                >
                <div class="min-w-0">
                  <p class="text-sm font-semibold text-slate-900">{{ horas(o) }}</p>
                  <p class="text-xs font-medium text-slate-700">{{ o.areaNombre }}</p>
                  @if (o.tipo === 'BLOQUEO') {
                    <p class="text-xs text-slate-600">Área bloqueada{{ o.motivo ? ': ' + o.motivo : '' }}</p>
                  } @else {
                    <p class="text-xs text-slate-600">
                      @if (o.numeroCasa) { <span class="font-semibold text-slate-900">Casa {{ o.numeroCasa }}</span> }
                      @if (titular(o)) { <span> · {{ titular(o) }}</span> }
                    </p>
                  }
                </div>
                @if (estado(o) === 'en-curso') {
                  <span class="shrink-0 inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-emerald-50 text-emerald-700 border-emerald-200">En curso</span>
                } @else if (estado(o) === 'terminada') {
                  <span class="shrink-0 inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-100 text-slate-600 border-slate-200">Terminó</span>
                } @else if (o.tipo === 'BLOQUEO') {
                  <span class="shrink-0 inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-700 text-white border-slate-700">Bloqueo</span>
                }
              </li>
            }
          </ul>
        </div>
      }
    </section>
  `
})
export class ReservasCasetaComponent implements OnInit {
  readonly servicio = inject(ReservasService);

  readonly rangos = RANGOS;
  readonly rango = signal<Rango>('hoy');
  readonly areaId = signal<string>('');
  readonly items = signal<ReservaCalendario[]>([]);
  readonly cargando = signal<boolean>(false);
  readonly error = signal<string | null>(null);

  private ultimaConsulta = 0;

  /** Todas las áreas comparten la zona horaria del condominio; con una sola basta */
  private readonly zona = computed(() => this.servicio.areas()[0]?.zonaHoraria ?? Intl.DateTimeFormat().resolvedOptions().timeZone);

  readonly sinAreas = computed(() => !this.servicio.isLoadingAreas() && !this.servicio.errorAreas() && this.servicio.areas().length === 0);

  /**
   * Solo las reservas ya aprobadas, los bloqueos y lo de un área vigente. La caseta no debe esperar a nadie cuya reserva
   * aún no se aprueba, y las áreas dadas de baja no deben aparecer.
   */
  private readonly visibles = computed(() => {
    const vigentes = new Set(this.servicio.areas().map(a => a.id));
    const aprobada = (o: ReservaCalendario) => ['APROBADA', 'CONFIRMADA'].includes(normalizarEstado(o.estado));
    return [...this.items()]
      .filter(o => (o.tipo === 'BLOQUEO' || aprobada(o)) && vigentes.has(o.areaId))
      .sort((a, b) => new Date(a.inicio).getTime() - new Date(b.inicio).getTime());
  });

  /** Agrupado por el día en que empieza, con "Hoy" y "Mañana" para ubicarse rápido */
  readonly grupos = computed<GrupoDia[]>(() => {
    const zona = this.zona();
    const hoy = fechaEnZona(Date.now(), zona);
    const manana = fechaEnZona(Date.now() + DIA_MS, zona);
    const porDia = new Map<string, ReservaCalendario[]>();
    for (const o of this.visibles()) {
      const dia = fechaEnZona(o.inicio, zona);
      porDia.set(dia, [...(porDia.get(dia) ?? []), o]);
    }
    return [...porDia.entries()].map(([fecha, items]) => {
      const legible = diaLegible(items[0].inicio, zona);
      const prefijo = fecha === hoy ? 'Hoy · ' : fecha === manana ? 'Mañana · ' : '';
      return { fecha, titulo: prefijo + legible, items };
    });
  });

  async ngOnInit(): Promise<void> {
    await this.servicio.cargarAreas();
    await this.cargar();
  }

  elegirRango(rango: Rango): void {
    this.rango.set(rango);
    void this.cargar();
  }

  elegirArea(areaId: string): void {
    this.areaId.set(areaId);
    void this.cargar();
  }

  textoVacio(): string {
    return RANGOS.find(r => r.valor === this.rango())?.vacio ?? 'No hay reservas.';
  }

  /** Trae la agenda del periodo; una respuesta lenta de otro periodo no pisa la más reciente */
  async cargar(): Promise<void> {
    if (this.servicio.areas().length === 0) {
      this.items.set([]);
      return;
    }
    const consulta = ++this.ultimaConsulta;
    this.cargando.set(true);
    this.error.set(null);
    try {
      const zona = this.zona();
      const r = RANGOS.find(x => x.valor === this.rango())!;
      const dia = (desplazamiento: number) => fechaEnZona(Date.now() + desplazamiento * DIA_MS, zona);
      const desde = instanteEnZona(dia(r.desde), '00:00', zona);
      const hasta = instanteEnZona(dia(r.hasta), '00:00', zona);
      const lista = await this.servicio.calendario(this.areaId() || null, desde, hasta);
      if (consulta === this.ultimaConsulta) this.items.set(lista);
    } catch (err: any) {
      if (consulta !== this.ultimaConsulta) return;
      console.error('[ReservasCasetaComponent] Error al consultar las reservas:', err);
      this.items.set([]);
      this.error.set(mensajeConValidacion(err, 'No se pudieron consultar las reservas de las áreas comunes.'));
    } finally {
      if (consulta === this.ultimaConsulta) this.cargando.set(false);
    }
  }

  horas(o: ReservaCalendario): string {
    const zona = this.zona();
    const termina = horaEnZona(o.fin, zona);
    // Si cruza la medianoche se dice el día en que termina
    return fechaEnZona(o.inicio, zona) === fechaEnZona(o.fin, zona)
      ? `${horaEnZona(o.inicio, zona)} a ${termina}`
      : `${horaEnZona(o.inicio, zona)} a ${termina} (${diaLegible(o.fin, zona)})`;
  }

  titular(o: ReservaCalendario): string {
    return nombreCompleto(o.titularNombre, o.titularApellidos);
  }

  /** Para destacar lo que ocurre ahora y atenuar lo que ya pasó */
  estado(o: ReservaCalendario): 'en-curso' | 'terminada' | 'proxima' {
    const ahora = Date.now();
    if (new Date(o.fin).getTime() <= ahora) return 'terminada';
    return new Date(o.inicio).getTime() <= ahora ? 'en-curso' : 'proxima';
  }
}
