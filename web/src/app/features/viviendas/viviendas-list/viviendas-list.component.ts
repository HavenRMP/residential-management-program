import { Component, inject, signal, computed, OnInit } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { Vivienda } from '../../../core/models/vivienda.model';
import { CondominiosService } from '../../../core/services/condominios.service';
import { Condominio } from '../../../core/models/condominio.model';
import { ViviendasDetalleComponent } from '../viviendas-detalle/viviendas-detalle.component';

@Component({
  selector: 'app-viviendas-list',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, DatePipe, ViviendasDetalleComponent],
  template: `
    <div class="p-4 sm:p-5 lg:p-6 max-w-7xl mx-auto space-y-4 selection:bg-[#111C99] selection:text-white">

      <!-- Breadcrumb & Top Navigation -->
      <nav class="flex items-center gap-2 text-xs text-slate-500 font-medium">
        <a routerLink="/dashboard/admin" class="hover:text-slate-900 transition-colors">Panel Principal</a>
        <span>/</span>
        <span class="text-slate-900">Directorio de Viviendas</span>
      </nav>

      <!-- Page Header & Action Bar -->
      <div class="bg-white border border-slate-200 rounded-lg p-4 sm:p-5 shadow-xs">
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div>
            <div class="flex flex-wrap items-center gap-3">
              <h1 class="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
                Directorio de Viviendas
              </h1>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-blue-50 text-[#111C99] border border-blue-200">
                {{ viviendas().length }} {{ viviendas().length === 1 ? 'vivienda' : 'viviendas' }}
              </span>
              <!-- Condominio Badge del Administrador -->
              <span *ngIf="condominioActual()" class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                </svg>
                <span>{{ condominioActual()?.nombre }}</span>
              </span>
            </div>
            <p class="text-sm text-slate-500 mt-1.5">
              Consulta, registra y administra los inmuebles de Haven Residencial.
            </p>
          </div>

          <div class="flex items-center gap-3 shrink-0">
            <!-- Refresh Button -->
            <button
              (click)="cargarViviendas()"
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

            <!-- Nueva Vivienda Button -->
            <button
              (click)="abrirModalCrear()"
              class="inline-flex items-center gap-2 px-3 py-2 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-lg text-xs font-bold shadow-xs transition-all cursor-pointer"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              <span>Nueva Vivienda</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Live Search & Control Toolbar -->
      <div class="bg-white border border-slate-200 rounded-lg p-2.5 shadow-2xs flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="flex items-center gap-2 flex-1 max-w-xl">
          <!-- Input Búsqueda -->
          <div class="relative flex-1">
            <svg class="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              [ngModel]="searchQuery()"
              (ngModelChange)="searchQuery.set($event)"
              placeholder="Buscar por número o identificador..."
              class="w-full h-8 pl-8 pr-8 text-xs bg-slate-50/70 hover:bg-white focus:bg-white border border-slate-200 rounded-lg text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all"
            />
            <button
              *ngIf="searchQuery()"
              (click)="searchQuery.set('')"
              class="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-0.5 rounded cursor-pointer"
              title="Limpiar búsqueda"
            >
              <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Selector de Tipo -->
          <select
            [ngModel]="filtroTipo()"
            (ngModelChange)="filtroTipo.set($event)"
            class="h-8 px-2 text-xs bg-slate-50/70 hover:bg-white focus:bg-white border border-slate-200 rounded-lg text-slate-700 focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all cursor-pointer shrink-0"
          >
            <option value="todos">Todos los tipos</option>
            <option *ngFor="let t of tiposDisponibles()" [value]="t">{{ t }}</option>
          </select>
        </div>

        <div class="flex items-center justify-between sm:justify-end gap-3 text-xs text-slate-500 font-medium px-2">
          <span>
            Mostrando <strong class="text-slate-800">{{ viviendasFiltradas().length }}</strong> de {{ viviendas().length }}
          </span>
        </div>
      </div>

      <!-- Loading State -->
      <div *ngIf="isLoading() && viviendas().length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-white rounded-lg border border-slate-200 shadow-xs">
        <div class="w-10 h-10 border-3 border-slate-200 border-t-[#111C99] rounded-full animate-spin"></div>
        <p class="text-sm font-semibold text-slate-600">Sincronizando viviendas...</p>
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
          (click)="cargarViviendas()"
          class="px-4 py-2 bg-red-100 hover:bg-red-200 text-red-900 font-semibold text-xs rounded-lg transition-colors cursor-pointer"
        >
          Reintentar
        </button>
      </div>

      <!-- Empty State -->
      <div
        *ngIf="!isLoading() && !errorMessage() && viviendas().length === 0"
        class="bg-white border border-slate-200/80 rounded-lg shadow-xs flex flex-col items-center justify-center py-12 px-4 text-center"
      >
        <div class="w-16 h-16 rounded-2xl bg-blue-50 border border-blue-100 flex items-center justify-center mb-4 text-[#111C99]">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
          </svg>
        </div>
        <h3 class="text-lg font-bold text-slate-900">No hay viviendas registradas</h3>
        <p class="text-sm text-slate-500 max-w-sm mt-1">
          Comienza dando de alta la primera vivienda del condominio.
        </p>
        <button
          (click)="abrirModalCrear()"
          class="mt-6 inline-flex items-center gap-2 px-4 py-2 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-lg text-xs font-semibold shadow-xs transition-all cursor-pointer"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Dar de alta vivienda
        </button>
      </div>

      <!-- Empty State por Filtro / Búsqueda -->
      <div
        *ngIf="!isLoading() && !errorMessage() && viviendas().length > 0 && viviendasFiltradas().length === 0"
        class="bg-white border border-slate-200 rounded-lg shadow-xs flex flex-col items-center justify-center py-8 px-4 text-center"
      >
        <p class="text-xs text-slate-500">No se encontraron viviendas con los filtros actuales.</p>
        <button
          (click)="searchQuery.set(''); filtroTipo.set('todos')"
          class="mt-2 text-xs font-semibold text-[#111C99] hover:underline cursor-pointer"
        >
          Limpiar filtros de búsqueda
        </button>
      </div>

      <!-- Modern, Spacious Table (Estilo amigable aprobado) -->
      <div
        *ngIf="!isLoading() && !errorMessage() && viviendasFiltradas().length > 0"
        class="bg-white border border-slate-200 rounded-lg shadow-xs overflow-hidden"
      >
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-slate-100">
            <thead>
              <tr class="bg-slate-50/80">
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Vivienda
                </th>
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Tipo de Unidad
                </th>
                <th class="px-6 py-4 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Fecha de Alta
                </th>
                <th class="px-6 py-4 text-right text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Acciones
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 bg-white">
              <tr
                *ngFor="let v of viviendasFiltradas()"
                (click)="abrirDetalle(v)"
                class="group hover:bg-blue-50/40 transition-colors cursor-pointer"
              >
                <!-- Numero Casa / Avatar -->
                <td class="px-6 py-4.5 whitespace-nowrap">
                  <div class="flex items-center gap-3.5">
                    <div class="w-10 h-10 rounded-full bg-[#eff6ff] text-[#111C99] flex items-center justify-center shadow-2xs ring-1 ring-blue-100 group-hover:scale-105 transition-transform shrink-0">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-[#111C99]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                      </svg>
                    </div>
                    <div>
                      <span class="text-sm font-bold text-slate-900 group-hover:text-[#111C99] transition-colors font-mono">
                        {{ v.numeroCasa }}
                      </span>
                    </div>
                  </div>
                </td>

                <!-- Tipo -->
                <td class="px-6 py-4.5 whitespace-nowrap">
                  <span class="inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700 border border-slate-200">
                    {{ v.tipo || 'Sin especificar' }}
                  </span>
                </td>

                <!-- Fecha de Alta -->
                <td class="px-6 py-4.5 whitespace-nowrap">
                  <div class="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 bg-slate-100/80 px-2.5 py-1 rounded-md">
                    <svg class="w-3.5 h-3.5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <span class="font-mono text-xs">{{ v.creadoEn ? (v.creadoEn | date:'dd/MM/yyyy') : '—' }}</span>
                  </div>
                </td>

                <!-- Acciones (Ver Detalle, Editar y Eliminar) -->
                <td class="px-6 py-4.5 whitespace-nowrap text-right text-sm">
                  <div class="inline-flex items-center gap-1.5">
                    <!-- Ver Detalle -->
                    <button
                      (click)="$event.stopPropagation(); abrirDetalle(v)"
                      title="Ver detalle de vivienda y residentes"
                      class="p-2 text-[#111C99] hover:text-[#0d1577] hover:bg-blue-50 rounded-lg transition-colors cursor-pointer"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </svg>
                    </button>

                    <!-- Editar -->
                    <button
                      (click)="$event.stopPropagation(); abrirModalEditar(v)"
                      title="Editar vivienda"
                      class="p-2 text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                      </svg>
                    </button>

                    <!-- Borrar -->
                    <button
                      (click)="$event.stopPropagation(); confirmarEliminar(v)"
                      title="Eliminar vivienda"
                      class="p-2 text-rose-500 hover:text-rose-700 hover:bg-rose-50 rounded-lg transition-colors cursor-pointer"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Modal de Creación / Edición Compacto -->
      <div
        *ngIf="showModal()"
        class="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4 animate-in fade-in duration-150"
      >
        <div
          class="bg-white rounded-lg shadow-xl border border-slate-200 w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-150"
          (click)="$event.stopPropagation()"
        >
          <!-- Header del Modal -->
          <div class="px-6 py-5 border-b border-slate-100 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="w-9 h-9 rounded-full bg-blue-50 text-[#111C99] flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
              </div>
              <div>
                <h3 class="text-lg font-bold text-slate-900">
                  {{ isEditing() ? 'Editar Vivienda' : 'Nueva Vivienda' }}
                </h3>
                <p class="text-xs text-slate-500">
                  {{ isEditing() ? 'Actualiza los datos del inmueble' : 'Captura el número y tipo de vivienda' }}
                </p>
              </div>
            </div>
            <button
              (click)="cerrarModal()"
              class="text-slate-400 hover:text-slate-600 p-1.5 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Formulario -->
          <form (ngSubmit)="guardarVivienda()" class="p-6 space-y-4">
            <!-- Mensaje de error local -->
            <div
              *ngIf="formError()"
              class="p-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl flex items-center gap-2"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-red-500 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>{{ formError() }}</span>
            </div>

            <!-- Campo: Condominio (Asignación Automática al Condominio del Administrador) -->
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Condominio
              </label>
              <div class="flex items-center gap-2.5 px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-800">
                <span class="w-2 h-2 rounded-full bg-emerald-500 shrink-0"></span>
                <span class="font-medium truncate">{{ condominioActual()?.nombre || 'Tu condominio administrado' }}</span>
                <span class="ml-auto text-[10px] font-semibold text-emerald-700 bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full shrink-0">
                  Asignación automática
                </span>
              </div>
              <p class="text-[11px] text-slate-400 mt-1">
                La vivienda se vinculará directamente a tu condominio administrado.
              </p>
            </div>

            <!-- Campo: Número de Casa -->
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Número de Casa o Identificador <span class="text-red-500">*</span>
              </label>
              <input
                type="text"
                name="numeroCasa"
                [(ngModel)]="formNumeroCasa"
                placeholder="Ej. Casa 42, Depto 301, Manzana 3 Lote 5..."
                class="w-full text-sm bg-slate-50/70 border border-slate-200 rounded-lg px-3 py-2 text-slate-900 placeholder-slate-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all"
                maxlength="50"
                required
              />
            </div>

            <!-- Campo: Tipo de Vivienda -->
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Tipo de Vivienda (Opcional)
              </label>

              <!-- Quick Chips -->
              <div class="flex flex-wrap gap-1 mb-2">
                <button
                  type="button"
                  *ngFor="let t of ['Casa', 'Departamento', 'Penthouse', 'Townhouse']"
                  (click)="formTipo = t"
                  [class.bg-blue-50]="formTipo === t"
                  [class.border-blue-300]="formTipo === t"
                  [class.text-[#111C99]]="formTipo === t"
                  class="px-2 py-0.5 text-[11px] font-medium rounded border border-slate-200 text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
                >
                  {{ t }}
                </button>
              </div>

              <input
                type="text"
                name="tipo"
                [(ngModel)]="formTipo"
                (keypress)="permitirSoloLetras($event)"
                (input)="filtrarSoloTextoTipo($event)"
                placeholder="Ej. Casa, Departamento, Townhouse..."
                class="w-full text-sm bg-slate-50/70 border border-slate-200 rounded-lg px-3 py-2 text-slate-900 placeholder-slate-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all"
                maxlength="50"
              />
            </div>

            <!-- Footer con Botones -->
            <div class="pt-4 border-t border-slate-100 flex items-center justify-end gap-3">
              <button
                type="button"
                (click)="cerrarModal()"
                [disabled]="isSaving()"
                class="px-4 py-2 text-sm font-semibold text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer disabled:opacity-50"
              >
                Cancelar
              </button>

              <button
                type="submit"
                [disabled]="isSaving() || !formNumeroCasa.trim()"
                class="inline-flex items-center gap-2 px-5 py-2 bg-[#111C99] hover:bg-[#0d1577] text-white text-sm font-semibold rounded-lg shadow-xs transition-all cursor-pointer disabled:opacity-50"
              >
                <div *ngIf="isSaving()" class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                <span>{{ isSaving() ? 'Guardando...' : (isEditing() ? 'Actualizar' : 'Guardar') }}</span>
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Slide-over Drawer Detalle Vivienda (Issue #50 & #87) -->
      <app-viviendas-detalle
        [vivienda]="viviendaSeleccionada()"
        [isOpen]="isDetalleOpen()"
        (close)="cerrarDetalle()"
        (viviendaUpdated)="cargarViviendas()"
      />

    </div>
  `
})
export class ViviendasListComponent implements OnInit {
  private readonly viviendasService = inject(ViviendasService);
  private readonly condominiosService = inject(CondominiosService);

