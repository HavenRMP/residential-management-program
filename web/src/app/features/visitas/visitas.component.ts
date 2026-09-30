import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { AuthService } from '../../core/services/auth.service';
import { ViviendasService } from '../../core/services/viviendas.service';
import { VisitasService } from '../../core/services/visitas.service';
import {
  ActualizarVisitaDto,
  CrearVisitaDto,
  EstadoVisita,
  MOTIVOS_VISITA,
  MotivoVisita,
  Visita
} from '../../core/models/visita.model';
import { UserMenuComponent } from '../../core/components/user-menu/user-menu.component';

const FILTROS: { valor: EstadoVisita | null; etiqueta: string }[] = [
  { valor: null, etiqueta: 'Todas' },
  { valor: 'programada', etiqueta: 'Programadas' },
  { valor: 'en_curso', etiqueta: 'En curso' },
  { valor: 'finalizada', etiqueta: 'Finalizadas' },
  { valor: 'cancelada', etiqueta: 'Canceladas' },
  { valor: 'expirada', etiqueta: 'Expiradas' }
];

const ETIQUETAS_ESTADO: Record<EstadoVisita, string> = {
  programada: 'Programada',
  en_curso: 'En curso',
  finalizada: 'Finalizada',
  cancelada: 'Cancelada',
  expirada: 'Expirada'
};

const CLASES_ESTADO: Record<EstadoVisita, string> = {
  programada: 'bg-indigo-50 text-indigo-700 border-indigo-200',
  en_curso: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  finalizada: 'bg-slate-100 text-slate-700 border-slate-200',
  cancelada: 'bg-rose-50 text-rose-700 border-rose-200',
  expirada: 'bg-amber-50 text-amber-700 border-amber-200'
};

interface FormularioVisita {
  nombreVisitante: string;
  apellidosVisitante: string;
  telefonoVisitante: string;
  motivo: MotivoVisita;
  numAcompanantes: number;
  vehiculoPlacas: string;
  notas: string;
  /** Valor del input datetime-local (hora local, sin zona) */
  fechaLlegada: string;
  horasVigencia: number;
}

