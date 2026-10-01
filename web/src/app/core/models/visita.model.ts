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

/**
 * Fecha y hora local legible para mostrar en pantallas de visitas.
 * Devuelve '' para fechas ausentes o inválidas, incluida la fecha por defecto de .NET (0001-01-01)
 * que el backend manda cuando no logra leer una columna.
 */
export function formatearFechaVisita(iso: string | null | undefined): string {
  if (!iso) return '';
  const fecha = new Date(iso);
  if (isNaN(fecha.getTime()) || fecha.getFullYear() < 2000) return '';
  return fecha.toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'short' });
}

/**
 * Combina una respuesta parcial sobre la visita que ya se tiene sin pisar datos buenos con
 * valores vacíos (null, undefined, '' o 0). Las respuestas de entrada y salida del backend
 * traen campos en blanco que borrarían el estado, la casa y la vigencia de la lista.
 */
export function fusionarSinVacios<T extends object>(actual: T, nueva: Partial<T>): T {
  const resultado = { ...actual };
  for (const [clave, valor] of Object.entries(nueva)) {
    if (valor !== null && valor !== undefined && valor !== '' && valor !== 0) {
      (resultado as Record<string, unknown>)[clave] = valor;
    }
  }
  return resultado;
}

/** Ordena de la visita con llegada más reciente a la más antigua, sin mutar la lista */
export function ordenarVisitasRecientesPrimero<T extends { fechaLlegadaEsperada: string }>(visitas: T[]): T[] {
  return [...visitas].sort(
    (a, b) => new Date(b.fechaLlegadaEsperada).getTime() - new Date(a.fechaLlegadaEsperada).getTime()
  );
}

/**
 * Rango de un par de inputs `type="date"` (yyyy-MM-dd, hora local) como filtros del histórico: cubre el día completo
 * de "desde" y de "hasta" y se manda en UTC. Una fecha vacía no genera filtro.
 */
export function rangoFechasIso(desde: string, hasta: string): { desde?: string; hasta?: string } {
  const rango: { desde?: string; hasta?: string } = {};
  if (desde) rango.desde = new Date(`${desde}T00:00:00`).toISOString();
  if (hasta) rango.hasta = new Date(`${hasta}T23:59:59.999`).toISOString();
  return rango;
}

/** "Desde" posterior a "hasta" */
export function rangoFechasInvalido(desde: string, hasta: string): boolean {
  return !!(desde && hasta && desde > hasta);
}

/** Ordena de la visita con llegada más próxima a la más lejana, sin mutar la lista */
export function ordenarVisitasProximasPrimero<T extends { fechaLlegadaEsperada: string }>(visitas: T[]): T[] {
  return [...visitas].sort(
    (a, b) => new Date(a.fechaLlegadaEsperada).getTime() - new Date(b.fechaLlegadaEsperada).getTime()
  );
}

/**
 * La visita sigue "programada" pero su vigencia ya terminó: el visitante no llegó a tiempo.
 * El backend la marca como expirada, pero puede tardar; mientras tanto no debe poder editarse ni usarse.
 */
export function visitaVencida(v: { estado: string; vigenciaHasta?: string | null }, ahora: number = Date.now()): boolean {
  if (v.estado !== 'programada' || !v.vigenciaHasta) return false;
  const fin = new Date(v.vigenciaHasta).getTime();
  return !isNaN(fin) && fin < ahora;
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
 * Visita proyectada para caseta y administración (GET /api/visitas/proximas, /codigo/{codigo},
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
