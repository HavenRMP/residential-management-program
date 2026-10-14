import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import Swal from 'sweetalert2';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { AreaComun } from '../../../core/models/reserva.model';
import { recortarHora } from '../../../core/utils/reservas.util';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';
import { AreaFormComponent } from './area-form.component';
import { BloqueoFormComponent } from './bloqueo-form.component';

@Component({
  selector: 'app-areas-admin',
  standalone: true,
  imports: [CommonModule, AreaFormComponent, BloqueoFormComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="space-y-4">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <p class="text-xs text-slate-600 max-w-2xl">
          Las áreas que des de alta aparecen para que los residentes las reserven. Si una deja de usarse, dala de baja; puedes reactivarla cuando quieras.
        </p>
        <button type="button" (click)="abrirFormulario(null)"
          class="h-9 px-3.5 inline-flex items-center gap-2 rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-semibold transition-colors shadow-2xs cursor-pointer self-start sm:self-auto">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          <span>Nueva área</span>
        </button>
      </div>

      @if (servicio.errorAreas(); as msg) {
        <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
          <span>{{ msg }}</span>
          <button type="button" (click)="servicio.cargarAreas()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">Reintentar</button>
        </div>
      }

      @if (servicio.isLoadingAreas() && servicio.areas().length === 0) {
        <div class="grid grid-cols-1 xl:grid-cols-2 gap-3" aria-busy="true">
          @for (s of [1, 2]; track s) {
            <div class="h-28 rounded-xl bg-white border border-slate-200 animate-pulse"></div>
          }
        </div>
      }

      @if (!servicio.isLoadingAreas() && !servicio.errorAreas() && servicio.areas().length === 0) {
        <div class="rounded-xl border border-dashed border-slate-300 bg-white p-8 text-center space-y-2">
          <p class="text-sm font-semibold text-slate-900">Todavía no hay áreas comunes</p>
          <p class="text-xs text-slate-500">Da de alta la primera (alberca, salón de usos múltiples…) para que los residentes puedan reservarla.</p>
        </div>
      }

      @if (servicio.areas().length > 0) {
        <ul class="grid grid-cols-1 xl:grid-cols-2 gap-3">
          @for (a of servicio.areas(); track a.id) {
            <li class="rounded-xl border bg-white p-4 shadow-xs space-y-3" [ngClass]="a.activo ? 'border-slate-200' : 'border-slate-200 bg-slate-50/70'">
              <div class="flex flex-wrap items-start justify-between gap-2">
                <div class="min-w-0">
                  <p class="text-sm font-semibold text-slate-900">{{ a.nombre }}</p>
                  @if (a.descripcion) {
                    <p class="text-xs text-slate-600 mt-0.5">{{ a.descripcion }}</p>
                  }
                </div>
                <span class="shrink-0 inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border"
                  [ngClass]="a.activo ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-slate-100 text-slate-600 border-slate-200'">
                  {{ a.activo ? 'Activa' : 'De baja' }}
                </span>
              </div>
              <p class="text-xs text-slate-600">Abierta de {{ hora(a.horaApertura) }} a {{ hora(a.horaCierre) }} · {{ a.zonaHoraria }}</p>
              <div class="flex flex-wrap items-center gap-1.5">
                <button type="button" (click)="abrirFormulario(a)" [attr.aria-label]="'Editar ' + a.nombre"
                  class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">Editar</button>
                @if (a.activo) {
                  <button type="button" (click)="areaBloqueo.set(a)" [attr.aria-label]="'Bloquear fechas de ' + a.nombre"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer">Bloquear fechas</button>
                  <button type="button" (click)="darDeBaja(a)" [disabled]="procesando() !== null" [attr.aria-label]="'Dar de baja ' + a.nombre"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer disabled:opacity-50">Dar de baja</button>
                } @else {
                  <button type="button" (click)="reactivar(a)" [disabled]="procesando() !== null" [attr.aria-label]="'Reactivar ' + a.nombre"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md bg-emerald-600 hover:bg-emerald-700 text-white transition-colors cursor-pointer disabled:opacity-50">Reactivar</button>
                }
              </div>
            </li>
          }
        </ul>
      }
    </div>

    @if (formularioAbierto()) {
      <app-area-form [area]="areaEditando()" (cerrado)="cerrarFormulario()" (guardado)="cerrarFormulario()" />
    }
    @if (areaBloqueo(); as area) {
      <app-bloqueo-form [area]="area" (cerrado)="areaBloqueo.set(null)" (creado)="areaBloqueo.set(null)" />
    }
  `
})
export class AreasAdminComponent implements OnInit {
  readonly servicio = inject(ReservasAdminService);

  readonly formularioAbierto = signal<boolean>(false);
  /** Área que se edita; null cuando el formulario da de alta una nueva */
  readonly areaEditando = signal<AreaComun | null>(null);
  readonly areaBloqueo = signal<AreaComun | null>(null);
  /** Id del área a la que se le está dando de baja o reactivando */
  readonly procesando = signal<string | null>(null);

  ngOnInit(): void {
    void this.servicio.cargarAreas();
  }

  hora(valor: string): string {
    return recortarHora(valor);
  }

  abrirFormulario(area: AreaComun | null): void {
    this.areaEditando.set(area);
    this.formularioAbierto.set(true);
  }

  cerrarFormulario(): void {
    this.formularioAbierto.set(false);
    this.areaEditando.set(null);
  }

  async darDeBaja(area: AreaComun): Promise<void> {
    const respuesta = await Swal.fire({
      title: '¿Dar de baja esta área?',
      text: `Los residentes ya no podrán reservar ${area.nombre}. Puedes reactivarla cuando quieras.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Sí, dar de baja',
      cancelButtonText: 'Volver'
    });
    if (!respuesta.isConfirmed) return;
    await this.cambiar(area.id, () => this.servicio.darDeBaja(area.id), 'Área dada de baja', 'No se pudo dar de baja');
  }

  async reactivar(area: AreaComun): Promise<void> {
    await this.cambiar(area.id, () => this.servicio.reactivar(area.id), 'Área reactivada', 'No se pudo reactivar');
  }

  private async cambiar(id: string, accion: () => Promise<void>, exito: string, fallo: string): Promise<void> {
    if (this.procesando() !== null) return;
    this.procesando.set(id);
    try {
      await accion();
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: exito, showConfirmButton: false, timer: 2500 });
    } catch (err: any) {
      console.error('[AreasAdminComponent] Error al cambiar el área:', err);
      Swal.fire({
        icon: 'error',
        title: fallo,
        text: mensajeConValidacion(err, 'No fue posible completar la acción. Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#111C99'
      });
      // Si otra persona ya la cambió, la lista se vuelve a pedir para no mostrar un estado viejo
      if ([404, 409, 410].includes(err?.status)) await this.servicio.cargarAreas();
    } finally {
      this.procesando.set(null);
    }
  }
}
