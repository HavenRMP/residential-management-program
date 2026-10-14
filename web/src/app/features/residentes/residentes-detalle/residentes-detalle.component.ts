import Swal from 'sweetalert2';
import { Component, Input, Output, EventEmitter, HostListener, inject, OnChanges, SimpleChanges, signal, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { Residente } from '../../../core/models/residente.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { SubusuariosService } from '../../../core/services/subusuarios.service';
import { SubUsuarioItem } from '../../../core/models/subusuario.model';
import { getInitials } from '../../../core/utils/iniciales.util';
import { formatearNumeroCasa } from '../../../core/utils/vivienda.util';
import { mensajeAmigable } from '../../../core/utils/api-errors.util';

interface GrupoSubusuarios {
  viviendaId: number;
  numeroCasa: string;
  items: SubUsuarioItem[];
  cargando: boolean;
  error: boolean;
}

@Component({
  selector: 'app-residentes-detalle',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.Eager,
  imports: [CommonModule, DatePipe],
  template: `
    <!-- Sticky Drawer Top Bar -->
    <div class="sticky top-0 z-10 bg-white/95 backdrop-blur-md px-6 py-4 border-b border-slate-100 flex items-center justify-between">
      <div class="flex items-center gap-2.5">
        <div class="w-8 h-8 rounded-lg bg-[#111C99] text-white flex items-center justify-center font-bold text-xs shadow-2xs">
          {{ getInitials(residente?.nombre, residente?.apellidos) }}
        </div>
        <span id="detalle-residente-title" class="text-sm font-bold text-slate-900 tracking-tight">Detalle del Residente</span>
      </div>
    
      <!-- Close Button -->
      <button
        type="button"
        (click)="cerrar()"
        class="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-all cursor-pointer focus:outline-none focus:ring-2 focus:ring-[#111C99]/20"
        aria-label="Cerrar detalle del residente"
        title="Cerrar detalle (Esc)"
        >
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    
    <div class="p-4 sm:p-6 space-y-6 flex-1 flex flex-col justify-between">
      <div class="space-y-5">
        <!-- Hero Profile -->
        <div class="flex flex-col items-center text-center">
          <div class="w-20 h-20 sm:w-24 sm:h-24 rounded-full bg-[#111C99] text-white font-bold text-2xl sm:text-3xl flex items-center justify-center shadow-md ring-4 ring-slate-100">
            {{ getInitials(residente?.nombre, residente?.apellidos) }}
          </div>
          <h2 class="text-xl sm:text-2xl font-extrabold text-slate-900 mt-4 tracking-tight">
            {{ residente?.nombre }} {{ residente?.apellidos }}
          </h2>
          <div class="mt-2">
            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
              Residente Haven
            </span>
          </div>
        </div>
    
        <!-- Viviendas Asignadas -->
        <div class="bg-white border border-slate-200/80 rounded-xl p-4 sm:p-5 shadow-xs space-y-3">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <div class="w-7 h-7 rounded-lg bg-indigo-50 text-indigo-700 flex items-center justify-center border border-indigo-100">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
              </div>
              <h3 class="text-xs font-bold text-slate-900 uppercase tracking-wider">
                Vivienda{{ viviendasAsignadas().length > 1 ? 's' : '' }} Asignada{{ viviendasAsignadas().length > 1 ? 's' : '' }}
              </h3>
            </div>
    
            @if (!cargandoViviendas()) {
              <span
                class="text-[11px] font-semibold px-2.5 py-0.5 rounded-full"
                [ngClass]="claseEtiquetaViviendas()"
                >
                {{ etiquetaViviendas() }}
              </span>
            }
          </div>
    
          <!-- Spinner durante carga reactiva -->
          @if (cargandoViviendas()) {
            <div class="flex items-center gap-2 py-3 justify-center text-xs text-slate-500 font-medium">
              <div class="w-4 h-4 border-2 border-slate-200 border-t-indigo-700 rounded-full animate-spin"></div>
              <span>Consultando viviendas...</span>
            </div>
          }
    
          <!-- Una tarjeta por vivienda, con sus sub-usuarios adentro -->
          @if (!cargandoViviendas() && viviendasAsignadas().length > 0) {
            <div class="space-y-3 pt-1">
              @for (v of viviendasAsignadas(); track v.id) {
                @let grupo = grupoDe(v.id);
                <section
                  class="rounded-lg bg-slate-50/80 border border-slate-200 overflow-hidden"
                  [attr.aria-label]="formatearNumeroCasa(v.numeroCasa) + ' y sus sub-usuarios'"
                  >
                  <div class="flex flex-wrap items-center justify-between gap-x-3 gap-y-2 p-3">
                    <div class="flex items-center gap-3">
                      <div class="w-8 h-8 shrink-0 rounded-lg bg-white border border-slate-200 text-indigo-700 flex items-center justify-center font-bold text-xs shadow-2xs">
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                        </svg>
                      </div>
                      <div class="min-w-0">
                        <p class="text-sm font-bold text-slate-900">{{ formatearNumeroCasa(v.numeroCasa) }}</p>
                        <p class="text-[11px] text-slate-600 font-medium">Tipo: {{ v.tipo || 'Residencial' }}</p>
                      </div>
                    </div>
                    <div class="flex items-center gap-2 shrink-0">
                      <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                        <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                        Asignada
                      </span>
                      <button
                        type="button"
                        (click)="confirmarDesvinculacion(v)"
                        [disabled]="desvinculando() !== null"
                        [attr.aria-label]="'Desvincular a ' + residente?.nombre + ' de ' + formatearNumeroCasa(v.numeroCasa)"
                        title="Quitar la asignación de esta vivienda (la cuenta no se borra)"
                        class="h-7 px-2.5 text-[11px] font-semibold rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-rose-300"
                      >
                        {{ desvinculando() === v.id ? 'Desvinculando...' : 'Desvincular' }}
                      </button>
                    </div>
                  </div>

                  <!-- Sub-usuarios de esta casa -->
                  <div class="border-t border-slate-200 bg-white px-3 py-2.5 space-y-2">
                    <div class="flex items-center justify-between gap-2">
                      <h4 class="text-[11px] font-bold text-slate-700 uppercase tracking-wide">Sub-usuarios</h4>
                      @if (grupo && !grupo.cargando && !grupo.error) {
                        <span class="text-[11px] font-medium text-slate-500">{{ grupo.items.length }} de {{ maxSubusuarios }}</span>
                      }
                    </div>
                    @if (!grupo || grupo.cargando) {
                      <div class="flex items-center gap-2 py-1 text-[11px] text-slate-500 font-medium" aria-busy="true">
                        <div class="w-3.5 h-3.5 border-2 border-slate-200 border-t-indigo-700 rounded-full animate-spin"></div>
                        <span>Consultando sub-usuarios...</span>
                      </div>
                    } @else if (grupo.error) {
                      <p class="p-2.5 rounded-md bg-amber-50/70 border border-amber-200 text-[11px] text-amber-900">
                        No se pudieron cargar los sub-usuarios de esta vivienda.
                      </p>
                    } @else if (grupo.items.length === 0) {
                      <p class="text-[11px] text-slate-500">Esta vivienda no tiene sub-usuarios.</p>
                    } @else {
                      <ul class="space-y-1.5">
                        @for (u of grupo.items; track u.id) {
                          <li
                            class="flex items-center justify-between gap-3 p-2.5 rounded-md border"
                            [ngClass]="u.activo ? 'border-slate-200 bg-slate-50/80' : 'border-dashed border-amber-300 bg-amber-50/40'"
                          >
                            <div class="min-w-0">
                              <p class="text-sm font-bold text-slate-900 truncate">{{ u.activo ? u.nombre : (u.email || 'Invitación sin correo') }}</p>
                              <p class="text-[11px] text-slate-600 font-medium truncate">
                                {{ u.activo ? (u.email || u.telefono || 'Sin contacto') : 'Aún no acepta la invitación' }}
                              </p>
                            </div>
                            <div class="shrink-0 flex flex-col items-end gap-1">
                              <span class="px-2 py-0.5 rounded text-[10px] font-medium border bg-slate-100 text-slate-600 border-slate-200">{{ u.parentesco }}</span>
                              <span
                                class="px-2 py-0.5 rounded text-[10px] font-medium border"
                                [ngClass]="u.activo ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-amber-50 text-amber-700 border-amber-200'"
                              >{{ u.activo ? 'Activo' : 'Invitación pendiente' }}</span>
                            </div>
                          </li>
                        }
                      </ul>
                    }
                  </div>
                </section>
              }
            </div>
          }

          <!-- Estado vacío: Sin vivienda -->
          @if (!cargandoViviendas() && viviendasAsignadas().length === 0 && subusuarioDe.length === 0) {
            <div class="p-3 rounded-lg bg-amber-50/70 border border-amber-200 text-xs text-amber-900 space-y-1">
              <div class="flex items-center gap-1.5 font-semibold text-amber-900">
                <span class="w-2 h-2 rounded-full bg-amber-500"></span>
                <span>Sin vivienda vinculada</span>
              </div>
              <p class="text-amber-800 text-[11px] leading-relaxed">
                Este residente está registrado en el condominio pero aún no tiene una vivienda asignada.
              </p>
            </div>
          }
        </div>
    
        <!-- Casas a las que entra como sub-usuario (no es titular) -->
        @if (!cargandoViviendas() && subusuarioDe.length > 0) {
          <div class="bg-white border border-slate-200/80 rounded-xl p-4 sm:p-5 shadow-xs space-y-3" aria-labelledby="detalle-acceso-subusuario">
            <div class="flex items-center gap-2">
              <div class="w-7 h-7 rounded-lg bg-sky-50 text-sky-700 flex items-center justify-center border border-sky-100">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a3 3 0 11-6 0 3 3 0 016 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
              </div>
              <h3 id="detalle-acceso-subusuario" class="text-xs font-bold text-slate-900 uppercase tracking-wider">Acceso como sub-usuario</h3>
            </div>
            <p class="text-[11px] text-slate-600 leading-relaxed">Entra a la vivienda de otro residente. No es el titular de la casa.</p>
            <ul class="space-y-2">
              @for (v of subusuarioDe; track v.id) {
                <li class="flex items-center justify-between p-3 rounded-lg bg-slate-50/80 border border-slate-200">
                  <div>
                    <p class="text-sm font-bold text-slate-900">{{ formatearNumeroCasa(v.numeroCasa) }}</p>
                    <p class="text-[11px] text-slate-600 font-medium">Tipo: {{ v.tipo || 'Residencial' }}</p>
                  </div>
                  <span class="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-sky-50 text-sky-700 border border-sky-200">Sub-usuario</span>
                </li>
              }
            </ul>
          </div>
        }

        <!-- Información de Contacto -->
        <div class="bg-white border border-slate-200/80 rounded-xl p-4 sm:p-5 shadow-xs divide-y divide-slate-100">
          <!-- Correo Electrónico -->
          <div class="pb-4">
            <span class="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5">
              Correo Electrónico
            </span>
            <div class="flex items-center gap-2.5 text-sm font-semibold text-slate-800">
              <svg class="w-4 h-4 text-[#111C99] shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              <span class="break-all">{{ residente?.email || '—' }}</span>
            </div>
          </div>
    
          <!-- Teléfono -->
          <div class="py-4">
            <span class="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5">
              Teléfono
            </span>
            <div class="flex items-center gap-2.5 text-sm font-semibold text-slate-800">
              <svg class="w-4 h-4 text-[#111C99] shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
              </svg>
              <span>{{ residente?.telefono || '—' }}</span>
            </div>
          </div>
    
          <!-- Fecha de Alta -->
          <div class="pt-4">
            <span class="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5">
              Fecha de Alta
            </span>
            <div class="flex items-center gap-2.5 text-sm font-semibold text-slate-800">
              <svg class="w-4 h-4 text-[#111C99] shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <span>{{ residente?.creadoEn ? (residente?.creadoEn | date:'dd/MM/yyyy') : '—' }}</span>
            </div>
          </div>
        </div>
      </div>
    
      <!-- ID de Usuario (Soporte Admin) -->
      <div class="pt-6 border-t border-slate-100 flex items-center justify-between text-xs text-slate-400">
        <span class="font-medium">ID de referencia:</span>
        <span class="font-mono bg-slate-100 px-2 py-1 rounded-md text-slate-600 select-all">{{ residente?.id || '—' }}</span>
      </div>
    </div>
    `
})
export class ResidentesDetalleComponent implements OnChanges {
  @Input() residente: Residente | null = null;
  @Input() viviendas: Vivienda[] = [];
  /** Viviendas a las que esta persona entra como sub-usuario activo (no las tiene a su nombre) */
  @Input() subusuarioDe: Vivienda[] = [];
  @Output() cerrado = new EventEmitter<void>();
  /** Se quitó una vivienda a este residente: el padre debe refrescar su lista */
  @Output() desvinculado = new EventEmitter<void>();

  private readonly viviendasService = inject(ViviendasService);
  private readonly subusuariosService = inject(SubusuariosService);

  readonly cargandoViviendas = signal<boolean>(false);
  /** Id de la vivienda que se está desvinculando; bloquea los botones mientras tanto */
  readonly desvinculando = signal<number | null>(null);
  readonly viviendasAsignadas = signal<Vivienda[]>([]);
  readonly gruposSubusuarios = signal<GrupoSubusuarios[]>([]);
  /** Cuántos sub-usuarios admite cada vivienda (activos más invitaciones pendientes) */
  readonly maxSubusuarios = this.subusuariosService.MAX_SUBUSUARIOS;
  /** Evita que la respuesta lenta de un residente anterior pise la del que se abrió después */
  private consultaSubusuarios = 0;
  /** Viviendas (por id) de las que ya se pidieron sub-usuarios: el padre puede mandar una lista nueva con lo mismo en cada ciclo */
  private viviendasConsultadas = '';
  readonly getInitials = getInitials;
  readonly formatearNumeroCasa = formatearNumeroCasa;

  @HostListener('window:keydown.escape')
  handleEscape(): void {
    this.cerrar();
  }

  async ngOnChanges(changes: SimpleChanges): Promise<void> {
    if (changes['viviendas']) {
      this.viviendasAsignadas.set(this.viviendas || []);
      void this.cargarSubusuarios();
    }

    if (changes['residente'] && this.residente) {
      // Si el componente padre ya suministró las viviendas (incluso si la lista está vacía []),
      // confiamos en ella y evitamos disparar una petición de red redundante.
      if (this.viviendas !== undefined && this.viviendas !== null) {
        this.viviendasAsignadas.set(this.viviendas);
        void this.cargarSubusuarios();
      } else {
        await this.cargarViviendasResidente();
      }
    }
  }

  async cargarViviendasResidente(): Promise<void> {
    if (!this.residente || !this.residente.id) {
      this.viviendasAsignadas.set([]);
      return;
    }

    this.cargandoViviendas.set(true);
    try {
      const list = await this.viviendasService.obtenerViviendasDeResidente(this.residente.id);
      this.viviendasAsignadas.set(list);
      void this.cargarSubusuarios();
    } catch {
      this.viviendasAsignadas.set([]);
    } finally {
      this.cargandoViviendas.set(false);
    }
  }

  /** Quita la asignación de una vivienda a este residente. La cuenta no se borra. */
  async confirmarDesvinculacion(vivienda: Vivienda): Promise<void> {
    if (!this.residente || this.desvinculando() !== null) return;
    const residente = this.residente;
    const casa = formatearNumeroCasa(vivienda.numeroCasa);

    const confirmacion = await Swal.fire({
      title: '¿Desvincular de esta vivienda?',
      text: `Se retirará a ${residente.nombre} ${residente.apellidos} de la ${casa}. Su cuenta no se borra.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Sí, desvincular',
      cancelButtonText: 'Cancelar',
      confirmButtonColor: '#e11d48',
      cancelButtonColor: '#64748b'
    });
    if (!confirmacion.isConfirmed) return;

    this.desvinculando.set(vivienda.id);
    try {
      await this.viviendasService.desvincularResidente(vivienda.id, residente.id);
      this.viviendasAsignadas.update(lista => lista.filter(v => v.id !== vivienda.id));
      void this.cargarSubusuarios();
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: `Desvinculado de la ${casa}`, showConfirmButton: false, timer: 2500 });
      this.desvinculado.emit();
    } catch (err: any) {
      console.error('[ResidentesDetalleComponent] Error al desvincular:', err);
      Swal.fire({
        icon: 'error',
        title: 'No se pudo desvincular',
        text: mensajeAmigable(err, 'No fue posible quitar la vivienda. Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#0F172A'
      });
    } finally {
      this.desvinculando.set(null);
    }
  }

  /** Pide los sub-usuarios de cada vivienda asignada; el fallo de una no afecta a las demás */
  async cargarSubusuarios(): Promise<void> {
    const viviendas = this.viviendasAsignadas();
    const clave = viviendas.map(v => v.id).join(',');
    if (clave === this.viviendasConsultadas) return;
    this.viviendasConsultadas = clave;

    const consulta = ++this.consultaSubusuarios;
    this.gruposSubusuarios.set(viviendas.map(v => ({ viviendaId: v.id, numeroCasa: v.numeroCasa, items: [], cargando: true, error: false })));

    const grupos = await Promise.all(viviendas.map(async (v): Promise<GrupoSubusuarios> => {
      try {
        return { viviendaId: v.id, numeroCasa: v.numeroCasa, items: await this.subusuariosService.listarPorVivienda(v.id), cargando: false, error: false };
      } catch (err) {
        console.error('[ResidentesDetalleComponent] Error al cargar sub-usuarios:', err);
        return { viviendaId: v.id, numeroCasa: v.numeroCasa, items: [], cargando: false, error: true };
      }
    }));
    if (consulta === this.consultaSubusuarios) this.gruposSubusuarios.set(grupos);
  }

  /** Sub-usuarios consultados de una vivienda; undefined mientras aún no se pide */
  grupoDe(viviendaId: number): GrupoSubusuarios | undefined {
    return this.gruposSubusuarios().find(g => g.viviendaId === viviendaId);
  }

  etiquetaViviendas(): string {
    const propias = this.viviendasAsignadas().length;
    if (propias > 0) return propias === 1 ? '1 vivienda' : `${propias} viviendas`;
    return this.subusuarioDe.length > 0 ? 'Sub-usuario' : 'Sin vivienda';
  }

  claseEtiquetaViviendas(): string {
    if (this.viviendasAsignadas().length > 0) return 'bg-indigo-50 text-indigo-700 border border-indigo-200';
    return this.subusuarioDe.length > 0
      ? 'bg-sky-50 text-sky-700 border border-sky-200'
      : 'bg-amber-50 text-amber-800 border border-amber-200';
  }

  cerrar(): void {
    this.cerrado.emit();
  }
}

