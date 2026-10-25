import { ChangeDetectionStrategy, Component, Input, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { PagosService } from '../../../core/services/pagos.service';
import {
  CLASES_ESTADO_PAGO,
  ETIQUETAS_ESTADO_PAGO,
  ETIQUETAS_METODO_PAGO,
  PagoResumen,
  formatearFechaPago,
  formatearMonto
} from '../../../core/models/pagos.model';
import { mensajeAmigable } from '../../../core/utils/api-errors.util';

/** Pagos que ha recibido un cargo, consultados al abrirse (residente y administrador lo comparten) */
@Component({
  selector: 'app-cargo-pagos',
  standalone: true,
  imports: [CommonModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="border-t border-slate-100 pt-2 space-y-1.5" data-test="detalle-cargo">
      @if (isLoading()) {
        <p class="text-xs text-slate-500">Cargando pagos...</p>
      } @else if (error(); as msg) {
        <p class="text-xs text-rose-700" role="alert">{{ msg }}</p>
      } @else if (pagos().length === 0) {
        <p class="text-xs text-slate-500">Este cargo todavía no tiene pagos.</p>
      } @else {
        @for (p of pagos(); track p.id) {
          <div class="flex flex-wrap items-center justify-between gap-2 text-xs">
            <span class="text-slate-700">
              {{ monto(p.monto) }} · {{ fecha(p.fechaPago) }} · {{ metodos[p.metodo] }}@if (p.esReversa) {<span> (reversa)</span>}
            </span>
            <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="clases[p.estado]">
              {{ etiquetas[p.estado] }}
            </span>
          </div>
        }
      }
    </div>
  `
})
export class CargoPagosComponent implements OnInit {
  private readonly pagosService = inject(PagosService);

  @Input({ required: true }) cargoId!: string;

  readonly pagos = signal<PagoResumen[]>([]);
  readonly isLoading = signal<boolean>(true);
  readonly error = signal<string | null>(null);

  readonly metodos = ETIQUETAS_METODO_PAGO;
  readonly etiquetas = ETIQUETAS_ESTADO_PAGO;
  readonly clases = CLASES_ESTADO_PAGO;

  async ngOnInit(): Promise<void> {
    try {
      const detalle = await this.pagosService.obtenerCargo(this.cargoId);
      this.pagos.set(detalle.pagos);
    } catch (err: any) {
      console.error('[CargoPagosComponent] Error al cargar los pagos del cargo:', err);
      this.error.set(mensajeAmigable(err, 'No se pudieron cargar los pagos de este cargo.'));
    } finally {
      this.isLoading.set(false);
    }
  }

  monto(valor: number): string {
    return formatearMonto(valor);
  }

  fecha(valor: string): string {
    return formatearFechaPago(valor);
  }
}
