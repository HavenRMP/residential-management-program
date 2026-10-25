import { ChangeDetectionStrategy, Component, Injector, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { PagosService } from '../../../core/services/pagos.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { Vivienda } from '../../../core/models/vivienda.model';
import { autoActualizar } from '../../../core/utils/auto-actualizar.util';
import { PagosAdminListaComponent } from './pagos-admin-lista.component';
import { CargosAdminComponent } from './cargos-admin.component';
import { PlantillasAdminComponent } from './plantillas-admin.component';
import { SaldosAdminComponent } from './saldos-admin.component';

type Pestana = 'por-confirmar' | 'cargos' | 'pagos' | 'plantillas' | 'saldos';

/** Pagos del condominio para el administrador: confirmar lo que reportan los residentes y llevar los cobros */
@Component({
  selector: 'app-pagos-admin',
  standalone: true,
  imports: [CommonModule, RouterLink, PagosAdminListaComponent, CargosAdminComponent, PlantillasAdminComponent, SaldosAdminComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="p-4 sm:p-6 w-full space-y-4">

      <nav aria-label="Ruta de navegación" class="flex items-center gap-2 text-xs text-slate-600 font-semibold">
        <a routerLink="/dashboard/admin" class="hover:text-slate-900 transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99] rounded">Panel</a>
        <span>/</span>
        <span class="text-slate-900">Pagos</span>
      </nav>

      <div class="pb-2 border-b border-slate-200">
        <h1 class="text-2xl font-bold tracking-tight text-slate-900">Pagos y cargos</h1>
        <p class="text-xs text-slate-600 mt-1 font-medium">Confirma los pagos de los residentes, genera las cuotas de cada mes y consulta el saldo de cada vivienda.</p>
      </div>

      <div class="flex items-center gap-1.5 flex-wrap" role="tablist" aria-label="Administración de pagos">
        @for (t of pestanas; track t.valor) {
          <button
            type="button"
            role="tab"
            [attr.aria-selected]="pestana() === t.valor"
            (click)="pestana.set(t.valor)"
            class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md text-xs font-medium border transition-colors cursor-pointer"
            [ngClass]="pestana() === t.valor ? 'bg-slate-900 text-white border-slate-900' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'"
            >
            {{ t.etiqueta }}
            @if (t.valor === 'por-confirmar' && porConfirmar() > 0) {
              <span class="min-w-5 h-5 px-1 inline-flex items-center justify-center rounded-full bg-amber-500 text-white text-[11px] font-semibold" data-test="insignia-por-confirmar">
                {{ porConfirmar() }}<span class="sr-only"> por confirmar</span>
              </span>
            }
          </button>
        }
      </div>

      @switch (pestana()) {
        @case ('por-confirmar') { <app-pagos-admin-lista modo="por-confirmar" [viviendas]="viviendas()" (cambio)="contarPorConfirmar()" /> }
        @case ('cargos') { <app-cargos-admin [viviendas]="viviendas()" (cambio)="contarPorConfirmar()" /> }
        @case ('pagos') { <app-pagos-admin-lista modo="historial" [viviendas]="viviendas()" (cambio)="contarPorConfirmar()" /> }
        @case ('plantillas') { <app-plantillas-admin [viviendas]="viviendas()" (cambio)="contarPorConfirmar()" /> }
        @case ('saldos') { <app-saldos-admin [viviendas]="viviendas()" (cambio)="contarPorConfirmar()" /> }
      }
    </div>
  `
})
export class PagosAdminComponent implements OnInit {
  private readonly pagosService = inject(PagosService);
  private readonly viviendasService = inject(ViviendasService);
  private readonly injector = inject(Injector);

  readonly pestanas: { valor: Pestana; etiqueta: string }[] = [
    { valor: 'por-confirmar', etiqueta: 'Por confirmar' },
    { valor: 'cargos', etiqueta: 'Cargos' },
    { valor: 'pagos', etiqueta: 'Pagos' },
    { valor: 'plantillas', etiqueta: 'Plantillas' },
    { valor: 'saldos', etiqueta: 'Saldos' }
  ];
  readonly pestana = signal<Pestana>('por-confirmar');
  /** Viviendas del condominio: alimentan los filtros y formularios de todas las pestañas */
  readonly viviendas = signal<Vivienda[]>([]);
  /** Pagos que reportaron los residentes y esperan una decisión: se ve como insignia aunque se esté en otra pestaña */
  readonly porConfirmar = signal<number>(0);

  async ngOnInit(): Promise<void> {
    void this.cargarViviendas();
    await this.contarPorConfirmar();
    // Lo que reportan los residentes se ve en la insignia sin tener que recargar
    autoActualizar(this.injector, () => void this.contarPorConfirmar());
  }

  /** Sin viviendas los filtros quedan solo con «Todas»; es mejor eso que bloquear la pantalla */
  private async cargarViviendas(): Promise<void> {
    try {
      this.viviendas.set(await this.viviendasService.listar());
    } catch (err) {
      console.error('[PagosAdminComponent] Error al cargar las viviendas:', err);
    }
  }

  /** Solo es una insignia: si la consulta falla la pantalla sigue igual */
  async contarPorConfirmar(): Promise<void> {
    try {
      const r = await this.pagosService.listarPagos({ estado: 'PendienteConfirmacion' }, 1, 1);
      this.porConfirmar.set(r.total);
    } catch {
      // se conserva el número anterior
    }
  }
}
