import { Injectable, inject, signal } from '@angular/core';
import { HttpParams } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';
import {
  Cargo,
  CargoDetalle,
  ComprobanteSubido,
  FiltrosCargos,
  FiltrosPagos,
  MovimientoSaldo,
  NuevoCargoDto,
  NuevoPagoDto,
  Pagina,
  Pago,
  ResultadoAnulacion,
  ResultadoPago,
  ResultadoSaldo,
  SaldoUsuario,
  SaldoVivienda,
  TipoMovimientoSaldo,
  aCargo,
  aCargoDetalle,
  aMovimientoSaldo,
  aPagina,
  aPago,
  aSaldoUsuario,
  aSaldoVivienda
} from '../models/pagos.model';
import { mensajeConValidacion } from '../utils/api-errors.util';

const POR_PAGINA = 20;
/** Tope del resumen del residente: 100 por página × 5 páginas son más cargos de los que una vivienda acumula */
const POR_PAGINA_RESUMEN = 100;
const MAX_PAGINAS_RESUMEN = 5;

/**
 * Cargos, pagos, comprobantes y saldos del condominio (Pagos.Api). Las operaciones sirven al administrador y al
 * residente; el backend limita a cada uno a lo suyo. El resumen del residente (`miSaldo`, `misCargos`, `misPagos`)
 * vive aquí para que el portal y la pantalla de pagos compartan los mismos datos.
 */
@Injectable({
  providedIn: 'root'
})
export class PagosService {
  private readonly apiService = inject(ApiService);

  readonly PAGE_SIZE = POR_PAGINA;

  readonly miSaldo = signal<SaldoUsuario | null>(null);
  readonly misCargos = signal<Cargo[]>([]);
  readonly misPagos = signal<Pago[]>([]);
  readonly isLoading = signal<boolean>(false);
  readonly errorMessage = signal<string | null>(null);

  private ultimaPeticion = 0;

  // --- Residente ---

  /** Saldo, cargos y pagos del residente; falla toda la carga si falla alguna de las tres consultas */
  async cargarResumen(silencioso = false): Promise<void> {
    // Una respuesta lenta de una carga anterior no debe pisar la más reciente
    const peticion = ++this.ultimaPeticion;
    if (!silencioso) {
      this.isLoading.set(true);
      this.errorMessage.set(null);
    }
    try {
      const [saldo, cargos, pagos] = await Promise.all([
        this.obtenerMiSaldo(),
        this.listarTodos(page => this.listarCargos({}, page, POR_PAGINA_RESUMEN)),
        this.listarTodos(page => this.listarPagos({}, page, POR_PAGINA_RESUMEN))
      ]);
      if (peticion !== this.ultimaPeticion) return;
      this.miSaldo.set(saldo);
      this.misCargos.set(cargos);
      this.misPagos.set(pagos);
    } catch (err: any) {
      if (peticion !== this.ultimaPeticion) return;
      console.error('[PagosService] Error al cargar tus pagos:', err);
      if (!silencioso) this.errorMessage.set(mensajeConValidacion(err, 'No se pudieron cargar tus pagos.'));
    } finally {
      if (peticion === this.ultimaPeticion) this.isLoading.set(false);
    }
  }

  /**
   * Cuántos cargos abiertos tiene el residente, sin traer la lista. Devuelve 0 si falla: es solo un aviso y no
   * debe romper el portal.
   */
  async contarCargosAbiertos(): Promise<number> {
    try {
      const saldo = await this.obtenerMiSaldo();
      this.miSaldo.set(saldo);
      return saldo.totalCargosAbiertos;
    } catch {
      return 0;
    }
  }

  /** (GET /api/saldos/mi-saldo) */
  async obtenerMiSaldo(): Promise<SaldoUsuario> {
    const r = await firstValueFrom(this.apiService.get<any>('/api/saldos/mi-saldo', undefined, undefined, 'pagos'));
    return aSaldoUsuario(r);
  }

  /** El residente reporta un pago con su comprobante; el administrador lo confirma después (POST /api/pagos/reportar) */
  async reportarPago(dto: NuevoPagoDto): Promise<Pago> {
    const r = await firstValueFrom(
      this.apiService.post<any>('/api/pagos/reportar', this.cuerpoPago(dto), undefined, 'pagos')
    );
    return aPago(r?.pago ?? r);
  }

  // --- Cargos ---

