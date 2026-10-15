import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { BloqueoFormComponent } from './bloqueo-form.component';
import {
  CLASES_ESTADO_RESERVA,
  ETIQUETAS_ESTADO_RESERVA,
  EstadoReserva,
  Reserva,
  adminPuedeAprobar,
  adminPuedeCancelar,
  adminPuedeMarcarNoUtilizada,
  adminPuedeModificarBloqueo,
  adminPuedeRechazar,
  AreaComun,
  estadoMostrado,
  nombreCompleto,
  reservaEstaConfirmada
} from '../../../core/models/reserva.model';
import { rangoFechasInvalido, rangoFechasIso } from '../../../core/models/visita.model';
import { rangoLegible } from '../../../core/utils/reservas.util';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';

/** Filtros de estado que ofrece el listado; el primero es el que más atiende el administrador */
const ESTADOS: { valor: EstadoReserva; etiqueta: string }[] = [
  { valor: 'PENDIENTE_ADMIN', etiqueta: 'Por aprobar' },
  { valor: 'PENDIENTE_TITULAR', etiqueta: 'Esperan al titular' },
  { valor: 'APROBADA', etiqueta: 'Aprobadas' },
  { valor: 'RECHAZADA', etiqueta: 'Rechazadas' },
  { valor: 'CANCELADA', etiqueta: 'Canceladas' },
  { valor: 'NO_UTILIZADA', etiqueta: 'No utilizadas' },
  { valor: 'FINALIZADA', etiqueta: 'Finalizadas' }
];

