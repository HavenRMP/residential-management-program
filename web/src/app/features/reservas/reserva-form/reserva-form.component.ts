import { ChangeDetectionStrategy, Component, EventEmitter, Output, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { ReservasService } from '../../../core/services/reservas.service';
import { AreaComun, REGLAS_RESERVA, Reserva, ReservaCalendario, ocupaHorario } from '../../../core/models/reserva.model';
import {
  diaLegible,
  diasReservables,
  fechaEnZona,
  horaEnZona,
  instanteEnZona,
  minutosDelDia,
  problemaDeSolicitud,
  rangoLegible,
  recortarHora,
  segmentosDelDia
} from '../../../core/utils/reservas.util';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';

/** Un día después de una fecha yyyy-MM-dd, para pedir el calendario de un día completo */
function diaSiguiente(fecha: string): string {
  const [a, m, d] = fecha.split('-').map(Number);
  return new Date(Date.UTC(a, m - 1, d + 1)).toISOString().slice(0, 10);
}

@Component({
  selector: 'app-reserva-form',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="space-y-6">

      <p class="text-xs text-slate-600 leading-relaxed">
        Reglas: se reserva con <strong>{{ reglas.diasMinimos }} a {{ reglas.diasMaximos }} días</strong> de anticipación,
        por <strong>{{ reglas.minutosMinimos }} minutos a {{ reglas.horasMaximas }} horas</strong>, dentro del horario del área y
        <strong>una reserva por día</strong>. Un administrador revisa cada solicitud.
      </p>

      <!-- 1. Área -->
      <section aria-labelledby="paso-area" class="space-y-2.5">
        <h3 id="paso-area" class="text-sm font-semibold text-slate-900">1. Elige el área</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-2.5" role="radiogroup" aria-labelledby="paso-area">
          @for (a of reservasService.areas(); track a.id) {
            <button
              type="button"
              role="radio"
              [attr.aria-checked]="area()?.id === a.id"
              (click)="seleccionarArea(a)"
              class="text-left p-3.5 rounded-lg border transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
              [ngClass]="area()?.id === a.id ? 'border-[#111C99] bg-indigo-50/60 ring-1 ring-[#111C99]' : 'border-slate-200 bg-white hover:bg-slate-50'"
              >
              <p class="text-sm font-semibold text-slate-900">{{ a.nombre }}</p>
              @if (a.descripcion) {
                <p class="text-xs text-slate-600 mt-0.5">{{ a.descripcion }}</p>
              }
              <p class="text-[11px] font-medium text-slate-500 mt-1.5">Abierta de {{ hora(a.horaApertura) }} a {{ hora(a.horaCierre) }}</p>
            </button>
          }
        </div>
      </section>

      @if (area(); as a) {
        <!-- 2. Día -->
        <section aria-labelledby="paso-dia" class="space-y-2.5">
          <h3 id="paso-dia" class="text-sm font-semibold text-slate-900">2. Elige el día</h3>
          <div class="max-w-xs">
            <label for="res-fecha" class="block text-xs font-semibold text-slate-800 mb-1">Día de la reserva</label>
            <input
              id="res-fecha"
              type="date"
              [ngModel]="fecha()"
              (ngModelChange)="cambiarFecha($event)"
              [min]="dias().min"
              [max]="dias().max"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
            />
            <p class="mt-1 text-[11px] text-slate-500">Del {{ diaCorto(dias().min) }} al {{ diaCorto(dias().max) }}.</p>
          </div>
        </section>

        @if (fecha()) {
          <!-- 3. Disponibilidad -->
          <section aria-labelledby="paso-disponibilidad" class="space-y-2.5">
            <h3 id="paso-disponibilidad" class="text-sm font-semibold text-slate-900">3. Revisa la disponibilidad</h3>

            @if (cargandoDia()) {
              <div class="h-12 rounded-md bg-slate-100 animate-pulse" aria-busy="true"></div>
            } @else if (errorDia()) {
              <p class="p-3 rounded-md border border-rose-200 bg-rose-50 text-xs text-rose-700 font-medium" role="alert">
                {{ errorDia() }}
                <button type="button" (click)="cargarDia()" class="ml-2 underline cursor-pointer">Reintentar</button>
              </p>
            } @else {
              <div class="relative h-12 rounded-md border border-slate-200 bg-emerald-50/60 overflow-hidden" role="img" [attr.aria-label]="descripcionLinea()">
                @for (s of segmentos(); track $index) {
                  <div
                    class="absolute top-0 bottom-0 border-x border-white/60"
                    [style.left.%]="s.izquierda"
                    [style.width.%]="s.ancho"
                    [ngClass]="claseSegmento(s.tipo, s.pendiente)"
                    [attr.title]="s.detalle + ' · ' + s.etiqueta"
                  ></div>
                }
                @if (seleccion(); as sel) {
                  <div
                    class="absolute top-1 bottom-1 rounded-sm border-2 border-[#111C99] bg-[#111C99]/15"
                    [style.left.%]="sel.izquierda"
                    [style.width.%]="sel.ancho"
                  ></div>
                }
              </div>
              <div class="relative h-4 text-[10px] font-medium text-slate-500" aria-hidden="true">
                @for (m of marcas(); track m.etiqueta) {
                  <span class="absolute -translate-x-1/2" [style.left.%]="m.izquierda">{{ m.etiqueta }}</span>
                }
              </div>
              <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-[11px] text-slate-600">
                <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-sm bg-emerald-100 border border-emerald-200"></span>Libre</span>
                <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-sm bg-indigo-500"></span>Reservada</span>
                <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-sm bg-amber-300"></span>Por aprobar</span>
                <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-sm bg-slate-500"></span>Bloqueada</span>
                <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-sm border-2 border-[#111C99] bg-[#111C99]/15"></span>Tu horario</span>
              </div>
              @if (segmentos().length === 0) {
                <p class="text-xs text-slate-600">Ese día el área está libre en todo su horario.</p>
              } @else {
                <ul class="text-xs text-slate-700 space-y-0.5">
                  @for (s of segmentos(); track $index) {
                    <li><span class="font-semibold">{{ s.etiqueta }}</span> · {{ s.detalle }}{{ s.pendiente ? ' (por aprobar)' : '' }}</li>
                  }
                </ul>
              }
            }
          </section>

          <!-- 4. Horario -->
          <section aria-labelledby="paso-horario" class="space-y-2.5">
            <h3 id="paso-horario" class="text-sm font-semibold text-slate-900">4. Elige el horario</h3>
            <div class="grid grid-cols-2 gap-3 max-w-md">
              <div>
                <label for="res-inicio" class="block text-xs font-semibold text-slate-800 mb-1">Desde</label>
                <input
                  id="res-inicio"
                  type="time"
                  step="900"
                  [min]="hora(a.horaApertura)"
                  [max]="hora(a.horaCierre)"
                  [ngModel]="horaInicio()"
                  (ngModelChange)="horaInicio.set($event)"
                  class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
                />
              </div>
              <div>
                <label for="res-fin" class="block text-xs font-semibold text-slate-800 mb-1">Hasta</label>
                <input
                  id="res-fin"
                  type="time"
                  step="900"
                  [min]="hora(a.horaApertura)"
                  [max]="hora(a.horaCierre)"
                  [ngModel]="horaFin()"
                  (ngModelChange)="horaFin.set($event)"
                  class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
                />
              </div>
            </div>

            @if (problema(); as texto) {
              <p class="text-xs text-rose-700 font-medium" role="alert">{{ texto }}</p>
            } @else if (resumen(); as texto) {
              <p class="text-xs text-emerald-800 font-medium" role="status">{{ texto }}</p>
            }

            <div class="pt-1">
              <button
                type="button"
                (click)="solicitar()"
                [disabled]="enviando() || !valido()"
                class="h-9 px-4 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                >
                {{ enviando() ? 'Enviando...' : 'Solicitar reserva' }}
              </button>
            </div>
          </section>
        }
      }
    </div>
  `
})
export class ReservaFormComponent {
  readonly reservasService = inject(ReservasService);

  /** Se emite con la reserva recién creada para que la pantalla muestre "Mis reservas" */
  @Output() solicitada = new EventEmitter<Reserva>();

  readonly reglas = REGLAS_RESERVA;
  readonly areaElegida = signal<AreaComun | null>(null);
  readonly fecha = signal<string>('');
  readonly horaInicio = signal<string>('');
  readonly horaFin = signal<string>('');
  readonly ocupados = signal<ReservaCalendario[]>([]);
  readonly cargandoDia = signal<boolean>(false);
  readonly errorDia = signal<string | null>(null);
  readonly enviando = signal<boolean>(false);

  private ultimaConsultaDia = 0;

  /** Con una sola área no hay nada que elegir: se usa esa */
  readonly area = computed<AreaComun | null>(() => {
    const areas = this.reservasService.areas();
    return this.areaElegida() ?? (areas.length === 1 ? areas[0] : null);
  });

  readonly dias = computed(() => diasReservables(Date.now(), this.area()?.zonaHoraria ?? 'America/Mexico_City'));

  readonly segmentos = computed(() => {
    const a = this.area();
    return a && this.fecha() ? segmentosDelDia(this.fecha(), a, this.ocupados()) : [];
  });

  /** Marcas de hora cada 2 horas sobre el horario de operación */
  readonly marcas = computed(() => {
    const a = this.area();
    if (!a) return [];
    const apertura = minutosDelDia(a.horaApertura);
    const total = minutosDelDia(a.horaCierre) - apertura;
    if (total <= 0) return [];
    const marcas: { izquierda: number; etiqueta: string }[] = [];
    for (let min = apertura; min <= apertura + total; min += 120) {
      marcas.push({ izquierda: ((min - apertura) / total) * 100, etiqueta: `${String(Math.floor(min / 60)).padStart(2, '0')}:00` });
    }
    return marcas;
  });

  /** El horario que va escogiendo la persona, dibujado sobre la línea de tiempo */
  readonly seleccion = computed(() => {
    const a = this.area();
    if (!a || !this.horaInicio() || !this.horaFin()) return null;
    const apertura = minutosDelDia(a.horaApertura);
    const total = minutosDelDia(a.horaCierre) - apertura;
    const desde = Math.max(minutosDelDia(this.horaInicio()), apertura);
    const hasta = Math.min(minutosDelDia(this.horaFin()), apertura + total);
    return total > 0 && hasta > desde ? { izquierda: ((desde - apertura) / total) * 100, ancho: ((hasta - desde) / total) * 100 } : null;
  });

  /**
   * El backend permite una sola reserva viva por vivienda y por día, aunque sea en otra área.
   * Se avisa antes de enviar con las reservas de la persona que ya se conocen; si fue otra persona de la vivienda, lo dice el backend.
   */
  readonly reservaDelDia = computed(() => {
    const a = this.area();
    const fecha = this.fecha();
    if (!a || !fecha) return null;
    return this.reservasService.mias().find(r => r.tipo !== 'BLOQUEO' && ocupaHorario(r) && fechaEnZona(r.inicio, a.zonaHoraria) === fecha) ?? null;
  });

  readonly problema = computed(() => {
    const a = this.area();
    if (!a) return null;
    const regla = problemaDeSolicitud({ fecha: this.fecha(), horaInicio: this.horaInicio(), horaFin: this.horaFin() }, a, Date.now(), this.ocupados());
    if (regla) return regla;
    const previa = this.reservaDelDia();
    return previa
      ? `Tu vivienda ya tiene una reserva ese día (${previa.areaNombre}, ${horaEnZona(previa.inicio, a.zonaHoraria)} a ${horaEnZona(previa.fin, a.zonaHoraria)}). Solo se permite una por día.`
      : null;
  });

  readonly valido = computed(() => !!this.area() && !!this.fecha() && !!this.horaInicio() && !!this.horaFin() && this.problema() === null);

  readonly resumen = computed(() => {
    const a = this.area();
    if (!a || !this.valido()) return null;
    const inicio = instanteEnZona(this.fecha(), this.horaInicio(), a.zonaHoraria);
    const fin = instanteEnZona(this.fecha(), this.horaFin(), a.zonaHoraria);
    const minutos = (new Date(fin).getTime() - new Date(inicio).getTime()) / 60_000;
    const duracion = minutos % 60 === 0 ? `${minutos / 60} h` : `${Math.floor(minutos / 60)} h ${minutos % 60} min`;
    return `${a.nombre}: ${rangoLegible(inicio, fin, a.zonaHoraria)} (${duracion}).`;
  });

  readonly descripcionLinea = computed(() => {
    const segs = this.segmentos();
    return segs.length === 0
      ? 'Línea de tiempo del día: libre en todo el horario'
      : `Línea de tiempo del día con ${segs.length} horario(s) ocupado(s): ${segs.map(s => s.etiqueta).join(', ')}`;
  });

  /** "mar 20 oct 2026" para un día yyyy-MM-dd en la zona del área */
  diaCorto(fecha: string): string {
    const zona = this.area()?.zonaHoraria ?? 'America/Mexico_City';
    return diaLegible(instanteEnZona(fecha, '12:00', zona), zona);
  }

  hora(valor: string): string {
    return recortarHora(valor);
  }

  claseSegmento(tipo: 'RESERVA' | 'BLOQUEO', pendiente: boolean): string {
    if (tipo === 'BLOQUEO') return 'bg-slate-500';
    return pendiente ? 'bg-amber-300' : 'bg-indigo-500';
  }

  seleccionarArea(area: AreaComun): void {
    this.areaElegida.set(area);
    this.horaInicio.set('');
    this.horaFin.set('');
    void this.cargarDia();
  }

  cambiarFecha(fecha: string): void {
    this.fecha.set(fecha);
    void this.cargarDia();
  }

  /** Trae lo que ya ocupa el área ese día; una respuesta lenta de otra fecha no pisa la actual */
  async cargarDia(): Promise<void> {
    const a = this.area();
    const fecha = this.fecha();
    if (!a || !fecha) {
      this.ocupados.set([]);
      return;
    }
    const consulta = ++this.ultimaConsultaDia;
    this.cargandoDia.set(true);
    this.errorDia.set(null);
    try {
      const desde = instanteEnZona(fecha, '00:00', a.zonaHoraria);
      const hasta = instanteEnZona(diaSiguiente(fecha), '00:00', a.zonaHoraria);
      const lista = await this.reservasService.calendario(a.id, desde, hasta);
      if (consulta === this.ultimaConsultaDia) this.ocupados.set(lista);
    } catch (err: any) {
      if (consulta !== this.ultimaConsultaDia) return;
      console.error('[ReservaFormComponent] Error al consultar la disponibilidad:', err);
      this.ocupados.set([]);
      this.errorDia.set(mensajeConValidacion(err, 'No se pudo consultar la disponibilidad de ese día.'));
    } finally {
      if (consulta === this.ultimaConsultaDia) this.cargandoDia.set(false);
    }
  }

  async solicitar(): Promise<void> {
    const a = this.area();
    if (!a || !this.valido() || this.enviando()) return;

    this.enviando.set(true);
    try {
      const creada = await this.reservasService.solicitar({
        areaId: a.id,
        inicio: instanteEnZona(this.fecha(), this.horaInicio(), a.zonaHoraria),
        fin: instanteEnZona(this.fecha(), this.horaFin(), a.zonaHoraria)
      });
      Swal.fire({
        toast: true,
        position: 'top-end',
        icon: 'success',
        title: creada.estado === 'PENDIENTE_TITULAR' ? 'Solicitud enviada al titular de tu vivienda' : 'Solicitud enviada al administrador',
        showConfirmButton: false,
        timer: 3500
      });
      this.horaInicio.set('');
      this.horaFin.set('');
      void this.cargarDia();
      this.solicitada.emit(creada);
    } catch (err: any) {
      console.error('[ReservaFormComponent] Error al solicitar la reserva:', err);
      Swal.fire({
        icon: 'error',
        title: 'No se pudo solicitar la reserva',
        text: mensajeConValidacion(err, 'No fue posible enviar la solicitud. Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#111C99'
      });
      // Un choque o un cambio de reglas suele significar que el día cambió: se actualiza la disponibilidad
      if (err?.status === 409) void this.cargarDia();
    } finally {
      this.enviando.set(false);
    }
  }
}
