export type EstadoPaquete = 'esperado' | 'recibido' | 'entregado' | 'cancelado' | 'vencido' | 'devuelto';

export const ETIQUETAS_ESTADO_PAQUETE: Record<EstadoPaquete, string> = {
  esperado: 'Esperado',
  recibido: 'En caseta',
  entregado: 'Entregado',
  cancelado: 'Cancelado',
  vencido: 'Vencido',
  devuelto: 'Devuelto'
};

export const CLASES_ESTADO_PAQUETE: Record<EstadoPaquete, string> = {
  esperado: 'bg-indigo-50 text-indigo-700 border-indigo-200',
  recibido: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  entregado: 'bg-slate-100 text-slate-700 border-slate-200',
  cancelado: 'bg-rose-50 text-rose-700 border-rose-200',
  vencido: 'bg-amber-50 text-amber-700 border-amber-200',
  devuelto: 'bg-slate-100 text-slate-700 border-slate-200'
};

/** Siguen por resolverse: el residente los espera o ya están en caseta para recogerse */
export const ESTADOS_PENDIENTES: EstadoPaquete[] = ['esperado', 'recibido'];

/** Ya se resolvieron: no admiten ninguna acción */
export const ESTADOS_HISTORIAL: EstadoPaquete[] = ['entregado', 'cancelado', 'vencido', 'devuelto'];

/** Largos máximos que acepta el backend; la pantalla los valida antes de enviar */
export const LIMITES_PAQUETE = {
  destinatario: 100,
  servicio: 50,
  guia: 100,
  descripcion: 250
} as const;

/** Valor del selector de empresa para escribir una que no está en el catálogo */
export const SERVICIO_OTRO = 'otro';

export interface ServicioPaqueteria {
  id: number;
  nombre: string;
  iconoUrl?: string | null;
  activo: boolean;
  esSistema: boolean;
}

export interface Paquete {
  id: string;
  viviendaId: number;
  numeroCasa?: string | null;
  servicioId?: number | null;
  servicioNombre?: string | null;
  destinatarioNombre: string;
  numeroGuia?: string | null;
  descripcion?: string | null;
  notas?: string | null;
  fechaEsperadaDesde?: string | null;
  fechaEsperadaHasta?: string | null;
  estado: EstadoPaquete;
  /** Llegó a caseta sin que el residente avisara */
  esInesperado?: boolean;
  ubicacionAlmacen?: string | null;
  recibidoEn?: string | null;
  recibidoPorNombre?: string | null;
  entregadoEn?: string | null;
  entregadoANombre?: string | null;
  creadoEn?: string | null;
}

export interface CrearPaqueteDto {
  viviendaId: number;
  destinatarioNombre: string;
  /** Empresa del catálogo; si es otra se manda solo `servicioNombre` */
  servicioId?: number;
  servicioNombre?: string;
  numeroGuia?: string;
  descripcion?: string;
  notas?: string;
  fechaEsperadaDesde?: string;
  fechaEsperadaHasta?: string;
}

export type ActualizarPaqueteDto = Partial<Omit<CrearPaqueteDto, 'viviendaId'>>;

function aMilisegundos(iso: string | null | undefined): number | null {
  if (!iso) return null;
  const ms = new Date(iso).getTime();
  return isNaN(ms) || new Date(ms).getFullYear() < 2000 ? null : ms;
}

/**
 * Sigue "esperado" pero su ventana de llegada ya terminó. El backend lo marca como vencido,
 * pero puede tardar; mientras tanto no debe poder editarse ni cancelarse como si siguiera vigente.
 */
export function paqueteVencido(p: Pick<Paquete, 'estado' | 'fechaEsperadaHasta'>, ahora: number = Date.now()): boolean {
  if (p.estado !== 'esperado') return false;
  const fin = aMilisegundos(p.fechaEsperadaHasta);
  return fin !== null && fin < ahora;
}

/** Estado que se muestra: el de la base, o "vencido" si la ventana ya pasó y el backend aún no lo actualiza */
export function estadoEfectivoPaquete(p: Pick<Paquete, 'estado' | 'fechaEsperadaHasta'>, ahora: number = Date.now()): EstadoPaquete {
  return paqueteVencido(p, ahora) ? 'vencido' : p.estado;
}

export function paqueteEsPendiente(p: Pick<Paquete, 'estado' | 'fechaEsperadaHasta'>, ahora: number = Date.now()): boolean {
  return ESTADOS_PENDIENTES.includes(estadoEfectivoPaquete(p, ahora));
}

/** Solo un paquete esperado y vigente se puede corregir o cancelar: una vez en caseta lo maneja vigilancia */
export function puedeModificarPaquete(p: Pick<Paquete, 'estado' | 'fechaEsperadaHasta'>, ahora: number = Date.now()): boolean {
  return estadoEfectivoPaquete(p, ahora) === 'esperado';
}

/** Momento más reciente del paquete: entrega, recepción en caseta o alta del aviso */
export function fechaActividadPaquete(p: Pick<Paquete, 'entregadoEn' | 'recibidoEn' | 'creadoEn'>): number {
  return aMilisegundos(p.entregadoEn) ?? aMilisegundos(p.recibidoEn) ?? aMilisegundos(p.creadoEn) ?? 0;
}

/** Los que ya están en caseta primero (hay que ir por ellos); luego los esperados, el más reciente arriba */
export function ordenarPaquetesPendientes<T extends Paquete>(paquetes: T[], ahora: number = Date.now()): T[] {
  const peso = (p: T) => (estadoEfectivoPaquete(p, ahora) === 'recibido' ? 0 : 1);
  return [...paquetes].sort((a, b) => peso(a) - peso(b) || fechaActividadPaquete(b) - fechaActividadPaquete(a));
}

/** Del más reciente al más antiguo */
export function ordenarPaquetesRecientesPrimero<T extends Paquete>(paquetes: T[]): T[] {
  return [...paquetes].sort((a, b) => fechaActividadPaquete(b) - fechaActividadPaquete(a));
}

function normalizar(texto: string): string {
  return texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

/** Búsqueda por empresa, guía, destinatario, descripción o casa, sin distinguir mayúsculas ni acentos */
export function paqueteCoincideConBusqueda(p: Paquete, texto: string): boolean {
  const buscado = normalizar(texto.trim());
  if (!buscado) return true;
  return [p.servicioNombre, p.numeroGuia, p.destinatarioNombre, p.descripcion, p.numeroCasa].some(
    campo => !!campo && normalizar(campo).includes(buscado)
  );
}

function fechaCorta(iso: string): string {
  return new Date(iso).toLocaleDateString('es-MX', { dateStyle: 'medium' });
}

/**
 * Texto de la ventana en la que el residente espera el paquete, solo con días (la hora no importa para un envío).
 * Devuelve '' si no se indicó ninguna fecha.
 */
export function textoVentanaPaquete(p: Pick<Paquete, 'fechaEsperadaDesde' | 'fechaEsperadaHasta'>): string {
  const desdeMs = aMilisegundos(p.fechaEsperadaDesde);
  const hastaMs = aMilisegundos(p.fechaEsperadaHasta);
  const desde = desdeMs !== null ? fechaCorta(p.fechaEsperadaDesde!) : '';
  const hasta = hastaMs !== null ? fechaCorta(p.fechaEsperadaHasta!) : '';
  if (desde && hasta) return desde === hasta ? `El ${desde}` : `Del ${desde} al ${hasta}`;
  if (hasta) return `Hasta el ${hasta}`;
  if (desde) return `A partir del ${desde}`;
  return '';
}
