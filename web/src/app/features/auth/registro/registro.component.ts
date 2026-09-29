import { Component, inject, signal, OnInit, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AbstractControl, FormBuilder, FormGroup, ReactiveFormsModule, ValidationErrors, ValidatorFn, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import Swal from 'sweetalert2';

export const passwordMatchValidator: ValidatorFn = (control: AbstractControl): ValidationErrors | null => {
  const password = control.get('password');
  const confirmPassword = control.get('confirmPassword');
  if (!password || !confirmPassword) return null;
  return password.value === confirmPassword.value ? null : { passwordMismatch: true };
};

@Component({
  selector: 'app-registro',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  template: `
    <div class="min-h-screen bg-[#F7F7F7] flex items-center justify-center p-4 sm:p-6 font-sans antialiased text-[#0f172a] selection:bg-[#111C99] selection:text-white py-12">
      <div class="w-full max-w-[540px] bg-white border border-[#e2e8f0] rounded-lg p-6 sm:p-8 shadow-sm">

        <!-- Brand Logo -->
        <div class="flex justify-center mb-6">
          <img src="/haven-logo.png" alt="Haven" class="w-12 h-12 object-contain" />
        </div>

        <!-- Pantalla de Éxito / Confirmación de Email -->
        <div *ngIf="emailConfirmationSent()" class="text-center py-6 animate-in fade-in duration-200">
          <div class="w-16 h-16 rounded-2xl bg-blue-50 border border-blue-100 flex items-center justify-center mx-auto mb-5 text-[#111C99]">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
          </div>
          <h2 class="text-2xl font-bold text-slate-900 tracking-tight">Verifica tu correo</h2>
          <p class="text-sm text-slate-600 mt-2 max-w-sm mx-auto leading-relaxed">
            Hemos enviado un enlace de activación a tu correo electrónico. Por favor verifica tu bandeja de entrada para activar tu cuenta de residente.
          </p>
          <div class="mt-8">
            <a
              routerLink="/login"
              class="inline-flex items-center justify-center py-3 px-6 bg-[#111C99] hover:bg-[#0c146e] text-white font-semibold text-sm rounded-lg transition-all shadow-xs cursor-pointer"
            >
              Ir a Iniciar Sesión
            </a>
          </div>
        </div>

        <!-- Formulario de Registro -->
        <div *ngIf="!emailConfirmationSent()">
          <!-- Title & Subtitle -->
          <div class="mb-8 text-center">
            <h1 class="text-2xl sm:text-3xl font-extrabold text-[#0f172a] tracking-tight">
              Crear cuenta de residente
            </h1>
            <p class="text-sm text-[#64748b] mt-1.5">
              Regístrate para acceder al portal y solicitar la vinculación a tu vivienda
            </p>
          </div>

          <!-- Form -->
          <form [formGroup]="registroForm" (ngSubmit)="onSubmit()" class="space-y-4 sm:space-y-5">
            <!-- Error Banner -->
            <div *ngIf="errorMessage()" class="p-3.5 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm font-medium flex items-center gap-2.5 animate-in fade-in duration-150">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5 shrink-0 text-red-600">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
              </svg>
              <span>{{ errorMessage() }}</span>
            </div>

            <!-- Nombre y Apellidos en 2 columnas -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label for="nombre" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Nombre <span class="text-red-500">*</span>
                </label>
                <input
                  id="nombre"
                  type="text"
                  formControlName="nombre"
                  (keypress)="permitirSoloLetras($event)"
                  (input)="filtrarSoloTexto($event, 'nombre')"
                  placeholder="Ej. Juan Carlos"
                  class="w-full px-3.5 py-2.5 bg-white border border-[#e2e8f0] rounded-lg text-[#0f172a] text-sm placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#111C99]/20 focus:border-[#111C99] transition-all"
                />
                <div *ngIf="registroForm.get('nombre')?.touched && registroForm.get('nombre')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                  <span *ngIf="registroForm.get('nombre')?.errors?.['required']">El nombre es requerido.</span>
                  <span *ngIf="registroForm.get('nombre')?.errors?.['pattern']">Solo se permiten letras y espacios.</span>
                </div>
              </div>

              <div>
                <label for="apellidos" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Apellidos <span class="text-red-500">*</span>
                </label>
                <input
                  id="apellidos"
                  type="text"
                  formControlName="apellidos"
                  (keypress)="permitirSoloLetras($event)"
                  (input)="filtrarSoloTexto($event, 'apellidos')"
                  placeholder="Ej. Pérez Gómez"
                  class="w-full px-3.5 py-2.5 bg-white border border-[#e2e8f0] rounded-lg text-[#0f172a] text-sm placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#111C99]/20 focus:border-[#111C99] transition-all"
                />
                <div *ngIf="registroForm.get('apellidos')?.touched && registroForm.get('apellidos')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                  <span *ngIf="registroForm.get('apellidos')?.errors?.['required']">Los apellidos son requeridos.</span>
                  <span *ngIf="registroForm.get('apellidos')?.errors?.['pattern']">Solo se permiten letras y espacios.</span>
                </div>
              </div>
            </div>

            <!-- Teléfono a 10 dígitos -->
            <div>
              <label for="telefono" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Teléfono de contacto <span class="text-red-500">*</span>
              </label>
              <input
                id="telefono"
                type="tel"
                maxlength="10"
                formControlName="telefono"
                placeholder="10 dígitos numéricos (ej. 4421234567)"
                class="w-full px-3.5 py-2.5 bg-white border border-[#e2e8f0] rounded-lg text-[#0f172a] text-sm placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#111C99]/20 focus:border-[#111C99] transition-all"
              />
              <div *ngIf="registroForm.get('telefono')?.touched && registroForm.get('telefono')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                Debe contener exactamente 10 dígitos numéricos.
              </div>
            </div>

            <!-- Correo Electrónico -->
            <div>
              <label for="email" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Correo Electrónico <span class="text-red-500">*</span>
              </label>
              <input
                id="email"
                type="email"
                formControlName="email"
                placeholder="tu@correo.com"
                class="w-full px-3.5 py-2.5 bg-white border border-[#e2e8f0] rounded-lg text-[#0f172a] text-sm placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#111C99]/20 focus:border-[#111C99] transition-all"
              />
              <div *ngIf="registroForm.get('email')?.touched && registroForm.get('email')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                <span *ngIf="registroForm.get('email')?.errors?.['required']">El correo es requerido.</span>
                <span *ngIf="registroForm.get('email')?.errors?.['email']">Ingrese un correo electrónico válido.</span>
              </div>
            </div>

            <!-- Contraseñas en 2 columnas -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label for="password" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Contraseña <span class="text-red-500">*</span>
                </label>
                <div class="relative">
                  <input
                    id="password"
                    [type]="showPassword() ? 'text' : 'password'"
                    formControlName="password"
                    placeholder="Mínimo 6 caracteres"
                    class="w-full pl-3.5 pr-10 py-2.5 bg-white border border-[#e2e8f0] rounded-lg text-[#0f172a] text-sm placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#111C99]/20 focus:border-[#111C99] transition-all"
                  />
                  <button
                    type="button"
                    (click)="showPassword.set(!showPassword())"
                    class="absolute inset-y-0 right-0 pr-3 flex items-center text-slate-400 hover:text-slate-700 cursor-pointer"
                    [title]="showPassword() ? 'Ocultar' : 'Mostrar'"
                  >
                    <svg *ngIf="showPassword()" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                    </svg>
                    <svg *ngIf="!showPassword()" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                  </button>
                </div>
                <div *ngIf="registroForm.get('password')?.touched && registroForm.get('password')?.invalid" class="mt-1 text-xs text-red-500 font-medium">
                  Mínimo 6 caracteres.
                </div>
              </div>

              <div>
                <label for="confirmPassword" class="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Confirmar Contraseña <span class="text-red-500">*</span>
                </label>
                <input
                  id="confirmPassword"
                  type="password"
                  formControlName="confirmPassword"
                  placeholder="Repite la contraseña"
                  class="w-full px-3.5 py-2.5 bg-white border border-[#e2e8f0] rounded-lg text-[#0f172a] text-sm placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#111C99]/20 focus:border-[#111C99] transition-all"
                />
                <div *ngIf="registroForm.hasError('passwordMismatch') && registroForm.get('confirmPassword')?.touched" class="mt-1 text-xs text-red-500 font-medium">
                  Las contraseñas no coinciden.
                </div>
              </div>
            </div>

            <!-- Submit Button -->
            <div class="pt-3">
              <button
                type="submit"
                id="btn-register-submit"
                [disabled]="isSubmitting()"
                class="w-full py-3.5 px-4 bg-[#111C99] hover:bg-[#0c146e] active:bg-[#0a1160] text-white font-semibold text-base rounded-lg disabled:opacity-75 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2 shadow-xs cursor-pointer"
              >
                <svg *ngIf="isSubmitting()" class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                <span>{{ isSubmitting() ? 'Registrando...' : 'Crear mi cuenta' }}</span>
              </button>
            </div>

            <!-- Divider -->
            <div class="flex items-center gap-3 pt-2">
              <div class="flex-1 h-px bg-[#e2e8f0]"></div>
              <span class="text-xs text-[#94a3b8] font-medium">o</span>
              <div class="flex-1 h-px bg-[#e2e8f0]"></div>
            </div>

            <!-- Google OAuth Button -->
            <button
              type="button"
              id="btn-register-google"
              [disabled]="isSubmittingGoogle()"
              (click)="registerWithGoogle()"
              class="w-full py-3 px-4 bg-white border border-[#e2e8f0] hover:bg-[#f1f3f7] active:bg-[#e2e8f0] text-[#0f172a] font-semibold text-sm rounded-lg disabled:opacity-75 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-3 cursor-pointer shadow-xs"
            >
              <svg width="18" height="18" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z" fill="#FFC107"/>
                <path d="M6.306 14.691l6.571 4.819C14.655 15.108 19.001 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z" fill="#FF3D00"/>
                <path d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238A11.91 11.91 0 0124 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z" fill="#4CAF50"/>
                <path d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 01-4.087 5.571l.003-.002 6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z" fill="#1976D2"/>
              </svg>
              <span>{{ isSubmittingGoogle() ? 'Redirigiendo...' : 'Registrarme con Google' }}</span>
            </button>

            <!-- Bottom Link hacia Login -->
            <div class="pt-4 text-center">
              <p class="text-sm text-slate-600">
                ¿Ya tienes una cuenta registrada?
                <a routerLink="/login" class="font-semibold text-[#111C99] hover:underline cursor-pointer ml-1">
                  Inicia sesión aquí
                </a>
              </p>
            </div>
          </form>
        </div>

      </div>
    </div>
  `
})
export class RegistroComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);

  readonly isSubmitting = signal(false);
  readonly isSubmittingGoogle = signal(false);
  readonly errorMessage = signal<string | null>(null);
  readonly showPassword = signal(false);
  readonly emailConfirmationSent = signal(false);

  registroForm: FormGroup = this.fb.group({
    nombre: ['', [Validators.required, Validators.pattern(/^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$/)]],
    apellidos: ['', [Validators.required, Validators.pattern(/^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$/)]],
    telefono: ['', [Validators.required, Validators.pattern('^[0-9]{10}$')]],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]],
    confirmPassword: ['', Validators.required]
  }, { validators: passwordMatchValidator });

  constructor() {
    effect(() => {
      if (this.authService.authStatus() === 'authenticated') {
        this.authService.navigateToDashboard();
      }
    });
  }

  ngOnInit(): void {
    if (this.authService.authStatus() === 'authenticated') {
      this.authService.navigateToDashboard();
    }
  }

  async onSubmit(): Promise<void> {
    if (this.registroForm.invalid) {
      this.registroForm.markAllAsTouched();
      return;
    }

    this.isSubmitting.set(true);
    this.errorMessage.set(null);

    try {
      const { nombre, apellidos, telefono, email, password } = this.registroForm.value;
      const res = await this.authService.register({
        nombre,
        apellidos,
        telefono,
        email,
        password
      });

      if (!res.success) {
        this.errorMessage.set(res.error || 'No fue posible registrar la cuenta.');
        return;
      }

      if (res.requiresEmailConfirmation) {
        this.emailConfirmationSent.set(true);
        return;
      }

      Swal.fire({
        icon: 'success',
        title: '¡Cuenta creada!',
        text: 'Te damos la bienvenida a Haven.',
        toast: true,
        position: 'top-end',
        showConfirmButton: false,
        timer: 2500,
        timerProgressBar: true
      });

      await this.authService.navigateToDashboard();
    } catch (err: any) {
      this.errorMessage.set(err?.message || 'Error inesperado al procesar el registro.');
    } finally {
      this.isSubmitting.set(false);
    }
  }

  async registerWithGoogle(): Promise<void> {
    this.isSubmittingGoogle.set(true);
    this.errorMessage.set(null);
    try {
      const res = await this.authService.loginWithGoogle();
      if (!res.success) {
        this.errorMessage.set(res.error || 'No se pudo conectar con Google.');
        this.isSubmittingGoogle.set(false);
      }
    } catch (err: any) {
      this.errorMessage.set(err?.message || 'Error inesperado al conectar con Google.');
      this.isSubmittingGoogle.set(false);
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
      this.registroForm.get(controlName)?.setValue(limpio, { emitEvent: true });
    }
  }
}