  readonly viviendas = signal<Vivienda[]>([]);
  readonly searchQuery = signal<string>('');
  readonly filtroTipo = signal<string>('todos');
  readonly isLoading = signal<boolean>(true);
  readonly errorMessage = signal<string | null>(null);

  // Estado del Condominio del Administrador y lista para selección
  readonly condominioActual = this.condominiosService.condominioActual;
  readonly listaCondominios = signal<Condominio[]>([]);

  // Modal State
  readonly showModal = signal<boolean>(false);
  readonly isEditing = signal<boolean>(false);
  readonly editingId = signal<number | null>(null);
  readonly isSaving = signal<boolean>(false);
  readonly formError = signal<string | null>(null);

  // Drawer Detalle State
  readonly viviendaSeleccionada = signal<Vivienda | null>(null);
  readonly isDetalleOpen = signal<boolean>(false);

  formNumeroCasa: string = '';
  formTipo: string = '';
  formCondominioId: string = '';

  readonly tiposDisponibles = computed(() => {
    const list = this.viviendas();
    const set = new Set<string>();
    for (const v of list) {
      if (v.tipo && v.tipo.trim()) {
        set.add(v.tipo.trim());
      }
    }
    return Array.from(set);
  });

  readonly viviendasFiltradas = computed(() => {
    const query = this.searchQuery().trim().toLowerCase();
    const tipo = this.filtroTipo();
    const list = this.viviendas();

    return list.filter(v => {
      const matchQuery = !query || (v.numeroCasa && v.numeroCasa.toLowerCase().includes(query));
      const matchTipo = tipo === 'todos' || (v.tipo && v.tipo.trim().toLowerCase() === tipo.toLowerCase());
      return matchQuery && matchTipo;
    });
  });

