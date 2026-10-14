import { AfterViewInit, ChangeDetectionStrategy, Component, ElementRef, EventEmitter, HostListener, Input, OnInit, Output, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { AreaComun, GuardarAreaDto } from '../../../core/models/reserva.model';
import { minutosDelDia, recortarHora } from '../../../core/utils/reservas.util';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';

const MAX_NOMBRE = 100;
const MAX_DESCRIPCION = 500;

/** "08:00" → "08:00:00", como espera el backend */
function conSegundos(hora: string): string {
  return `${recortarHora(hora)}:00`;
}

@Component({
  selector: 'app-area-form',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
      <div class="bg-white rounded-lg max-w-lg w-full p-5 shadow-lg border border-slate-200" role="dialog" aria-modal="true" aria-labelledby="area-form-titulo">
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 id="area-form-titulo" class="text-sm font-semibold text-slate-900">{{ area ? 'Editar área' : 'Nueva área común' }}</h3>
          <button type="button" (click)="cerrar()" aria-label="Cerrar" class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-3.5 space-y-3">
          <div>
            <label for="area-nombre" class="block text-xs font-semibold text-slate-800 mb-1">Nombre *</label>
            <input id="area-nombre" type="text" [(ngModel)]="form.nombre" [attr.maxlength]="maxNombre" placeholder="Ej. Alberca, Salón de usos múltiples"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>
          <div>
            <label for="area-descripcion" class="block text-xs font-semibold text-slate-800 mb-1">Descripción</label>
            <textarea id="area-descripcion" [(ngModel)]="form.descripcion" [attr.maxlength]="maxDescripcion" rows="2" placeholder="Qué incluye el área, aforo, reglas…"
              class="w-full text-xs rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"></textarea>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label for="area-apertura" class="block text-xs font-semibold text-slate-800 mb-1">Abre *</label>
              <input id="area-apertura" type="time" [(ngModel)]="form.horaApertura"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label for="area-cierre" class="block text-xs font-semibold text-slate-800 mb-1">Cierra *</label>
              <input id="area-cierre" type="time" [(ngModel)]="form.horaCierre"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          </div>
          @if (horarioInvalido()) {
            <p class="text-[11px] text-red-600 font-medium" role="alert">La hora de apertura debe ser anterior a la de cierre.</p>
          } @else {
            <p class="text-[11px] text-slate-500">Los residentes reservan dentro de este horario, en la zona horaria del condominio.</p>
          }

          <div class="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
            <button type="button" (click)="cerrar()" class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer">Cancelar</button>
            <button type="button" (click)="guardar()" [disabled]="isSaving() || !esValido() || (area && !hayCambios())"
              class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
              {{ isSaving() ? 'Guardando...' : (area ? 'Guardar cambios' : 'Crear área') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
})
export class AreaFormComponent implements OnInit, AfterViewInit {
  private readonly servicio = inject(ReservasAdminService);
  private readonly elemento = inject(ElementRef<HTMLElement>);

  /** Área que se edita; sin ella el formulario da de alta una nueva */
  @Input() area: AreaComun | null = null;
  @Output() cerrado = new EventEmitter<void>();
  @Output() guardado = new EventEmitter<AreaComun>();

  readonly maxNombre = MAX_NOMBRE;
  readonly maxDescripcion = MAX_DESCRIPCION;
  readonly isSaving = signal<boolean>(false);

  form = { nombre: '', descripcion: '', horaApertura: '08:00', horaCierre: '22:00' };

  ngOnInit(): void {
    const a = this.area;
    if (!a) return;
    this.form = {
      nombre: a.nombre,
      descripcion: a.descripcion ?? '',
      horaApertura: recortarHora(a.horaApertura),
      horaCierre: recortarHora(a.horaCierre)
    };
  }

  ngAfterViewInit(): void {
    (this.elemento.nativeElement as HTMLElement).querySelector<HTMLInputElement>('#area-nombre')?.focus();
  }

  @HostListener('document:keydown.escape')
  alPresionarEscape(): void {
    if (!this.isSaving()) this.cerrar();
  }

  cerrar(): void {
    this.cerrado.emit();
  }

  horarioInvalido(): boolean {
    const { horaApertura, horaCierre } = this.form;
    return !!horaApertura && !!horaCierre && minutosDelDia(horaApertura) >= minutosDelDia(horaCierre);
  }

  esValido(): boolean {
    const f = this.form;
    const nombre = f.nombre.trim();
    return nombre.length > 0 && nombre.length <= MAX_NOMBRE && f.descripcion.length <= MAX_DESCRIPCION && !!f.horaApertura && !!f.horaCierre && !this.horarioInvalido();
  }

  /** Solo lo que cambió respecto al área que se abrió */
  armarCambios(): Partial<GuardarAreaDto> {
    const a = this.area;
    if (!a) return {};
    const f = this.form;
    const cambios: Partial<GuardarAreaDto> = {};
    if (f.nombre.trim() !== a.nombre) cambios.nombre = f.nombre.trim();
    if (f.descripcion.trim() !== (a.descripcion ?? '')) cambios.descripcion = f.descripcion.trim();
    if (f.horaApertura !== recortarHora(a.horaApertura)) cambios.horaApertura = conSegundos(f.horaApertura);
    if (f.horaCierre !== recortarHora(a.horaCierre)) cambios.horaCierre = conSegundos(f.horaCierre);
    return cambios;
  }

  hayCambios(): boolean {
    return Object.keys(this.armarCambios()).length > 0;
  }

  armarAlta(): GuardarAreaDto {
    const f = this.form;
    const dto: GuardarAreaDto = { nombre: f.nombre.trim(), horaApertura: conSegundos(f.horaApertura), horaCierre: conSegundos(f.horaCierre) };
    if (f.descripcion.trim()) dto.descripcion = f.descripcion.trim();
    return dto;
  }

  async guardar(): Promise<void> {
    if (!this.esValido() || this.isSaving()) return;
    this.isSaving.set(true);
    try {
      const resultado = this.area
        ? await this.servicio.actualizarArea(this.area.id, this.armarCambios())
        : await this.servicio.crearArea(this.armarAlta());
      this.guardado.emit(resultado);
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: this.area ? 'Área actualizada' : 'Área creada', showConfirmButton: false, timer: 2500 });
    } catch (err: any) {
      console.error('[AreaFormComponent] Error al guardar el área:', err);
      Swal.fire({
        icon: 'error',
        title: this.area ? 'No se pudo guardar el área' : 'No se pudo crear el área',
        text: mensajeConValidacion(err, 'No fue posible guardar el área. Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#111C99'
      });
    } finally {
      this.isSaving.set(false);
    }
  }
}