  /** Cargos con filtros y paginación; el residente solo recibe los de sus viviendas (GET /api/cargos) */
  async listarCargos(filtros: FiltrosCargos = {}, pagina = 1, tamano = POR_PAGINA): Promise<Pagina<Cargo>> {
    let params = new HttpParams().set('page', pagina.toString()).set('pageSize', tamano.toString());
    if (filtros.viviendaId) params = params.set('vivienda_id', filtros.viviendaId.toString());
    if (filtros.tipo) params = params.set('tipo', filtros.tipo);
    if (filtros.estado) params = params.set('estado', filtros.estado);
    if (filtros.vencido != null) params = params.set('vencido', String(filtros.vencido));
    if (filtros.periodo) params = params.set('periodo', filtros.periodo);
    if (filtros.desde) params = params.set('vencimiento_desde', filtros.desde);
    if (filtros.hasta) params = params.set('vencimiento_hasta', filtros.hasta);
    const r = await firstValueFrom(this.apiService.get<any>('/api/cargos', params, undefined, 'pagos'));
    return aPagina(r, aCargo);
  }

  /** Un cargo con sus pagos (GET /api/cargos/{id}) */
  async obtenerCargo(id: string): Promise<CargoDetalle> {
    const r = await firstValueFrom(this.apiService.get<any>(`/api/cargos/${id}`, undefined, undefined, 'pagos'));
    return aCargoDetalle(r);
  }

  /** (POST /api/cargos) */
  async crearCargo(dto: NuevoCargoDto): Promise<Cargo> {
    const cuerpo: Record<string, unknown> = {
      vivienda_id: dto.viviendaId,
      tipo: dto.tipo,
      concepto: dto.concepto.trim(),
      monto: dto.monto,
      fecha_vencimiento: dto.fechaVencimiento
    };
    if (dto.periodo) cuerpo['periodo'] = dto.periodo;
    if (dto.responsablePago) cuerpo['responsable_pago'] = dto.responsablePago;
    const r = await firstValueFrom(this.apiService.post<any>('/api/cargos', cuerpo, undefined, 'pagos'));
    return aCargo(r);
  }

  /** (POST /api/cargos/{id}/cancelar) */
  async cancelarCargo(id: string, motivo: string): Promise<Cargo> {
    const r = await firstValueFrom(
      this.apiService.post<any>(`/api/cargos/${id}/cancelar`, { motivo: motivo.trim() }, undefined, 'pagos')
    );
    return aCargo(r?.cargo ?? r);
  }

  /** Cubre un cargo con el saldo a favor de la vivienda (POST /api/cargos/{id}/aplicar-saldo) */
  async aplicarSaldo(id: string, monto: number): Promise<ResultadoSaldo> {
    const r = await firstValueFrom(
      this.apiService.post<any>(`/api/cargos/${id}/aplicar-saldo`, { monto }, undefined, 'pagos')
    );
    return this.aResultadoSaldo(r);
  }

  // --- Pagos ---

  /** Pagos con filtros y paginación; el residente solo recibe los de sus viviendas (GET /api/pagos) */
  async listarPagos(filtros: FiltrosPagos = {}, pagina = 1, tamano = POR_PAGINA): Promise<Pagina<Pago>> {
    let params = new HttpParams().set('page', pagina.toString()).set('pageSize', tamano.toString());
    if (filtros.cargoId) params = params.set('cargo_id', filtros.cargoId);
    if (filtros.viviendaId) params = params.set('vivienda_id', filtros.viviendaId.toString());
    if (filtros.estado) params = params.set('estado', filtros.estado);
    if (filtros.metodo) params = params.set('metodo', filtros.metodo);
    if (filtros.desde) params = params.set('fecha_pago_desde', filtros.desde);
    if (filtros.hasta) params = params.set('fecha_pago_hasta', filtros.hasta);
    const r = await firstValueFrom(this.apiService.get<any>('/api/pagos', params, undefined, 'pagos'));
    return aPagina(r, aPago);
  }

  /** El administrador registra un pago directo, que queda confirmado (POST /api/pagos) */
  async registrarPago(dto: NuevoPagoDto): Promise<ResultadoPago> {
    const r = await firstValueFrom(this.apiService.post<any>('/api/pagos', this.cuerpoPago(dto), undefined, 'pagos'));
    return this.aResultadoPago(r);
  }

  /** (POST /api/pagos/{id}/confirmar) */
  async confirmarPago(id: string): Promise<ResultadoPago> {
    const r = await firstValueFrom(this.apiService.post<any>(`/api/pagos/${id}/confirmar`, {}, undefined, 'pagos'));
    return this.aResultadoPago(r);
  }

  /** (POST /api/pagos/{id}/rechazar) */
  async rechazarPago(id: string, motivo: string): Promise<Pago> {
    const r = await firstValueFrom(
      this.apiService.post<any>(`/api/pagos/${id}/rechazar`, { motivo: motivo.trim() }, undefined, 'pagos')
    );
    return aPago(r?.pago ?? r);
  }

