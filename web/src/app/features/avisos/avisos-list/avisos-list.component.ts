import { Component, inject, signal, computed, OnInit, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { AvisosService } from '../../../core/services/avisos.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { AuthService } from '../../../core/services/auth.service';
import { Aviso, AvisoPrioridad, CrearAvisoDto } from '../../../core/models/aviso.model';

@Component({
  selector: 'app-avisos-list',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <div class="p-4 sm:p-6 max-w-7xl mx-auto space-y-4">

      <!-- Breadcrumb -->
      <nav class="flex items-center gap-2 text-xs text-slate-600 font-semibold">
        <a routerLink="/dashboard/admin" class="hover:text-slate-900 transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] rounded">Panel</a>
        <span>/</span>
        <span class="text-slate-900">Avisos</span>
      </nav>

      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200">
        <div>
          <div class="flex items-center gap-2.5">
            <h1 class="text-2xl font-bold tracking-tight text-slate-900">
              Tablón de avisos
            </h1>
            <span *ngIf="condominioActual()" class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-semibold bg-slate-200 text-slate-800 border border-slate-300">
              {{ condominioActual()?.nombre }}
            </span>
          </div>
          <p class="text-xs text-slate-600 mt-1 font-medium">
            Comunicados y avisos operativos para los residentes.
          </p>
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <button
            type="button"
            (click)="recargar(true)"
            [disabled]="avisosService.isLoading()"
            title="Actualizar"
            aria-label="Actualizar avisos"
            class="h-9 w-9 inline-flex items-center justify-center rounded-md border border-slate-300 bg-white text-slate-700 hover:bg-slate-50 hover:text-slate-900 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] transition-colors cursor-pointer disabled:opacity-50"
          >
            <svg
              [class.animate-spin]="avisosService.isLoading()"
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>

          <button
            type="button"
            (click)="abrirModalCrear()"
            class="h-9 px-3.5 inline-flex items-center gap-2 rounded-md bg-[#111C99] hover:bg-[#0d1577] focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#111C99] text-white text-xs font-semibold transition-colors shadow-2xs cursor-pointer"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            <span>Nuevo aviso</span>
          </button>
        </div>
      </div>

      <!-- Toolbar: Tabs + Search & Filters Spartan UI -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-1">
        
        <!-- Segmented Tab Control -->
        <div class="flex items-center p-1 bg-slate-200/80 rounded-lg text-xs font-semibold text-slate-700 w-fit">
          <button
            type="button"
            (click)="tabActiva.set('vigentes')"
            [class.bg-white]="tabActiva() === 'vigentes'"
            [class.text-slate-900]="tabActiva() === 'vigentes'"
            [class.shadow-2xs]="tabActiva() === 'vigentes'"
            class="px-3 py-1 rounded-md transition-all cursor-pointer flex items-center gap-1.5 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
          >
            <span>Vigentes</span>
            <span class="text-[10px] px-1.5 py-0.2 rounded-full font-mono bg-slate-100 text-slate-800 border border-slate-200">
              {{ avisosService.vigentes().length }}
            </span>
          </button>
          
          <button
            type="button"
            (click)="tabActiva.set('historial')"
            [class.bg-white]="tabActiva() === 'historial'"
            [class.text-slate-900]="tabActiva() === 'historial'"
            [class.shadow-2xs]="tabActiva() === 'historial'"
            class="px-3 py-1 rounded-md transition-all cursor-pointer flex items-center gap-1.5 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
          >
            <span>Historial</span>
            <span class="text-[10px] px-1.5 py-0.2 rounded-full font-mono bg-slate-100 text-slate-800 border border-slate-200">
              {{ avisosService.expirados().length }}
            </span>
          </button>
        </div>

        <!-- Search -->
        <div class="flex items-center gap-2">
          <div class="relative">
            <input
              type="text"
              [(ngModel)]="busqueda"
              placeholder="Buscar..."
              aria-label="Buscar aviso"
              class="h-9 text-xs rounded-lg border border-slate-300 bg-white pl-8 pr-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99] w-44 sm:w-56"
            />
            <svg class="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-2.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </div>
        </div>
      </div>

      <!-- Card Grid Spartan UI -->
      <div *ngIf="avisosFiltrados().length > 0; else emptyState" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        <div
          *ngFor="let aviso of avisosFiltrados()"
          class="rounded-xl border border-slate-200/90 bg-white p-4 shadow-xs hover:border-slate-300 transition-colors flex flex-col justify-between"
        >
          <div>
            <div class="flex items-center justify-between gap-2 mb-2">
              <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-[11px] font-semibold bg-slate-100 text-slate-700 border border-slate-200">
                <svg class="w-3 h-3 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" />
                </svg>
                <span>Comunicado</span>
              </span>

              <div class="flex items-center gap-1">
                <button
                  type="button"
                  (click)="abrirModalEditar(aviso)"
                  class="p-1 text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
                  title="Editar"
                  aria-label="Editar aviso"
                >
                  <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                </button>
                <button
                  type="button"
                  (click)="confirmarEliminar(aviso)"
                  class="p-1 text-slate-500 hover:text-rose-600 hover:bg-rose-50 rounded transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-rose-600"
                  title="Eliminar"
                  aria-label="Eliminar aviso"
                >
                  <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </div>

            <h3 class="text-sm font-semibold text-slate-900 leading-snug">
              {{ aviso.titulo }}
            </h3>
            <p class="text-xs text-slate-700 mt-1.5 leading-relaxed line-clamp-3 font-normal">
              {{ aviso.contenido }}
            </p>
          </div>

          <div class="mt-4 pt-2.5 border-t border-slate-200 text-[11px] font-medium text-slate-600 flex items-center justify-between">
            <span>{{ aviso.creadoPorNombre || 'Administración' }}</span>
            <span [class.text-rose-600]="esVencido(aviso)" [class.font-semibold]="esVencido(aviso)">
              {{ tiempoRestante(aviso) }}
            </span>
          </div>
        </div>
      </div>

      <!-- Empty State -->
      <ng-template #emptyState>
        <div class="rounded-xl border border-dashed border-slate-300 bg-white p-8 text-center">
          <p class="text-xs font-semibold text-slate-600">
            {{ tabActiva() === 'vigentes' ? 'No hay avisos vigentes en este momento.' : 'No hay avisos en el historial.' }}
          </p>
        </div>
      </ng-template>

    </div>

    <!-- Modal Spartan UI Dialog -->
    <div
      *ngIf="modalAbierto()"
      class="fixed inset-0 z-50 overflow-y-auto bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4"
    >
      <div class="bg-white rounded-xl max-w-md w-full p-5 shadow-lg border border-slate-200">
        <div class="flex items-center justify-between pb-3 border-b border-slate-200">
          <h3 class="text-sm font-semibold text-slate-900">
            {{ modoEdicion() ? 'Editar aviso' : 'Publicar aviso' }}
          </h3>
          <button
            type="button"
            (click)="cerrarModal()"
            class="text-slate-500 hover:text-slate-700 p-1 rounded-lg focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] cursor-pointer"
            aria-label="Cerrar ventana modal"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form (ngSubmit)="guardarAviso()" class="mt-3.5 space-y-3">
          <!-- Titulo -->
          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">
              Título
            </label>
            <input
              type="text"
              [(ngModel)]="formAviso.titulo"
              name="titulo"
              required
              placeholder="Asunto o tema principal"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
            />
          </div>

          <!-- Contenido -->
          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">
              Detalle
            </label>
            <textarea
              [(ngModel)]="formAviso.contenido"
              name="contenido"
              rows="3"
              required
              placeholder="Descripción del comunicado..."
              class="w-full text-xs rounded-lg border border-slate-300 bg-white p-2.5 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
            ></textarea>
          </div>

          <!-- Vigencia del comunicado -->
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <label class="block text-xs font-semibold text-slate-800">
                Vigencia del comunicado
              </label>
              <!-- Selector de modo: Por días vs Fecha exacta -->
              <div class="inline-flex rounded-lg bg-slate-100 p-0.5 border border-slate-200" role="group" aria-label="Modo de vigencia">
                <button
                  type="button"
                  (click)="seleccionarModoVigencia('dias')"
                  [class.bg-white]="formAviso.tipoVigencia === 'dias'"
                  [class.text-[#111C99]]="formAviso.tipoVigencia === 'dias'"
                  [class.shadow-2xs]="formAviso.tipoVigencia === 'dias'"
                  [class.font-semibold]="formAviso.tipoVigencia === 'dias'"
                  [class.text-slate-600]="formAviso.tipoVigencia !== 'dias'"
                  class="px-2.5 py-1 text-[11px] rounded-md transition-all cursor-pointer"
                >
                  Por días
                </button>
                <button
                  type="button"
                  (click)="seleccionarModoVigencia('fecha')"
                  [class.bg-white]="formAviso.tipoVigencia === 'fecha'"
                  [class.text-[#111C99]]="formAviso.tipoVigencia === 'fecha'"
                  [class.shadow-2xs]="formAviso.tipoVigencia === 'fecha'"
                  [class.font-semibold]="formAviso.tipoVigencia === 'fecha'"
                  [class.text-slate-600]="formAviso.tipoVigencia !== 'fecha'"
                  class="px-2.5 py-1 text-[11px] rounded-md transition-all cursor-pointer"
                >
                  Fecha en calendario
                </button>
              </div>
            </div>

            <!-- Modo 1: Por días -->
            <div *ngIf="formAviso.tipoVigencia === 'dias'" class="space-y-2">
              <div class="grid grid-cols-4 gap-1.5">
                <button
                  *ngFor="let d of [3, 7, 15, 30]"
                  type="button"
                  (click)="setPresetDias(d)"
                  [class.bg-[#111C99]]="!formAviso.esDiasPersonalizado && formAviso.diasVigencia === d"
                  [class.text-white]="!formAviso.esDiasPersonalizado && formAviso.diasVigencia === d"
                  [class.border-[#111C99]]="!formAviso.esDiasPersonalizado && formAviso.diasVigencia === d"
                  [class.bg-slate-50]="formAviso.esDiasPersonalizado || formAviso.diasVigencia !== d"
                  [class.text-slate-700]="formAviso.esDiasPersonalizado || formAviso.diasVigencia !== d"
                  [class.border-slate-200]="formAviso.esDiasPersonalizado || formAviso.diasVigencia !== d"
                  class="py-1.5 px-2 rounded-lg border text-xs font-medium transition-all text-center cursor-pointer hover:border-slate-300"
                >
                  {{ d }} días
                </button>
              </div>

              <!-- Duración personalizada -->
              <div class="flex items-center gap-2 pt-0.5">
                <label class="text-[11px] text-slate-500 whitespace-nowrap">O duración exacta:</label>
                <div class="relative flex-1">
                  <input
                    type="number"
                    min="1"
                    max="365"
                    [(ngModel)]="formAviso.diasVigencia"
                    (input)="formAviso.esDiasPersonalizado = true"
                    name="diasVigenciaNum"
                    placeholder="1 - 365"
                    class="h-8 w-full text-xs rounded-lg border border-slate-300 bg-white px-2.5 pr-12 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
                  />
                  <span class="absolute right-2.5 top-2 text-[11px] text-slate-400 pointer-events-none">días</span>
                </div>
              </div>
            </div>

            <!-- Modo 2: Fecha calendario -->
            <div *ngIf="formAviso.tipoVigencia === 'fecha'" class="space-y-1.5">
              <input
                type="date"
                [(ngModel)]="formAviso.fechaExpiracion"
                [min]="minFechaExpiracion"
                name="fechaExpiracion"
                required
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-2.5 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
              />
              <p class="text-[11px] text-slate-500 leading-tight">
                El comunicado se mantendrá activo hasta las 23:59 hrs del día seleccionado (permite desde hoy en adelante).
              </p>
            </div>
          </div>

          <div class="pt-3 border-t border-slate-200 flex items-center justify-end gap-2">
            <button
              type="button"
              (click)="cerrarModal()"
              class="h-8 px-3 text-xs font-medium text-slate-700 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
            >
              Cancelar
            </button>
            <button
              type="submit"
              [disabled]="isSaving() || !isFormValido"
              class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#111C99] text-white rounded-lg text-xs font-semibold shadow-2xs transition-colors cursor-pointer disabled:opacity-50 inline-flex items-center gap-1.5"
            >
              <svg *ngIf="isSaving()" class="animate-spin -ml-0.5 mr-1 h-3.5 w-3.5 text-white" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span>{{ isSaving() ? 'Guardando...' : (modoEdicion() ? 'Guardar' : 'Publicar') }}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  `
})
export class AvisosListComponent implements OnInit {
  readonly avisosService = inject(AvisosService);
  readonly condominiosService = inject(CondominiosService);
  readonly authService = inject(AuthService);

  readonly condominioActual = this.condominiosService.condominioActual;

  tabActiva = signal<'vigentes' | 'historial'>('vigentes');
  readonly _filtroPrioridad = signal<string>('todas');
  get filtroPrioridad(): string {
    return this._filtroPrioridad();
  }
  set filtroPrioridad(val: string) {
    this._filtroPrioridad.set(val);
  }

  readonly _busqueda = signal<string>('');
  get busqueda(): string {
    return this._busqueda();
  }
  set busqueda(val: string) {
    this._busqueda.set(val);
  }

  modalAbierto = signal<boolean>(false);
  modoEdicion = signal<boolean>(false);
  readonly isSaving = signal<boolean>(false);
  avisoEditandoId: string | null = null;

  @HostListener('document:keydown.escape')
  onEscape(): void {
    if (this.modalAbierto() && !this.isSaving()) {
      this.cerrarModal();
    }
  }

  formAviso = {
    titulo: '',
    contenido: '',
    prioridad: 'informativo' as AvisoPrioridad,
    tipoVigencia: 'dias' as 'dias' | 'fecha',
    diasVigencia: 7,
    esDiasPersonalizado: false,
    fechaExpiracion: ''
  };

  get minFechaExpiracion(): string {
    const hoy = new Date();
    const y = hoy.getFullYear();
    const m = String(hoy.getMonth() + 1).padStart(2, '0');
    const d = String(hoy.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  get isFormValido(): boolean {
    if (!this.formAviso.titulo?.trim() || !this.formAviso.contenido?.trim()) return false;
    if (this.formAviso.tipoVigencia === 'fecha') {
      return !!this.formAviso.fechaExpiracion && this.formAviso.fechaExpiracion >= this.minFechaExpiracion;
    }
    const d = Number(this.formAviso.diasVigencia);
    return !isNaN(d) && d >= 1 && d <= 365;
  }

  seleccionarModoVigencia(modo: 'dias' | 'fecha'): void {
    this.formAviso.tipoVigencia = modo;
    if (modo === 'fecha' && !this.formAviso.fechaExpiracion) {
      this.formAviso.fechaExpiracion = this.minFechaExpiracion;
    }
  }

  setPresetDias(dias: number): void {
    this.formAviso.diasVigencia = dias;
    this.formAviso.esDiasPersonalizado = false;
  }

  ngOnInit(): void {
    this.recargar();
  }

  async recargar(forceRefresh: boolean = false): Promise<void> {
    const cond = this.condominioActual();
    await this.avisosService.cargarAvisos(cond?.id, forceRefresh);
  }

  readonly avisosFiltrados = computed(() => {
    const lista = this.tabActiva() === 'vigentes'
      ? this.avisosService.vigentes()
      : this.avisosService.expirados();

    const normalizar = (texto: string) =>
      texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim().toLowerCase();

    const q = normalizar(this.busqueda);
    const prio = this.filtroPrioridad;

    return lista.filter(a => {
      const matchTexto = !q || normalizar(a.titulo).includes(q) || normalizar(a.contenido).includes(q);
      const matchPrio = prio === 'todas' || a.prioridad === prio;
      return matchTexto && matchPrio;
    });
  });

  abrirModalCrear(): void {
    this.modoEdicion.set(false);
    this.avisoEditandoId = null;
    this.formAviso = {
      titulo: '',
      contenido: '',
      prioridad: 'informativo',
      tipoVigencia: 'dias',
      diasVigencia: 7,
      esDiasPersonalizado: false,
      fechaExpiracion: this.minFechaExpiracion
    };
    this.modalAbierto.set(true);
  }

  abrirModalEditar(aviso: Aviso): void {
    this.modoEdicion.set(true);
    this.avisoEditandoId = aviso.id;

    if (aviso.duracionDias) {
      const presets = [3, 7, 15, 30];
      this.formAviso = {
        titulo: aviso.titulo,
        contenido: aviso.contenido,
        prioridad: aviso.prioridad,
        tipoVigencia: 'dias',
        diasVigencia: aviso.duracionDias,
        esDiasPersonalizado: !presets.includes(aviso.duracionDias),
        fechaExpiracion: aviso.fechaExpiracion ? aviso.fechaExpiracion.split('T')[0] : this.minFechaExpiracion
      };
    } else {
      const fechaStr = aviso.fechaExpiracion ? aviso.fechaExpiracion.split('T')[0] : this.minFechaExpiracion;
      this.formAviso = {
        titulo: aviso.titulo,
        contenido: aviso.contenido,
        prioridad: aviso.prioridad,
        tipoVigencia: 'fecha',
        diasVigencia: 7,
        esDiasPersonalizado: false,
        fechaExpiracion: fechaStr
      };
    }
    this.modalAbierto.set(true);
  }

  cerrarModal(): void {
    this.modalAbierto.set(false);
  }

  async guardarAviso(): Promise<void> {
    if (this.isSaving() || !this.isFormValido) return;

    let payload: { titulo: string; contenido: string; duracion_dias?: number; fecha_expiracion?: string };

    if (this.formAviso.tipoVigencia === 'fecha') {
      if (!this.formAviso.fechaExpiracion) {
        Swal.fire({
          icon: 'warning',
          title: 'Fecha requerida',
          text: 'Por favor selecciona la fecha de expiración del aviso.',
          confirmButtonColor: '#111C99'
        });
        return;
      }

      if (this.formAviso.fechaExpiracion < this.minFechaExpiracion) {
        Swal.fire({
          icon: 'warning',
          title: 'Fecha no válida',
          text: 'No es posible seleccionar una fecha anterior al día de hoy.',
          confirmButtonColor: '#111C99'
        });
        return;
      }

      const [y, m, d] = this.formAviso.fechaExpiracion.split('-').map(Number);
      const finDia = new Date(y, m - 1, d, 23, 59, 59, 999);

      if (finDia.getTime() <= Date.now()) {
        Swal.fire({
          icon: 'warning',
          title: 'Fecha no válida',
          text: 'La fecha y hora de expiración debe ser posterior al momento actual.',
          confirmButtonColor: '#111C99'
        });
        return;
      }

      payload = {
        titulo: this.formAviso.titulo.trim(),
        contenido: this.formAviso.contenido.trim(),
        fecha_expiracion: finDia.toISOString()
      };
    } else {
      const dias = Number(this.formAviso.diasVigencia);
      if (!dias || dias < 1 || dias > 365) {
        Swal.fire({
          icon: 'warning',
          title: 'Días no válidos',
          text: 'La vigencia en días debe ser un número entero entre 1 y 365.',
          confirmButtonColor: '#111C99'
        });
        return;
      }

      payload = {
        titulo: this.formAviso.titulo.trim(),
        contenido: this.formAviso.contenido.trim(),
        duracion_dias: Math.floor(dias)
      };
    }

    this.isSaving.set(true);
    try {
      if (this.modoEdicion() && this.avisoEditandoId) {
        await this.avisosService.actualizar(this.avisoEditandoId, payload);
        Swal.fire({
          icon: 'success',
          title: 'Aviso actualizado',
          text: 'El comunicado se actualizó con éxito.',
          timer: 2000,
          showConfirmButton: false
        });
      } else {
        const cond = this.condominioActual();
        await this.avisosService.crear(payload, cond?.id);
        Swal.fire({
          icon: 'success',
          title: 'Aviso publicado',
          text: 'El comunicado ya está visible en el tablón del condominio.',
          timer: 2000,
          showConfirmButton: false
        });
      }

      this.cerrarModal();
      await this.recargar();
    } catch (err: any) {
      const msg = err?.error?.error || err?.error?.message || err?.message || 'No fue posible guardar el aviso.';
      Swal.fire({
        icon: 'error',
        title: 'Error al guardar',
        text: msg,
        confirmButtonColor: '#111C99'
      });
    } finally {
      this.isSaving.set(false);
    }
  }

  async confirmarEliminar(aviso: Aviso): Promise<void> {
    const res = await Swal.fire({
      title: '¿Dar de baja este aviso?',
      text: `Se retirará "${aviso.titulo}" del tablón visible para los residentes.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Sí, dar de baja',
      cancelButtonText: 'Cancelar'
    });

    if (res.isConfirmed) {
      try {
        await this.avisosService.eliminar(aviso.id);
        Swal.fire({
          icon: 'success',
          title: 'Aviso retirado',
          text: 'El aviso fue dado de baja correctamente.',
          timer: 1800,
          showConfirmButton: false
        });
        await this.recargar();
      } catch (err: any) {
        const msg = err?.error?.error || err?.error?.message || err?.message || 'No se pudo eliminar el aviso.';
        Swal.fire({
          icon: 'error',
          title: 'Error al eliminar',
          text: msg,
          confirmButtonColor: '#111C99'
        });
      }
    }
  }

  getBadgeClass(prioridad: AvisoPrioridad): string {
    switch (prioridad) {
      case 'urgente':
        return 'bg-rose-50 text-rose-800 border-rose-300';
      case 'mantenimiento':
        return 'bg-amber-50 text-amber-800 border-amber-300';
      case 'evento':
        return 'bg-indigo-50 text-indigo-800 border-indigo-300';
      case 'informativo':
      default:
        return 'bg-slate-100 text-slate-800 border-slate-300';
    }
  }

  getPrioridadLabel(prioridad: AvisoPrioridad): string {
    switch (prioridad) {
      case 'urgente': return 'Urgente';
      case 'mantenimiento': return 'Mantenimiento';
      case 'evento': return 'Evento';
      case 'informativo':
      default: return 'Informativo';
    }
  }

  esVencido(aviso: Aviso): boolean {
    return new Date(aviso.fechaExpiracion).getTime() < Date.now();
  }

  tiempoRestante(aviso: Aviso): string {
    const diff = new Date(aviso.fechaExpiracion).getTime() - Date.now();
    if (diff <= 0) return 'Expirado';

    const dias = Math.ceil(diff / (1000 * 60 * 60 * 24));
    return dias === 1 ? '1 día restante' : `${dias} días restantes`;
  }
}
