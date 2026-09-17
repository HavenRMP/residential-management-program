import { Component, effect, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterLink, RouterLinkActive, Router } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { UserMenuComponent } from '../../../core/components/user-menu/user-menu.component';

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive, UserMenuComponent],
  template: `
    <div class="min-h-screen bg-slate-100 text-slate-900 font-sans antialiased flex flex-col lg:flex-row">
      
      <!-- Mobile Top Bar -->
      <header class="lg:hidden bg-white border-b border-slate-200 sticky top-0 z-40 px-4 h-16 flex items-center justify-between shadow-2xs">
        <div class="flex items-center gap-3">
          <button
            type="button"
            (click)="toggleMobileMenu()"
            class="p-2 text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer"
            aria-label="Abrir menú de navegación"
          >
            <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
          
          <div class="flex items-center gap-2.5">
            <img src="/haven-logo.png" alt="Haven" class="w-7 h-7 rounded-lg object-contain" />
            <span class="font-bold text-base tracking-tight text-slate-900">Haven</span>
            <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded bg-indigo-50 text-indigo-700 border border-indigo-200">
              Admin
            </span>
          </div>
        </div>

        <app-user-menu [user]="currentUser()" (logout)="onLogout()" />
      </header>

      <!-- Mobile Backdrop Overlay -->
      <div
        *ngIf="mobileMenuOpen()"
        (click)="mobileMenuOpen.set(false)"
        class="lg:hidden fixed inset-0 z-40 bg-slate-900/40 backdrop-blur-xs transition-opacity"
        aria-hidden="true"
      ></div>

      <!-- Persistent Sidebar (Desktop & Mobile Drawer) -->
      <aside
        class="fixed inset-y-0 left-0 z-50 bg-white border-r border-slate-200 flex flex-col justify-between transition-all duration-300 ease-in-out lg:translate-x-0 lg:static lg:h-screen lg:shrink-0 overflow-hidden"
        [class.w-64]="!sidebarCollapsed()"
        [class.w-16]="sidebarCollapsed()"
        [class.translate-x-0]="mobileMenuOpen()"
        [class.-translate-x-full]="!mobileMenuOpen()"
      >
        <div class="flex-1 overflow-hidden flex flex-col">
          <!-- Sidebar Brand Header (Logo Estático y Destacado) -->
          <div
            class="h-16 border-b border-slate-100 flex items-center shrink-0 w-full transition-all duration-300 select-none"
            [class.px-4]="!sidebarCollapsed()"
            [class.px-2]="sidebarCollapsed()"
            [class.justify-between]="!sidebarCollapsed()"
            [class.justify-center]="sidebarCollapsed()"
          >
            <div class="flex items-center gap-3 overflow-hidden" [class.justify-center]="sidebarCollapsed()">
              <!-- Logo Container Destacado pero 100% No Clicable -->
              <div class="relative size-9 rounded-xl bg-gradient-to-br from-indigo-50/80 via-slate-50 to-blue-50/40 p-1.5 border border-slate-200/80 shadow-2xs flex items-center justify-center shrink-0 pointer-events-none">
                <img src="/haven-logo.png" alt="Haven" class="w-full h-full object-contain" />
              </div>

              <!-- Textos de Marca -->
              <div *ngIf="showText()" class="whitespace-nowrap fade-in-direct">
                <div class="flex items-center gap-1.5">
                  <span class="font-extrabold text-base tracking-tight text-slate-900 leading-none">Haven</span>
                  <span class="inline-flex items-center px-1.5 py-0.2 rounded text-[9px] font-bold uppercase tracking-wider bg-indigo-50 text-[#111C99] border border-indigo-100/80">
                    Admin
                  </span>
                </div>
                <span class="text-[10px] text-slate-400 font-medium mt-0.5 block tracking-normal">Gestión Residencial</span>
              </div>
            </div>

            <!-- Botón Cerrar Drawer (Móvil) -->
            <button
              *ngIf="showText()"
              type="button"
              (click)="mobileMenuOpen.set(false)"
              class="lg:hidden p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer shrink-0"
              aria-label="Cerrar menú"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Navigation Links (Altura e inicio invariantes en colapsado y expandido) -->
          <nav class="p-2 space-y-1 overflow-y-auto flex-1 custom-scrollbar w-full select-none">
            <!-- Panel Principal -->
            <a
              routerLink="/dashboard/admin"
              [routerLinkActiveOptions]="{ exact: true }"
              routerLinkActive="bg-[#111C99] text-white font-semibold shadow-xs"
              class="flex items-center h-10 rounded-lg text-xs font-semibold text-slate-700 hover:text-slate-900 hover:bg-slate-100 transition-colors cursor-pointer group whitespace-nowrap focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#111C99]"
              [class.px-3]="!sidebarCollapsed()"
              [class.px-0]="sidebarCollapsed()"
              [class.justify-center]="sidebarCollapsed()"
              [title]="sidebarCollapsed() ? 'Panel Principal' : ''"
              aria-label="Panel Principal"
              (click)="mobileMenuOpen.set(false)"
            >
              <svg
                class="w-5 h-5 shrink-0 transition-transform group-hover:scale-105"
                [class.mr-3]="!sidebarCollapsed()"
                fill="none" viewBox="0 0 24 24" stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
              </svg>
              <span *ngIf="showText()" class="whitespace-nowrap font-medium fade-in-direct">Panel Principal</span>
            </a>

            <!-- Residentes -->
            <a
              routerLink="/dashboard/admin/residentes"
              [routerLinkActiveOptions]="{ exact: false }"
              routerLinkActive="bg-[#111C99] text-white font-semibold shadow-xs"
              class="flex items-center h-10 rounded-lg text-xs font-semibold text-slate-700 hover:text-slate-900 hover:bg-slate-100 transition-colors cursor-pointer group whitespace-nowrap focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#111C99]"
              [class.px-3]="!sidebarCollapsed()"
              [class.px-0]="sidebarCollapsed()"
              [class.justify-center]="sidebarCollapsed()"
              [title]="sidebarCollapsed() ? 'Directorio de Residentes' : ''"
              aria-label="Directorio de Residentes"
              (click)="mobileMenuOpen.set(false)"
            >
              <svg
                class="w-5 h-5 shrink-0 transition-transform group-hover:scale-105"
                [class.mr-3]="!sidebarCollapsed()"
                fill="none" viewBox="0 0 24 24" stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              <span *ngIf="showText()" class="whitespace-nowrap font-medium fade-in-direct">Directorio de Residentes</span>
            </a>

            <!-- Viviendas -->
            <a
              routerLink="/dashboard/admin/viviendas"
              [routerLinkActiveOptions]="{ exact: false }"
              routerLinkActive="bg-[#111C99] text-white font-semibold shadow-xs"
              class="flex items-center h-10 rounded-lg text-xs font-semibold text-slate-700 hover:text-slate-900 hover:bg-slate-100 transition-colors cursor-pointer group whitespace-nowrap focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#111C99]"
              [class.px-3]="!sidebarCollapsed()"
              [class.px-0]="sidebarCollapsed()"
              [class.justify-center]="sidebarCollapsed()"
              [title]="sidebarCollapsed() ? 'Directorio de Viviendas' : ''"
              aria-label="Directorio de Viviendas"
              (click)="mobileMenuOpen.set(false)"
            >
              <svg
                class="w-5 h-5 shrink-0 transition-transform group-hover:scale-105"
                [class.mr-3]="!sidebarCollapsed()"
                fill="none" viewBox="0 0 24 24" stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
              </svg>
              <span *ngIf="showText()" class="whitespace-nowrap font-medium fade-in-direct">Directorio de Viviendas</span>
            </a>

            <!-- Tablón de Avisos -->
            <a
              routerLink="/dashboard/admin/avisos"
              [routerLinkActiveOptions]="{ exact: false }"
              routerLinkActive="bg-[#111C99] text-white font-semibold shadow-xs"
              class="flex items-center h-10 rounded-lg text-xs font-semibold text-slate-700 hover:text-slate-900 hover:bg-slate-100 transition-colors cursor-pointer group whitespace-nowrap focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#111C99]"
              [class.px-3]="!sidebarCollapsed()"
              [class.px-0]="sidebarCollapsed()"
              [class.justify-center]="sidebarCollapsed()"
              [title]="sidebarCollapsed() ? 'Tablón de Avisos' : ''"
              aria-label="Tablón de Avisos"
              (click)="mobileMenuOpen.set(false)"
            >
              <svg
                class="w-5 h-5 shrink-0 transition-transform group-hover:scale-105"
                [class.mr-3]="!sidebarCollapsed()"
                fill="none" viewBox="0 0 24 24" stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" />
              </svg>
              <span *ngIf="showText()" class="whitespace-nowrap font-medium fade-in-direct">Tablón de Avisos</span>
            </a>
          </nav>
        </div>

        <!-- Sidebar Footer Container (Altura estrictamente fija e idéntica en ambos estados) -->
        <div class="border-t border-slate-100 bg-slate-50/40 shrink-0 w-full select-none p-2 space-y-1">
          <!-- 1. Botón Toggle Colapsar/Expandir (Desktop) -->
          <button
            type="button"
            (click)="toggleSidebar()"
            class="hidden lg:flex items-center h-9 w-full rounded-lg text-xs font-medium text-slate-500 hover:text-slate-900 hover:bg-slate-100 transition-colors cursor-pointer group"
            [class.justify-center]="sidebarCollapsed()"
            [class.px-2.5]="!sidebarCollapsed()"
            [title]="sidebarCollapsed() ? 'Expandir menú' : 'Colapsar menú'"
            [attr.aria-label]="sidebarCollapsed() ? 'Expandir menú' : 'Colapsar menú'"
          >
            <svg
              class="w-4 h-4 shrink-0 text-slate-400 group-hover:text-slate-700 transition-transform group-hover:scale-110"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                *ngIf="sidebarCollapsed()"
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 5l7 7-7 7M5 5l7 7-7 7"
              />
              <path
                *ngIf="!sidebarCollapsed()"
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M11 19l-7-7 7-7m8 14l-7-7 7-7"
              />
            </svg>
            <span *ngIf="showText()" class="ml-2.5 whitespace-nowrap text-xs font-medium text-slate-600 group-hover:text-slate-900 fade-in-direct">
              Colapsar menú
            </span>
          </button>

          <!-- 2. Perfil de Usuario -->
          <a
            routerLink="/perfil"
            (click)="mobileMenuOpen.set(false)"
            routerLinkActive="bg-indigo-50/80 border-indigo-200 text-[#111C99]"
            class="flex items-center h-9 w-full rounded-lg hover:bg-slate-100 transition-colors group cursor-pointer border border-transparent whitespace-nowrap overflow-hidden"
            [class.justify-center]="sidebarCollapsed()"
            [class.px-2]="!sidebarCollapsed()"
            [title]="sidebarCollapsed() ? ('Perfil: ' + (currentUser()?.nombre || 'Administrador')) : ''"
          >
            <div class="w-7 h-7 rounded-md bg-[#111C99] text-white font-bold text-[10px] flex items-center justify-center shrink-0 shadow-xs group-hover:scale-105 transition-transform">
              {{ userInitials }}
            </div>
            <div *ngIf="showText()" class="ml-2.5 truncate fade-in-direct">
              <p class="text-[11px] font-bold text-slate-900 group-hover:text-[#111C99] transition-colors leading-tight truncate">
                {{ currentUser()?.nombre || 'Administrador' }}
              </p>
            </div>
          </a>

          <!-- 3. Botón Cerrar Sesión -->
          <button
            type="button"
            (click)="onLogout()"
            class="flex items-center h-9 w-full rounded-lg text-xs font-medium text-slate-500 hover:text-rose-600 hover:bg-rose-50 transition-colors cursor-pointer group"
            [class.justify-center]="sidebarCollapsed()"
            [class.px-2.5]="!sidebarCollapsed()"
            title="Cerrar sesión"
            aria-label="Cerrar sesión"
          >
            <svg class="w-4 h-4 shrink-0 text-slate-400 group-hover:text-rose-600 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
            <span *ngIf="showText()" class="ml-2.5 whitespace-nowrap text-xs font-medium text-slate-600 group-hover:text-rose-600 fade-in-direct">
              Cerrar sesión
            </span>
          </button>
        </div>
      </aside>

      <!-- Main Scrollable Content Area -->
      <main class="flex-1 min-w-0 lg:h-screen lg:overflow-y-auto">
        <router-outlet />
      </main>

    </div>
  `,
  styles: [`
    @keyframes fadeInDirect {
      from {
        opacity: 0;
      }
      to {
        opacity: 1;
      }
    }
    .fade-in-direct {
      animation: fadeInDirect 150ms ease-out forwards;
    }
  `]
})
export class AdminLayoutComponent {
  private readonly authService = inject(AuthService);
  private readonly condominiosService = inject(CondominiosService);
  private readonly router = inject(Router);

