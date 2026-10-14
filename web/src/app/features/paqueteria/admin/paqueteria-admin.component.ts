import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { PaqueteriaCasetaComponent } from '../caseta/paqueteria-caseta.component';

/** Paquetería para el administrador: consulta lo esperado, lo que sigue en caseta sin recoger y el historial */
@Component({
  selector: 'app-paqueteria-admin',
  standalone: true,
  imports: [RouterLink, PaqueteriaCasetaComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="p-4 sm:p-6 w-full space-y-4">

      <nav class="flex items-center gap-2 text-xs text-slate-600 font-semibold">
        <a routerLink="/dashboard/admin" class="hover:text-slate-900 transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] rounded">Panel</a>
        <span>/</span>
        <span class="text-slate-900">Paquetería</span>
      </nav>

      <div class="pb-2 border-b border-slate-200">
        <h1 class="text-2xl font-bold tracking-tight text-slate-900">Paquetería</h1>
        <p class="text-xs text-slate-600 mt-1 font-medium">Revisa los paquetes que esperan las casas, los que siguen en caseta sin recoger y el historial.</p>
      </div>

      <app-paqueteria-caseta [soloLectura]="true" />
    </div>
  `
})
export class PaqueteriaAdminComponent {}
