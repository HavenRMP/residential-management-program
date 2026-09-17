import { Component, Input, Output, EventEmitter, signal, inject, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink, NavigationEnd } from '@angular/router';
import { filter } from 'rxjs';
import { AuthUser } from '../../models/auth-user.model';


@Component({
  selector: 'app-user-menu',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <div class="relative">
      <button
        type="button"
        (click)="toggleMenu()"
        [attr.aria-expanded]="menuOpen()"
        aria-haspopup="true"
        aria-label="Menú de usuario"
        class="flex items-center gap-3 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#111C99] focus-visible:ring-offset-2 rounded-xl p-1 cursor-pointer group transition-all"
      >
        <div class="hidden sm:flex flex-col text-right">
          <span class="text-sm font-semibold text-slate-800 group-hover:text-slate-900">
            {{ user?.nombre || 'Usuario' }} {{ user?.apellidos || '' }}
          </span>
          <span class="text-xs text-slate-600 font-medium">{{ user?.email }}</span>
        </div>
        <div
          class="w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm shrink-0 border border-white shadow-xs transition-transform group-hover:scale-105"
          [ngClass]="avatarClasses"
        >
          {{ iniciales }}
        </div>
      </button>

      <!-- Backdrop: cierra al hacer clic fuera -->
      <div
        *ngIf="menuOpen()"
        class="fixed inset-0 z-40 bg-transparent"
        aria-hidden="true"
        (click)="closeMenu()"
      ></div>

      <!-- Dropdown Menu -->
      <div
        *ngIf="menuOpen()"
        role="menu"
        aria-orientation="vertical"
        class="absolute right-0 mt-3 w-60 bg-white rounded-xl border border-slate-200 shadow-xl shadow-slate-200/60 z-50 overflow-hidden animate-in fade-in zoom-in-95 duration-100"
      >
        <div class="px-4 py-3 border-b border-slate-100 sm:hidden">
          <p class="text-sm font-semibold text-slate-800">{{ user?.nombre || 'Usuario' }} {{ user?.apellidos || '' }}</p>
          <p class="text-xs text-slate-600 font-medium truncate">{{ user?.email }}</p>
        </div>

        <a
          routerLink="/perfil"
          role="menuitem"
          (click)="closeMenu()"
          class="flex items-center gap-2.5 px-4 py-2.5 text-sm font-medium text-slate-800 hover:bg-slate-50 focus:bg-slate-50 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] transition-colors cursor-pointer"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
          Mi perfil
        </a>

        <button
          type="button"
          role="menuitem"
          (click)="onLogoutClick()"
          class="w-full flex items-center gap-2.5 px-4 py-2.5 text-sm font-semibold text-rose-700 hover:bg-rose-50 focus:bg-rose-50 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-rose-600 transition-colors border-t border-slate-100 cursor-pointer text-left"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-rose-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
          </svg>
          Cerrar sesión
        </button>
      </div>
    </div>
  `
})
export class UserMenuComponent {
  private readonly router = inject(Router, { optional: true });

  @Input({ required: true }) user: AuthUser | null = null;
  @Output() logout = new EventEmitter<void>();

  readonly menuOpen = signal(false);

  constructor() {
    // Cerrar automáticamente el menú al navegar a cualquier otra ruta
    this.router?.events
      .pipe(filter(event => event instanceof NavigationEnd))
      .subscribe(() => {
        this.closeMenu();
      });
  }

  @HostListener('window:keydown.escape')
  onEscape(): void {
    if (this.menuOpen()) {
      this.closeMenu();
    }
  }

  toggleMenu(): void {
    this.menuOpen.update(open => !open);
  }

  closeMenu(): void {
    this.menuOpen.set(false);
  }

  onLogoutClick(): void {
    this.closeMenu();
    this.logout.emit();
  }

  get iniciales(): string {
    const inicialNombre = this.user?.nombre?.trim()?.charAt(0) ?? '';
    const inicialApellido = this.user?.apellidos?.trim()?.charAt(0) ?? '';
    const combinadas = `${inicialNombre}${inicialApellido}`.toUpperCase();
    if (combinadas) return combinadas;
    return (this.user?.email?.trim()?.charAt(0) ?? '?').toUpperCase();
  }

  get avatarClasses(): string {
    const rol = (this.user?.role || this.user?.rol || '').toLowerCase();
    if (rol.includes('admin')) return 'bg-indigo-100 text-indigo-700';
    if (rol.includes('vigilan')) return 'bg-amber-100 text-amber-800';
    return 'bg-emerald-100 text-emerald-700';
  }
}
