import { Component, inject, signal, computed, OnInit, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { PingService } from '../../../core/services/ping.service';
import Swal from 'sweetalert2';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  template: `
    <div class="min-h-screen bg-[#F7F7F7] flex items-center justify-center p-6 font-sans antialiased text-[#0f172a] selection:bg-[#111C99] selection:text-white">
      <div class="w-full max-w-[480px] bg-white border border-[#e2e8f0] rounded-lg p-8 shadow-sm">

        <!-- Brand Logo -->
        <div class="flex justify-center mb-8">
          <img src="/haven-logo.png" alt="Haven" class="w-12 h-12 object-contain" />
        </div>

        <!-- Mode Toggle -->
        <div class="flex border border-[#e2e8f0] rounded-lg overflow-hidden mb-8">
          <button
            type="button"
            id="toggle-residente"
            (click)="setModo('residente')"
            class="flex-1 py-2.5 text-sm font-semibold transition-all"
            [class.bg-[#111C99]]="modo() === 'residente'"
            [class.text-white]="modo() === 'residente'"
            [class.text-[#64748b]]="modo() !== 'residente'"
            [class.bg-white]="modo() !== 'residente'"
          >
            Residente
          </button>
          <button
            type="button"
            id="toggle-staff"
            (click)="setModo('staff')"
            class="flex-1 py-2.5 text-sm font-semibold transition-all"
            [class.bg-[#111C99]]="modo() === 'staff'"
            [class.text-white]="modo() === 'staff'"
            [class.text-[#64748b]]="modo() !== 'staff'"
            [class.bg-white]="modo() !== 'staff'"
          >
            Administrador · Vigilancia
          </button>
        </div>

        <!-- Title & Subtitle -->
        <h2 class="text-3xl leading-tight font-bold text-[#0f172a] tracking-tight">
          Iniciar sesión
        </h2>
        <p class="text-base font-normal text-[#64748b] mt-2 mb-8 min-h-[24px]">
          {{ modo() === 'residente' ? 'Acceso para residentes' : 'Acceso para administración y vigilancia' }}
        </p>

        <!-- Skeleton de carga: sustituye al formulario mientras se valida la sesión -->
        <div *ngIf="isSubmitting() || isSubmittingGoogle()" class="space-y-6" aria-live="polite" aria-busy="true">
          <div class="flex items-center gap-3 p-3.5 rounded-lg bg-[#111C99]/5 border border-[#111C99]/10">
            <span class="relative flex h-2.5 w-2.5 shrink-0">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#111C99]/50"></span>
              <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-[#111C99]"></span>
            </span>
            <span class="text-sm font-medium text-[#111C99]">{{ mensajeEstadoCarga() }}</span>
          </div>

          <div class="space-y-2">
            <div class="h-3 w-14 bg-slate-200 rounded-sm animate-pulse"></div>
            <div class="h-[50px] w-full bg-slate-100 rounded-lg animate-pulse"></div>
          </div>

          <div class="space-y-2">
            <div class="h-3 w-24 bg-slate-200 rounded-sm animate-pulse"></div>
            <div class="h-[50px] w-full bg-slate-100 rounded-lg animate-pulse"></div>
          </div>

          <div class="h-[50px] w-full bg-slate-200 rounded-lg animate-pulse"></div>
        </div>

        <!-- Form -->
        <form *ngIf="!isSubmitting() && !isSubmittingGoogle()" [formGroup]="loginForm" (ngSubmit)="onSubmit()" class="space-y-6">
          <!-- Error Banner -->
          <div *ngIf="errorMessage()" class="p-3.5 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm font-medium flex items-center gap-2.5">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5 shrink-0 text-red-600">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
            </svg>
            <span>{{ errorMessage() }}</span>
          </div>

          <!-- Email -->
          <div>
            <label for="email" class="block text-sm font-semibold text-[#1e293b] mb-2">
              Correo
            </label>
            <input
              id="email"
              type="email"
              formControlName="email"
              placeholder="usuario@haven.com"
              class="w-full px-4 py-3 bg-white border border-[#e2e8f0] rounded-lg text-[#0f172a] text-base placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#111C99]/20 focus:border-[#111C99] transition-all"
            />
            <div *ngIf="loginForm.get('email')?.touched && loginForm.get('email')?.invalid" class="mt-1.5 text-xs text-red-500 font-medium">
              <span *ngIf="loginForm.get('email')?.errors?.['required']">El correo es requerido.</span>
              <span *ngIf="loginForm.get('email')?.errors?.['email']">Ingrese un correo válido.</span>
            </div>
          </div>

          <!-- Password -->
          <div>
            <label for="password" class="block text-sm font-semibold text-[#1e293b] mb-2">
              Contraseña
            </label>
            <div class="relative">
              <input
                id="password"
                [type]="showPassword() ? 'text' : 'password'"
                formControlName="password"
                placeholder="••••••••"
                class="w-full pl-4 pr-12 py-3 bg-white border border-[#e2e8f0] rounded-lg text-[#0f172a] text-base placeholder-[#94a3b8] focus:outline-none focus:ring-2 focus:ring-[#111C99]/20 focus:border-[#111C99] transition-all"
              />
              <button
                type="button"
                (click)="showPassword.set(!showPassword())"
                class="absolute inset-y-0 right-0 pr-3.5 pl-2 flex items-center text-slate-400 hover:text-slate-700 active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#111C99]/30 rounded-md transition-all cursor-pointer"
                [title]="showPassword() ? 'Ocultar contraseña' : 'Ver contraseña'"
                [attr.aria-label]="showPassword() ? 'Ocultar contraseña' : 'Ver contraseña'"
                [attr.aria-pressed]="showPassword()"
              >
                <!-- Eye slash (when visible) -->
                <svg *ngIf="showPassword()" xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                </svg>
                <!-- Eye (when hidden) -->
                <svg *ngIf="!showPassword()" xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
              </button>
            </div>
            <div *ngIf="loginForm.get('password')?.touched && loginForm.get('password')?.invalid" class="mt-1.5 text-xs text-red-500 font-medium">
              <span *ngIf="loginForm.get('password')?.errors?.['required']">La contraseña es requerida.</span>
              <span *ngIf="loginForm.get('password')?.errors?.['minlength']">Mínimo 6 caracteres.</span>
            </div>
          </div>

          <!-- Submit Button -->
          <div class="pt-2">
            <button
              type="submit"
              id="btn-submit"
              [disabled]="isSubmitting()"
              class="w-full py-3.5 px-4 bg-[#111C99] hover:bg-[#0c146e] active:bg-[#0a1160] text-white font-semibold text-base rounded-lg disabled:opacity-75 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2 shadow-xs cursor-pointer"
            >
              <svg *ngIf="isSubmitting()" class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span>{{ isSubmitting() ? 'Entrando...' : 'Entrar' }}</span>
            </button>
          </div>

          <!-- Zona de Acción Secundaria / Simétrica (Misma altura para ambos modos) -->
          <div class="min-h-[88px] flex flex-col justify-end">
            <!-- Google OAuth (solo modo residente) -->
            <ng-container *ngIf="modo() === 'residente'">
              <div class="flex items-center gap-3 mb-4">
                <div class="flex-1 h-px bg-[#e2e8f0]"></div>
                <span class="text-xs text-[#94a3b8] font-medium">o</span>
                <div class="flex-1 h-px bg-[#e2e8f0]"></div>
              </div>
              <button
                type="button"
                id="btn-google"
                [disabled]="isSubmittingGoogle()"
                (click)="loginGoogle()"
                class="w-full py-3.5 px-4 bg-white border border-[#e2e8f0] hover:bg-[#f1f3f7] active:bg-[#e2e8f0] text-[#0f172a] font-semibold text-base rounded-lg disabled:opacity-75 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-3 cursor-pointer shadow-xs"
              >
                <!-- Google SVG icon 4 colores -->
                <svg width="20" height="20" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z" fill="#FFC107"/>
                  <path d="M6.306 14.691l6.571 4.819C14.655 15.108 19.001 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z" fill="#FF3D00"/>
                  <path d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238A11.91 11.91 0 0124 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z" fill="#4CAF50"/>
                  <path d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 01-4.087 5.571l.003-.002 6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z" fill="#1976D2"/>
                </svg>
                <span>{{ isSubmittingGoogle() ? 'Redirigiendo...' : 'Continuar con Google' }}</span>
              </button>
            </ng-container>

            <!-- Nota Institucional de Seguridad (solo modo staff) -->
            <ng-container *ngIf="modo() === 'staff'">
              <div class="flex items-center gap-3 mb-4">
                <div class="flex-1 h-px bg-[#e2e8f0]"></div>
                <span class="text-[11px] text-[#94a3b8] font-semibold uppercase tracking-wider">Seguridad Haven</span>
                <div class="flex-1 h-px bg-[#e2e8f0]"></div>
              </div>
              <div class="py-3 px-4 bg-[#f8fafc] border border-[#e2e8f0] rounded-lg text-center flex items-center justify-center gap-2.5">
                <svg class="w-4 h-4 text-[#64748b] shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                </svg>
                <span class="text-xs text-[#64748b] font-medium leading-tight">Acceso restringido con credenciales corporativas directas.</span>
              </div>
            </ng-container>
          </div>

          <!-- Enlace a Registro (solo residentes) -->
          <div *ngIf="modo() === 'residente'" class="pt-4 text-center border-t border-slate-100">
            <p class="text-sm text-slate-600">
              ¿No tienes una cuenta?
              <a routerLink="/registro" class="font-semibold text-[#111C99] hover:underline cursor-pointer ml-1">
                Regístrate aquí
              </a>
            </p>
          </div>
        </form>
      </div>
    </div>
  `
})
export class LoginComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly authService = inject(AuthService);
  private readonly pingService = inject(PingService);

  readonly isSubmitting = signal<boolean>(false);
  readonly isSubmittingGoogle = signal<boolean>(false);
  readonly isWakingUp = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);
  readonly modo = signal<'residente' | 'staff'>('residente');
  readonly showPassword = signal<boolean>(false);

  readonly mensajeEstadoCarga = computed(() => {
    if (this.isSubmittingGoogle()) return 'Redirigiendo a Google...';
    if (this.isWakingUp()) return 'Conectando con el servidor en la nube, esto puede tardar unos segundos...';
    return 'Verificando tus datos...';
  });

  private readonly MODO_ROLES: Record<'residente' | 'staff', string[]> = {
    residente: ['residente'],
    staff: ['administrador', 'vigilante']
  };

  loginForm: FormGroup = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]]
  });

  constructor() {
    effect(() => {
      // Solo redirige automaticamente si el usuario ya venia autenticado (ej. OAuth o sesion previa)
      // y no esta enviando el formulario manualmente en este momento para evitar colisiones
      if (this.authService.authStatus() === 'authenticated' && !this.isSubmitting()) {
        this.authService.navigateToDashboard();
      }
    });
  }

  ngOnInit(): void {
    // Despierta el servidor en Render en segundo plano mientras el usuario llena el formulario
    this.pingService.checkBackendConnection();
  }

  setModo(modo: 'residente' | 'staff'): void {
    this.modo.set(modo);
    this.errorMessage.set(null);
    this.showPassword.set(false);
    this.loginForm.reset();
  }

  async loginGoogle(): Promise<void> {
    this.errorMessage.set(null);
    this.isSubmittingGoogle.set(true);
    // Timeout de seguridad: si el redirect de Supabase no ocurre en 10s, restaurar el botón.
    const safetyTimer = setTimeout(() => this.isSubmittingGoogle.set(false), 10000);
    const result = await this.authService.loginWithGoogle();
    if (!result.success) {
      clearTimeout(safetyTimer);
      this.isSubmittingGoogle.set(false);
      this.errorMessage.set(result.error || 'No se pudo iniciar sesión con Google.');
    }
    // En éxito, Supabase redirige el navegador — el timer se cancela solo con la navegación.
  }

  async onSubmit(): Promise<void> {
    if (this.loginForm.invalid) {
      this.loginForm.markAllAsTouched();
      return;
    }

    this.isSubmitting.set(true);
    this.errorMessage.set(null);

    // Si tarda más de 3.5s (backend en frío en Render), el skeleton actualiza su mensaje
    const wakingTimer = setTimeout(() => {
      if (this.isSubmitting()) {
        this.isWakingUp.set(true);
      }
    }, 3500);

    try {
      const { email, password } = this.loginForm.value;
      const result = await this.authService.login(email, password);

      if (result.success) {
        const Toast = Swal.mixin({
          toast: true,
          position: 'top-end',
          showConfirmButton: false,
          timer: 3000,
          timerProgressBar: true
        });

        const rolReal = result.role || '';
        const coincideConModo = this.MODO_ROLES[this.modo()].includes(rolReal);

        if (coincideConModo) {
          Toast.fire({ icon: 'success', title: '¡Inicio de sesión correcto!' });
        } else {
          const etiqueta = rolReal === 'vigilante' ? 'vigilancia' : rolReal;
          Toast.fire({
            icon: 'info',
            title: `Detectamos que tu cuenta es de ${etiqueta}, te llevamos a tu panel.`
          });
        }
      } else {
        let errText = result.error || 'Ocurrió un error al iniciar sesión.';
        if (errText.includes('Invalid login credentials')) {
          errText = 'Correo o contraseña incorrectos.';
        }
        this.errorMessage.set(errText);
      }
    } finally {
      clearTimeout(wakingTimer);
      this.isSubmitting.set(false);
      this.isWakingUp.set(false);
    }
  }
}
