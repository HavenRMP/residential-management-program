import { Component, inject, signal } from '@angular/core';
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
        <div class="w-full px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
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
      <main class="w-full px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        <!-- Welcome Hero -->
        <div class="bg-white border border-slate-200 rounded-xl px-5 py-4 shadow-xs">
          <h1 class="text-xl sm:text-2xl font-bold tracking-tight text-slate-900">
            Control de Caseta y Accesos
          </h1>
          <p class="text-sm text-slate-600 mt-1">
            Valida códigos, registra entradas y salidas, y consulta a quién llamar en cada casa.
          </p>
        </div>

        <!-- Dos vistas para no saturar la pantalla: la caseta del día y el directorio de personas -->
        <div class="flex items-center p-1 bg-slate-200/80 rounded-lg text-xs font-semibold text-slate-700 w-fit" role="tablist" aria-label="Secciones del portal de vigilancia">
          <button
            type="button"
            role="tab"
            [attr.aria-selected]="vista() === 'caseta'"
            (click)="vista.set('caseta')"
            class="px-4 py-1.5 rounded-md transition-all cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
            [ngClass]="vista() === 'caseta' ? 'bg-white text-slate-900 shadow-2xs' : 'text-slate-700'"
          >
            Caseta
          </button>
          <button
            type="button"
            role="tab"
            [attr.aria-selected]="vista() === 'directorio'"
            (click)="vista.set('directorio')"
            class="px-4 py-1.5 rounded-md transition-all cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
            [ngClass]="vista() === 'directorio' ? 'bg-white text-slate-900 shadow-2xs' : 'text-slate-700'"
          >
            Directorio
          </button>
        </div>

        <!-- Las dos vistas se ocultan en vez de destruirse, para no perder la búsqueda ni la pestaña elegida -->
        <div [class.hidden]="vista() !== 'caseta'" class="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
          <div class="lg:col-span-2 min-w-0">
            <app-caseta-visitas />
          </div>
          <aside class="min-w-0">
            <app-avisos-caseta />
          </aside>
        </div>

        <div [class.hidden]="vista() !== 'directorio'">
          <app-directorio-casas />
        </div>
      </main>
    </div>
  `
})
export class VigilanteDashboardComponent {
  private readonly authService = inject(AuthService);
  readonly currentUser = this.authService.currentUser;
  readonly vista = signal<'caseta' | 'directorio'>('caseta');

  onLogout(): void {
    this.authService.logout();
  }
}