  readonly currentUser = this.authService.currentUser;
  readonly condominioActual = this.condominiosService.condominioActual;
  readonly mobileMenuOpen = signal<boolean>(false);
  readonly sidebarCollapsed = signal<boolean>(false);
  readonly showText = signal<boolean>(true);

  private textTimeout?: ReturnType<typeof setTimeout>;

  constructor() {
    effect(() => {
      const user = this.currentUser();
      if (user) {
        this.condominiosService.cargarCondominioUsuario(user.condominioId);
      }
    });
  }

  get userInitials(): string {
    const user = this.currentUser();
    const n = user?.nombre?.trim()?.charAt(0) ?? '';
    const a = user?.apellidos?.trim()?.charAt(0) ?? '';
    return (n + a).toUpperCase() || 'AD';
  }

  toggleMobileMenu(): void {
    this.mobileMenuOpen.update(o => {
      const next = !o;
      if (next && this.sidebarCollapsed()) {
        this.sidebarCollapsed.set(false);
        this.showText.set(true);
      }
      return next;
    });
  }

  toggleSidebar(): void {
    if (this.textTimeout) {
      clearTimeout(this.textTimeout);
      this.textTimeout = undefined;
    }

    const willCollapse = !this.sidebarCollapsed();
    this.sidebarCollapsed.set(willCollapse);

    if (willCollapse) {
      // Al colapsar: ocultar texto INMEDIATAMENTE para que solo queden los logos
      this.showText.set(false);
    } else {
      // Al expandir: esperar a que termine la animación de ensanchado (280ms)
      // y luego mostrar el texto directo sin que se vea cómo se acomoda
      this.textTimeout = setTimeout(() => {
        if (!this.sidebarCollapsed()) {
          this.showText.set(true);
        }
      }, 280);
    }
  }

  onLogout(): void {
    this.authService.logout();
  }
}
