export type EstadoVisita = 'programada' | 'en_curso' | 'finalizada' | 'cancelada' | 'expirada';

export const ETIQUETAS_ESTADO_VISITA: Record<EstadoVisita, string> = {
  programada: 'Programada',
  en_curso: 'En curso',
  finalizada: 'Finalizada',
  cancelada: 'Cancelada',
  expirada: 'Expirada'
};

export const CLASES_ESTADO_VISITA: Record<EstadoVisita, string> = {
  programada: 'bg-indigo-50 text-indigo-700 border-indigo-200',
  en_curso: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  finalizada: 'bg-slate-100 text-slate-700 border-slate-200',
  cancelada: 'bg-rose-50 text-rose-700 border-rose-200',
  expirada: 'bg-amber-50 text-amber-700 border-amber-200'
};

/** Fecha y hora local legible para mostrar en pantallas de visitas */
export function formatearFechaVisita(iso: string | null | undefined): string {
  if (!iso) return '';
  return new Date(iso).toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'short' });
}

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

/**
 * Visita proyectada para caseta y administración (GET /api/visitas/hoy, /codigo/{codigo},
 * /historico y POST /{id}/entrada|salida). No incluye el código de acceso ni datos privados.
 */
export type VisitaVigilancia = Omit<Visita, 'codigo' | 'creadoEn'>;

/** Filtros de GET /api/visitas/historico (fechas ISO-8601 UTC) */
export interface FiltrosHistoricoVisitas {
  desde?: string;
  hasta?: string;
  viviendaId?: number;
  estado?: EstadoVisita;
}
