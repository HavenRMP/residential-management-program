import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { NotificacionesService } from '../../services/notificaciones.service';
import { Notificacion } from '../../models/notificacion.model';
import { tiempoRelativo } from '../../utils/tiempo-relativo.util';

@Component({
  selector: 'app-notificaciones-popover',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="relative">
      <button
        type="button"
        (click)="togglePanel()"
        [attr.aria-expanded]="panelAbierto()"
        aria-haspopup="true"
        aria-label="Notificaciones"
        class="h-9 w-9 inline-flex items-center justify-center text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-md transition-colors relative cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
        </svg>
        <span
          *ngIf="notificacionesService.contadorNoLeidas() > 0"
          class="absolute top-1 right-1 min-w-[16px] h-4 px-1 rounded-full bg-rose-600 text-white text-[9px] font-bold flex items-center justify-center leading-none"
        >
          {{ notificacionesService.contadorNoLeidas() > 9 ? '9+' : notificacionesService.contadorNoLeidas() }}
        </span>
      </button>

      <!-- Backdrop: cierra al hacer clic fuera -->
      <div
        *ngIf="panelAbierto()"
        class="fixed inset-0 z-40 bg-transparent"
        aria-hidden="true"
        (click)="cerrarPanel()"
      ></div>

      <!-- Panel -->
      <div
        *ngIf="panelAbierto()"
        role="menu"
        class="absolute right-0 mt-2 w-80 max-w-[90vw] bg-white rounded-xl border border-slate-200 shadow-xl shadow-slate-200/60 z-50 overflow-hidden animate-in fade-in zoom-in-95 duration-100"
      >
        <div class="px-4 py-3 border-b border-slate-100 flex items-center justify-between">
          <h3 class="text-sm font-semibold text-slate-900">Notificaciones</h3>
          <button
            type="button"
            *ngIf="notificacionesService.hayNoLeidas()"
            (click)="marcarTodasComoLeidas()"
            class="text-[11px] font-medium text-[#111C99] hover:underline cursor-pointer"
          >
            Marcar todas como leídas
          </button>
        </div>

        <div class="max-h-96 overflow-y-auto divide-y divide-slate-100">
          <!-- Loading -->
          <div *ngIf="notificacionesService.isLoading()" class="p-4 space-y-3">
            <div *ngFor="let s of [1, 2, 3]" class="animate-pulse space-y-1.5">
              <div class="h-3 w-2/3 bg-slate-200 rounded"></div>
              <div class="h-2.5 w-full bg-slate-100 rounded"></div>
            </div>
          </div>

          <!-- Empty state -->
          <div
            *ngIf="!notificacionesService.isLoading() && notificacionesService.notificaciones().length === 0"
            class="p-6 text-center text-xs text-slate-500 font-medium"
          >
            No tienes notificaciones.
          </div>

          <!-- Lista -->
          <button
            *ngFor="let n of notificacionesService.notificaciones()"
            type="button"
            role="menuitem"
            (click)="onClickNotificacion(n)"
            class="w-full text-left px-4 py-3 hover:bg-slate-50 transition-colors cursor-pointer flex gap-2.5"
          >
            <span
              class="mt-1 w-1.5 h-1.5 rounded-full shrink-0"
              [class.bg-[#111C99]]="!n.leida"
              [class.bg-transparent]="n.leida"
            ></span>
            <div class="min-w-0 flex-1">
              <p class="text-xs leading-snug" [class.font-semibold]="!n.leida" [class.text-slate-900]="!n.leida" [class.font-medium]="n.leida" [class.text-slate-600]="n.leida">
                {{ n.titulo }}
              </p>
              <p class="text-[11px] text-slate-500 mt-0.5 line-clamp-2 leading-snug">{{ n.mensaje }}</p>
              <p class="text-[10px] text-slate-400 mt-1">{{ tiempoRelativo(n.creadoEn) }}</p>
            </div>
          </button>
        </div>
      </div>
    </div>
  `
})
export class NotificacionesPopoverComponent implements OnInit {
  readonly notificacionesService = inject(NotificacionesService);
  private readonly router = inject(Router);

  readonly panelAbierto = signal(false);
  readonly tiempoRelativo = tiempoRelativo;

  ngOnInit(): void {
    this.notificacionesService.cargarContador();
  }

  togglePanel(): void {
    const abrir = !this.panelAbierto();
    this.panelAbierto.set(abrir);
    if (abrir) {
      this.notificacionesService.cargarNotificaciones();
    }
  }

  cerrarPanel(): void {
    this.panelAbierto.set(false);
  }

  async onClickNotificacion(n: Notificacion): Promise<void> {
    if (!n.leida) {
      await this.notificacionesService.marcarComoLeida(n.id);
    }
    this.cerrarPanel();
    if (n.urlRedireccion) {
      this.router.navigateByUrl(n.urlRedireccion);
    }
  }

  async marcarTodasComoLeidas(): Promise<void> {
    await this.notificacionesService.marcarTodasComoLeidas();
  }
}