  async ngOnInit(): Promise<void> {
    await Promise.all([
      this.cargarCondominios(),
      this.cargarViviendas()
    ]);
  }

  async cargarCondominios(): Promise<void> {
    try {
      const conds = await this.condominiosService.listar();
      this.listaCondominios.set(conds);
      if (!this.condominioActual() && conds.length > 0) {
        await this.condominiosService.cargarCondominioUsuario(conds[0].id);
      }
    } catch (err) {
      console.warn('[ViviendasList] Error al cargar condominios:', err);
    }
  }

  async cargarViviendas(): Promise<void> {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    try {
      const data = await this.viviendasService.listar();
      this.viviendas.set(data || []);
    } catch {
      this.errorMessage.set('No fue posible cargar la lista de viviendas desde el servidor.');
    } finally {
      this.isLoading.set(false);
    }
  }

  abrirDetalle(vivienda: Vivienda): void {
    this.viviendaSeleccionada.set(vivienda);
    this.isDetalleOpen.set(true);
  }

  cerrarDetalle(): void {
    this.isDetalleOpen.set(false);
  }

  abrirModalCrear(): void {
    this.isEditing.set(false);
    this.editingId.set(null);
    this.formNumeroCasa = '';
    this.formTipo = '';
    this.formCondominioId = this.condominioActual()?.id || (this.listaCondominios().length > 0 ? this.listaCondominios()[0].id : 'a0000000-0000-0000-0000-000000000001');
    this.formError.set(null);
    this.showModal.set(true);
  }

