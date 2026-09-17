import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import { ResidentesService } from '../../../core/services/residentes.service';
import { Residente } from '../../../core/models/residente.model';
import { ResidentesDetalleComponent } from '../residentes-detalle/residentes-detalle.component';
import { getInitials } from '../../../core/utils/iniciales.util';

@Component({
  selector: 'app-residentes-list',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, DatePipe, ResidentesDetalleComponent],
  template: `
    <div class="p-4 sm:p-5 lg:p-6 max-w-7xl mx-auto space-y-4 selection:bg-[#111C99] selection:text-white">

      <!-- Breadcrumb & Top Navigation -->
      <nav class="flex items-center gap-2 text-xs text-slate-500 font-medium">
        <a routerLink="/dashboard/admin" class="hover:text-slate-900 transition-colors">Panel Principal</a>
        <span>/</span>
        <span class="text-slate-900">Directorio de Residentes</span>
      </nav>

      <!-- Page Header & Action Bar -->
      <div class="bg-white border border-slate-200 rounded-lg p-4 sm:p-5 shadow-xs">
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div>
            <div class="flex items-center gap-3">
              <h1 class="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
                Directorio de Residentes
              </h1>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-indigo-50 text-indigo-700 border border-indigo-200">
                {{ residentes().length }} {{ residentes().length === 1 ? 'residente' : 'residentes' }}
              </span>
            </div>
            <p class="text-sm text-slate-500 mt-1.5">
              Administra el padrón de habitantes, credenciales y datos de contacto de Haven Residencial.
            </p>
          </div>

          <!-- Action Buttons -->
          <div class="flex items-center gap-3 shrink-0">
            <!-- Refresh Button -->
            <button
              (click)="cargarResidentes()"
              [disabled]="isLoading()"
              title="Actualizar datos"
              class="p-2 bg-slate-50 hover:bg-slate-100 active:bg-slate-200 border border-slate-200 text-slate-600 rounded-lg transition-all shadow-2xs cursor-pointer disabled:opacity-50"
            >
              <svg
                [class.animate-spin]="isLoading()"
                xmlns="http://www.w3.org/2000/svg"
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Segmented Subpage Switcher (Todos vs Sin Vivienda) -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="flex items-center gap-1.5 p-1 bg-slate-100 rounded-lg w-fit border border-slate-200/80">
          <button
            type="button"
            (click)="cambiarTab('todos')"
            [class.bg-white]="tabActiva() === 'todos'"
            [class.text-slate-900]="tabActiva() === 'todos'"
            [class.shadow-2xs]="tabActiva() === 'todos'"
            [class.font-semibold]="tabActiva() === 'todos'"
            class="px-3 py-1.5 rounded-md text-xs text-slate-600 transition-all cursor-pointer flex items-center gap-2"
          >
            <span>Todos los residentes</span>
            <span
              class="text-[10px] px-1.5 py-0.2 rounded-full font-mono font-bold"
              [class.bg-indigo-50]="tabActiva() === 'todos'"
              [class.text-indigo-700]="tabActiva() === 'todos'"
              [class.bg-slate-200]="tabActiva() !== 'todos'"
              [class.text-slate-600]="tabActiva() !== 'todos'"
            >
              {{ totalResidentesRegistrados() }}
            </span>
          </button>
          <button
            type="button"
            (click)="cambiarTab('sin-vivienda')"
            [class.bg-white]="tabActiva() === 'sin-vivienda'"
            [class.text-slate-900]="tabActiva() === 'sin-vivienda'"
            [class.shadow-2xs]="tabActiva() === 'sin-vivienda'"
            [class.font-semibold]="tabActiva() === 'sin-vivienda'"
            class="px-3 py-1.5 rounded-md text-xs text-slate-600 transition-all cursor-pointer flex items-center gap-2"
          >
            <span class="flex items-center gap-1.5">
              <span class="w-2 h-2 rounded-full bg-amber-500"></span>
              <span>Sin vivienda asignada</span>
            </span>
            <span *ngIf="conteoSinVivienda() !== null" class="text-[10px] px-1.5 py-0.2 rounded-full font-mono font-bold bg-amber-100 text-amber-800">
              {{ conteoSinVivienda() }}
            </span>
          </button>
        </div>

        <div class="text-xs text-slate-400 font-medium">
          {{ tabActiva() === 'todos' ? 'Padrón general del condominio' : 'Subpágina: Residentes pendientes de vincular' }}
        </div>
      </div>

      <!-- Banner Informativo Subpágina Sin Vivienda -->
      <div
        *ngIf="tabActiva() === 'sin-vivienda'"
        class="p-3.5 rounded-lg bg-amber-50/80 border border-amber-200 text-amber-900 flex items-start gap-3 shadow-2xs"
      >
        <svg class="w-5 h-5 text-amber-600 shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <div class="text-xs">
          <p class="font-bold text-amber-900">Residentes registrados sin vivienda en el condominio</p>
          <p class="text-amber-700 mt-0.5 leading-relaxed">
            Estos usuarios completaron su alta en el sistema pero aún no tienen una unidad habitacional asignada. Puedes seleccionarlos para consultar su información o vincularlos a su casa correspondiente.
          </p>
        </div>
      </div>

      <!-- Live Search & Control Toolbar -->
      <div class="bg-white border border-slate-200 rounded-lg p-2.5 shadow-2xs flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="relative flex-1 max-w-md">
          <svg class="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            type="text"
            [ngModel]="searchQuery()"
            (ngModelChange)="onSearchChange($event)"
            placeholder="Buscar por nombre, correo o teléfono..."
            class="w-full h-8 pl-8 pr-8 text-xs bg-slate-50/70 hover:bg-white focus:bg-white border border-slate-200 rounded-lg text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all"
          />
          <button
            *ngIf="searchQuery()"
            (click)="onSearchChange('')"
            class="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-0.5 rounded cursor-pointer"
            title="Limpiar búsqueda"
          >
            <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="flex items-center justify-between sm:justify-end gap-3 text-xs text-slate-500 font-medium px-2">
          <span>
            Mostrando <strong class="text-slate-800">{{ indiceInicio() }}-{{ indiceFin() }}</strong> de {{ totalFiltrados() }}
          </span>
        </div>
      </div>

      <!-- Loading State -->
      <div *ngIf="isLoading() && residentes().length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-white rounded-lg border border-slate-200 shadow-xs">
        <div class="w-10 h-10 border-3 border-slate-200 border-t-[#111C99] rounded-full animate-spin"></div>
        <p class="text-sm font-semibold text-slate-600">Sincronizando residentes...</p>
      </div>

      <!-- Error State -->
      <div
        *ngIf="!isLoading() && errorMessage()"
        class="p-4 rounded-lg bg-red-50/80 border border-red-200 text-red-800 flex items-center justify-between shadow-xs mb-6"
      >
        <div class="flex items-center gap-3">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-6 h-6 shrink-0 text-red-600">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
          </svg>
          <div>
            <p class="text-sm font-bold text-red-900">Error de conexión</p>
            <p class="text-xs text-red-700 mt-0.5">{{ errorMessage() }}</p>
          </div>
        </div>
        <button
          (click)="cargarResidentes()"
          class="px-4 py-2 bg-red-100 hover:bg-red-200 text-red-900 font-semibold text-xs rounded-lg transition-colors cursor-pointer"
        >
          Reintentar
        </button>
      </div>

      <!-- Empty State (No residents at all) -->
      <div
        *ngIf="!isLoading() && !errorMessage() && residentes().length === 0"
        class="bg-white border border-slate-200/80 rounded-lg shadow-xs flex flex-col items-center justify-center py-12 px-4 text-center"
      >
        <div class="w-16 h-16 rounded-2xl bg-indigo-50 border border-indigo-100 flex items-center justify-center mb-4 text-indigo-600">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
        </div>
        <h3 class="text-lg font-bold text-slate-900">
          {{ tabActiva() === 'sin-vivienda' ? '¡Excelente! No hay residentes sin vivienda' : 'No hay residentes registrados' }}
        </h3>
        <p class="text-sm text-slate-500 max-w-sm mt-1">
          {{ tabActiva() === 'sin-vivienda' ? 'Todos los residentes dados de alta en este condominio cuentan con una vivienda asignada.' : 'Los residentes se registran directamente desde la aplicación móvil o el portal de registro.' }}
        </p>
      </div>

      <!-- Empty State por Filtro / Búsqueda -->
      <div
        *ngIf="!isLoading() && !errorMessage() && residentes().length > 0 && residentesFiltrados().length === 0"
        class="bg-white border border-slate-200 rounded-lg shadow-xs flex flex-col items-center justify-center py-8 px-4 text-center"
      >
        <p class="text-xs text-slate-500">No se encontraron residentes con ese criterio de búsqueda.</p>
        <button
          (click)="onSearchChange('')"
          class="mt-2 text-xs font-semibold text-[#111C99] hover:underline cursor-pointer"
        >
          Limpiar búsqueda
        </button>
      </div>

      <!-- Modern, Spacious Residents Table (Estilo amigable aprobado) -->
      <div
        *ngIf="!isLoading() && !errorMessage() && residentesFiltrados().length > 0"
        class="bg-white border border-slate-200/90 rounded-xl shadow-xs overflow-hidden"
      >
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-slate-200">
            <thead>
              <tr class="bg-slate-50 border-b border-slate-200">
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-700 uppercase tracking-wider">
                  Residente
                </th>
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-700 uppercase tracking-wider">
                  Contacto
                </th>
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-700 uppercase tracking-wider">
                  Teléfono
                </th>
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-700 uppercase tracking-wider">
                  {{ tabActiva() === 'sin-vivienda' ? 'Estado de Vivienda' : 'Fecha de Alta' }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-200 bg-white">
              <tr
                *ngFor="let r of residentesPaginados()"
                (click)="verDetalle(r)"
                (keydown.enter)="verDetalle(r)"
                tabindex="0"
                class="hover:bg-slate-50/70 transition-colors group cursor-pointer focus:outline-none focus:bg-slate-50/90 focus:ring-1 focus:ring-inset focus:ring-[#111C99]/30"
              >
                <!-- Name & Avatar Initials -->
                <td class="px-6 py-4.5 whitespace-nowrap">
                  <div class="flex items-center gap-3.5">
                    <div class="w-10 h-10 rounded-full bg-[#111C99] text-white font-bold text-xs flex items-center justify-center shadow-2xs ring-2 ring-slate-100 group-hover:scale-105 transition-transform shrink-0">
                      {{ getInitials(r.nombre, r.apellidos) }}
                    </div>
                    <div>
                      <div class="text-sm font-bold text-slate-900 group-hover:text-indigo-600 transition-colors">
                        {{ r.nombre }} {{ r.apellidos }}
                      </div>
                      <div class="text-xs text-slate-400">
                        Residente Haven
                      </div>
                    </div>
                  </div>
                </td>

                <!-- Email -->
                <td class="px-6 py-4.5 whitespace-nowrap">
                  <div class="inline-flex items-center gap-2 text-sm text-slate-600">
                    <svg class="w-4 h-4 text-slate-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                    <span class="font-medium font-mono text-xs">{{ r.email }}</span>
                  </div>
                </td>

                <!-- Phone -->
                <td class="px-6 py-4.5 whitespace-nowrap">
                  <div class="inline-flex items-center gap-2 text-sm text-slate-600">
                    <svg class="w-4 h-4 text-slate-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                    </svg>
                    <span class="font-mono text-xs">{{ (r.telefono && r.telefono !== '0') ? r.telefono : '—' }}</span>
                  </div>
                </td>

                <!-- Created Date or Status Badge -->
                <td class="px-6 py-4.5 whitespace-nowrap">
                  <ng-container *ngIf="tabActiva() === 'sin-vivienda'; else fechaNormal">
                    <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-semibold bg-amber-50 text-amber-800 border border-amber-200">
                      <span class="w-1.5 h-1.5 rounded-full bg-amber-500"></span>
                      Sin vivienda
                    </span>
                  </ng-container>
                  <ng-template #fechaNormal>
                    <div class="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 bg-slate-100/80 px-2.5 py-1 rounded-md">
                      <svg class="w-3.5 h-3.5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                      <span>{{ r.creadoEn ? (r.creadoEn | date:'dd/MM/yyyy') : '—' }}</span>
                    </div>
                  </ng-template>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Pagination Control Bar Spartan UI -->
        <div class="px-4 py-3 border-t border-slate-200 bg-slate-50/70 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
          <div class="flex items-center gap-3 text-slate-500">
            <span>
              Mostrando <strong class="text-slate-800 font-semibold">{{ indiceInicio() }}</strong> a <strong class="text-slate-800 font-semibold">{{ indiceFin() }}</strong> de <strong class="text-slate-800 font-semibold">{{ totalFiltrados() }}</strong> residentes
            </span>

            <div class="flex items-center gap-1.5 pl-3 border-l border-slate-200">
              <span class="text-slate-400">Por página:</span>
              <select
                [ngModel]="elementosPorPagina()"
                (ngModelChange)="cambiarElementosPorPagina($event)"
                class="h-7 px-1.5 text-xs bg-white border border-slate-200 rounded font-medium text-slate-700 focus:outline-none focus:ring-1 focus:ring-[#111C99] cursor-pointer"
              >
                <option *ngFor="let opt of opcionesPaginacion" [value]="opt">{{ opt }}</option>
              </select>
            </div>
          </div>

          <!-- Page Buttons -->
          <div class="flex items-center gap-1 self-end sm:self-auto">
            <button
              type="button"
              (click)="irAPagina(1)"
              [disabled]="paginaActual() === 1"
              title="Primera página"
              class="px-2 py-1 bg-white border border-slate-200 rounded text-slate-600 hover:bg-slate-100 disabled:opacity-40 disabled:cursor-not-allowed transition-colors cursor-pointer"
            >
              «
            </button>
            <button
              type="button"
              (click)="irAPagina(paginaActual() - 1)"
              [disabled]="paginaActual() === 1"
              title="Página anterior"
              class="px-2.5 py-1 bg-white border border-slate-200 rounded text-slate-600 hover:bg-slate-100 disabled:opacity-40 disabled:cursor-not-allowed transition-colors cursor-pointer"
            >
              Anterior
            </button>

            <span class="px-3 py-1 font-semibold text-slate-800">
              {{ paginaActual() }} / {{ totalPaginas() }}
            </span>

            <button
              type="button"
              (click)="irAPagina(paginaActual() + 1)"
              [disabled]="paginaActual() >= totalPaginas()"
              title="Página siguiente"
              class="px-2.5 py-1 bg-white border border-slate-200 rounded text-slate-600 hover:bg-slate-100 disabled:opacity-40 disabled:cursor-not-allowed transition-colors cursor-pointer"
            >
              Siguiente
            </button>
            <button
              type="button"
              (click)="irAPagina(totalPaginas())"
              [disabled]="paginaActual() >= totalPaginas()"
              title="Última página"
              class="px-2 py-1 bg-white border border-slate-200 rounded text-slate-600 hover:bg-slate-100 disabled:opacity-40 disabled:cursor-not-allowed transition-colors cursor-pointer"
            >
              »
            </button>
          </div>
        </div>

      </div>

      <!-- Slide-Over Drawer de Detalle Residente -->
      <div
        *ngIf="isDetalleOpen()"
        (click)="cerrarDetalle()"
        aria-hidden="true"
        class="fixed inset-0 z-40 bg-slate-900/20 backdrop-blur-[1.5px] transition-opacity duration-300 animate-fade-in"
      ></div>

      <aside
        *ngIf="isDetalleOpen()"
        role="dialog"
        aria-modal="true"
        aria-label="Detalle del residente"
        class="fixed inset-y-0 right-0 z-50 w-full sm:max-w-md md:max-w-lg lg:max-w-xl bg-white shadow-2xl flex flex-col border-l border-slate-200 overflow-y-auto transform transition-transform duration-300 ease-out animate-slide-left"
      >
        <app-residentes-detalle
          [residente]="residenteSeleccionado()"
          (cerrado)="cerrarDetalle()"
        ></app-residentes-detalle>
      </aside>

    </div>
  `
})
export class ResidentesListComponent implements OnInit {
  private readonly residentesService = inject(ResidentesService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  readonly residentes = signal<Residente[]>([]);
  readonly searchQuery = signal<string>('');
  readonly isLoading = signal<boolean>(true);
  readonly errorMessage = signal<string | null>(null);
  readonly residenteSeleccionado = signal<Residente | null>(null);
  readonly isDetalleOpen = signal<boolean>(false);

  // Subpágina / Tabs: 'todos' o 'sin-vivienda'
  readonly tabActiva = signal<'todos' | 'sin-vivienda'>('todos');
  readonly totalResidentesRegistrados = signal<number>(0);
  readonly conteoSinVivienda = signal<number | null>(null);

  // Paginación reactiva
  readonly paginaActual = signal<number>(1);
  readonly elementosPorPagina = signal<number>(10);
  readonly opcionesPaginacion = [5, 10, 25, 50];

  readonly getInitials = getInitials;

  readonly residentesFiltrados = computed(() => {
    const query = this.searchQuery().trim().toLowerCase();
    const list = this.residentes();
    if (!query) return list;

    return list.filter(r => {
      const nombreCompleto = `${r.nombre || ''} ${r.apellidos || ''}`.toLowerCase();
      const email = (r.email || '').toLowerCase();
      const telefono = (r.telefono || '').toLowerCase();
      return nombreCompleto.includes(query) || email.includes(query) || telefono.includes(query);
    });
  });

  readonly totalFiltrados = computed(() => this.residentesFiltrados().length);

  readonly totalPaginas = computed(() => {
    return Math.max(1, Math.ceil(this.totalFiltrados() / this.elementosPorPagina()));
  });

  readonly residentesPaginados = computed(() => {
    const lista = this.residentesFiltrados();
    const inicio = (this.paginaActual() - 1) * this.elementosPorPagina();
    const fin = inicio + this.elementosPorPagina();
    return lista.slice(inicio, fin);
  });

  readonly indiceInicio = computed(() => {
    if (this.totalFiltrados() === 0) return 0;
    return (this.paginaActual() - 1) * this.elementosPorPagina() + 1;
  });

  readonly indiceFin = computed(() => {
    return Math.min(this.paginaActual() * this.elementosPorPagina(), this.totalFiltrados());
  });

  async ngOnInit(): Promise<void> {
    const filtroParam = this.route.snapshot.queryParamMap.get('filtro') || this.route.snapshot.queryParamMap.get('tab');
    if (filtroParam === 'sin-vivienda') {
      this.tabActiva.set('sin-vivienda');
    }
    await this.cargarResidentes();
  }

  onSearchChange(val: string): void {
    this.searchQuery.set(val);
    this.paginaActual.set(1);
  }

  async cambiarTab(tab: 'todos' | 'sin-vivienda'): Promise<void> {
    if (this.tabActiva() === tab) return;
    this.tabActiva.set(tab);
    this.paginaActual.set(1);
    this.searchQuery.set('');

    this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { filtro: tab === 'sin-vivienda' ? 'sin-vivienda' : null },
      queryParamsHandling: 'merge'
    });

