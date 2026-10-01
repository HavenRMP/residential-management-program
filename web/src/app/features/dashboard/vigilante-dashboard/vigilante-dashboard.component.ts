import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AuthService } from '../../../core/services/auth.service';
import { UserMenuComponent } from '../../../core/components/user-menu/user-menu.component';
import { CasetaVisitasComponent } from '../../visitas/caseta-visitas/caseta-visitas.component';
import { AvisosCasetaComponent } from '../../avisos/avisos-caseta/avisos-caseta.component';
import { DirectorioCasasComponent } from '../../visitas/directorio-casas/directorio-casas.component';

@Component({
  selector: 'app-vigilante-dashboard',
  standalone: true,
  imports: [CommonModule, UserMenuComponent, CasetaVisitasComponent, DirectorioCasasComponent, AvisosCasetaComponent],
  template: `
    <div class="min-h-screen bg-[#F7F7F7] text-[#0f172a] font-sans antialiased">
      <!-- Navbar -->
      <header class="bg-white border-b border-slate-200 sticky top-0 z-30">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <img src="/haven-logo.png" alt="Haven" class="w-9 h-9 rounded-lg object-contain" />
            <div>
              <span class="font-bold text-lg tracking-tight text-slate-900">Haven</span>
              <span class="ml-2 text-xs font-semibold px-2 py-0.5 rounded-full bg-amber-50 text-amber-800 border border-amber-200">
                Control de Caseta / Vigilancia
              </span>
            </div>
          </div>

          <app-user-menu [user]="currentUser()" (logout)="onLogout()" />
        </div>
      </header>

      <!-- Main Content -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        <!-- Welcome Hero -->
        <div class="bg-white border border-slate-200 rounded-xl p-6 sm:p-8 shadow-xs">
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">
            Control de Caseta y Accesos
          </h1>
          <p class="text-slate-600 mt-2">
            Bienvenido al portal de vigilancia y control de accesos.
          </p>
        </div>

        <!-- Caseta a la izquierda; a la derecha en pantallas grandes, el directorio de casas y los avisos vigentes (solo lectura) -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
          <div class="lg:col-span-2 min-w-0">
            <app-caseta-visitas />
          </div>
          <aside class="min-w-0 space-y-6">
            <app-directorio-casas />
            <app-avisos-caseta />
          </aside>
        </div>
      </main>
    </div>
  `
})
export class VigilanteDashboardComponent {
  private readonly authService = inject(AuthService);
  readonly currentUser = this.authService.currentUser;

  onLogout(): void {
    this.authService.logout();
  }
}
