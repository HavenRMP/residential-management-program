import { Component, inject, OnInit, ChangeDetectionStrategy } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import Swal from 'sweetalert2';

@Component({
  selector: 'app-auth-callback',
  standalone: true,
  imports: [],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="min-h-screen bg-[#F7F7F7] flex items-center justify-center font-sans antialiased">
      <div class="flex flex-col items-center gap-4 text-center">
        <svg class="animate-spin h-10 w-10 text-[#111C99]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="text-[#64748b] font-medium text-base">Verificando tu cuenta...</p>
      </div>
    </div>
  `
})
export class AuthCallbackComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);

  async ngOnInit(): Promise<void> {
    const params = new URLSearchParams(window.location.search);
    const errorDescription = params.get('error_description');
    if (errorDescription) {
      this.showErrorToastAndRedirect(errorDescription);
      return;
    }

    try {
      const result = await this.authService.handleCallback();
      if (!result.success) {
        this.showErrorToastAndRedirect(result.error || 'No se pudo completar el inicio de sesión.');
        return;
      }

      const role = this.authService.userRole();

      if (role === 'administrador' || role === 'vigilante') {
        // Staff no puede usar Google OAuth — cerrar sesión y redirigir con aviso.
        await this.authService.signOutAndRedirect(
          'El acceso con Google es exclusivo para residentes. Inicia sesión con tu correo y contraseña.'
        );
        return;
      }

      // Residente OK — si el perfil está incompleto (sin teléfono o apellidos), redirigir a completar perfil
      if (this.authService.isProfileIncomplete()) {
        await this.router.navigate(['/perfil'], { queryParams: { onboarding: 'true' } });
        return;
      }

      await this.authService.navigateToDashboard();
    } catch (err: any) {
      this.showErrorToastAndRedirect(err?.message || 'Error inesperado al verificar la cuenta.');
    }
  }

  private showErrorToastAndRedirect(message: string): void {
    Swal.fire({
      icon: 'error',
      title: 'Error de autenticación',
      text: message,
      toast: true,
      position: 'top-end',
      showConfirmButton: false,
      timer: 3500,
      timerProgressBar: true
    });
    this.router.navigate(['/login']);
  }
}
