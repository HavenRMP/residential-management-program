import { Component, inject, signal, computed, OnInit } from '@angular/core';
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
      <nav class="flex items-center gap-2 text-xs text-slate-500 font-medium">
        <a routerLink="/dashboard/admin" class="hover:text-slate-900 transition-colors">Panel</a>
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
            <span *ngIf="condominioActual()" class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium bg-slate-100 text-slate-700 border border-slate-200">
              {{ condominioActual()?.nombre }}
            </span>
          </div>
          <p class="text-xs text-slate-500 mt-1">
            Comunicados y avisos operativos para los residentes.
          </p>
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <button
            type="button"
            (click)="recargar(true)"
            [disabled]="avisosService.isLoading()"
            title="Actualizar"
            class="h-9 w-9 inline-flex items-center justify-center rounded-md border border-slate-200 bg-white text-slate-600 hover:bg-slate-50 hover:text-slate-900 transition-colors cursor-pointer disabled:opacity-50"
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
            class="h-9 px-3.5 inline-flex items-center gap-2 rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            <span>Publicar aviso</span>
          </button>
        </div>
      </div>

      <!-- Controls: Spartan Tabs & Filters -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-1">
        <!-- Tabs Spartan UI -->
        <div class="inline-flex h-9 items-center rounded-lg bg-slate-100 p-1 text-xs text-slate-500">
          <button
            type="button"
            (click)="tabActiva.set('vigentes')"
            [class.bg-white]="tabActiva() === 'vigentes'"
            [class.text-slate-900]="tabActiva() === 'vigentes'"
            [class.shadow-2xs]="tabActiva() === 'vigentes'"
            [class.font-semibold]="tabActiva() === 'vigentes'"
            class="px-3 py-1 rounded-md transition-all cursor-pointer flex items-center gap-1.5"
          >
            <span>Vigentes</span>
            <span class="text-[10px] px-1.5 py-0.2 rounded-full font-mono bg-slate-200 text-slate-700">
              {{ avisosService.vigentes().length }}
            </span>
          </button>

          <button
            type="button"
            (click)="tabActiva.set('historial')"
            [class.bg-white]="tabActiva() === 'historial'"
            [class.text-slate-900]="tabActiva() === 'historial'"
            [class.shadow-2xs]="tabActiva() === 'historial'"
            [class.font-semibold]="tabActiva() === 'historial'"
            class="px-3 py-1 rounded-md transition-all cursor-pointer flex items-center gap-1.5"
          >
            <span>Historial</span>
            <span class="text-[10px] px-1.5 py-0.2 rounded-full font-mono bg-slate-200 text-slate-700">
              {{ avisosService.expirados().length }}
            </span>
          </button>
        </div>

        <!-- Filters -->
        <div class="flex items-center gap-2">
          <select
            [(ngModel)]="filtroPrioridad"
            class="h-9 text-xs rounded-md border border-slate-200 bg-white px-2.5 text-slate-700 font-medium focus:outline-none focus:ring-1 focus:ring-slate-900"
          >
            <option value="todas">Todas las prioridades</option>
            <option value="urgente">Urgente</option>
            <option value="mantenimiento">Mantenimiento</option>
            <option value="informativo">Informativo</option>
            <option value="evento">Evento</option>
          </select>

          <div class="relative">
            <input
              type="text"
              [(ngModel)]="busqueda"
              placeholder="Buscar..."
              class="h-9 text-xs rounded-md border border-slate-200 bg-white pl-8 pr-3 text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900 w-44 sm:w-56"
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
          class="rounded-lg border border-slate-200 bg-white p-4 shadow-2xs hover:border-slate-300 transition-colors flex flex-col justify-between"
        >
          <div>
            <div class="flex items-center justify-between gap-2 mb-2">
              <span
                class="inline-flex items-center px-2 py-0.5 rounded-md text-[11px] font-medium border"
                [ngClass]="getBadgeClass(aviso.prioridad)"
              >
                {{ getPrioridadLabel(aviso.prioridad) }}
              </span>

              <div class="flex items-center gap-1">
                <button
                  type="button"
                  (click)="abrirModalEditar(aviso)"
                  class="p-1 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded transition-colors cursor-pointer"
                  title="Editar"
                >
                  <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                </button>
                <button
                  type="button"
                  (click)="confirmarEliminar(aviso)"
                  class="p-1 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded transition-colors cursor-pointer"
                  title="Eliminar"
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
            <p class="text-xs text-slate-600 mt-1.5 leading-relaxed line-clamp-3">
              {{ aviso.contenido }}
            </p>
          </div>

          <div class="mt-4 pt-2.5 border-t border-slate-100 text-[11px] text-slate-400 flex items-center justify-between">
            <span>{{ aviso.creadoPorNombre || 'Administración' }}</span>
            <span [class.text-rose-600]="esVencido(aviso)">
              {{ tiempoRestante(aviso) }}
            </span>
          </div>
        </div>
      </div>

      <!-- Empty State -->
      <ng-template #emptyState>
        <div class="rounded-lg border border-dashed border-slate-200 bg-white p-8 text-center">
          <p class="text-xs font-medium text-slate-500">
            {{ tabActiva() === 'vigentes' ? 'No hay avisos vigentes en este momento.' : 'No hay avisos en el historial.' }}
          </p>
        </div>
      </ng-template>

    </div>

    <!-- Modal Spartan UI Dialog -->
    <div
      *ngIf="modalAbierto()"
      class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4"
    >
      <div class="bg-white rounded-lg max-w-md w-full p-5 shadow-lg border border-slate-200">
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 class="text-sm font-semibold text-slate-900">
            {{ modoEdicion() ? 'Editar aviso' : 'Publicar aviso' }}
          </h3>
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

        <form (ngSubmit)="guardarAviso()" class="mt-3.5 space-y-3">
          <!-- Titulo -->
          <div>
            <label class="block text-xs font-medium text-slate-700 mb-1">
              Título
            </label>
            <input
              type="text"
              [(ngModel)]="formAviso.titulo"
              name="titulo"
              required
              placeholder="Asunto o tema principal"
              class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
            />
          </div>

          <!-- Prioridad (Spartan Segmented Control) -->
          <div>
            <label class="block text-xs font-medium text-slate-700 mb-1">
              Prioridad
            </label>
            <div class="grid grid-cols-4 gap-1.5 p-1 bg-slate-100 rounded-md">
              <button
                type="button"
                (click)="formAviso.prioridad = 'informativo'"
                [class.bg-white]="formAviso.prioridad === 'informativo'"
                [class.text-slate-900]="formAviso.prioridad === 'informativo'"
                [class.shadow-2xs]="formAviso.prioridad === 'informativo'"
                [class.font-semibold]="formAviso.prioridad === 'informativo'"
                class="py-1 rounded text-[11px] text-slate-600 text-center transition-all cursor-pointer"
              >
                Informativo
              </button>
              <button
                type="button"
                (click)="formAviso.prioridad = 'urgente'"
                [class.bg-white]="formAviso.prioridad === 'urgente'"
                [class.text-rose-700]="formAviso.prioridad === 'urgente'"
                [class.shadow-2xs]="formAviso.prioridad === 'urgente'"
                [class.font-semibold]="formAviso.prioridad === 'urgente'"
                class="py-1 rounded text-[11px] text-slate-600 text-center transition-all cursor-pointer"
              >
                Urgente
              </button>
              <button
                type="button"
                (click)="formAviso.prioridad = 'mantenimiento'"
                [class.bg-white]="formAviso.prioridad === 'mantenimiento'"
                [class.text-amber-700]="formAviso.prioridad === 'mantenimiento'"
                [class.shadow-2xs]="formAviso.prioridad === 'mantenimiento'"
                [class.font-semibold]="formAviso.prioridad === 'mantenimiento'"
                class="py-1 rounded text-[11px] text-slate-600 text-center transition-all cursor-pointer"
              >
                Mantenim.
              </button>
              <button
                type="button"
                (click)="formAviso.prioridad = 'evento'"
                [class.bg-white]="formAviso.prioridad === 'evento'"
                [class.text-indigo-700]="formAviso.prioridad === 'evento'"
                [class.shadow-2xs]="formAviso.prioridad === 'evento'"
                [class.font-semibold]="formAviso.prioridad === 'evento'"
                class="py-1 rounded text-[11px] text-slate-600 text-center transition-all cursor-pointer"
              >
                Evento
              </button>
            </div>
          </div>

          <!-- Contenido -->
          <div>
            <label class="block text-xs font-medium text-slate-700 mb-1">
              Detalle
            </label>
            <textarea
              [(ngModel)]="formAviso.contenido"
              name="contenido"
              rows="3"
              required
              placeholder="Descripción del comunicado..."
              class="w-full text-xs rounded-md border border-slate-200 bg-white p-2.5 text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900"
            ></textarea>
          </div>

          <!-- Vigencia -->
          <div>
            <label class="block text-xs font-medium text-slate-700 mb-1">
              Vigencia
            </label>
            <select
              [(ngModel)]="formAviso.diasVigencia"
              name="diasVigencia"
              class="h-9 w-full text-xs rounded-md border border-slate-200 bg-white px-2.5 text-slate-900 focus:outline-none focus:ring-1 focus:ring-slate-900"
            >
              <option [ngValue]="3">3 días</option>
              <option [ngValue]="7">7 días (1 semana)</option>
              <option [ngValue]="15">15 días</option>
              <option [ngValue]="30">30 días</option>
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
              [disabled]="!formAviso.titulo || !formAviso.contenido"
              class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50"
            >
              {{ modoEdicion() ? 'Guardar' : 'Publicar' }}
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
  avisoEditandoId: string | null = null;

  formAviso: CrearAvisoDto = {
    titulo: '',
    contenido: '',
    prioridad: 'informativo',
    diasVigencia: 7
  };

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

    const q = this.busqueda.trim().toLowerCase();
    const prio = this.filtroPrioridad;

    return lista.filter(a => {
      const matchTexto = !q || a.titulo.toLowerCase().includes(q) || a.contenido.toLowerCase().includes(q);
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
      diasVigencia: 7
    };
    this.modalAbierto.set(true);
  }

  abrirModalEditar(aviso: Aviso): void {
    this.modoEdicion.set(true);
    this.avisoEditandoId = aviso.id;
    this.formAviso = {
      titulo: aviso.titulo,
      contenido: aviso.contenido,
      prioridad: aviso.prioridad,
      diasVigencia: 7
    };
    this.modalAbierto.set(true);
  }

  cerrarModal(): void {
    this.modalAbierto.set(false);
  }

  async guardarAviso(): Promise<void> {
    if (!this.formAviso.titulo || !this.formAviso.contenido) return;

    try {
      if (this.modoEdicion() && this.avisoEditandoId) {
        await this.avisosService.actualizar(this.avisoEditandoId, {
          titulo: this.formAviso.titulo,
          contenido: this.formAviso.contenido,
          duracion_dias: this.formAviso.diasVigencia || 7
        });
        Swal.fire({
          icon: 'success',
          title: 'Aviso actualizado',
          text: 'El comunicado se actualizó con éxito.',
          timer: 2000,
          showConfirmButton: false
        });
      } else {
        const cond = this.condominioActual();
        await this.avisosService.crear({
          titulo: this.formAviso.titulo,
          contenido: this.formAviso.contenido,
          duracion_dias: this.formAviso.diasVigencia || 7
        }, cond?.id);
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
        return 'bg-rose-50 text-rose-700 border-rose-200';
      case 'mantenimiento':
        return 'bg-amber-50 text-amber-700 border-amber-200';
      case 'evento':
        return 'bg-indigo-50 text-indigo-700 border-indigo-200';
      case 'informativo':
      default:
        return 'bg-slate-100 text-slate-800 border-slate-200';
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