  /** Anula un pago confirmado y genera su reversa (POST /api/pagos/{id}/anular) */
  async anularPago(id: string, motivo: string): Promise<ResultadoAnulacion> {
    const r = await firstValueFrom(
      this.apiService.post<any>(`/api/pagos/${id}/anular`, { motivo: motivo.trim() }, undefined, 'pagos')
    );
    return {
      pagoAnulado: aPago(r.pago_anulado),
      pagoReversa: r.pago_reversa ? aPago(r.pago_reversa) : null,
      cargo: aCargo(r.cargo),
      saldoAFavor: Number(r.saldo_a_favor) || 0
    };
  }

  /** Enlace temporal para ver o descargar el comprobante de un pago (GET /api/pagos/{id}/comprobante-url) */
  async obtenerUrlComprobante(id: string): Promise<string> {
    const r = await firstValueFrom(
      this.apiService.get<any>(`/api/pagos/${id}/comprobante-url`, undefined, undefined, 'pagos')
    );
    return r?.url ?? '';
  }

  /**
   * Sube el archivo del comprobante a la vivienda del cargo y devuelve la ruta y el hash que el pago debe llevar
   * (POST /api/comprobantes, multipart)
   */
  async subirComprobante(archivo: File, viviendaId: number): Promise<ComprobanteSubido> {
    const formulario = new FormData();
    formulario.append('archivo', archivo, archivo.name);
    formulario.append('vivienda_id', viviendaId.toString());
    const r = await firstValueFrom(this.apiService.post<any>('/api/comprobantes', formulario, undefined, 'pagos'));
    return {
      ruta: r.ruta,
      hash: r.hash,
      tamanoBytes: Number(r.tamano_bytes) || 0,
      contentType: r.content_type ?? ''
    };
  }

  // --- Saldos ---

  /** (GET /api/saldos/viviendas/{id}) */
  async obtenerSaldoVivienda(viviendaId: number): Promise<SaldoVivienda> {
    const r = await firstValueFrom(
      this.apiService.get<any>(`/api/saldos/viviendas/${viviendaId}`, undefined, undefined, 'pagos')
    );
    return aSaldoVivienda(r);
  }

  /** Movimientos del saldo a favor de una vivienda (GET /api/saldos/viviendas/{id}/movimientos) */
  async listarMovimientos(
    viviendaId: number,
    pagina = 1,
    tipo: TipoMovimientoSaldo | '' = '',
    tamano = POR_PAGINA
  ): Promise<Pagina<MovimientoSaldo>> {
    let params = new HttpParams().set('page', pagina.toString()).set('pageSize', tamano.toString());
    if (tipo) params = params.set('tipo', tipo);
    const r = await firstValueFrom(
      this.apiService.get<any>(`/api/saldos/viviendas/${viviendaId}/movimientos`, params, undefined, 'pagos')
    );
    return aPagina(r, aMovimientoSaldo);
  }

  /** Deshace la aplicación de saldo a un cargo (POST /api/saldos/movimientos/{id}/revertir) */
  async revertirMovimiento(id: string, motivo: string): Promise<ResultadoSaldo> {
    const r = await firstValueFrom(
      this.apiService.post<any>(`/api/saldos/movimientos/${id}/revertir`, { motivo: motivo.trim() }, undefined, 'pagos')
    );
    return this.aResultadoSaldo(r);
  }

  // --- Internos ---

  private cuerpoPago(dto: NuevoPagoDto): Record<string, unknown> {
    const cuerpo: Record<string, unknown> = {
      cargo_id: dto.cargoId,
      monto: dto.monto,
      fecha_pago: dto.fechaPago,
      metodo: dto.metodo
    };
    if (dto.referencia?.trim()) cuerpo['referencia'] = dto.referencia.trim();
    if (dto.bancoOrigen?.trim()) cuerpo['banco_origen'] = dto.bancoOrigen.trim();
    if (dto.comprobante) cuerpo['comprobante'] = { ruta: dto.comprobante.ruta, hash: dto.comprobante.hash };
    return cuerpo;
  }

  private aResultadoPago(r: any): ResultadoPago {
    return { pago: aPago(r.pago), cargo: aCargo(r.cargo), saldoAFavor: Number(r.saldo_a_favor) || 0 };
  }

  private aResultadoSaldo(r: any): ResultadoSaldo {
    return { movimiento: aMovimientoSaldo(r.movimiento), cargo: aCargo(r.cargo), saldoAFavor: Number(r.saldo_a_favor) || 0 };
  }

  /** Pide páginas hasta traer todo (con tope de seguridad) */
  private async listarTodos<T>(pedir: (pagina: number) => Promise<Pagina<T>>): Promise<T[]> {
    const todos: T[] = [];
    for (let pagina = 1; pagina <= MAX_PAGINAS_RESUMEN; pagina++) {
      const r = await pedir(pagina);
      todos.push(...r.items);
      if (r.items.length === 0 || todos.length >= r.total) break;
    }
    return todos;
  }
}
