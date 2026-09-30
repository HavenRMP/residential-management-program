export type EstadoVisita = 'programada' | 'en_curso' | 'finalizada' | 'cancelada' | 'expirada';

export type MotivoVisita = 'personal' | 'familiar' | 'proveedor' | 'servicio' | 'paqueteria';

export const MOTIVOS_VISITA: { valor: MotivoVisita; etiqueta: string }[] = [
  { valor: 'personal', etiqueta: 'Personal' },
  { valor: 'familiar', etiqueta: 'Familiar' },
  { valor: 'proveedor', etiqueta: 'Proveedor' },
  { valor: 'servicio', etiqueta: 'Servicio' },
  { valor: 'paqueteria', etiqueta: 'Paquetería' }
];

/**
 * Visita tal como la devuelven POST /api/visitas, GET /api/visitas/mis-visitas y PUT /api/visitas/{id}
 * (Visitas.Api). Las fechas llegan en ISO-8601 UTC.
 */
export interface Visita {
  id: string;
  viviendaId: number;
  numeroCasa: string;
  nombreVisitante: string;
  apellidosVisitante: string;
  telefonoVisitante?: string | null;
  motivo: MotivoVisita;
  numAcompanantes: number;
  vehiculoPlacas?: string | null;
  notas?: string | null;
  fechaLlegadaEsperada: string;
  vigenciaHasta: string;
  codigo?: string | null;
  estado: EstadoVisita;
  horaEntrada?: string | null;
  horaSalida?: string | null;
  creadoPorNombre?: string | null;
  creadoEn: string;
}

export interface CrearVisitaDto {
  viviendaId: number;
  nombreVisitante: string;
  apellidosVisitante: string;
  telefonoVisitante?: string;
  motivo: MotivoVisita;
  numAcompanantes: number;
  vehiculoPlacas?: string;
  notas?: string;
  fechaLlegadaEsperada: string;
  horasVigencia?: number;
}

/** PUT /api/visitas/{id}: solo se envían los campos que cambian, al menos uno */
export type ActualizarVisitaDto = Partial<Omit<CrearVisitaDto, 'viviendaId'>>;
