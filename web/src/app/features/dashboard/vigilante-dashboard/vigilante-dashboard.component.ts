import { Component, inject, signal, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AuthService } from '../../../core/services/auth.service';
import { UserMenuComponent } from '../../../core/components/user-menu/user-menu.component';
import { CasetaVisitasComponent } from '../../visitas/caseta-visitas/caseta-visitas.component';
import { AvisosCasetaComponent } from '../../avisos/avisos-caseta/avisos-caseta.component';
import { DirectorioCasasComponent } from '../../visitas/directorio-casas/directorio-casas.component';
import { ReservasCasetaComponent } from '../../reservas/caseta/reservas-caseta.component';
import { PaqueteriaCasetaComponent } from '../../paqueteria/caseta/paqueteria-caseta.component';

type Vista = 'caseta' | 'paquetes' | 'directorio' | 'reservas';

@Component({
  selector: 'app-vigilante-dashboard',
  standalone: true,
  imports: [CommonModule, UserMenuComponent, CasetaVisitasComponent, DirectorioCasasComponent, AvisosCasetaComponent, ReservasCasetaComponent, PaqueteriaCasetaComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
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
            Valida códigos, recibe y entrega paquetes, consulta a quién llamar en cada casa y revisa las reservas de áreas comunes.
          </p>
        </div>

        <!-- Cuatro vistas para no saturar la pantalla. Las pestañas son grandes: quien atiende la caseta las toca de pie y con prisa -->
        <div class="grid grid-cols-2 sm:flex sm:w-fit items-center gap-1 p-1 bg-slate-200/80 rounded-lg text-sm sm:text-base font-semibold text-slate-700" role="tablist" aria-label="Secciones del portal de vigilancia">
          @for (s of secciones; track s.id) {
            <button
              type="button"
              role="tab"
              [attr.aria-selected]="vista() === s.id"
              (click)="elegirVista(s.id)"
              class="min-h-11 px-5 py-2 rounded-md transition-all cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
              [ngClass]="vista() === s.id ? 'bg-white text-slate-900 shadow-2xs' : 'text-slate-700 hover:bg-white/60'"
            >
              {{ s.texto }}
            </button>
          }
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

        <!-- Los paquetes se piden la primera vez que se abre la vista, no al entrar al portal -->
        @if (paquetesAbierta()) {
          <div [class.hidden]="vista() !== 'paquetes'">
            <app-paqueteria-caseta />
          </div>
        }

        <div [class.hidden]="vista() !== 'directorio'">
          <app-directorio-casas />
        </div>

        <!-- Las reservas se piden a la primera vez que se abre la vista, no al entrar al portal -->
        @if (reservasAbierta()) {
          <div [class.hidden]="vista() !== 'reservas'">
            <app-reservas-caseta />
          </div>
        }
      </main>
    </div>
  `
})
export class VigilanteDashboardComponent {
  private readonly authService = inject(AuthService);
  readonly currentUser = this.authService.currentUser;
  readonly secciones: { id: Vista; texto: string }[] = [
    { id: 'caseta', texto: 'Caseta' },
    { id: 'paquetes', texto: 'Paquetes' },
    { id: 'directorio', texto: 'Directorio' },
    { id: 'reservas', texto: 'Reservas' }
  ];
  readonly vista = signal<Vista>('caseta');
  /** Pasan a true la primera vez que se abre la vista y ya no vuelven a false: la vista se oculta, no se destruye */
  readonly reservasAbierta = signal<boolean>(false);
  readonly paquetesAbierta = signal<boolean>(false);

  elegirVista(vista: Vista): void {
    if (vista === 'reservas') this.reservasAbierta.set(true);
    if (vista === 'paquetes') this.paquetesAbierta.set(true);
    this.vista.set(vista);
  }

  onLogout(): void {
    this.authService.logout();
  }
}
