import { Injectable, inject } from '@angular/core';
import { HttpParams } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { ApiService } from './api.service';
import {
  ActualizarPlantillaDto,
  NuevaPlantillaDto,
  Pagina,
  Plantilla,
  ResultadoGeneracion,
  TipoCargo,
  aPagina,
  aPlantilla
} from '../models/pagos.model';

export interface FiltrosPlantillas {
  viviendaId?: number | null;
  tipo?: TipoCargo | '';
  activa?: boolean | null;
}

/**
 * Plantillas de cargo recurrentes (cuotas de mantenimiento, renta…) y la generación de sus cargos por periodo.
 * Solo para el administrador.
 */
@Injectable({
  providedIn: 'root'
})
export class PlantillasCargoService {
  private readonly apiService = inject(ApiService);

  readonly PAGE_SIZE = 20;

  /** (GET /api/plantillas-cargo) */
  async listar(filtros: FiltrosPlantillas = {}, pagina = 1, tamano = this.PAGE_SIZE): Promise<Pagina<Plantilla>> {
    let params = new HttpParams().set('page', pagina.toString()).set('pageSize', tamano.toString());
    if (filtros.viviendaId) params = params.set('vivienda_id', filtros.viviendaId.toString());
    if (filtros.tipo) params = params.set('tipo', filtros.tipo);
    if (filtros.activa != null) params = params.set('activa', String(filtros.activa));
    const r = await firstValueFrom(this.apiService.get<any>('/api/plantillas-cargo', params, undefined, 'pagos'));
    return aPagina(r, aPlantilla);
  }

  /** Una plantilla por cada vivienda elegida, con un monto común o uno propio (POST /api/plantillas-cargo) */
  async crear(dto: NuevaPlantillaDto): Promise<Plantilla[]> {
    const cuerpo: Record<string, unknown> = {
      concepto: dto.concepto.trim(),
      tipo: dto.tipo,
      monto: dto.monto,
      dia_vencimiento: dto.diaVencimiento,
      vigencia_inicio: dto.vigenciaInicio,
      viviendas: dto.viviendas.map(v => (v.monto ? { vivienda_id: v.viviendaId, monto: v.monto } : { vivienda_id: v.viviendaId }))
    };
    if (dto.vigenciaFin) cuerpo['vigencia_fin'] = dto.vigenciaFin;
    if (dto.responsablePago) cuerpo['responsable_pago'] = dto.responsablePago;
    const r = await firstValueFrom(this.apiService.post<any>('/api/plantillas-cargo', cuerpo, undefined, 'pagos'));
    return Array.isArray(r) ? r.map(aPlantilla) : [];
  }

  /** (PUT /api/plantillas-cargo/{id}) */
  async actualizar(id: string, dto: ActualizarPlantillaDto): Promise<Plantilla> {
    const cuerpo: Record<string, unknown> = {
      concepto: dto.concepto.trim(),
      monto: dto.monto,
      dia_vencimiento: dto.diaVencimiento,
      vigencia_fin: dto.vigenciaFin || null
    };
    if (dto.responsablePago) cuerpo['responsable_pago'] = dto.responsablePago;
    const r = await firstValueFrom(this.apiService.put<any>(`/api/plantillas-cargo/${id}`, cuerpo, undefined, 'pagos'));
    return aPlantilla(r);
  }

  /** (POST /api/plantillas-cargo/{id}/activar y /desactivar) */
  async cambiarActiva(id: string, activa: boolean): Promise<Plantilla> {
    const r = await firstValueFrom(
      this.apiService.post<any>(`/api/plantillas-cargo/${id}/${activa ? 'activar' : 'desactivar'}`, {}, undefined, 'pagos')
    );
    return aPlantilla(r);
  }

  /**
   * Genera los cargos del periodo (YYYY-MM) de todas las plantillas activas o solo de las indicadas. Lo que ya
   * existía se omite, así que repetirlo es seguro. (POST /api/plantillas-cargo/generar)
   */
  async generarCargos(periodo: string, plantillaIds?: string[]): Promise<ResultadoGeneracion> {
    const cuerpo: Record<string, unknown> = { periodo };
    if (plantillaIds?.length) cuerpo['plantilla_ids'] = plantillaIds;
    const r = await firstValueFrom(this.apiService.post<any>('/api/plantillas-cargo/generar', cuerpo, undefined, 'pagos'));
    return {
      creados: Number(r?.creados) || 0,
      omitidosPorYaExistir: Number(r?.omitidos_por_ya_existir) || 0,
      omitidosPorVigencia: Number(r?.omitidos_por_vigencia) || 0
    };
  }
}
