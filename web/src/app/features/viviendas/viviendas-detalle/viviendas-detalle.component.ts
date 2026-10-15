import { AfterViewInit, Component, ElementRef, Input, Output, EventEmitter, HostListener, inject, OnChanges, SimpleChanges, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Vivienda } from '../../../core/models/vivienda.model';
import { Residente } from '../../../core/models/residente.model';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { ResidentesService } from '../../../core/services/residentes.service';
import { SubusuariosService } from '../../../core/services/subusuarios.service';
import { SubUsuarioItem } from '../../../core/models/subusuario.model';
import { getInitials } from '../../../core/utils/iniciales.util';
import Swal from 'sweetalert2';
import { mensajeAmigable } from '../../../core/utils/api-errors.util';

@Component({
  selector: 'app-viviendas-detalle',
  standalone: true,
  imports: [CommonModule, DatePipe, FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <!-- Backdrop Blur Overlay -->
    @if (isOpen) {
      <div
        (click)="cerrar()"
        class="fixed inset-0 z-50 !m-0 bg-slate-900/50 backdrop-blur-xs transition-opacity duration-300 cursor-pointer"
        aria-hidden="true"
      ></div>
    }
    
    <!-- Slide-over Drawer Panel -->
    @if (isOpen) {
      <aside
        role="dialog"
        aria-modal="true"
        aria-labelledby="detalle-vivienda-title"
        class="fixed inset-y-0 right-0 z-[60] !m-0 max-w-lg w-full bg-white shadow-2xl flex flex-col transform transition-transform duration-300 ease-in-out border-l border-slate-200"
        >
        <!-- Top Sticky Bar -->
        <div class="sticky top-0 z-10 bg-white/95 backdrop-blur-md px-6 py-4 border-b border-slate-100 flex items-center justify-between">
          <div class="flex items-center gap-3">
            @if (conAtras) {
              <button
                type="button"
                data-foco-inicial
                (click)="atras.emit()"
                [attr.aria-label]="textoAtras"
                [title]="textoAtras + ' (Esc)'"
                class="h-9 w-9 -ml-2 inline-flex items-center justify-center text-slate-700 hover:text-slate-900 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-blue-600"
                >
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                </svg>
              </button>
            }
            <div class="w-9 h-9 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center font-bold text-sm border border-blue-100">
              <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
              </svg>
            </div>
            <div>
              <h2 id="detalle-vivienda-title" class="text-base font-bold text-slate-900 tracking-tight">
                Detalle de Vivienda
              </h2>
              <p class="text-xs text-slate-500 font-medium">Gestión de inmueble y residentes</p>
            </div>
          </div>
          <!-- Boton Cerrar -->
          <button
            type="button"
            (click)="cerrar()"
            class="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-all cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-600/20"
            data-foco-cierre
            aria-label="Cerrar detalle de vivienda"
            title="Cerrar (Esc)"
            >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <!-- Body Scrollable -->
        <div class="p-6 overflow-y-auto flex-1 space-y-6">
          <!-- Hero del Inmueble -->
          <div class="bg-gradient-to-b from-slate-50/80 to-white border border-slate-200/80 rounded-xl p-6 text-center shadow-xs">
            <div class="w-20 h-20 mx-auto rounded-2xl bg-[#eff6ff] text-[#3b82f6] flex items-center justify-center shadow-sm border border-blue-100 ring-4 ring-blue-50/50">
              <svg class="w-10 h-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
              </svg>
            </div>
            <h3 class="text-2xl font-black text-slate-900 mt-4 tracking-tight">
              {{ vivienda?.numeroCasa }}
            </h3>
            <div class="mt-3 flex items-center justify-center gap-2 flex-wrap">
              <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-blue-50 text-blue-700 border border-blue-200">
                {{ vivienda?.tipo || 'Sin especificar' }}
              </span>
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                Activa
              </span>
            </div>
            <p class="text-xs text-slate-400 mt-3 font-medium">
              Registrada en sistema el {{ $safeNavigationMigration(vivienda?.creadoEn) | date:'dd/MM/yyyy' }}
            </p>
          </div>
          @if (!soloLectura) {
          <!-- Seccion: Residente Asignado (Issue #50) -->
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <h4 class="text-sm font-bold text-slate-900 tracking-tight">Residente Asignado</h4>
                <span
                  class="text-[11px] font-semibold px-2 py-0.5 rounded-full"
                  [ngClass]="residenteAsignado && !errorResidente ? 'bg-indigo-50 text-indigo-700 border border-indigo-200' : 'bg-slate-100 text-slate-600'"
                  >
                  {{ errorResidente ? 'No disponible' : residenteAsignado ? 'Asignado' : 'Sin asignar' }}
                </span>
              </div>
              <div class="flex items-center gap-2">
                <!-- Boton Generar Codigo de Invitacion para la Vivienda -->
                <button
                  type="button"
                  (click)="generarCodigoVivienda()"
                  [disabled]="isGeneratingCode"
                  class="text-xs font-semibold text-slate-700 hover:text-[#111C99] bg-slate-100 hover:bg-slate-200/80 px-2.5 py-1.5 rounded-lg border border-slate-200 transition-colors flex items-center gap-1.5 cursor-pointer disabled:opacity-50"
                  title="Generar código de invitación para esta vivienda específica"
                  >
                  <svg class="w-3.5 h-3.5 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
                  </svg>
                  <span>{{ isGeneratingCode ? 'Generando...' : 'Generar Código' }}</span>
                </button>
                <!-- Boton para abrir formulario si no esta asignado y no esta en modo form -->
                @if (!residenteAsignado && !mostrarFormularioVinculacion && !errorResidente && !cargandoResidente) {
                  <button
                    type="button"
                    (click)="abrirFormularioVinculacion()"
                    class="text-xs font-bold text-[#111C99] hover:text-[#0d1577] bg-indigo-50 hover:bg-indigo-100/80 px-2.5 py-1.5 rounded-lg border border-indigo-200 transition-colors flex items-center gap-1 cursor-pointer"
                    >
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                    </svg>
                    Vincular
                  </button>
                }
              </div>
            </div>
            <!-- Spinner cargando estado -->
            @if (cargandoResidente) {
              <div class="py-8 flex flex-col items-center justify-center text-slate-400 gap-2">
                <div class="w-6 h-6 border-2 border-slate-300 border-t-blue-600 rounded-full animate-spin"></div>
                <span class="text-xs">Consultando información de residentes...</span>
              </div>
            }
            <!-- No se pudo consultar: no se dice que la casa está vacía, porque no se sabe -->
            @if (!cargandoResidente && errorResidente) {
              <div class="bg-amber-50/70 border border-amber-200 rounded-xl p-4 space-y-2" role="alert">
                <p class="text-xs font-semibold text-amber-900">No se pudo consultar el residente de esta vivienda.</p>
                <button
                  type="button"
                  (click)="cargarDetalleResidente()"
                  class="text-xs font-semibold text-amber-900 bg-white hover:bg-amber-100 px-3 py-1.5 rounded-lg border border-amber-300 transition-colors cursor-pointer"
                  >
                  Reintentar
                </button>
              </div>
            }
            <!-- CASO 1: TIENE RESIDENTE ASIGNADO -->
            @if (!cargandoResidente && residenteAsignado) {
              <div
                class="bg-white border border-slate-200 rounded-xl p-5 shadow-xs relative overflow-hidden"
                >
                <div class="flex items-start justify-between gap-4">
                  <button
                    type="button"
                    (click)="verResidente.emit(residenteAsignado)"
                    data-origen-detalle="residente"
                    [attr.aria-label]="'Ver el detalle de ' + residenteAsignado.nombre + ' ' + residenteAsignado.apellidos"
                    title="Ver el detalle del residente"
                    class="group flex items-center gap-3.5 -m-1 p-1 rounded-lg text-left w-full cursor-pointer hover:bg-slate-50 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-blue-600"
                  >
                    <div class="w-12 h-12 rounded-full bg-[#111C99] text-white font-bold text-base flex items-center justify-center shadow-xs shrink-0">
                      {{ getInitials(residenteAsignado.nombre, residenteAsignado.apellidos) }}
                    </div>
                    <div>
                      <p class="text-base font-bold text-slate-900 leading-tight group-hover:underline">
                        {{ residenteAsignado.nombre }} {{ residenteAsignado.apellidos }}
                      </p>
                      <p class="text-xs text-slate-500 mt-1 flex items-center gap-1.5">
                        <svg class="w-3.5 h-3.5 text-slate-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                        </svg>
                        {{ residenteAsignado.email }}
                      </p>
                      @if (residenteAsignado.telefono) {
                        <p class="text-xs text-slate-500 mt-0.5 flex items-center gap-1.5">
                          <svg class="w-3.5 h-3.5 text-slate-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                          </svg>
                          {{ residenteAsignado.telefono }}
                        </p>
                      }
                    </div>
                    <svg class="w-4 h-4 text-slate-500 shrink-0 ml-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                  </button>
                </div>
                <!-- Accion de Desvincular -->
                <div class="mt-4 pt-3.5 border-t border-slate-100 flex items-center justify-between">
                  <span class="text-xs font-semibold text-emerald-600 flex items-center gap-1">
                    <svg class="w-4 h-4 text-emerald-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                    Habitante vinculado
                  </span>
                  <button
                    type="button"
                    (click)="confirmarDesvinculacion()"
                    [disabled]="procesandoVinculacion"
                    class="text-xs font-semibold text-rose-600 hover:text-rose-800 hover:bg-rose-50 px-2.5 py-1.5 rounded-lg transition-colors cursor-pointer flex items-center gap-1"
                    title="Desvincular habitante de esta casa"
                    >
                    <svg class="w-4 h-4 text-rose-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                    Desvincular
                  </button>
                </div>
              </div>
            }
            <!-- CASO 2: NO TIENE RESIDENTE ASIGNADO (Estado vacio amigable) -->
            @if (!cargandoResidente && !errorResidente && !residenteAsignado && !mostrarFormularioVinculacion) {
              <div
                class="bg-slate-50/70 border-2 border-dashed border-slate-200 rounded-xl p-6 text-center"
                >
                <div class="w-12 h-12 mx-auto rounded-full bg-slate-100 text-slate-400 flex items-center justify-center mb-3">
                  <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                  </svg>
                </div>
                <h5 class="text-sm font-bold text-slate-800 tracking-tight">Sin habitante registrado</h5>
                <p class="text-xs text-slate-500 mt-1 max-w-xs mx-auto">
                  Esta vivienda se encuentra desocupada o no tiene un residente asignado en el sistema.
                </p>
                <button
                  type="button"
                  (click)="abrirFormularioVinculacion()"
                  class="mt-4 inline-flex items-center gap-2 px-4 py-2 bg-[#0F172A] hover:bg-slate-800 text-white text-xs font-bold rounded-xl transition-all cursor-pointer shadow-xs focus:ring-2 focus:ring-slate-900/20"
                  >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  Vincular Residente Ahora
                </button>
              </div>
            }
            <!-- CASO 3: FORMULARIO DE VINCULACION (Issue #87) -->
            @if (mostrarFormularioVinculacion) {
              <div
                class="bg-white border border-blue-200 rounded-xl p-5 shadow-sm space-y-4 ring-2 ring-blue-500/10"
                >
                <div class="flex items-center justify-between border-b border-slate-100 pb-3">
                  <div class="flex items-center gap-2">
                    <div class="w-7 h-7 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center">
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                      </svg>
                    </div>
                    <h5 class="text-sm font-bold text-slate-900">Vincular a {{ vivienda?.numeroCasa }}</h5>
                  </div>
                  <button
                    type="button"
                    (click)="cancelarFormularioVinculacion()"
                    class="text-xs text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-100 cursor-pointer"
                    >
                    ✕
                  </button>
                </div>
                <!-- Buscador rapido de residentes -->
                <div>
                  <label class="block text-xs font-semibold text-slate-600 mb-1.5">
                    Selecciona un residente registrado:
                  </label>
                  <div class="relative">
                    <input
                      type="text"
                      [(ngModel)]="busquedaResidente"
                      placeholder="Filtrar por nombre o correo..."
                      class="w-full text-xs bg-slate-50 border border-slate-200 rounded-xl px-3 py-2.5 pl-8 text-slate-800 placeholder-slate-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-600/20 focus:border-blue-600 transition-all"
                      />
                      <svg class="w-4 h-4 text-slate-400 absolute left-2.5 top-2.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                      </svg>
                    </div>
                  </div>
                  <!-- Lista seleccionable con scroll -->
                  <div class="max-h-48 overflow-y-auto space-y-1.5 pr-1 divide-y divide-slate-50 border border-slate-100 rounded-xl p-1 bg-slate-50/50">
                    @if (cargandoCatalogo) {
                      <div class="py-6 text-center text-xs text-slate-400">
                        Cargando directorio de residentes...
                      </div>
                    }
                    @for (res of residentesFiltrados; track res.id) {
                      <div
                        (click)="seleccionarResidente(res)"
                        class="p-2.5 rounded-xl cursor-pointer transition-all flex items-center justify-between"
                        [ngClass]="residenteSeleccionadoId === res.id ? 'bg-blue-50 border border-blue-200 shadow-2xs' : 'hover:bg-white hover:shadow-2xs'"
                        >
                        <div class="flex items-center gap-2.5 overflow-hidden">
                          <div class="w-8 h-8 rounded-full bg-slate-200 text-slate-700 font-bold text-xs flex items-center justify-center shrink-0">
                            {{ getInitials(res.nombre, res.apellidos) }}
                          </div>
                          <div class="truncate">
                            <p class="text-xs font-bold text-slate-900 truncate">
                              {{ res.nombre }} {{ res.apellidos }}
                            </p>
                            <p class="text-[11px] text-slate-500 truncate">{{ res.email }}</p>
                          </div>
                        </div>
                        <div class="shrink-0 ml-2">
                          <div
                            class="w-4 h-4 rounded-full border flex items-center justify-center"
                            [ngClass]="residenteSeleccionadoId === res.id ? 'border-blue-600 bg-blue-600 text-white' : 'border-slate-300 bg-white'"
                            >
                            @if (residenteSeleccionadoId === res.id) {
                              <svg class="w-2.5 h-2.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                              </svg>
                            }
                          </div>
                        </div>
                      </div>
                    }
                    @if (!cargandoCatalogo && residentesFiltrados.length === 0) {
                      <div class="py-6 text-center text-xs text-slate-400">
                        No se encontraron residentes con ese criterio.
                      </div>
                    }
                  </div>
                  <!-- Botones de Accion del Formulario -->
                  <div class="pt-2 flex items-center gap-2 justify-end">
                    <button
                      type="button"
                      (click)="cancelarFormularioVinculacion()"
                      class="px-3 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer"
                      >
                      Cancelar
                    </button>
                    <button
                      type="button"
                      (click)="confirmarVinculacion()"
                      [disabled]="!residenteSeleccionadoId || procesandoVinculacion"
                      class="px-4 py-2 text-xs font-bold bg-[#0F172A] hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed text-white rounded-xl transition-all cursor-pointer shadow-xs flex items-center gap-1.5"
                      >
                      @if (procesandoVinculacion) {
                        <div class="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      }
                      <span>{{ procesandoVinculacion ? 'Vinculando...' : 'Asignar a Vivienda' }}</span>
                    </button>
                  </div>
                </div>
              }
            </div>
          }
            <!-- Sub-usuarios de la vivienda: personas que entran a la casa del titular -->
            <div class="space-y-3" aria-labelledby="detalle-vivienda-subusuarios">
              <div class="flex items-center justify-between gap-2">
                <h4 id="detalle-vivienda-subusuarios" class="text-sm font-bold text-slate-900 tracking-tight">Sub-usuarios</h4>
                @if (!cargandoSubusuarios && !errorSubusuarios) {
                  <span class="text-[11px] font-semibold px-2 py-0.5 rounded-full bg-slate-100 text-slate-600">
                    {{ subusuarios.length }} de {{ maxSubusuarios }}
                  </span>
                }
              </div>
              @if (cargandoSubusuarios) {
                <div class="flex items-center gap-2 py-2 text-xs text-slate-500 font-medium" aria-busy="true">
                  <div class="w-4 h-4 border-2 border-slate-200 border-t-blue-600 rounded-full animate-spin"></div>
                  <span>Consultando sub-usuarios...</span>
                </div>
              } @else if (errorSubusuarios) {
                <p class="p-3 rounded-xl bg-amber-50/70 border border-amber-200 text-xs text-amber-900" role="alert">
                  No se pudieron cargar los sub-usuarios de esta vivienda.
                </p>
              } @else if (subusuarios.length === 0) {
                <p class="p-4 rounded-xl bg-slate-50/70 border border-dashed border-slate-200 text-xs text-slate-500 text-center">
                  Esta vivienda no tiene sub-usuarios.
                </p>
              } @else {
                <ul class="space-y-2">
                  @for (u of subusuarios; track u.id) {
                    <li
                      class="flex items-center justify-between gap-3 p-3 rounded-xl border"
                      [ngClass]="u.activo ? 'border-slate-200 bg-white' : 'border-dashed border-amber-300 bg-amber-50/40'"
                    >
                      <div class="min-w-0">
                        <p class="text-sm font-bold text-slate-900 truncate">{{ u.activo ? u.nombre : (u.email || 'Invitación sin correo') }}</p>
                        <p class="text-xs text-slate-600 font-medium truncate">
                          {{ u.activo ? (u.email || u.telefono || 'Sin contacto') : 'Aún no acepta la invitación' }}
                        </p>
                      </div>
                      <div class="shrink-0 flex flex-col items-end gap-1">
                        <span class="px-2 py-0.5 rounded text-[10px] font-medium border bg-slate-100 text-slate-600 border-slate-200">{{ u.parentesco }}</span>
                        <span
                          class="px-2 py-0.5 rounded text-[10px] font-medium border"
                          [ngClass]="u.activo ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-amber-50 text-amber-700 border-amber-200'"
                        >{{ u.activo ? 'Activo' : 'Invitación pendiente' }}</span>
                      </div>
                    </li>
                  }
                </ul>
              }
            </div>
            <!-- Informacion Tecnica Adicional -->
            <div class="bg-white border border-slate-200/80 rounded-xl p-5 shadow-xs divide-y divide-slate-100 text-xs">
              <div class="py-2 flex items-center justify-between">
                <span class="text-slate-400 font-medium">ID Interno</span>
                <span class="font-mono font-semibold text-slate-700">#{{ vivienda?.id }}</span>
              </div>
              <div class="py-2 flex items-center justify-between">
                <span class="text-slate-400 font-medium">Tipo de Estructura</span>
                <span class="font-semibold text-slate-700">{{ vivienda?.tipo || 'Casa Residencial' }}</span>
              </div>
              <div class="py-2 flex items-center justify-between">
                <span class="text-slate-400 font-medium">Condominio</span>
                <span class="font-semibold text-slate-700">Haven Residencial</span>
              </div>
            </div>
          </div>
        </aside>
      }
    `
})
export class ViviendasDetalleComponent implements OnChanges, AfterViewInit {
  @Input() vivienda: Vivienda | null = null;
  @Input() isOpen = false;
  /** Se abrió desde el detalle de un residente: muestra la flecha para volver a él */
  @Input() conAtras = false;
  @Input() textoAtras = 'Volver';
  /** Hay otro detalle encima de este: no reacciona a Escape para que solo se cierre el de arriba */
  @Input() inactivo = false;
  /** Vista del residente: sin residente asignado ni acciones de administración (el backend las restringe al administrador) */
  @Input() soloLectura = false;
  @Output() atras = new EventEmitter<void>();
  /** Se tocó al residente asignado: el padre abre su detalle */
  @Output() verResidente = new EventEmitter<Residente>();
  @Output() close = new EventEmitter<void>();
  @Output() viviendaUpdated = new EventEmitter<void>();

  private readonly viviendasService = inject(ViviendasService);
  private readonly residentesService = inject(ResidentesService);
  private readonly subusuariosService = inject(SubusuariosService);
  private readonly elemento = inject(ElementRef<HTMLElement>);

  readonly getInitials = getInitials;
  readonly maxSubusuarios = this.subusuariosService.MAX_SUBUSUARIOS;

  // Sub-usuarios de la vivienda abierta (activos e invitaciones pendientes), solo lectura
  subusuarios: SubUsuarioItem[] = [];
  cargandoSubusuarios = false;
  errorSubusuarios = false;
  /** Solo la respuesta de la última consulta se aplica: una lenta de otra vivienda no debe pisarla */
  private consultaSubusuarios = 0;

  residenteAsignado: Residente | null = null;
  cargandoResidente = false;
  errorResidente = false;

  // Estado del formulario de vinculacion (Issue #87)
  mostrarFormularioVinculacion = false;
  catalogoResidentes: Residente[] = [];
  cargandoCatalogo = false;
  busquedaResidente = '';
  residenteSeleccionadoId: string | null = null;
  procesandoVinculacion = false;
  isGeneratingCode = false;

  async generarCodigoVivienda(): Promise<void> {
    if (!this.vivienda) return;
    this.isGeneratingCode = true;
    try {
      const res = await this.viviendasService.generarCodigo(this.vivienda.id, 1440);
      if (res && res.codigo) {
        await Swal.fire({
          title: `Código para Casa #${this.vivienda.numeroCasa}`,
          html: `
            <div class="text-center space-y-3 p-2">
              <p class="text-xs text-slate-500">Comparte este código con el residente para vincularse a esta vivienda:</p>
              <div class="p-3 bg-slate-100 rounded-xl border border-slate-200 inline-block tracking-widest font-mono text-3xl font-black text-[#111C99]">
                ${res.codigo}
              </div>
              <p class="text-[11px] text-slate-400">⏱️ Válido durante 24 horas.</p>
            </div>
          `,
          icon: 'success',
          showCancelButton: true,
          confirmButtonText: 'Copiar Código',
          cancelButtonText: 'Cerrar',
          confirmButtonColor: '#111C99',
          cancelButtonColor: '#64748B'
        }).then((result) => {
          if (result.isConfirmed) {
            navigator.clipboard.writeText(res.codigo);
            Swal.fire({
              toast: true,
              position: 'top-end',
              icon: 'success',
              title: 'Código copiado al portapapeles',
              showConfirmButton: false,
              timer: 2500
            });
          }
        });
      } else {
        await Swal.fire({
          icon: 'error',
          title: 'Error al generar código',
          text: 'No se pudo generar el código para la vivienda.',
          confirmButtonColor: '#111C99'
        });
      }
    } catch (err: any) {
      console.error('Error generando código de vivienda:', err);
      await Swal.fire({
        icon: 'error',
        title: 'Error',
        text: mensajeAmigable(err, 'Ocurrió un problema al solicitar el código.'),
        confirmButtonColor: '#111C99'
      });
    } finally {
      this.isGeneratingCode = false;
    }
  }

  /** Al abrirse, el foco pasa al detalle (flecha de regreso o botón de cerrar) para que el teclado no se quede en lo de abajo */
  ngAfterViewInit(): void {
    if (this.isOpen) (this.elemento.nativeElement as HTMLElement).querySelector<HTMLElement>('[data-foco-inicial], [data-foco-cierre]')?.focus();
  }

  @HostListener('document:keydown.escape', ['$event'])
  onEsc(evento?: Event): void {
    // Otro detalle ya atendió esta pulsación (o hay uno encima): este no debe cerrarse también
    if (this.inactivo || evento?.defaultPrevented) return;
    if (this.isOpen && !this.procesandoVinculacion) {
      if (this.mostrarFormularioVinculacion) {
        this.cancelarFormularioVinculacion();
      } else if (this.conAtras) {
        // Escape hace lo mismo que la flecha: retrocede un paso en vez de cerrar todo
        evento?.preventDefault();
        this.atras.emit();
      } else {
        this.cerrar();
      }
    }
  }

  ngOnChanges(changes: SimpleChanges): void {
    if ((changes['vivienda'] || changes['isOpen']) && this.vivienda && this.isOpen) {
      this.mostrarFormularioVinculacion = false;
      this.residenteSeleccionadoId = null;
      if (!this.soloLectura) this.cargarDetalleResidente();
      void this.cargarSubusuarios();
    }
  }

  async cargarSubusuarios(): Promise<void> {
    if (!this.vivienda) return;
    const consulta = ++this.consultaSubusuarios;
    this.subusuarios = [];
    this.errorSubusuarios = false;
    this.cargandoSubusuarios = true;
    try {
      const lista = await this.subusuariosService.listarPorVivienda(this.vivienda.id);
      if (consulta !== this.consultaSubusuarios) return;
      this.subusuarios = lista;
    } catch (err) {
      if (consulta !== this.consultaSubusuarios) return;
      console.error('[ViviendasDetalleComponent] Error al cargar sub-usuarios:', err);
      this.errorSubusuarios = true;
    } finally {
      if (consulta === this.consultaSubusuarios) this.cargandoSubusuarios = false;
    }
  }

  cerrar(): void {
    this.mostrarFormularioVinculacion = false;
    this.close.emit();
  }

  async cargarDetalleResidente(): Promise<void> {
    if (!this.vivienda) return;
    this.cargandoResidente = true;
    this.errorResidente = false;

    try {
      const residentes = await this.viviendasService.obtenerResidentesVivienda(this.vivienda.id);
      this.residenteAsignado = (residentes && residentes.length > 0) ? residentes[0] : null;
    } catch (err) {
      console.error('[ViviendasDetalleComponent] Error al consultar el residente:', err);
      this.residenteAsignado = null;
      this.errorResidente = true;
    } finally {
      this.cargandoResidente = false;
    }
  }

  async abrirFormularioVinculacion(): Promise<void> {
    this.mostrarFormularioVinculacion = true;
    this.residenteSeleccionadoId = null;
    this.busquedaResidente = '';

    if (this.catalogoResidentes.length === 0) {
      this.cargandoCatalogo = true;
      try {
        this.catalogoResidentes = await this.residentesService.listar();
      } catch (err) {
        console.error('Error al cargar catalogo de residentes:', err);
      } finally {
        this.cargandoCatalogo = false;
      }
    }
  }

  cancelarFormularioVinculacion(): void {
    this.mostrarFormularioVinculacion = false;
    this.residenteSeleccionadoId = null;
  }

  get residentesFiltrados(): Residente[] {
    if (!this.busquedaResidente.trim()) return this.catalogoResidentes;
    const normalizar = (texto: string) =>
      texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim().toLowerCase();
    const query = normalizar(this.busquedaResidente);
    return this.catalogoResidentes.filter(r => {
      const nom = normalizar(`${r.nombre} ${r.apellidos}`);
      const em = normalizar(r.email || '');
      return nom.includes(query) || em.includes(query);
    });
  }

  seleccionarResidente(residente: Residente): void {
    this.residenteSeleccionadoId = residente.id;
  }

  async confirmarVinculacion(): Promise<void> {
    if (!this.vivienda || !this.residenteSeleccionadoId) return;

    this.procesandoVinculacion = true;
    try {
      await this.viviendasService.vincularResidente(this.vivienda.id, this.residenteSeleccionadoId);

      this.mostrarFormularioVinculacion = false;
      this.residenteSeleccionadoId = null;
      if (this.vivienda) {
        this.vivienda = { ...this.vivienda, ocupada: true };
      }

      await Swal.fire({
        title: '¡Residente Vinculado!',
        text: `El residente ha sido asignado a la vivienda ${this.vivienda.numeroCasa}.`,
        icon: 'success',
        confirmButtonText: 'Aceptar',
        confirmButtonColor: '#0F172A'
      });

      await this.cargarDetalleResidente();
      this.viviendaUpdated.emit();
    } catch (err: any) {
      console.error('Error al vincular residente:', err);
      const errorMsg = mensajeAmigable(err, 'No fue posible vincular el residente a la vivienda.');

      if (errorMsg.includes('ya está asignado a esta vivienda') || err?.status === 409) {
        this.mostrarFormularioVinculacion = false;
        this.residenteSeleccionadoId = null;
        if (this.vivienda) {
          this.vivienda = { ...this.vivienda, ocupada: true };
        }

        await Swal.fire({
          title: 'Asignación Existente',
          text: `El residente ya se encuentra asignado a la vivienda ${this.vivienda.numeroCasa} en el sistema.`,
          icon: 'info',
          confirmButtonText: 'Entendido',
          confirmButtonColor: '#0F172A'
        });

        await this.cargarDetalleResidente();
        this.viviendaUpdated.emit();
        return;
      }

      Swal.fire({
        title: 'Error de Vinculación',
        text: errorMsg,
        icon: 'error',
        confirmButtonText: 'Entendido',
        confirmButtonColor: '#0F172A'
      });
    } finally {
      this.procesandoVinculacion = false;
    }
  }

  async confirmarDesvinculacion(): Promise<void> {
    if (!this.vivienda || !this.residenteAsignado) return;

    const confirm = await Swal.fire({
      title: '¿Desvincular Residente?',
      text: `Se retirará la asignación de ${this.residenteAsignado.nombre} ${this.residenteAsignado.apellidos} de la ${this.vivienda.numeroCasa}.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Sí, desvincular',
      cancelButtonText: 'Cancelar',
      confirmButtonColor: '#e11d48',
      cancelButtonColor: '#64748b'
    });

    if (!confirm.isConfirmed) return;

    this.procesandoVinculacion = true;
    try {
      await this.viviendasService.desvincularResidente(this.vivienda.id, this.residenteAsignado.id);
      this.residenteAsignado = null;
      if (this.vivienda) {
        this.vivienda = { ...this.vivienda, ocupada: false };
      }

      await Swal.fire({
        title: 'Desvinculado',
        text: 'La vivienda ahora se encuentra disponible y sin habitante registrado.',
        icon: 'success',
        confirmButtonText: 'Aceptar',
        confirmButtonColor: '#0F172A'
      });

      this.viviendaUpdated.emit();
    } catch (err: any) {
      console.error('Error al desvincular residente:', err);
      const errorMsg = mensajeAmigable(err, 'No fue posible desvincular al habitante.');
      Swal.fire({
        title: 'Error al Desvincular',
        text: errorMsg,
        icon: 'error',
        confirmButtonText: 'Entendido',
        confirmButtonColor: '#0F172A'
      });
    } finally {
      this.procesandoVinculacion = false;
    }
  }
}