@Component({
  selector: 'app-reservas-admin-lista',
  standalone: true,
  imports: [CommonModule, FormsModule, BloqueoFormComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="space-y-4">
      <!-- Filtros -->
      <div class="rounded-xl border border-slate-200 bg-white p-4 shadow-xs">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3 items-end">
          <div>
            <label for="adm-res-estado" class="block text-xs font-semibold text-slate-800 mb-1">Estado</label>
            <select id="adm-res-estado" [(ngModel)]="estado"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option [ngValue]="''">Todas</option>
              @for (e of estados; track e.valor) {
                <option [ngValue]="e.valor">{{ e.etiqueta }}</option>
              }
            </select>
          </div>
          <div>
            <label for="adm-res-area" class="block text-xs font-semibold text-slate-800 mb-1">Área</label>
            <select id="adm-res-area" [(ngModel)]="areaId"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
              <option [ngValue]="''">Todas</option>
              @for (a of servicio.areas(); track a.id) {
                <option [ngValue]="a.id">{{ a.nombre }}{{ a.activo ? '' : ' (de baja)' }}</option>
              }
            </select>
          </div>
          <div>
            <label for="adm-res-desde" class="block text-xs font-semibold text-slate-800 mb-1">Desde</label>
            <input id="adm-res-desde" type="date" [(ngModel)]="desde"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>
          <div>
            <label for="adm-res-hasta" class="block text-xs font-semibold text-slate-800 mb-1">Hasta</label>
            <input id="adm-res-hasta" type="date" [(ngModel)]="hasta"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>
          <div class="flex items-center gap-2">
            <button type="button" (click)="buscar()" [disabled]="rangoInvalido()"
              class="h-9 px-4 rounded-lg bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-semibold transition-colors cursor-pointer disabled:opacity-50">
              Buscar
            </button>
            <button type="button" (click)="limpiar()"
              class="h-9 px-3 rounded-lg border border-slate-200 text-xs font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">
              Limpiar
            </button>
          </div>
        </div>
        @if (rangoInvalido()) {
          <p class="mt-2 text-[11px] text-red-600 font-medium" role="alert">La fecha "desde" no puede ser posterior a "hasta".</p>
        }
      </div>

      @if (servicio.errorMessage(); as msg) {
        <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
          <span>{{ msg }}</span>
          <button type="button" (click)="recargar()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">Reintentar</button>
        </div>
      }

      @if (servicio.isLoading()) {
        <div class="rounded-xl border border-slate-200 bg-white divide-y divide-slate-100" aria-busy="true">
          @for (s of [1, 2, 3]; track s) {
            <div class="p-4 animate-pulse space-y-1.5">
              <div class="h-3.5 w-1/3 bg-slate-200 rounded"></div>
              <div class="h-3 w-1/2 bg-slate-100 rounded"></div>
            </div>
          }
        </div>
      }

      @if (!servicio.isLoading() && !servicio.errorMessage()) {
        <div class="rounded-xl border border-slate-200 bg-white shadow-xs overflow-x-auto">
          <table class="w-full text-left min-w-[860px]">
            <thead class="bg-slate-50 border-b border-slate-200">
              <tr>
                <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Área y horario</th>
                <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Vivienda</th>
                <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Solicitó</th>
                <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Estado</th>
                <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              @for (r of servicio.reservas(); track r.id) {
                <tr class="hover:bg-slate-50/70 transition-colors align-top">
                  <td class="px-4 py-3">
                    <p class="text-xs font-semibold text-slate-900">{{ r.areaNombre }}</p>
                    <p class="text-xs text-slate-700">{{ rango(r) }}</p>
                  </td>
                  <td class="px-4 py-3 text-xs text-slate-700">
                    @if (r.tipo === 'BLOQUEO') {
                      <span class="text-slate-400">—</span>
                    } @else {
                      <p class="font-semibold text-slate-900">{{ r.numeroCasa || '—' }}</p>
                      <p>Titular: {{ nombre(r.titularNombre, r.titularApellidos) }}</p>
                      @if (r.noShowsTitular) {
                        <p class="text-violet-700">{{ r.noShowsTitular }} inasistencia(s) del titular</p>
                      }
                    }
                  </td>
                  <td class="px-4 py-3 text-xs text-slate-700">
                    @if (r.tipo === 'BLOQUEO') {
                      <span class="text-slate-400">—</span>
                    } @else {
                      <p>{{ nombre(r.solicitanteNombre, r.solicitanteApellidos) }}</p>
                      @if (r.solicitanteId !== r.titularId && r.noShowsSolicitante) {
                        <p class="text-violet-700">{{ r.noShowsSolicitante }} inasistencia(s)</p>
                      }
                    }
                  </td>
                  <td class="px-4 py-3 text-xs">
                    <div class="flex flex-wrap items-center gap-1.5">
                      @if (r.tipo === 'BLOQUEO') {
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-700 text-white border-slate-700">Bloqueo</span>
                      } @else {
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="claseEstado(r)">{{ etiquetaEstado(r) }}</span>
                      }
                    </div>
                    @if (r.motivo) {
                      <p class="mt-1 text-slate-500 italic">{{ r.motivo }}</p>
                    }
                    @if (estaConfirmada(r)) {
                      <p class="mt-1 text-emerald-700">Asistencia confirmada</p>
                    }
                  </td>
                  <td class="px-4 py-3">
                    @if (puedeAprobar(r) || puedeRechazar(r) || puedeCancelar(r) || puedeMarcar(r) || puedeModificarBloqueo(r)) {
                      <div class="flex flex-wrap items-center gap-1.5">
                        @if (puedeAprobar(r)) {
                          <button type="button" (click)="aprobar(r)" [disabled]="resolviendo() !== null"
                            [attr.aria-label]="'Aprobar la reserva de ' + r.areaNombre + ' de ' + (r.numeroCasa || '')"
                            class="h-7 px-2.5 text-[11px] font-medium rounded-md bg-emerald-600 hover:bg-emerald-700 text-white transition-colors cursor-pointer disabled:opacity-50">
                            {{ resolviendo() === r.id ? 'Procesando...' : 'Aprobar' }}
                          </button>
                        }
                        @if (puedeRechazar(r)) {
                          <button type="button" (click)="rechazar(r)" [disabled]="resolviendo() !== null"
                            [attr.aria-label]="'Rechazar la reserva de ' + r.areaNombre + ' de ' + (r.numeroCasa || '')"
                            class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50">
                            Rechazar
                          </button>
                        }
                        @if (puedeCancelar(r)) {
                          <button type="button" (click)="cancelar(r)" [disabled]="resolviendo() !== null"
                            [attr.aria-label]="'Cancelar la reserva de ' + r.areaNombre + ' de ' + (r.numeroCasa || '')"
                            class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50">
                            Cancelar
                          </button>
                        }
                        @if (puedeModificarBloqueo(r)) {
                          <button type="button" (click)="editarBloqueo(r)" [disabled]="resolviendo() !== null"
                            [attr.aria-label]="'Editar el bloqueo de ' + r.areaNombre + ' ' + rango(r)"
                            class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-300 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer disabled:opacity-50">
                            Editar
                          </button>
                          <button type="button" (click)="quitarBloqueo(r)" [disabled]="resolviendo() !== null"
                            [attr.aria-label]="'Quitar el bloqueo de ' + r.areaNombre + ' ' + rango(r)"
                            class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50">
                            {{ resolviendo() === r.id ? 'Quitando...' : 'Quitar' }}
                          </button>
                        }
                        @if (puedeMarcar(r)) {
                          <button type="button" (click)="marcarNoUtilizada(r)" [disabled]="resolviendo() !== null"
                            [attr.aria-label]="'Marcar como no utilizada la reserva de ' + r.areaNombre + ' de ' + (r.numeroCasa || '')"
                            class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-violet-200 text-violet-700 hover:bg-violet-50 transition-colors cursor-pointer disabled:opacity-50">
                            No utilizada
                          </button>
                        }
                      </div>
                    } @else {
                      <span class="text-xs text-slate-400">Sin acciones</span>
                    }
                  </td>
                </tr>
              }
            </tbody>
          </table>
          @if (servicio.reservas().length === 0) {
            <div class="p-8 text-center text-xs text-slate-500 font-medium">{{ textoVacio() }}</div>
          }
        </div>

        @if (totalPaginas() > 1) {
          <div class="flex items-center justify-between">
            <button type="button" (click)="irAPagina(servicio.page() - 1)" [disabled]="servicio.page() <= 1"
              class="h-8 px-3 text-xs font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer">Anterior</button>
            <span class="text-xs text-slate-500 font-medium">Página {{ servicio.page() }} de {{ totalPaginas() }} · {{ servicio.total() }} en total</span>
            <button type="button" (click)="irAPagina(servicio.page() + 1)" [disabled]="servicio.page() >= totalPaginas()"
              class="h-8 px-3 text-xs font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer">Siguiente</button>
          </div>
        }
      }

      @if (bloqueoEnEdicion(); as bloqueo) {
        <app-bloqueo-form [area]="areaDe(bloqueo)" [bloqueo]="bloqueo" (cerrado)="bloqueoEnEdicion.set(null)"
          (actualizado)="alCambiarBloqueo()" (obsoleto)="alCambiarBloqueo()" />
      }
    </div>
  `
})
export class ReservasAdminListaComponent implements OnInit {
  readonly servicio = inject(ReservasAdminService);

  readonly estados = ESTADOS;
  /** Por defecto lo que espera una decisión del administrador */
  estado: EstadoReserva | '' = 'PENDIENTE_ADMIN';
  areaId = '';
  desde = '';
  hasta = '';

  /** Id de la reserva que se está resolviendo; bloquea los botones mientras tanto */
  readonly resolviendo = signal<string | null>(null);
  /** Bloqueo que se está corrigiendo en el formulario */
  readonly bloqueoEnEdicion = signal<Reserva | null>(null);
  readonly totalPaginas = computed(() => Math.max(1, Math.ceil(this.servicio.total() / this.servicio.PAGE_SIZE)));

  /** Los filtros con los que se hizo la última búsqueda: paginar y refrescar no deben usar lo que se está escribiendo */
  private filtrosAplicados = { estado: 'PENDIENTE_ADMIN' as EstadoReserva | '', areaId: '', desde: '', hasta: '' };

  ngOnInit(): void {
    void this.buscar();
  }

  rangoInvalido(): boolean {
    return rangoFechasInvalido(this.desde, this.hasta);
  }

  async buscar(): Promise<void> {
    if (this.rangoInvalido()) return;
    this.filtrosAplicados = { estado: this.estado, areaId: this.areaId, desde: this.desde, hasta: this.hasta };
    await this.cargar(1);
  }

  async limpiar(): Promise<void> {
    this.estado = 'PENDIENTE_ADMIN';
    this.areaId = '';
    this.desde = '';
    this.hasta = '';
    await this.buscar();
  }

  async irAPagina(pagina: number): Promise<void> {
    if (pagina < 1 || pagina > this.totalPaginas()) return;
    await this.cargar(pagina);
  }

  /** Vuelve a pedir la página actual con los filtros de la última búsqueda */
  async recargar(): Promise<void> {
    await this.cargar(this.servicio.page());
  }

  private cargar(pagina: number): Promise<void> {
    const f = this.filtrosAplicados;
    const rango = rangoFechasIso(f.desde, f.hasta);
    return this.servicio.cargarReservas({ estado: f.estado, areaId: f.areaId, from: rango.desde, to: rango.hasta }, pagina);
  }

  textoVacio(): string {
    return this.filtrosAplicados.estado === 'PENDIENTE_ADMIN' && !this.filtrosAplicados.areaId && !this.filtrosAplicados.desde && !this.filtrosAplicados.hasta
      ? 'No hay solicitudes por aprobar.'
      : 'No hay reservas con estos filtros.';
  }

  private zonaDe(areaId: string): string {
    return this.servicio.areas().find(a => a.id === areaId)?.zonaHoraria ?? Intl.DateTimeFormat().resolvedOptions().timeZone;
  }

  rango(r: Reserva): string {
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

  estaConfirmada(r: Reserva): boolean {
    return r.tipo !== 'BLOQUEO' && reservaEstaConfirmada(r);
  }

  puedeAprobar(r: Reserva): boolean {
    return adminPuedeAprobar(r);
  }

  puedeRechazar(r: Reserva): boolean {
    return adminPuedeRechazar(r);
  }

  puedeCancelar(r: Reserva): boolean {
    return adminPuedeCancelar(r);
  }

  puedeMarcar(r: Reserva): boolean {
    return adminPuedeMarcarNoUtilizada(r);
  }

  puedeModificarBloqueo(r: Reserva): boolean {
    return adminPuedeModificarBloqueo(r);
  }

  /** Área del bloqueo (con su zona horaria); si no está en la lista se usa la zona del navegador */
  areaDe(r: Reserva): AreaComun {
    return this.servicio.areas().find(a => a.id === r.areaId) ?? {
      id: r.areaId, nombre: r.areaNombre, horaApertura: '00:00:00', horaCierre: '23:59:00', zonaHoraria: this.zonaDe(r.areaId), activo: true
    };
  }

  editarBloqueo(r: Reserva): void {
    this.bloqueoEnEdicion.set(r);
  }

  /** Se guardó o ya no existía: se cierra el formulario y se vuelve a pedir la página */
  async alCambiarBloqueo(): Promise<void> {
    this.bloqueoEnEdicion.set(null);
    await this.recargar();
  }

  async quitarBloqueo(r: Reserva): Promise<void> {
    const respuesta = await Swal.fire({
      title: '¿Quitar este bloqueo?',
      text: `${r.areaNombre} volverá a estar disponible ${this.rango(r)}.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Sí, quitar',
      cancelButtonText: 'Volver'
    });
    if (!respuesta.isConfirmed) return;
    await this.resolver(r.id, () => this.servicio.quitarBloqueo(r.id), 'Bloqueo quitado', 'No se pudo quitar el bloqueo', 'Este bloqueo ya cambió');
  }

  async aprobar(r: Reserva): Promise<void> {
    const respuesta = await Swal.fire({
      title: '¿Aprobar esta reserva?',
      text: `${r.areaNombre} para ${this.nombre(r.solicitanteNombre, r.solicitanteApellidos)} (${r.numeroCasa || 'sin casa'}): ${this.rango(r)}.`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#059669',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Sí, aprobar',
      cancelButtonText: 'Volver'
    });
    if (!respuesta.isConfirmed) return;
    await this.resolver(r.id, () => this.servicio.aprobar(r.id), 'Reserva aprobada', 'No se pudo aprobar');
  }

  async rechazar(r: Reserva): Promise<void> {
    const motivo = await this.pedirMotivo('¿Rechazar esta reserva?', `Se le avisará a ${this.nombre(r.solicitanteNombre, r.solicitanteApellidos)} con el motivo.`, 'Rechazar');
    if (motivo === null) return;
    await this.resolver(r.id, () => this.servicio.rechazar(r.id, motivo), 'Reserva rechazada', 'No se pudo rechazar');
  }

  async cancelar(r: Reserva): Promise<void> {
    const motivo = await this.pedirMotivo('¿Cancelar esta reserva?', 'Ya estaba aprobada: se le avisará al residente con el motivo y el horario quedará libre.', 'Cancelar reserva');
    if (motivo === null) return;
    await this.resolver(r.id, () => this.servicio.cancelar(r.id, motivo), 'Reserva cancelada', 'No se pudo cancelar');
  }

  async marcarNoUtilizada(r: Reserva): Promise<void> {
    const respuesta = await Swal.fire({
      title: '¿Marcar como no utilizada?',
      text: 'Se registra una inasistencia del titular y de quien la solicitó. Esta acción no se puede deshacer.',
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#7C3AED',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Sí, marcar',
      cancelButtonText: 'Volver'
    });
    if (!respuesta.isConfirmed) return;
    await this.resolver(r.id, () => this.servicio.marcarNoUtilizada(r.id), 'Marcada como no utilizada', 'No se pudo marcar');
  }

  /** El motivo es obligatorio para rechazar y cancelar; null si el administrador se arrepiente */
  private async pedirMotivo(titulo: string, texto: string, confirmar: string): Promise<string | null> {
    const respuesta = await Swal.fire({
      title: titulo,
      text: texto,
      icon: 'warning',
      input: 'textarea',
      inputPlaceholder: 'Motivo (lo verá el residente)',
      inputAttributes: { maxlength: '500', 'aria-label': 'Motivo' },
      inputValidator: valor => (valor?.trim() ? undefined : 'Escribe el motivo.'),
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: confirmar,
      cancelButtonText: 'Volver'
    });
    return respuesta.isConfirmed && typeof respuesta.value === 'string' && respuesta.value.trim() ? respuesta.value.trim() : null;
  }

  /**
   * Ejecuta una acción sobre una reserva y vuelve a pedir la página. Si otra persona ya la resolvió (404, 409, 410)
   * se explica con el mensaje del backend en vez de insistir; un 400 se muestra como error a corregir.
   */
  private async resolver(id: string, accion: () => Promise<void>, exito: string, fallo: string, yaCambioTitulo = 'Esta reserva ya cambió'): Promise<void> {
    if (this.resolviendo() !== null) return;
    this.resolviendo.set(id);
    try {
      await accion();
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: exito, showConfirmButton: false, timer: 2500 });
      await this.recargar();
    } catch (err: any) {
      console.error('[ReservasAdminListaComponent] Error en la acción:', err);
      const yaCambio = [404, 409, 410].includes(err?.status);
      Swal.fire({
        icon: yaCambio ? 'info' : 'error',
        title: yaCambio ? yaCambioTitulo : fallo,
        text: mensajeConValidacion(err, 'No fue posible completar la acción. Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#111C99'
      });
      if (yaCambio) await this.recargar();
    } finally {
      this.resolviendo.set(null);
    }
  }
}