  abrirModalEditar(vivienda: Vivienda): void {
    this.isEditing.set(true);
    this.editingId.set(vivienda.id);
    this.formNumeroCasa = vivienda.numeroCasa;
    this.formTipo = vivienda.tipo || '';
    this.formCondominioId = vivienda.condominioId || this.condominioActual()?.id || (this.listaCondominios().length > 0 ? this.listaCondominios()[0].id : '');
    this.formError.set(null);
    this.showModal.set(true);
  }

  cerrarModal(): void {
    if (this.isSaving()) return;
    this.showModal.set(false);
  }

  async guardarVivienda(): Promise<void> {
    const numeroCasa = this.formNumeroCasa.trim();
    if (!numeroCasa) {
      this.formError.set('El número de casa es obligatorio.');
      return;
    }

    this.isSaving.set(true);
    this.formError.set(null);

    try {
      if (this.isEditing()) {
        const id = this.editingId()!;
        await this.viviendasService.actualizar(id, {
          numeroCasa,
          tipo: this.formTipo.trim() || null,
          condominioId: this.formCondominioId || undefined
        });
        await Swal.fire({
          title: '¡Actualizada!',
          text: 'Los datos de la vivienda han sido actualizados exitosamente.',
          icon: 'success',
          confirmButtonText: 'Aceptar',
          confirmButtonColor: '#111C99'
        });
      } else {
        await this.viviendasService.crear({
          numeroCasa,
          tipo: this.formTipo.trim() || null
        });
        await Swal.fire({
          title: '¡Vivienda Creada!',
          text: 'La vivienda se ha registrado correctamente en tu condominio.',
          icon: 'success',
          confirmButtonText: 'Aceptar',
          confirmButtonColor: '#111C99'
        });
      }

      this.showModal.set(false);
      await this.cargarViviendas();
    } catch (err: any) {
      console.error('Error al guardar vivienda:', err);
      const msg = err?.error?.error || err?.message || 'Ocurrió un error al procesar la solicitud.';
      this.formError.set(msg);
    } finally {
      this.isSaving.set(false);
    }
  }