    await this.cargarResidentes();
  }

  irAPagina(pagina: number): void {
    if (pagina >= 1 && pagina <= this.totalPaginas()) {
      this.paginaActual.set(pagina);
    }
  }

  cambiarElementosPorPagina(cantidad: number): void {
    this.elementosPorPagina.set(Number(cantidad));
    this.paginaActual.set(1);
  }

  async cargarResidentes(): Promise<void> {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    const soloSinVivienda = this.tabActiva() === 'sin-vivienda';

    try {
      const data = await this.residentesService.listar(soloSinVivienda);
      this.residentes.set(data || []);

      if (!soloSinVivienda) {
        this.totalResidentesRegistrados.set((data || []).length);
        // Consultar en segundo plano la cantidad sin vivienda para actualizar el badge de la subpágina
        this.residentesService.listar(true).then(sinV => {
          this.conteoSinVivienda.set(sinV.length);
        }).catch(() => {});
      } else {
        this.conteoSinVivienda.set((data || []).length);
      }
    } catch {
      this.errorMessage.set('No fue posible cargar la lista de residentes desde el servidor.');
    } finally {
      this.isLoading.set(false);
    }
  }

  verDetalle(r: Residente): void {
    this.residenteSeleccionado.set(r);
    this.isDetalleOpen.set(true);
  }

  cerrarDetalle(): void {
    this.isDetalleOpen.set(false);
  }
}