/** Convierte una fecha ISO a formato yyyy-MM-ddTHH:mm en hora local para un input datetime-local */
function isoAInputLocal(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

@Component({
  selector: 'app-visitas',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, UserMenuComponent],
  template: `
    <div class="min-h-screen bg-[#F8FAFC] text-slate-900 font-sans antialiased">

      <header class="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-2xs">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <a
              routerLink="/dashboard/residente"
              class="h-8 w-8 inline-flex items-center justify-center text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-md transition-colors cursor-pointer"
              title="Volver"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
            </a>
            <div class="flex items-center gap-2">
              <span class="font-bold text-base tracking-tight text-slate-900">Visitas</span>
              <span class="text-[11px] font-medium px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 border border-slate-200">
                Gestión
              </span>
            </div>
          </div>

          <app-user-menu [user]="currentUser()" (logout)="onLogout()" />
        </div>
      </header>

      <main class="max-w-4xl mx-auto px-4 sm:px-6 py-6 space-y-6">

        <nav class="flex items-center gap-2 text-xs text-slate-500 font-medium">
          <a routerLink="/dashboard/residente" class="hover:text-slate-900 transition-colors">Portal</a>
          <span>/</span>
          <span class="text-slate-900">Visitas</span>
        </nav>

        <!-- Sin vivienda asignada -->
        <div *ngIf="!isLoadingVivienda() && !viviendaId()" class="rounded-lg border border-slate-200 bg-white p-8 text-center shadow-2xs space-y-2">
          <h2 class="text-base font-semibold text-slate-900">Necesitas una vivienda asignada</h2>
          <p class="text-xs text-slate-500 max-w-md mx-auto">
            Vincula tu cuenta a una vivienda desde el portal para poder programar visitas.
          </p>
          <a routerLink="/dashboard/residente" class="h-8 px-4 inline-flex items-center justify-center rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs mt-2">
            Volver al portal
          </a>
        </div>

        <section *ngIf="viviendaId()" class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Mis visitas</h2>
              <p class="text-xs text-slate-500 mt-0.5">
                Programa la llegada de tus invitados. Comparte el código de acceso para que caseta los deje pasar.
              </p>
            </div>

            <button
              type="button"
              (click)="abrirModalCrear()"
              class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer self-start sm:self-auto"
            >
              <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              <span>Programar visita</span>
            </button>
          </div>

          <!-- Filtro por estado -->
          <div class="flex flex-wrap items-center gap-1.5">
            <button
              *ngFor="let f of filtros"
              type="button"
              (click)="cambiarFiltro(f.valor)"
              class="h-7 px-2.5 rounded-md text-xs font-medium border transition-colors cursor-pointer"
              [class.bg-slate-900]="filtroActivo() === f.valor"
              [class.text-white]="filtroActivo() === f.valor"
              [class.border-slate-900]="filtroActivo() === f.valor"
              [class.bg-white]="filtroActivo() !== f.valor"
              [class.text-slate-600]="filtroActivo() !== f.valor"
              [class.border-slate-200]="filtroActivo() !== f.valor"
            >
              {{ f.etiqueta }}
            </button>
          </div>

          <div *ngIf="visitasService.isLoading()" class="space-y-2">
            <div *ngFor="let s of [1, 2]" class="p-4 rounded-md bg-white border border-slate-200 animate-pulse h-20"></div>
          </div>

          <div *ngIf="visitasService.errorMessage() as msg" class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium">
            {{ msg }}
          </div>

          <div
            *ngIf="!visitasService.isLoading() && !visitasService.errorMessage() && visitasService.items().length === 0"
            class="py-10 text-center text-xs text-slate-500 font-medium"
          >
            {{ filtroActivo() ? 'No hay visitas con este estado.' : 'Todavía no has programado ninguna visita.' }}
          </div>

          <ul *ngIf="!visitasService.isLoading()" class="space-y-2">
            <li
              *ngFor="let v of visitasService.items()"
              class="p-4 rounded-md border border-slate-200 bg-white flex flex-col sm:flex-row sm:items-start justify-between gap-3"
            >
              <div class="min-w-0 space-y-1">
                <div class="flex flex-wrap items-center gap-2">
                  <p class="text-sm font-semibold text-slate-900">{{ v.nombreVisitante }} {{ v.apellidosVisitante }}</p>
                  <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="claseEstado(v.estado)">
                    {{ etiquetaEstado(v.estado) }}
                  </span>
                  <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">
                    {{ etiquetaMotivo(v.motivo) }}
                  </span>
                </div>
                <p class="text-xs text-slate-600">
                  Llegada: {{ formatearFecha(v.fechaLlegadaEsperada) }} · Vigente hasta {{ formatearFecha(v.vigenciaHasta) }}
                </p>
                <p class="text-xs text-slate-500">
                  <span *ngIf="v.numAcompanantes > 0">{{ v.numAcompanantes }} acompañante(s) · </span>
                  <span *ngIf="v.vehiculoPlacas">Placas {{ v.vehiculoPlacas }} · </span>
                  <span *ngIf="v.telefonoVisitante">Tel. {{ v.telefonoVisitante }}</span>
                </p>
                <p *ngIf="v.notas" class="text-xs text-slate-500 italic">{{ v.notas }}</p>
                <p *ngIf="v.horaEntrada" class="text-xs text-slate-500">
                  Entrada: {{ formatearFecha(v.horaEntrada) }}<span *ngIf="v.horaSalida"> · Salida: {{ formatearFecha(v.horaSalida) }}</span>
                </p>
              </div>

              <div class="flex flex-col items-start sm:items-end gap-2 shrink-0">
                <div *ngIf="v.codigo && (v.estado === 'programada' || v.estado === 'en_curso')" class="text-right">
                  <p class="text-[10px] uppercase tracking-wide font-semibold text-slate-500">Código de acceso</p>
                  <p class="font-mono text-base font-bold tracking-widest text-[#111C99]">{{ v.codigo }}</p>
                </div>

                <div *ngIf="v.estado === 'programada'" class="flex items-center gap-1.5">
                  <button
                    type="button"
                    (click)="abrirModalEditar(v)"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
                  >
                    Editar
                  </button>
                  <button
                    type="button"
                    (click)="confirmarCancelar(v)"
                    class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer"
                  >
                    Cancelar
                  </button>
                </div>
              </div>
            </li>
          </ul>

          <!-- Paginación -->
          <div *ngIf="totalPaginas() > 1" class="flex items-center justify-between pt-2 border-t border-slate-100">
            <button
              type="button"
              (click)="irAPagina(visitasService.page() - 1)"
              [disabled]="visitasService.page() <= 1"
              class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer"
            >
              Anterior
            </button>
            <span class="text-xs text-slate-500 font-medium">Página {{ visitasService.page() }} de {{ totalPaginas() }}</span>
            <button
              type="button"
              (click)="irAPagina(visitasService.page() + 1)"
              [disabled]="visitasService.page() >= totalPaginas()"
              class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 cursor-pointer"
            >
              Siguiente
            </button>
          </div>
        </section>
      </main>
    </div>

    <!-- Modal programar / editar visita -->
    <div
      *ngIf="modalAbierto()"
      class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4"
    >
      <div class="bg-white rounded-lg max-w-lg w-full p-5 shadow-lg border border-slate-200">
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 class="text-sm font-semibold text-slate-900">{{ visitaEditandoId() ? 'Editar visita' : 'Programar visita' }}</h3>
          <button type="button" (click)="cerrarModal()" class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-3.5 space-y-3">
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Nombre *</label>
              <input type="text" [(ngModel)]="form.nombreVisitante" maxlength="100" placeholder="Nombre"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Apellidos *</label>
              <input type="text" [(ngModel)]="form.apellidosVisitante" maxlength="100" placeholder="Apellidos"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Motivo *</label>
              <select [(ngModel)]="form.motivo"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
                <option *ngFor="let m of motivos" [value]="m.valor">{{ m.etiqueta }}</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Teléfono</label>
              <input type="tel" [(ngModel)]="form.telefonoVisitante" maxlength="20" placeholder="Opcional"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Llegada esperada *</label>
              <input type="datetime-local" [(ngModel)]="form.fechaLlegada"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Vigencia (horas) *</label>
              <input type="number" [(ngModel)]="form.horasVigencia" min="1" max="72"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
              <p class="mt-1 text-[11px] text-slate-500">Entre 1 y 72 horas.</p>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Acompañantes</label>
              <input type="number" [(ngModel)]="form.numAcompanantes" min="0" max="20"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-slate-800 mb-1">Placas del vehículo</label>
              <input type="text" [(ngModel)]="form.vehiculoPlacas" maxlength="15" placeholder="Opcional"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          </div>

          <div>
            <label class="block text-xs font-semibold text-slate-800 mb-1">Notas</label>
            <textarea [(ngModel)]="form.notas" maxlength="500" rows="2" placeholder="Opcional"
              class="w-full text-xs rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"></textarea>
          </div>

          <div class="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
            <button type="button" (click)="cerrarModal()"
              class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer">
              Cancelar
            </button>
            <button type="button" (click)="guardar()" [disabled]="isSaving() || !esFormularioValido()"
              class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50">
              {{ isSaving() ? 'Guardando...' : (visitaEditandoId() ? 'Guardar cambios' : 'Programar') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
})
export class VisitasComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly viviendasService = inject(ViviendasService);
  readonly visitasService = inject(VisitasService);

  readonly currentUser = this.authService.currentUser;
  readonly filtros = FILTROS;
  readonly motivos = MOTIVOS_VISITA;

  readonly isLoadingVivienda = signal<boolean>(true);
  readonly viviendaId = signal<number | null>(null);
  readonly filtroActivo = signal<EstadoVisita | null>(null);
  readonly modalAbierto = signal<boolean>(false);
  readonly isSaving = signal<boolean>(false);
  readonly visitaEditandoId = signal<string | null>(null);

  readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.visitasService.totalCount() / this.visitasService.PAGE_SIZE))
  );

  form: FormularioVisita = this.formularioVacio();
  /** Copia de la visita al abrir la edición, para enviar solo los campos que cambian */
  private visitaOriginal: Visita | null = null;

  async ngOnInit(): Promise<void> {
    this.isLoadingVivienda.set(true);
    try {
      const viviendas = await this.viviendasService.obtenerMisViviendas();
      const id = viviendas[0]?.id ?? null;
      this.viviendaId.set(id);
      if (id) {
        await this.visitasService.cargar();
      }
    } finally {
      this.isLoadingVivienda.set(false);
    }
  }

  onLogout(): void {
    this.authService.logout();
  }

  etiquetaEstado(estado: EstadoVisita): string {
    return ETIQUETAS_ESTADO[estado] ?? estado;
  }

  claseEstado(estado: EstadoVisita): string {
    return CLASES_ESTADO[estado] ?? 'bg-slate-100 text-slate-700 border-slate-200';
  }

  etiquetaMotivo(motivo: string): string {
    return MOTIVOS_VISITA.find(m => m.valor === motivo)?.etiqueta ?? motivo;
  }

  formatearFecha(iso: string | null | undefined): string {
    if (!iso) return '';
    return new Date(iso).toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'short' });
  }

  cambiarFiltro(estado: EstadoVisita | null): void {
    this.filtroActivo.set(estado);
    this.visitasService.cargar(estado, 1);
  }

  irAPagina(pagina: number): void {
    if (pagina < 1 || pagina > this.totalPaginas()) return;
    this.visitasService.cargar(this.filtroActivo(), pagina);
  }

  esFormularioValido(): boolean {
    const f = this.form;
    const vigencia = Number(f.horasVigencia);
    const acompanantes = Number(f.numAcompanantes);
    return !!(
      f.nombreVisitante.trim() &&
      f.apellidosVisitante.trim() &&
      f.motivo &&
      f.fechaLlegada &&
      vigencia >= 1 && vigencia <= 72 &&
      acompanantes >= 0 && acompanantes <= 20
    );
  }

  abrirModalCrear(): void {
    this.visitaEditandoId.set(null);
    this.visitaOriginal = null;
    this.form = this.formularioVacio();
    this.modalAbierto.set(true);
  }

  abrirModalEditar(v: Visita): void {
    this.visitaEditandoId.set(v.id);
    this.visitaOriginal = v;
    const horas = Math.round((new Date(v.vigenciaHasta).getTime() - new Date(v.fechaLlegadaEsperada).getTime()) / 3_600_000);
    this.form = {
      nombreVisitante: v.nombreVisitante,
      apellidosVisitante: v.apellidosVisitante,
      telefonoVisitante: v.telefonoVisitante ?? '',
      motivo: v.motivo,
      numAcompanantes: v.numAcompanantes,
      vehiculoPlacas: v.vehiculoPlacas ?? '',
      notas: v.notas ?? '',
      fechaLlegada: isoAInputLocal(v.fechaLlegadaEsperada),
      horasVigencia: Math.min(72, Math.max(1, horas))
    };
    this.modalAbierto.set(true);
  }

  cerrarModal(): void {
    this.modalAbierto.set(false);
  }

  async guardar(): Promise<void> {
    if (!this.esFormularioValido() || this.isSaving()) return;

    this.isSaving.set(true);
    try {
      const editandoId = this.visitaEditandoId();
      if (editandoId) {
        await this.guardarEdicion(editandoId);
      } else {
        await this.guardarNueva();
      }
    } catch (err: any) {
      console.error('[VisitasComponent] Error al guardar visita:', err);
      Swal.fire({
        icon: 'error',
        title: 'No se pudo guardar la visita',
        text: this.mensajeError(err),
        confirmButtonColor: '#111C99'
      });
    } finally {
      this.isSaving.set(false);
    }
  }

  async confirmarCancelar(v: Visita): Promise<void> {
    const res = await Swal.fire({
      title: '¿Cancelar esta visita?',
      text: `${v.nombreVisitante} ${v.apellidosVisitante} ya no podrá ingresar con su código.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Cancelar visita',
      cancelButtonText: 'Volver'
    });
    if (!res.isConfirmed) return;

    try {
      await this.visitasService.cancelar(v.id);
    } catch (err: any) {
      console.error('[VisitasComponent] Error al cancelar visita:', err);
      Swal.fire({
        icon: 'error',
        title: 'No se pudo cancelar',
        text: this.mensajeError(err),
        confirmButtonColor: '#111C99'
      });
    }
  }

  private async guardarNueva(): Promise<void> {
    const viviendaId = this.viviendaId();
    if (!viviendaId) return;

    const f = this.form;
    const dto: CrearVisitaDto = {
      viviendaId,
      nombreVisitante: f.nombreVisitante.trim(),
      apellidosVisitante: f.apellidosVisitante.trim(),
      motivo: f.motivo,
      numAcompanantes: Number(f.numAcompanantes),
      fechaLlegadaEsperada: new Date(f.fechaLlegada).toISOString(),
      horasVigencia: Number(f.horasVigencia)
    };
    if (f.telefonoVisitante.trim()) dto.telefonoVisitante = f.telefonoVisitante.trim();
    if (f.vehiculoPlacas.trim()) dto.vehiculoPlacas = f.vehiculoPlacas.trim();
    if (f.notas.trim()) dto.notas = f.notas.trim();

    const creada = await this.visitasService.crear(dto);
    this.cerrarModal();
    await this.visitasService.cargar(this.filtroActivo(), 1);
    Swal.fire({
      icon: 'success',
      title: 'Visita programada',
      html: `Comparte este código con tu visitante:<br><strong style="font-family:monospace;font-size:1.75rem;letter-spacing:0.2em">${creada.codigo ?? ''}</strong>`,
      confirmButtonColor: '#111C99'
    });
  }

  private async guardarEdicion(id: string): Promise<void> {
    const original = this.visitaOriginal;
    if (!original) return;

    const f = this.form;
    const cambios: ActualizarVisitaDto = {};
    if (f.nombreVisitante.trim() !== original.nombreVisitante) cambios.nombreVisitante = f.nombreVisitante.trim();
    if (f.apellidosVisitante.trim() !== original.apellidosVisitante) cambios.apellidosVisitante = f.apellidosVisitante.trim();
    if (f.telefonoVisitante.trim() !== (original.telefonoVisitante ?? '')) cambios.telefonoVisitante = f.telefonoVisitante.trim();
    if (f.motivo !== original.motivo) cambios.motivo = f.motivo;
    if (Number(f.numAcompanantes) !== original.numAcompanantes) cambios.numAcompanantes = Number(f.numAcompanantes);
    if (f.vehiculoPlacas.trim() !== (original.vehiculoPlacas ?? '')) cambios.vehiculoPlacas = f.vehiculoPlacas.trim();
    if (f.notas.trim() !== (original.notas ?? '')) cambios.notas = f.notas.trim();
    if (f.fechaLlegada !== isoAInputLocal(original.fechaLlegadaEsperada)) {
      cambios.fechaLlegadaEsperada = new Date(f.fechaLlegada).toISOString();
    }
    const horasOriginales = Math.round((new Date(original.vigenciaHasta).getTime() - new Date(original.fechaLlegadaEsperada).getTime()) / 3_600_000);
    if (Number(f.horasVigencia) !== horasOriginales) cambios.horasVigencia = Number(f.horasVigencia);

    if (Object.keys(cambios).length === 0) {
      this.cerrarModal();
      return;
    }

    await this.visitasService.actualizar(id, cambios);
    this.cerrarModal();
    Swal.fire({
      toast: true,
      position: 'top-end',
      icon: 'success',
      title: 'Visita actualizada',
      showConfirmButton: false,
      timer: 2000
    });
  }

  /** Extrae el mensaje del backend: { error } o el primer error de validación de ModelState */
  private mensajeError(err: any): string {
    const body = err?.error;
    if (body?.error) return body.error;
    if (body?.errors) {
      const primero = Object.values(body.errors as Record<string, string[]>)[0];
      if (primero?.length) return primero[0];
    }
    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }

  private formularioVacio(): FormularioVisita {
    return {
      nombreVisitante: '',
      apellidosVisitante: '',
      telefonoVisitante: '',
      motivo: 'personal',
      numAcompanantes: 0,
      vehiculoPlacas: '',
      notas: '',
      fechaLlegada: '',
      horasVigencia: 24
    };
  }
}
