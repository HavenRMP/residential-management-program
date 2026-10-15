import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { ReservasAdminListaComponent } from './reservas-admin-lista.component';
import { AreasAdminComponent } from './areas-admin.component';
import { NoShowsAdminComponent } from './no-shows-admin.component';

type Pestana = 'reservas' | 'areas' | 'no-shows';

@Component({
  selector: 'app-reservas-admin',
  standalone: true,
  imports: [CommonModule, RouterLink, ReservasAdminListaComponent, AreasAdminComponent, NoShowsAdminComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="p-4 sm:p-6 w-full space-y-4">

      <nav aria-label="Ruta de navegación" class="flex items-center gap-2 text-xs text-slate-600 font-semibold">
        <a routerLink="/dashboard/admin" class="hover:text-slate-900 transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] rounded">Panel</a>
        <span>/</span>
        <span class="text-slate-900">Reservas</span>
      </nav>

      <div class="pb-2 border-b border-slate-200">
        <h1 class="text-2xl font-bold tracking-tight text-slate-900">Reservas de áreas comunes</h1>
        <p class="text-xs text-slate-600 mt-1 font-medium">Aprueba las solicitudes, da de alta las áreas, bloquea fechas y revisa las inasistencias.</p>
      </div>

      <div class="flex items-center gap-1.5" role="tablist" aria-label="Administración de reservas">
        @for (t of pestanas; track t.valor) {
          <button
            type="button"
            role="tab"
            [attr.aria-selected]="pestana() === t.valor"
            (click)="pestana.set(t.valor)"
            class="h-8 px-3 rounded-md text-xs font-medium border transition-colors cursor-pointer"
            [ngClass]="pestana() === t.valor ? 'bg-slate-900 text-white border-slate-900' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'"
            >
            {{ t.etiqueta }}
          </button>
        }
      </div>

      @switch (pestana()) {
        @case ('reservas') { <app-reservas-admin-lista /> }
        @case ('areas') { <app-areas-admin /> }
        @case ('no-shows') { <app-no-shows-admin /> }
      }
    </div>
  `
})
export class ReservasAdminComponent implements OnInit {
  private readonly servicio = inject(ReservasAdminService);

  readonly pestanas: { valor: Pestana; etiqueta: string }[] = [
    { valor: 'reservas', etiqueta: 'Reservas' },
    { valor: 'areas', etiqueta: 'Áreas' },
    { valor: 'no-shows', etiqueta: 'No utilizadas' }
  ];
  readonly pestana = signal<Pestana>('reservas');

  ngOnInit(): void {
    // Las áreas alimentan el filtro y la zona horaria de cada reserva del listado
    void this.servicio.cargarAreas();
  }
}
