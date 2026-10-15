import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { AuthService } from '../../core/services/auth.service';
import { ViviendasService } from '../../core/services/viviendas.service';
import { ReservasService } from '../../core/services/reservas.service';
import {
  CLASES_ESTADO_RESERVA,
  ETIQUETAS_ESTADO_RESERVA,
  PendienteTitular,
  REGLAS_RESERVA,
  Reserva,
  nombreCompleto,
  normalizarEstado,
  estadoMostrado,
  reservaEsCancelable,
  reservaEsConfirmable,
  reservaEstaConfirmada
} from '../../core/models/reserva.model';
import { diaLegible, rangoLegible } from '../../core/utils/reservas.util';
import { mensajeConValidacion } from '../../core/utils/api-errors.util';
import { Vivienda } from '../../core/models/vivienda.model';
import { UserMenuComponent } from '../../core/components/user-menu/user-menu.component';
import { ReservaFormComponent } from './reserva-form/reserva-form.component';

type Pestana = 'reservar' | 'mias';
type Vista = 'proximas' | 'historial';

const DIA_MS = 86_400_000;
const HORA_MS = 3_600_000;

@Component({
  selector: 'app-reservas',
  standalone: true,
  imports: [CommonModule, RouterLink, UserMenuComponent, ReservaFormComponent],
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
              <span class="font-bold text-base tracking-tight text-slate-900">Reservas</span>
              <span class="text-[11px] font-medium px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 border border-slate-200">Áreas comunes</span>
            </div>
          </div>
          <app-user-menu [user]="currentUser()" (logout)="onLogout()" />
        </div>
      </header>

      <main class="w-full px-4 sm:px-6 lg:px-8 py-6 space-y-6">

        <nav aria-label="Ruta de navegación" class="flex items-center gap-2 text-xs text-slate-600 font-medium">
          <a routerLink="/dashboard/residente" class="hover:text-slate-900 transition-colors">Portal</a>
          <span>/</span>
          <span class="text-slate-900">Reservas</span>
        </nav>
        <h1 class="sr-only">Reservas</h1>

        @if (!isLoadingVivienda() && viviendas().length === 0) {
          <div class="rounded-lg border border-slate-200 bg-white p-8 text-center shadow-2xs space-y-2">
            <h2 class="text-base font-semibold text-slate-900">Necesitas una vivienda asignada</h2>
            <p class="text-xs text-slate-500 max-w-md mx-auto">Vincula tu cuenta a una vivienda desde el portal para poder reservar áreas comunes.</p>
            <a routerLink="/dashboard/residente" class="h-8 px-4 inline-flex items-center justify-center rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs mt-2">
              Volver al portal
            </a>
          </div>
        }

        @if (viviendas().length > 0) {

          <!-- Solicitudes de sub-usuarios que el titular debe resolver -->
          @if (reservasService.porAprobar().length > 0) {
            <section class="rounded-lg border border-amber-200 bg-amber-50/70 p-4 space-y-3" aria-labelledby="por-aprobar-titulo">
              <div>
                <h2 id="por-aprobar-titulo" class="text-sm font-semibold text-amber-900">
                  {{ reservasService.porAprobar().length === 1 ? 'Una solicitud espera tu aprobación' : reservasService.porAprobar().length + ' solicitudes esperan tu aprobación' }}
                </h2>
                <p class="text-xs text-amber-800 mt-0.5">Las pidieron sub-usuarios de tu vivienda. Si las apruebas, pasan al administrador.</p>
              </div>
              <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2.5">
                @for (p of reservasService.porAprobar(); track p.id) {
                  <li class="p-3.5 rounded-md border border-amber-200 bg-white space-y-2">
                    <div>
                      <p class="text-sm font-semibold text-slate-900">{{ p.areaNombre }}</p>
                      <p class="text-xs text-slate-600">{{ rango(p) }}</p>
                    </div>
                    <p class="text-xs text-slate-600">
                      Pide <strong class="text-slate-900">{{ nombre(p.solicitanteNombre, p.solicitanteApellidos) }}</strong>
                      ({{ p.parentesco }}) · {{ p.solicitanteEmail }}
                    </p>
                    <div class="flex items-center gap-2">
                      <button
                        type="button"
                        (click)="aprobarSolicitud(p)"
                        [disabled]="resolviendo() !== null"
                        class="h-8 px-3 rounded-md bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-medium transition-colors cursor-pointer disabled:opacity-50"
                        >
                        {{ resolviendo() === p.id ? 'Procesando...' : 'Aprobar' }}
                      </button>
                      <button
                        type="button"
                        (click)="rechazarSolicitud(p)"
                        [disabled]="resolviendo() !== null"
                        class="h-8 px-3 rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 text-xs font-medium transition-colors cursor-pointer disabled:opacity-50"
                        >
                        Rechazar
                      </button>
                    </div>
                  </li>
                }
              </ul>
            </section>
          }

          <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-5">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
              <div>
                <h2 class="text-sm font-semibold text-slate-900">Reservas de áreas comunes</h2>
                <p class="text-xs text-slate-500 mt-0.5">Reserva el salón, la alberca y otras áreas, y da seguimiento a tus solicitudes.</p>
              </div>
              <div class="flex items-center gap-1.5" role="tablist" aria-label="Reservas">
                <button
                  type="button"
                  role="tab"
                  [attr.aria-selected]="pestana() === 'reservar'"
                  (click)="pestana.set('reservar')"
                  class="h-8 px-3 rounded-md text-xs font-medium border transition-colors cursor-pointer"
                  [ngClass]="pestana() === 'reservar' ? 'bg-slate-900 text-white border-slate-900' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'"
                  >
                  Reservar
                </button>
                <button
                  type="button"
                  role="tab"
                  [attr.aria-selected]="pestana() === 'mias'"
                  (click)="pestana.set('mias')"
                  class="h-8 px-3 rounded-md text-xs font-medium border transition-colors cursor-pointer"
                  [ngClass]="pestana() === 'mias' ? 'bg-slate-900 text-white border-slate-900' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'"
                  >
                  Mis reservas @if (mostrarConteos()) {({{ reservasService.proximas().length }})}
                </button>
              </div>
            </div>

            <!-- Reservar -->
            @if (pestana() === 'reservar') {
              @if (reservasService.isLoadingAreas() && reservasService.areas().length === 0) {
                <div class="space-y-2" aria-busy="true">
                  @for (s of [1, 2]; track s) {
                    <div class="h-16 rounded-md bg-slate-100 animate-pulse"></div>
                  }
                </div>
              } @else if (reservasService.errorAreas()) {
                <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
                  <span>{{ reservasService.errorAreas() }}</span>
                  <button type="button" (click)="reservasService.cargarAreas()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">Reintentar</button>
                </div>
              } @else if (reservasService.areas().length === 0) {
                <div class="py-10 text-center text-xs text-slate-500 font-medium space-y-1">
                  <p>Tu condominio aún no tiene áreas comunes para reservar.</p>
                  <p class="text-slate-400">Cuando el administrador las dé de alta, aparecerán aquí.</p>
                </div>
              } @else {
                <app-reserva-form (solicitada)="alSolicitar()" />
              }
            }

            <!-- Mis reservas -->
            @if (pestana() === 'mias') {
              <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div class="flex items-center gap-1.5" role="tablist" aria-label="Filtrar mis reservas">
                  <button type="button" role="tab" [attr.aria-selected]="vista() === 'proximas'" (click)="vista.set('proximas')"
                    class="h-7 px-2.5 rounded-md text-xs font-medium border transition-colors cursor-pointer"
                    [ngClass]="vista() === 'proximas' ? 'bg-indigo-50 text-indigo-800 border-indigo-200' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'">
                    Próximas @if (mostrarConteos()) {({{ reservasService.proximas().length }})}
                  </button>
                  <button type="button" role="tab" [attr.aria-selected]="vista() === 'historial'" (click)="vista.set('historial')"
                    class="h-7 px-2.5 rounded-md text-xs font-medium border transition-colors cursor-pointer"
                    [ngClass]="vista() === 'historial' ? 'bg-indigo-50 text-indigo-800 border-indigo-200' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'">
                    Historial @if (mostrarConteos()) {({{ reservasService.historial().length }})}
                  </button>
                </div>
                <button type="button" (click)="recargar()" [disabled]="reservasService.isLoading()"
                  class="h-7 px-2.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors cursor-pointer disabled:opacity-50 self-start sm:self-auto">
                  Actualizar
                </button>
              </div>

              @if (reservasService.isLoading() && reservasService.mias().length === 0) {
                <div class="space-y-2" aria-busy="true">
                  @for (s of [1, 2]; track s) {
                    <div class="p-4 rounded-md bg-white border border-slate-200 animate-pulse h-20"></div>
                  }
                </div>
              }

              @if (reservasService.errorMessage(); as msg) {
                <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
                  <span>{{ msg }}</span>
                  <button type="button" (click)="recargar()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">Reintentar</button>
                </div>
              }

              @if (!reservasService.isLoading() && !reservasService.errorMessage() && lista().length === 0) {
                <div class="py-10 text-center text-xs text-slate-500 font-medium space-y-1">
                  @if (vista() === 'proximas') {
                    <p>No tienes reservas próximas.</p>
                    <button type="button" (click)="pestana.set('reservar')" class="mt-2 h-8 px-3 inline-flex items-center rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer">
                      Reservar un área
                    </button>
                  } @else {
                    <p>Todavía no hay reservas en tu historial.</p>
                    <p class="text-slate-400">Aquí quedan las terminadas, canceladas y rechazadas.</p>
                  }
                </div>
              }

              @if (lista().length > 0) {
                <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2.5 items-start">
                  @for (r of lista(); track r.id) {
                    <li class="p-4 rounded-md border bg-white space-y-1.5" [ngClass]="esConfirmable(r) ? 'border-emerald-300' : 'border-slate-200'">
                      <div class="flex flex-wrap items-center gap-2">
                        <p class="text-sm font-semibold text-slate-900">{{ r.areaNombre }}</p>
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="claseEstado(r)">{{ etiquetaEstado(r) }}</span>
                        @if (viviendas().length > 1 && r.numeroCasa) {
                          <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">Casa {{ r.numeroCasa }}</span>
                        }
                      </div>
                      <p class="text-xs text-slate-700 font-medium">{{ rango(r) }}</p>
                      @if (solicitadaPorOtro(r)) {
                        <p class="text-xs text-slate-600">Solicitada por {{ nombre(r.solicitanteNombre, r.solicitanteApellidos) }}</p>
                      }
                      @if (r.motivo) {
                        <p class="text-xs text-slate-500 italic">Motivo: {{ r.motivo }}</p>
                      }
                      @if (estaConfirmada(r)) {
                        <p class="text-xs text-emerald-700">Asistencia confirmada.</p>
                      }
                      @if (avisoConfirmacion(r); as aviso) {
                        <p class="text-xs text-slate-600">{{ aviso }}</p>
                      }
                      @if (esConfirmable(r) || esCancelable(r)) {
                        <div class="flex flex-wrap items-center gap-1.5 pt-1">
                          @if (esConfirmable(r)) {
                            <button type="button" (click)="confirmarAsistencia(r)" [disabled]="resolviendo() !== null"
                              [attr.aria-label]="'Confirmar asistencia a ' + r.areaNombre"
                              class="h-7 px-2.5 text-[11px] font-medium rounded-md bg-emerald-600 hover:bg-emerald-700 text-white transition-colors cursor-pointer disabled:opacity-50">
                              {{ resolviendo() === r.id ? 'Procesando...' : 'Confirmar asistencia' }}
                            </button>
                          }
                          @if (esCancelable(r)) {
                            <button type="button" (click)="cancelarReserva(r)" [disabled]="resolviendo() !== null"
                              [attr.aria-label]="'Cancelar la reserva de ' + r.areaNombre"
                              class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50">
                              Cancelar
                            </button>
                          }
                        </div>
                      }
                    </li>
                  }
                </ul>
              }
            }
          </section>
        }
      </main>
    </div>
  `
})
export class ReservasComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly viviendasService = inject(ViviendasService);
  readonly reservasService = inject(ReservasService);

  readonly currentUser = this.authService.currentUser;
  readonly isLoadingVivienda = signal<boolean>(true);
  readonly viviendas = signal<Vivienda[]>([]);
  readonly pestana = signal<Pestana>('reservar');
  readonly vista = signal<Vista>('proximas');
  /** Id de la reserva o solicitud que se está resolviendo; bloquea los botones mientras tanto */
  readonly resolviendo = signal<string | null>(null);

  readonly lista = computed(() => (this.vista() === 'proximas' ? this.reservasService.proximas() : this.reservasService.historial()));
  /** Mientras llegan los primeros datos los contadores dirían "(0)" sin ser cierto, así que se ocultan */
  readonly mostrarConteos = computed(() => !(this.reservasService.isLoading() && this.reservasService.mias().length === 0));

  async ngOnInit(): Promise<void> {
    this.isLoadingVivienda.set(true);
    try {
      this.viviendas.set(await this.viviendasService.obtenerMisViviendas());
      if (this.viviendas().length > 0) {
        void this.reservasService.cargarAreas();
        void this.reservasService.cargarPorAprobar();
        await this.reservasService.cargarMias();
      }
    } finally {
      this.isLoadingVivienda.set(false);
    }
  }

  onLogout(): void {
    this.authService.logout();
  }

  async recargar(): Promise<void> {
    await Promise.all([this.reservasService.cargarMias(), this.reservasService.cargarPorAprobar()]);
  }

  /** La reserva recién pedida es una próxima: se muestra ahí */
  alSolicitar(): void {
    this.vista.set('proximas');
    this.pestana.set('mias');
  }

  private zonaDe(areaId: string): string {
    return this.reservasService.areas().find(a => a.id === areaId)?.zonaHoraria ?? Intl.DateTimeFormat().resolvedOptions().timeZone;
  }

  rango(r: { areaId: string; inicio: string; fin: string }): string {
    return rangoLegible(r.inicio, r.fin, this.zonaDe(r.areaId));
  }

  nombre(nombre?: string | null, apellidos?: string | null): string {
    return nombreCompleto(nombre, apellidos) || 'Sin nombre';
  }

  etiquetaEstado(r: Reserva): string {
    return ETIQUETAS_ESTADO_RESERVA[estadoMostrado(r)] ?? r.estado;
  }

  claseEstado(r: Reserva): string {
    return CLASES_ESTADO_RESERVA[estadoMostrado(r)] ?? 'bg-slate-100 text-slate-700 border-slate-200';
  }

  esConfirmable(r: Reserva): boolean {
    return reservaEsConfirmable(r);
  }

  esCancelable(r: Reserva): boolean {
    return reservaEsCancelable(r);
  }

  estaConfirmada(r: Reserva): boolean {
    return reservaEstaConfirmada(r);
  }

  /** Una reserva que pidió otra persona de la vivienda (sub-usuario o titular) */
  solicitadaPorOtro(r: Reserva): boolean {
    return !!r.solicitanteId && r.solicitanteId !== this.currentUser()?.id;
  }

  /** Cuándo se puede confirmar la asistencia de una reserva ya aprobada, para que la persona no tenga que adivinarlo */
  avisoConfirmacion(r: Reserva): string | null {
    if (normalizarEstado(r.estado) !== 'APROBADA' || reservaEstaConfirmada(r)) return null;
    const ahora = Date.now();
    const faltan = new Date(r.inicio).getTime() - ahora;
    if (faltan <= 0) return null;
    if (faltan > REGLAS_RESERVA.confirmarHastaDiasAntes * DIA_MS) {
      const desde = new Date(new Date(r.inicio).getTime() - REGLAS_RESERVA.confirmarHastaDiasAntes * DIA_MS).toISOString();
      return `Podrás confirmar tu asistencia a partir del ${diaLegible(desde, this.zonaDe(r.areaId))}.`;
    }
    if (faltan < REGLAS_RESERVA.confirmarDesdeHorasAntes * HORA_MS) return 'Ya pasó el plazo para confirmar la asistencia.';
    return null;
  }

  async confirmarAsistencia(r: Reserva): Promise<void> {
    const respuesta = await Swal.fire({
      title: '¿Confirmar tu asistencia?',
      text: 'Si confirmas y no asistes, contará como inasistencia.',
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#059669',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Sí, confirmar',
      cancelButtonText: 'Volver'
    });
    if (!respuesta.isConfirmed) return;
    await this.resolver(r.id, () => this.reservasService.confirmar(r.id), 'Asistencia confirmada', 'No se pudo confirmar');
  }

  async cancelarReserva(r: Reserva): Promise<void> {
    const respuesta = await Swal.fire({
      title: '¿Cancelar esta reserva?',
      text: `Se liberará ${r.areaNombre} para ese horario.`,
      icon: 'warning',
      input: 'text',
      inputPlaceholder: 'Motivo (opcional)',
      inputAttributes: { maxlength: '200', 'aria-label': 'Motivo de la cancelación (opcional)' },
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Cancelar reserva',
      cancelButtonText: 'Volver'
    });
    if (!respuesta.isConfirmed) return;
    const motivo = typeof respuesta.value === 'string' ? respuesta.value : undefined;
    await this.resolver(r.id, () => this.reservasService.cancelar(r.id, motivo), 'Reserva cancelada', 'No se pudo cancelar');
  }

  async aprobarSolicitud(p: PendienteTitular): Promise<void> {
    const respuesta = await Swal.fire({
      title: '¿Aprobar esta solicitud?',
      text: `${this.nombre(p.solicitanteNombre, p.solicitanteApellidos)} podrá usar ${p.areaNombre} si el administrador también la aprueba.`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#059669',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Sí, aprobar',
      cancelButtonText: 'Volver'
    });
    if (!respuesta.isConfirmed) return;
    await this.resolver(p.id, () => this.reservasService.aprobarComoTitular(p.id), 'Solicitud aprobada', 'No se pudo aprobar');
  }

  async rechazarSolicitud(p: PendienteTitular): Promise<void> {
    const respuesta = await Swal.fire({
      title: '¿Rechazar esta solicitud?',
      text: `${this.nombre(p.solicitanteNombre, p.solicitanteApellidos)} verá que no la aprobaste.`,
      icon: 'warning',
      input: 'text',
      inputPlaceholder: 'Motivo (opcional)',
      inputAttributes: { maxlength: '200', 'aria-label': 'Motivo del rechazo (opcional)' },
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Rechazar',
      cancelButtonText: 'Volver'
    });
    if (!respuesta.isConfirmed) return;
    const motivo = typeof respuesta.value === 'string' ? respuesta.value : undefined;
    await this.resolver(p.id, () => this.reservasService.rechazarComoTitular(p.id, motivo), 'Solicitud rechazada', 'No se pudo rechazar');
  }

  /**
   * Ejecuta una acción sobre una reserva o solicitud. Si ya cambió desde otro lado (ya no existe, ya no admite la acción)
   * se explica y se trae todo al día en lugar de insistir con lo mismo.
   */
  private async resolver(id: string, accion: () => Promise<void>, exito: string, fallo: string): Promise<void> {
    if (this.resolviendo() !== null) return;
    this.resolviendo.set(id);
    try {
      await accion();
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: exito, showConfirmButton: false, timer: 2500 });
      // Aprobar o rechazar como titular cambia el estado de la reserva del sub-usuario: se actualiza la lista
      void this.reservasService.cargarMias();
    } catch (err: any) {
      console.error('[ReservasComponent] Error en la acción:', err);
      // 400 es una validación (hay que corregir algo); 404, 409 y 410 indican que la reserva ya cambió
      const yaCambio = [404, 409, 410].includes(err?.status);
      Swal.fire({
        icon: yaCambio ? 'info' : 'error',
        title: yaCambio ? 'Esto ya cambió' : fallo,
        text: mensajeConValidacion(err, 'No fue posible completar la acción. Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#111C99'
      });
      if (yaCambio) await this.recargar();
    } finally {
      this.resolviendo.set(null);
    }
  }
}