  async confirmarEliminar(vivienda: Vivienda): Promise<void> {
    const result = await Swal.fire({
      title: '¿Eliminar vivienda?',
      text: `¿Estás seguro de que deseas eliminar la vivienda ${vivienda.numeroCasa}? Esta acción no se puede deshacer.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Sí, eliminar',
      cancelButtonText: 'Cancelar',
      confirmButtonColor: '#e11d48',
      cancelButtonColor: '#64748b'
    });

    if (result.isConfirmed) {
      try {
        await this.viviendasService.eliminar(vivienda.id);
        await Swal.fire({
          title: '¡Eliminada!',
          text: 'La vivienda ha sido eliminada del sistema.',
          icon: 'success',
          confirmButtonText: 'Aceptar',
          confirmButtonColor: '#111C99'
        });
        await this.cargarViviendas();
      } catch (err: any) {
        console.error('Error al eliminar vivienda:', err);
        const msg = err?.error?.error || err?.message || 'No fue posible eliminar la vivienda.';
        Swal.fire({
          title: 'Error al eliminar',
          text: msg,
          icon: 'error',
          confirmButtonText: 'Entendido',
          confirmButtonColor: '#111C99'
        });
      }
    }
  }

  permitirSoloLetras(event: KeyboardEvent): void {
    if (['Backspace', 'Tab', 'ArrowLeft', 'ArrowRight', 'Delete', 'Enter'].includes(event.key)) {
      return;
    }
    if (event.ctrlKey || event.metaKey) {
      return;
    }
    const regex = /^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]$/;
    if (!regex.test(event.key)) {
      event.preventDefault();
    }
  }

  filtrarSoloTextoTipo(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input) {
      const limpio = input.value.replace(/[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]/g, '');
      if (input.value !== limpio) {
        input.value = limpio;
      }
      this.formTipo = limpio;
    }
  }
}
