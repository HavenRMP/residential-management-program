import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { VigilantesService } from '../../../core/services/vigilantes.service';
import { TurnoVigilante, Vigilante } from '../../../core/models/vigilante.model';

const TURNOS: { valor: TurnoVigilante; etiqueta: string }[] = [
  { valor: 'matutino', etiqueta: 'Matutino' },
  { valor: 'vespertino', etiqueta: 'Vespertino' },
  { valor: 'nocturno', etiqueta: 'Nocturno' }
];

@Component({
  selector: 'app-vigilantes-list',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  template: `
    <div class="p-4 sm:p-6 max-w-7xl mx-auto space-y-4">

      <!-- Breadcrumb -->
      <nav class="flex items-center gap-2 text-xs text-slate-600 font-semibold">
        <a routerLink="/dashboard/admin" class="hover:text-slate-900 transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] rounded">Panel</a>
        <span>/</span>
        <span class="text-slate-900">Vigilantes</span>
      </nav>

      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200">
        <div>
          <h1 class="text-2xl font-bold tracking-tight text-slate-900">Vigilantes</h1>
          <p class="text-xs text-slate-600 mt-1 font-medium">
            Personal de seguridad y control de accesos en caseta.
          </p>
        </div>

        <button
          type="button"
          (click)="abrirModalCrear()"
          class="h-9 px-3.5 inline-flex items-center gap-2 rounded-md bg-[#111C99] hover:bg-[#0d1577] focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#111C99] text-white text-xs font-semibold transition-colors shadow-2xs cursor-pointer shrink-0"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          <span>Nuevo vigilante</span>
        </button>
      </div>

      <!-- Tabs -->
      <div class="flex items-center p-1 bg-slate-200/80 rounded-lg text-xs font-semibold text-slate-700 w-fit">
        <button
          type="button"
          (click)="tabActiva.set('activos')"
          [class.bg-white]="tabActiva() === 'activos'"
          [class.text-slate-900]="tabActiva() === 'activos'"
          [class.shadow-2xs]="tabActiva() === 'activos'"
          class="px-3 py-1 rounded-md transition-all cursor-pointer flex items-center gap-1.5 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
        >
          <span>Activos</span>
          <span class="text-[10px] px-1.5 py-0.2 rounded-full font-mono bg-slate-100 text-slate-800 border border-slate-200">
            {{ vigilantesService.activos().length }}
          </span>
        </button>
        <button
          type="button"
          (click)="tabActiva.set('inactivos')"
          [class.bg-white]="tabActiva() === 'inactivos'"
          [class.text-slate-900]="tabActiva() === 'inactivos'"
          [class.shadow-2xs]="tabActiva() === 'inactivos'"
          class="px-3 py-1 rounded-md transition-all cursor-pointer flex items-center gap-1.5 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
        >
          <span>Dados de baja</span>
          <span class="text-[10px] px-1.5 py-0.2 rounded-full font-mono bg-slate-100 text-slate-800 border border-slate-200">
            {{ vigilantesService.inactivos().length }}
          </span>
        </button>
      </div>

      <!-- Loading skeleton -->
      <div *ngIf="vigilantesService.isLoading()" class="rounded-xl border border-slate-200 bg-white divide-y divide-slate-100">
        <div *ngFor="let s of [1, 2, 3]" class="p-4 animate-pulse flex items-center gap-3">
          <div class="w-9 h-9 rounded-full bg-slate-200 shrink-0"></div>
          <div class="flex-1 space-y-1.5">
            <div class="h-3.5 w-1/3 bg-slate-200 rounded"></div>
            <div class="h-3 w-1/2 bg-slate-100 rounded"></div>
          </div>
        </div>
      </div>

      <!-- Directorio -->
      <div *ngIf="!vigilantesService.isLoading()" class="rounded-xl border border-slate-200 bg-white shadow-xs overflow-hidden">
        <table class="w-full text-left">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Vigilante</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Contacto</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Turno</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide">Estatus</th>
              <th class="px-4 py-2.5 text-[11px] font-semibold text-slate-600 uppercase tracking-wide text-right">Acciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr *ngFor="let v of vigilantesFiltrados()" class="hover:bg-slate-50/70 transition-colors">
              <td class="px-4 py-3">
                <p class="text-xs font-semibold text-slate-900">{{ v.nombre }} {{ v.apellidos }}</p>
              </td>
              <td class="px-4 py-3">
                <p class="text-xs text-slate-700">{{ v.email }}</p>
                <p class="text-[11px] text-slate-500">{{ v.telefono }}</p>
              </td>
              <td class="px-4 py-3">
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border"
                  [class.bg-amber-50]="v.turno === 'matutino'" [class.text-amber-700]="v.turno === 'matutino'" [class.border-amber-200]="v.turno === 'matutino'"
                  [class.bg-indigo-50]="v.turno === 'vespertino'" [class.text-indigo-700]="v.turno === 'vespertino'" [class.border-indigo-200]="v.turno === 'vespertino'"
                  [class.bg-slate-100]="v.turno === 'nocturno'" [class.text-slate-700]="v.turno === 'nocturno'" [class.border-slate-300]="v.turno === 'nocturno'"
                >
                  {{ etiquetaTurno(v.turno) }}
                </span>
              </td>
              <td class="px-4 py-3">
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border"
                  [class.bg-emerald-50]="v.activo" [class.text-emerald-700]="v.activo" [class.border-emerald-200]="v.activo"
                  [class.bg-rose-50]="!v.activo" [class.text-rose-700]="!v.activo" [class.border-rose-200]="!v.activo"
                >
                  {{ v.activo ? 'Activo' : 'Dado de baja' }}
                </span>
              </td>
              <td class="px-4 py-3 text-right">
                <button
                  type="button"
                  (click)="confirmarCambioEstado(v)"
                  class="h-7 px-2.5 text-[11px] font-medium rounded-md border transition-colors cursor-pointer"
                  [class.text-rose-700]="v.activo"
                  [class.border-rose-200]="v.activo"
                  [class.hover:bg-rose-50]="v.activo"
                  [class.text-emerald-700]="!v.activo"
                  [class.border-emerald-200]="!v.activo"
                  [class.hover:bg-emerald-50]="!v.activo"
                >
                  {{ v.activo ? 'Dar de baja' : 'Reactivar' }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <div *ngIf="vigilantesFiltrados().length === 0" class="p-8 text-center text-xs text-slate-500 font-medium">
          {{ tabActiva() === 'activos' ? 'No hay vigilantes activos todavía.' : 'No hay vigilantes dados de baja.' }}
        </div>
      </div>
    </div>

    <!-- Modal Alta de Vigilante -->
    <div
      *ngIf="modalAbierto()"
      class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4"
    >
      <div class="bg-white rounded-lg max-w-md w-full p-5 shadow-lg border border-slate-200">
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 class="text-sm font-semibold text-slate-900">Nuevo vigilante</h3>
          <button
            type="button"
            (click)="cerrarModal()"
            class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form [formGroup]="form" (ngSubmit)="guardar()" class="mt-3.5 space-y-3">
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Nombre *</label>
              <input
                type="text"
                formControlName="nombre"
                placeholder="Nombre"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
              />
              <div *ngIf="form.get('nombre')?.touched && form.get('nombre')?.invalid" class="mt-1 text-[11px] text-red-600 font-medium">
                <span *ngIf="form.get('nombre')?.errors?.['required']">Requerido.</span>
                <span *ngIf="form.get('nombre')?.errors?.['pattern']">Solo letras.</span>
              </div>
            </div>
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Apellidos *</label>
              <input
                type="text"
                formControlName="apellidos"
                placeholder="Apellidos"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
              />
              <div *ngIf="form.get('apellidos')?.touched && form.get('apellidos')?.invalid" class="mt-1 text-[11px] text-red-600 font-medium">
                <span *ngIf="form.get('apellidos')?.errors?.['required']">Requerido.</span>
                <span *ngIf="form.get('apellidos')?.errors?.['pattern']">Solo letras.</span>
              </div>
            </div>
          </div>

          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">Correo *</label>
            <input
              type="email"
              formControlName="email"
              placeholder="vigilante@haven.com"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
            />
            <div *ngIf="form.get('email')?.touched && form.get('email')?.invalid" class="mt-1 text-[11px] text-red-600 font-medium">
              <span *ngIf="form.get('email')?.errors?.['required']">Requerido.</span>
              <span *ngIf="form.get('email')?.errors?.['email']">Correo no válido.</span>
            </div>
          </div>

          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">Teléfono *</label>
            <input
              type="tel"
              formControlName="telefono"
              placeholder="10 dígitos"
              maxlength="10"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
            />
            <div *ngIf="form.get('telefono')?.touched && form.get('telefono')?.invalid" class="mt-1 text-[11px] text-red-600 font-medium">
              <span *ngIf="form.get('telefono')?.errors?.['required']">Requerido.</span>
              <span *ngIf="form.get('telefono')?.errors?.['pattern']">Deben ser 10 dígitos.</span>
            </div>
          </div>

          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">Turno *</label>
            <select
              formControlName="turno"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
            >
              <option *ngFor="let t of turnos" [value]="t.valor">{{ t.etiqueta }}</option>
            </select>
          </div>

          <div class="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
            <button
              type="button"
              (click)="cerrarModal()"
              class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer"
            >
              Cancelar
            </button>
            <button
              type="submit"
              [disabled]="isSaving() || form.invalid"
              class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50"
            >
              {{ isSaving() ? 'Guardando...' : 'Registrar' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  `
})
export class VigilantesListComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  readonly vigilantesService = inject(VigilantesService);

  readonly turnos = TURNOS;
  readonly tabActiva = signal<'activos' | 'inactivos'>('activos');
  readonly modalAbierto = signal<boolean>(false);
  readonly isSaving = signal<boolean>(false);

  readonly vigilantesFiltrados = computed(() =>
    this.tabActiva() === 'activos' ? this.vigilantesService.activos() : this.vigilantesService.inactivos()
  );

  form: FormGroup = this.fb.group({
    nombre: ['', [Validators.required, Validators.pattern(/^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$/)]],
    apellidos: ['', [Validators.required, Validators.pattern(/^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$/)]],
    email: ['', [Validators.required, Validators.email]],
    telefono: ['', [Validators.required, Validators.pattern('^[0-9]{10}$')]],
    turno: ['matutino', [Validators.required]]
  });

  ngOnInit(): void {
    this.vigilantesService.listar();
  }

  etiquetaTurno(turno: string): string {
    return TURNOS.find(t => t.valor === turno)?.etiqueta || turno;
  }

  abrirModalCrear(): void {
    this.form.reset({ nombre: '', apellidos: '', email: '', telefono: '', turno: 'matutino' });
    this.modalAbierto.set(true);
  }

  cerrarModal(): void {
    this.modalAbierto.set(false);
  }

  async guardar(): Promise<void> {
    if (this.form.invalid || this.isSaving()) {
      this.form.markAllAsTouched();
      return;
    }

    this.isSaving.set(true);
    try {
      await this.vigilantesService.crear(this.form.value);
      this.cerrarModal();
      Swal.fire({
        toast: true,
        position: 'top-end',
        icon: 'success',
        title: 'Vigilante registrado',
        showConfirmButton: false,
        timer: 2000
      });
    } finally {
      this.isSaving.set(false);
    }
  }

  async confirmarCambioEstado(v: Vigilante): Promise<void> {
    const darDeBaja = v.activo;
    const res = await Swal.fire({
      title: darDeBaja ? '¿Dar de baja a este vigilante?' : '¿Reactivar a este vigilante?',
      text: `${v.nombre} ${v.apellidos}`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: darDeBaja ? '#EF4444' : '#059669',
      cancelButtonColor: '#64748B',
      confirmButtonText: darDeBaja ? 'Dar de baja' : 'Reactivar',
      cancelButtonText: 'Cancelar'
    });

    if (res.isConfirmed) {
      await this.vigilantesService.cambiarEstado(v.id, !darDeBaja);
    }
  }
}
