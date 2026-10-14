import { AfterViewInit, ChangeDetectionStrategy, Component, ElementRef, EventEmitter, HostListener, Input, Output, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { AreaComun, ResultadoBloqueo } from '../../../core/models/reserva.model';
import { fechaEnZona, instanteEnZona, rangoLegible } from '../../../core/utils/reservas.util';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';

const MAX_MOTIVO = 500;

@Component({
  selector: 'app-bloqueo-form',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
      <div class="bg-white rounded-lg max-w-lg w-full p-5 shadow-lg border border-slate-200" role="dialog" aria-modal="true" aria-labelledby="bloqueo-form-titulo">
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 id="bloqueo-form-titulo" class="text-sm font-semibold text-slate-900">Bloquear fechas · {{ area.nombre }}</h3>
          <button type="button" (click)="cerrar()" aria-label="Cerrar" class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-3.5 space-y-3">
          <div class="rounded-md border border-amber-200 bg-amber-50 p-3 text-[11px] text-amber-900 leading-relaxed">
            Mientras dure el bloqueo nadie podrá reservar el área. <strong>Las reservas pendientes o aprobadas que caigan en ese horario se cierran</strong>:
            se rechazan las pendientes y se cancelan las aprobadas, y se avisa a sus titulares con el motivo. <strong>Un bloqueo no se puede quitar después.</strong>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label for="blq-fecha-inicio" class="block text-xs font-semibold text-slate-800 mb-1">Desde el día *</label>
              <input id="blq-fecha-inicio" type="date" [(ngModel)]="form.fechaInicio" [min]="hoy"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label for="blq-hora-inicio" class="block text-xs font-semibold text-slate-800 mb-1">A las *</label>
              <input id="blq-hora-inicio" type="time" [(ngModel)]="form.horaInicio"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label for="blq-fecha-fin" class="block text-xs font-semibold text-slate-800 mb-1">Hasta el día *</label>
              <input id="blq-fecha-fin" type="date" [(ngModel)]="form.fechaFin" [min]="form.fechaInicio || hoy"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label for="blq-hora-fin" class="block text-xs font-semibold text-slate-800 mb-1">A las *</label>
              <input id="blq-hora-fin" type="time" [(ngModel)]="form.horaFin"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          </div>
          @if (problema(); as texto) {
            <p class="text-[11px] text-red-600 font-medium" role="alert">{{ texto }}</p>
          } @else if (resumen(); as texto) {
            <p class="text-[11px] text-slate-600">{{ texto }}</p>
          }

          <div>
            <label for="blq-motivo" class="block text-xs font-semibold text-slate-800 mb-1">Motivo *</label>
            <textarea id="blq-motivo" [(ngModel)]="form.motivo" [attr.maxlength]="maxMotivo" rows="2" placeholder="Ej. Mantenimiento de la alberca, evento del condominio"
              class="w-full text-xs rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"></textarea>
            <p class="mt-1 text-[11px] text-slate-500">Lo verán los residentes en el calendario y los titulares cuyas reservas se cancelen.</p>
          </div>

          <div class="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
            <button type="button" (click)="cerrar()" class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer">Cancelar</button>
            <button type="button" (click)="bloquear()" [disabled]="isSaving() || !esValido()"
              class="h-8 px-3.5 bg-slate-800 hover:bg-slate-900 text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
              {{ isSaving() ? 'Bloqueando...' : 'Bloquear área' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
})
export class BloqueoFormComponent implements AfterViewInit {
  private readonly servicio = inject(ReservasAdminService);
  private readonly elemento = inject(ElementRef<HTMLElement>);

  @Input({ required: true }) area!: AreaComun;
  @Output() cerrado = new EventEmitter<void>();
  @Output() creado = new EventEmitter<ResultadoBloqueo>();

  readonly maxMotivo = MAX_MOTIVO;
  readonly isSaving = signal<boolean>(false);

  form = { fechaInicio: '', horaInicio: '', fechaFin: '', horaFin: '', motivo: '' };

  /** Hoy en la zona del área, para que no se pueda empezar un bloqueo en el pasado */
  get hoy(): string {
    return fechaEnZona(Date.now(), this.area.zonaHoraria);
  }

  ngAfterViewInit(): void {
    (this.elemento.nativeElement as HTMLElement).querySelector<HTMLInputElement>('#blq-fecha-inicio')?.focus();
  }

  @HostListener('document:keydown.escape')
  alPresionarEscape(): void {
    if (!this.isSaving()) this.cerrar();
  }

  cerrar(): void {
    this.cerrado.emit();
  }

  private instantes(): { inicio: string; fin: string } | null {
    const f = this.form;
    if (!f.fechaInicio || !f.horaInicio || !f.fechaFin || !f.horaFin) return null;
    const zona = this.area.zonaHoraria;
    return { inicio: instanteEnZona(f.fechaInicio, f.horaInicio, zona), fin: instanteEnZona(f.fechaFin, f.horaFin, zona) };
  }

  /** Primer problema del rango; null si todo cuadra o aún falta llenar algo */
  problema = (): string | null => {
    const t = this.instantes();
    if (!t) return null;
    if (new Date(t.fin).getTime() <= new Date(t.inicio).getTime()) return 'El fin del bloqueo debe ser posterior al inicio.';
    if (new Date(t.fin).getTime() <= Date.now()) return 'El bloqueo ya terminó: elige fechas futuras.';
    return null;
  };

  resumen = (): string | null => {
    const t = this.instantes();
    return t && !this.problema() ? `Quedará bloqueada ${rangoLegible(t.inicio, t.fin, this.area.zonaHoraria)}.` : null;
  };

  esValido(): boolean {
    const motivo = this.form.motivo.trim();
    return !!this.instantes() && !this.problema() && motivo.length > 0 && motivo.length <= MAX_MOTIVO;
  }

  async bloquear(): Promise<void> {
    const t = this.instantes();
    if (!t || !this.esValido() || this.isSaving()) return;

    const confirmacion = await Swal.fire({
      title: '¿Bloquear esta área?',
      text: `${this.area.nombre} quedará bloqueada ${rangoLegible(t.inicio, t.fin, this.area.zonaHoraria)}. Las reservas de ese horario se rechazarán o cancelarán y el bloqueo no se podrá quitar.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#1E293B',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Sí, bloquear',
      cancelButtonText: 'Volver'
    });
    if (!confirmacion.isConfirmed) return;

    this.isSaving.set(true);
    try {
      const resultado = await this.servicio.crearBloqueo({ areaId: this.area.id, inicio: t.inicio, fin: t.fin, motivo: this.form.motivo });
      this.creado.emit(resultado);
      Swal.fire({
        icon: 'success',
        title: 'Área bloqueada',
        text: resultado.reservasAfectadas === 0
          ? 'No había reservas en ese horario.'
          : resultado.reservasAfectadas === 1
            ? 'Una reserva que caía en ese horario quedó rechazada o cancelada.'
            : `${resultado.reservasAfectadas} reservas que caían en ese horario quedaron rechazadas o canceladas.`,
        confirmButtonColor: '#111C99'
      });
    } catch (err: any) {
      console.error('[BloqueoFormComponent] Error al crear el bloqueo:', err);
      Swal.fire({
        icon: 'error',
        title: 'No se pudo bloquear el área',
        text: mensajeConValidacion(err, 'No fue posible crear el bloqueo. Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#111C99'
      });
    } finally {
      this.isSaving.set(false);
    }
  }
}
