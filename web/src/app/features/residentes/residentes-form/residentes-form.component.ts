import { Component, inject, signal, Input, Output, EventEmitter, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { ResidentesService } from '../../../core/services/residentes.service';
import { Subscription } from 'rxjs';
import Swal from 'sweetalert2';

@Component({
  selector: 'app-residentes-form',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  template: `
    <div [class]="isDrawer ? 'p-4 sm:p-5' : 'min-h-screen bg-slate-50 flex items-center justify-center p-4 sm:p-6 font-sans antialiased text-slate-900'">
      
      <!-- Container for Standalone (Half-page card) vs Drawer -->
      <div [class]="isDrawer ? 'w-full' : 'w-full max-w-4xl bg-white border border-slate-200/80 rounded-lg shadow-xl shadow-slate-200/50 overflow-hidden grid grid-cols-1 lg:grid-cols-12'">

        <!-- Left Branding Panel (only shown in standalone route / non-drawer mode) -->
        <div *ngIf="!isDrawer" class="lg:col-span-5 bg-gradient-to-br from-[#0a1160] via-[#111C99] to-[#1e2bb8] p-8 text-white flex flex-col justify-between relative overflow-hidden">
          <!-- Background glow circle -->
          <div class="absolute -top-12 -left-12 w-48 h-48 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none"></div>
          <div class="absolute -bottom-12 -right-12 w-48 h-48 bg-blue-500/10 rounded-full blur-3xl pointer-events-none"></div>

          <div class="relative z-10">
            <!-- Back link -->
            <a
              [routerLink]="['/dashboard/admin/residentes']"
              class="inline-flex items-center gap-1.5 text-xs font-medium text-slate-400 hover:text-white transition-colors mb-8"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              Volver al listado
            </a>

            <h1 class="text-2xl sm:text-3xl font-bold tracking-tight text-white mb-3">
              Nuevo residente
            </h1>
            <p class="text-sm text-slate-400 leading-relaxed">
              Completa los datos del nuevo residente para habilitar su acceso al residencial Haven.
            </p>
          </div>

          <div class="relative z-10 pt-8 border-t border-slate-800/80 text-xs text-slate-400 flex items-center gap-2">
            <svg class="w-4 h-4 text-emerald-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
            <span>Registro seguro y sincronización inmediata.</span>
          </div>
        </div>

        <!-- Form section (Occupies Right half in standalone or full width in drawer) -->
        <div [class]="isDrawer ? 'w-full' : 'lg:col-span-7 p-6 sm:p-8'">

          <!-- Form Header inside drawer -->
          <div *ngIf="isDrawer" class="mb-6">
            <div class="flex items-center justify-between">
              <div class="inline-flex items-center gap-2 px-2.5 py-1 rounded-full bg-indigo-50 border border-indigo-100 text-xs font-semibold text-indigo-700">
                <span class="w-1.5 h-1.5 rounded-full bg-indigo-600"></span>
                Alta Express
              </div>
            </div>
            <h2 class="text-xl sm:text-2xl font-bold text-slate-900 mt-2">
              Registrar Residente
            </h2>
            <p class="text-sm text-slate-500 mt-1">
              Ingresa la información personal del nuevo residente.
            </p>
          </div>

          <!-- Error Banner -->
          <div
            *ngIf="errorMessage()"
            class="mb-6 p-4 rounded-lg bg-red-50/90 border border-red-200 text-red-700 text-sm font-medium flex items-start gap-3 shadow-2xs transition-all"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5 shrink-0 text-red-600 mt-0.5">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
            </svg>
            <div class="flex-1">
              <span>{{ errorMessage() }}</span>
            </div>
          </div>

          <!-- Form -->
          <form [formGroup]="residenteForm" (ngSubmit)="onSubmit()" class="space-y-5">

            <!-- Grid: Nombre y Apellidos -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <!-- Nombre -->
              <div>
                <label for="nombre" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Nombre <span class="text-red-500">*</span>
                </label>
                <div class="relative rounded-lg shadow-2xs">
                  <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                  </div>
                  <input
                    id="nombre"
                    type="text"
                    formControlName="nombre"
                    (keypress)="permitirSoloLetras($event)"
                    (input)="filtrarSoloTexto($event, 'nombre')"
                    placeholder="Ej. Juan Carlos"
                    class="w-full pl-10 pr-3.5 py-2.5 bg-slate-50/50 hover:bg-white focus:bg-white border border-slate-200 rounded-lg text-slate-900 text-sm placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all"
                  />
                </div>
                <div *ngIf="residenteForm.get('nombre')?.touched && residenteForm.get('nombre')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                  <span *ngIf="residenteForm.get('nombre')?.errors?.['required']">El nombre es requerido.</span>
                  <span *ngIf="residenteForm.get('nombre')?.errors?.['pattern']">Solo se permiten letras y espacios.</span>
                  <span *ngIf="residenteForm.get('nombre')?.errors?.['backend']">{{ residenteForm.get('nombre')?.errors?.['backend'] }}</span>
                </div>
              </div>

              <!-- Apellidos -->
              <div>
                <label for="apellidos" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Apellidos <span class="text-red-500">*</span>
                </label>
                <div class="relative rounded-lg shadow-2xs">
                  <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V8a2 2 0 00-2-2h-5m-4 0V5a2 2 0 114 0v1m-4 0a2 2 0 104 0m-5 8a2 2 0 100-4 2 2 0 000 4zm0 0c1.306 0 2.417.835 2.83 2M9 14a3.001 3.001 0 00-2.83 2M15 11h3m-3 4h2" />
                    </svg>
                  </div>
                  <input
                    id="apellidos"
                    type="text"
                    formControlName="apellidos"
                    (keypress)="permitirSoloLetras($event)"
                    (input)="filtrarSoloTexto($event, 'apellidos')"
                    placeholder="Ej. Pérez García"
                    class="w-full pl-10 pr-3.5 py-2.5 bg-slate-50/50 hover:bg-white focus:bg-white border border-slate-200 rounded-lg text-slate-900 text-sm placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all"
                  />
                </div>
                <div *ngIf="residenteForm.get('apellidos')?.touched && residenteForm.get('apellidos')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                  <span *ngIf="residenteForm.get('apellidos')?.errors?.['required']">Los apellidos son requeridos.</span>
                  <span *ngIf="residenteForm.get('apellidos')?.errors?.['pattern']">Solo se permiten letras y espacios.</span>
                  <span *ngIf="residenteForm.get('apellidos')?.errors?.['backend']">{{ residenteForm.get('apellidos')?.errors?.['backend'] }}</span>
                </div>
              </div>
            </div>

            <!-- Teléfono -->
            <div>
              <label for="telefono" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Teléfono <span class="text-red-500">*</span>
              </label>
              <div class="relative rounded-lg shadow-2xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                  </svg>
                </div>
                <input
                  id="telefono"
                  type="tel"
                  formControlName="telefono"
                  placeholder="Ej. 4421234567"
                  class="w-full pl-10 pr-3.5 py-2.5 bg-slate-50/50 hover:bg-white focus:bg-white border border-slate-200 rounded-lg text-slate-900 text-sm placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all"
                />
              </div>
              <div *ngIf="residenteForm.get('telefono')?.touched && residenteForm.get('telefono')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                <span *ngIf="residenteForm.get('telefono')?.errors?.['required']">El teléfono es requerido.</span>
                <span *ngIf="residenteForm.get('telefono')?.errors?.['pattern']">Ingrese un número de teléfono válido (mínimo 10 dígitos).</span>
                <span *ngIf="residenteForm.get('telefono')?.errors?.['backend']">{{ residenteForm.get('telefono')?.errors?.['backend'] }}</span>
              </div>
            </div>

            <!-- Email -->
            <div>
              <label for="email" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Correo Electrónico <span class="text-red-500">*</span>
              </label>
              <div class="relative rounded-lg shadow-2xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                </div>
                <input
                  id="email"
                  type="email"
                  formControlName="email"
                  placeholder="residente@haven.com"
                  [class.border-red-400]="residenteForm.get('email')?.touched && residenteForm.get('email')?.invalid"
                  class="w-full pl-10 pr-3.5 py-2.5 bg-slate-50/50 hover:bg-white focus:bg-white border border-slate-200 rounded-lg text-slate-900 text-sm placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all"
                />
              </div>
              <div *ngIf="residenteForm.get('email')?.touched && residenteForm.get('email')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                <span *ngIf="residenteForm.get('email')?.errors?.['required']">El correo es requerido.</span>
                <span *ngIf="residenteForm.get('email')?.errors?.['email']">Ingrese un correo válido.</span>
                <span *ngIf="residenteForm.get('email')?.errors?.['duplicate']">Este correo ya está registrado en el sistema.</span>
                <span *ngIf="residenteForm.get('email')?.errors?.['backend']">{{ residenteForm.get('email')?.errors?.['backend'] }}</span>
              </div>
            </div>

            <!-- Password with Generator and Copy button -->
            <div>
              <div class="flex items-center justify-between mb-1.5">
                <label for="password" class="block text-xs font-bold text-slate-700 uppercase tracking-wider">
                  Contraseña <span class="text-red-500">*</span>
                </label>
                
                <div class="flex items-center gap-1.5">
                  <!-- Generate Random Password -->
                  <button
                    type="button"
                    (click)="generarPassword()"
                    class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold rounded-md bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border border-indigo-200 transition-colors cursor-pointer"
                    title="Generar contraseña segura aleatoria"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
                    </svg>
                    <span>Generar</span>
                  </button>

                  <!-- Copy Password -->
                  <button
                    type="button"
                    *ngIf="residenteForm.get('password')?.value"
                    (click)="copiarPassword()"
                    [class]="copiedPassword() ? 'bg-emerald-50 text-emerald-700 border-emerald-300' : 'bg-slate-100 hover:bg-slate-200 text-slate-700 border-slate-300'"
                    class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold rounded-md border transition-colors cursor-pointer"
                    title="Copiar contraseña al portapapeles"
                  >
                    <svg *ngIf="!copiedPassword()" xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                    </svg>
                    <svg *ngIf="copiedPassword()" xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-emerald-600" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                    </svg>
                    <span>{{ copiedPassword() ? '¡Copiada!' : 'Copiar' }}</span>
                  </button>
                </div>
              </div>

              <div class="relative rounded-lg shadow-2xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </div>
                <input
                  id="password"
                  [type]="showPassword() ? 'text' : 'password'"
                  formControlName="password"
                  placeholder="Mínimo 8 caracteres (o pulsa Generar)"
                  class="w-full pl-10 pr-10 py-2.5 bg-slate-50/50 hover:bg-white focus:bg-white border border-slate-200 rounded-lg text-slate-900 text-sm placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#111C99]/10 focus:border-[#111C99] transition-all font-mono"
                />
                <button
                  type="button"
                  (click)="showPassword.set(!showPassword())"
                  class="absolute inset-y-0 right-0 pr-3 flex items-center text-slate-400 hover:text-slate-600 cursor-pointer"
                  [title]="showPassword() ? 'Ocultar contraseña' : 'Ver contraseña'"
                >
                  <svg *ngIf="!showPassword()" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                  <svg *ngIf="showPassword()" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                  </svg>
                </button>
              </div>
              <div *ngIf="residenteForm.get('password')?.touched && residenteForm.get('password')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                <span *ngIf="residenteForm.get('password')?.errors?.['required']">La contraseña es requerida.</span>
                <span *ngIf="residenteForm.get('password')?.errors?.['minlength']">La contraseña debe tener al menos 8 caracteres.</span>
                <span *ngIf="residenteForm.get('password')?.errors?.['backend']">{{ residenteForm.get('password')?.errors?.['backend'] }}</span>
              </div>
            </div>

            <!-- Notice card -->
            <div class="p-3.5 rounded-lg bg-slate-50 border border-slate-200/80 text-xs text-slate-600 flex items-start gap-2.5">
              <svg class="w-4 h-4 text-indigo-600 shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>Recuerda compartir la contraseña generada con el residente para que pueda ingresar a Haven.</span>
            </div>

            <!-- Actions -->
            <div class="pt-3 flex items-center gap-3">
              <!-- Cancel -->
              <button
                type="button"
                (click)="onCancel()"
                class="px-5 py-2.5 bg-white hover:bg-slate-100 active:bg-slate-200 text-slate-700 font-medium text-sm rounded-lg transition-all border border-slate-300 shadow-2xs cursor-pointer"
              >
                Cancelar
              </button>

              <!-- Submit -->
              <button
                type="submit"
                [disabled]="isSubmitting()"
                class="flex-1 py-2.5 px-5 bg-[#111C99] hover:bg-[#0c146e] active:bg-[#0a1160] text-white font-semibold text-sm rounded-lg disabled:opacity-70 disabled:cursor-not-allowed transition-all shadow-md shadow-[#111C99]/10 hover:shadow-lg flex items-center justify-center gap-2 cursor-pointer"
              >
                <svg *ngIf="isSubmitting()" class="animate-spin h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                <span>{{ isSubmitting() ? 'Guardando...' : 'Guardar Residente' }}</span>
              </button>
            </div>

          </form>
        </div>

      </div>
    </div>
  `
})
export class ResidentesFormComponent implements OnInit, OnDestroy {
  @Input() isDrawer: boolean = false;
  @Output() saved = new EventEmitter<void>();
  @Output() cancelled = new EventEmitter<void>();

  private readonly fb = inject(FormBuilder);
  private readonly residentesService = inject(ResidentesService);
  private readonly router = inject(Router);

  readonly isSubmitting = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);
  readonly showPassword = signal<boolean>(false);
  readonly copiedPassword = signal<boolean>(false);

  private formSubscription: Subscription | null = null;

  residenteForm: FormGroup = this.fb.group({
    nombre: ['', [Validators.required, Validators.pattern(/^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$/)]],
    apellidos: ['', [Validators.required, Validators.pattern(/^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$/)]],
    telefono: ['', [Validators.required, Validators.pattern(/^[0-9\s\-+()]{10,15}$/)]],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]]
  });

  ngOnInit(): void {
    this.setupFormErrorCleaners();
  }

  private setupFormErrorCleaners(): void {
    this.formSubscription = this.residenteForm.valueChanges.subscribe(() => {
      // Limpiar mensaje global si el usuario edita
      if (this.errorMessage()) {
        this.errorMessage.set(null);
      }
    });

    // Limpiar errores personalizados de email al modificarlo
    const emailControl = this.residenteForm.get('email');
    emailControl?.valueChanges.subscribe(() => {
      if (emailControl.hasError('duplicate') || emailControl.hasError('backend')) {
        const errors = { ...emailControl.errors };
        delete errors['duplicate'];
        delete errors['backend'];
        emailControl.setErrors(Object.keys(errors).length ? errors : null);
      }
    });
  }

  generarPassword(): void {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&*';
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghjkmnpqrstuvwxyz';
    const digits = '23456789';
    const special = '!@#$%&*';
    
    let pwd = '';
    pwd += upper.charAt(Math.floor(Math.random() * upper.length));
    pwd += lower.charAt(Math.floor(Math.random() * lower.length));
    pwd += digits.charAt(Math.floor(Math.random() * digits.length));
    pwd += special.charAt(Math.floor(Math.random() * special.length));
    
    for (let i = 4; i < 10; i++) {
      pwd += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    
    pwd = pwd.split('').sort(() => 0.5 - Math.random()).join('');
    
    this.residenteForm.patchValue({ password: pwd });
    this.residenteForm.get('password')?.markAsDirty();
    this.residenteForm.get('password')?.markAsTouched();
    this.showPassword.set(true);
    this.copiedPassword.set(false);
  }

  async copiarPassword(): Promise<void> {
    const pwd = this.residenteForm.get('password')?.value;
    if (!pwd) return;
    
    try {
      await navigator.clipboard.writeText(pwd);
      this.copiedPassword.set(true);
      setTimeout(() => this.copiedPassword.set(false), 2500);
    } catch {
      // fallback
    }
  }

  reset(): void {
    this.residenteForm.reset();
    this.errorMessage.set(null);
    this.isSubmitting.set(false);
    this.showPassword.set(false);
    this.copiedPassword.set(false);
  }

  onCancel(): void {
    this.reset();
    if (this.isDrawer) {
      this.cancelled.emit();
    } else {
      this.router.navigate(['/dashboard/admin/residentes']);
    }
  }

  async onSubmit(): Promise<void> {
    if (this.residenteForm.invalid) {
      this.residenteForm.markAllAsTouched();
      return;
    }

    this.isSubmitting.set(true);
    this.errorMessage.set(null);

    const payload = { ...this.residenteForm.value, rol: 'residente' };

    try {
      await this.residentesService.crear(payload);
      
      const Toast = Swal.mixin({
        toast: true,
        position: 'top-end',
        showConfirmButton: false,
        timer: 3500,
        timerProgressBar: true
      });
      Toast.fire({
        icon: 'success',
        title: 'Residente registrado correctamente'
      });

      this.reset();

      if (this.isDrawer) {
        this.saved.emit();
      } else {
        this.router.navigate(['/dashboard/admin/residentes']);
      }
    } catch (err: any) {
      console.error('[ResidentesFormComponent] Error al registrar residente:', err);
      this.isSubmitting.set(false);
      
      const rawErrorString = (
        typeof err?.error === 'string'
          ? err.error
          : JSON.stringify(err?.error || '') + ' ' + (err?.message || '')
      ).toLowerCase();

      // 1. Detectar Correo Duplicado (409 Conflict, 400 Bad Request o mensajes de Supabase/Backend)
      const isDuplicateEmail =
        err?.status === 409 ||
        rawErrorString.includes('already registered') ||
        rawErrorString.includes('already exists') ||
        rawErrorString.includes('email_exists') ||
        rawErrorString.includes('user_already_exists') ||
        rawErrorString.includes('ya está registrado') ||
        rawErrorString.includes('ya se encuentra registrado') ||
        rawErrorString.includes('correo duplicado') ||
        rawErrorString.includes('correo ya existe') ||
        rawErrorString.includes('email already in use');

      if (isDuplicateEmail) {
        this.residenteForm.get('email')?.setErrors({ duplicate: true });
        this.residenteForm.get('email')?.markAsTouched();
        this.errorMessage.set('El correo electrónico ya se encuentra registrado. Por favor ingresa otro correo.');
        return;
      }

      // 2. Detectar errores de validación de campos del backend (400 / 422 ModelState)
      if (err?.error?.errors && typeof err.error.errors === 'object') {
        const validationMsgs: string[] = [];
        for (const [key, val] of Object.entries(err.error.errors)) {
          const fieldName = key.toLowerCase();
          const fieldErrors = Array.isArray(val) ? val.join(', ') : String(val);

          if (fieldName.includes('email') || fieldName.includes('correo')) {
            this.residenteForm.get('email')?.setErrors({ backend: fieldErrors });
            this.residenteForm.get('email')?.markAsTouched();
          } else if (fieldName.includes('nombre')) {
            this.residenteForm.get('nombre')?.setErrors({ backend: fieldErrors });
            this.residenteForm.get('nombre')?.markAsTouched();
          } else if (fieldName.includes('apellido')) {
            this.residenteForm.get('apellidos')?.setErrors({ backend: fieldErrors });
            this.residenteForm.get('apellidos')?.markAsTouched();
          } else if (fieldName.includes('telefono')) {
            this.residenteForm.get('telefono')?.setErrors({ backend: fieldErrors });
            this.residenteForm.get('telefono')?.markAsTouched();
          } else if (fieldName.includes('password') || fieldName.includes('contraseña')) {
            this.residenteForm.get('password')?.setErrors({ backend: fieldErrors });
            this.residenteForm.get('password')?.markAsTouched();
          }
          validationMsgs.push(fieldErrors);
        }

        if (validationMsgs.length > 0) {
          this.errorMessage.set(`Datos inválidos: ${validationMsgs.join('. ')}`);
          return;
        }
      }

      // 3. Categorizar otros errores generales / conexión / permisos
      let msg = 'No fue posible registrar al residente. Intenta de nuevo.';

      if (err?.status === 0) {
        msg = 'No fue posible conectar con el servidor. Verifica tu conexión a internet o intenta más tarde.';
      } else if (err?.status === 405) {
        msg = 'El servidor no tiene habilitado el método POST en esta ruta (Error 405 Method Not Allowed).';
      } else if (err?.status === 404) {
        msg = `La ruta ${err?.url || '/api/residentes'} no existe en el backend (Error 404 Not Found).`;
      } else if (err?.status === 429) {
        msg = 'Límite de peticiones o correos excedido en Supabase (Error 429 Rate Limit Exceeded). Espera unos minutos.';
      } else if (err?.status === 401 || err?.status === 403) {
        msg = 'No tienes permisos suficientes para registrar residentes (Error 401/403).';
      } else if (err?.status === 500) {
        msg = 'Ocurrió un error interno en el servidor. Por favor intenta más tarde.';
      } else if (err?.error?.message) {
        msg = err.error.message;
      } else if (err?.error?.error) {
        msg = typeof err.error.error === 'string' ? err.error.error : JSON.stringify(err.error.error);
      } else if (err?.error?.title) {
        msg = err.error.title;
      } else if (err?.error?.detail) {
        msg = err.error.detail;
      } else if (err?.message) {
        msg = err.message;
      }

      this.errorMessage.set(msg);
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

  filtrarSoloTexto(event: Event, controlName: 'nombre' | 'apellidos'): void {
    const input = event.target as HTMLInputElement;
    if (input) {
      const limpio = input.value.replace(/[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]/g, '');
      if (input.value !== limpio) {
        input.value = limpio;
      }
      this.residenteForm.get(controlName)?.setValue(limpio, { emitEvent: true });
    }
  }

  ngOnDestroy(): void {
    this.formSubscription?.unsubscribe();
  }
}
