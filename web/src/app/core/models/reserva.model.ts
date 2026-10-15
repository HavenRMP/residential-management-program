export type EstadoReserva =
  | 'PENDIENTE_TITULAR'
  | 'PENDIENTE_ADMIN'
  | 'APROBADA'
  | 'CONFIRMADA'
  | 'RECHAZADA_TITULAR'
  | 'RECHAZADA_ADMIN'
  | 'RECHAZADA'
  | 'CANCELADA'
  | 'CANCELADA_ADMIN'
  | 'NO_UTILIZADA'
  | 'FINALIZADA';

/** El calendario mezcla reservas de residentes con bloqueos que pone el administrador */
export type TipoReserva = 'RESERVA' | 'BLOQUEO';

export const ETIQUETAS_ESTADO_RESERVA: Record<EstadoReserva, string> = {
  PENDIENTE_TITULAR: 'Espera al titular',
  PENDIENTE_ADMIN: 'Espera al administrador',
  APROBADA: 'Aprobada',
  CONFIRMADA: 'Confirmada',
  RECHAZADA_TITULAR: 'Rechazada por el titular',
  RECHAZADA_ADMIN: 'Rechazada por el administrador',
  RECHAZADA: 'Rechazada',
  CANCELADA: 'Cancelada',
  CANCELADA_ADMIN: 'Cancelada por el administrador',
  NO_UTILIZADA: 'No utilizada',
  FINALIZADA: 'Finalizada'
};

export const CLASES_ESTADO_RESERVA: Record<EstadoReserva, string> = {
  PENDIENTE_TITULAR: 'bg-amber-50 text-amber-700 border-amber-200',
  PENDIENTE_ADMIN: 'bg-amber-50 text-amber-700 border-amber-200',
  APROBADA: 'bg-indigo-50 text-indigo-700 border-indigo-200',
  CONFIRMADA: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  RECHAZADA_TITULAR: 'bg-rose-50 text-rose-700 border-rose-200',
  RECHAZADA_ADMIN: 'bg-rose-50 text-rose-700 border-rose-200',
  RECHAZADA: 'bg-rose-50 text-rose-700 border-rose-200',
  CANCELADA: 'bg-slate-100 text-slate-700 border-slate-200',
  CANCELADA_ADMIN: 'bg-slate-100 text-slate-700 border-slate-200',
  NO_UTILIZADA: 'bg-violet-50 text-violet-700 border-violet-200',
  FINALIZADA: 'bg-slate-100 text-slate-700 border-slate-200'
};

/** Reglas que aplica el backend; la pantalla las usa para guiar a la persona antes de enviar */
export const REGLAS_RESERVA = {
  /** Se reserva con entre 7 y 30 días de anticipación */
  diasMinimos: 7,
  diasMaximos: 30,
  minutosMinimos: 30,
  horasMaximas: 12,
  /** La asistencia se confirma entre 7 días y 72 horas antes del evento */
  confirmarHastaDiasAntes: 7,
  confirmarDesdeHorasAntes: 72
} as const;

const HORA_MS = 3_600_000;
const DIA_MS = 24 * HORA_MS;

export interface AreaComun {
  id: string;
  nombre: string;
  descripcion?: string | null;
  /** "08:00:00", en la zona horaria del área */
  horaApertura: string;
  horaCierre: string;
  zonaHoraria: string;
  activo: boolean;
}

export interface Reserva {
  id: string;
  areaId: string;
  areaNombre: string;
  tipo: TipoReserva;
  estado: EstadoReserva;
  inicio: string;
  fin: string;
  titularId?: string | null;
  titularNombre?: string | null;
  titularApellidos?: string | null;
  viviendaId?: number | null;
  numeroCasa?: string | null;
  solicitanteId?: string | null;
  solicitanteNombre?: string | null;
  solicitanteApellidos?: string | null;
  aprobadorNombre?: string | null;
  aprobadorApellidos?: string | null;
  motivo?: string | null;
  confirmadaEn?: string | null;
  creadoEn?: string | null;
  /** Solo en la vista del administrador */
  noShowsTitular?: number;
  noShowsSolicitante?: number;
}

/** Lo que ve cualquier residente de una reserva ajena: solo lo necesario para saber que el horario está ocupado */
export type ReservaCalendario = Pick<
  Reserva,
  'id' | 'areaId' | 'areaNombre' | 'tipo' | 'estado' | 'inicio' | 'fin' | 'titularNombre' | 'titularApellidos' | 'numeroCasa' | 'motivo'
>;

/** Solicitud de un sub-usuario que el titular de la vivienda debe aprobar o rechazar */
export interface PendienteTitular {
  id: string;
  areaId: string;
  areaNombre: string;
  inicio: string;
  fin: string;
  viviendaId: number;
  numeroCasa: string;
  solicitanteId: string;
  solicitanteNombre: string;
  solicitanteApellidos: string;
  solicitanteEmail: string;
  parentesco: string;
  creadoEn?: string | null;
}

export interface NoShow {
  id: string;
  areaId: string;
  areaNombre: string;
  inicio: string;
  fin: string;
  titularId: string;
  titularNombre: string;
  titularApellidos: string;
  viviendaId: number;
  numeroCasa: string;
  solicitanteId: string;
  solicitanteNombre: string;
  solicitanteApellidos: string;
}

export interface CrearReservaDto {
  areaId: string;
  inicio: string;
  fin: string;
}

export interface GuardarAreaDto {
  nombre: string;
  descripcion?: string;
  horaApertura: string;
  horaCierre: string;
}

export interface CrearBloqueoDto {
  areaId: string;
  inicio: string;
  fin: string;
  motivo: string;
}

/** Lo que se puede cambiar de un bloqueo: solo se manda lo que cambió */
export interface ActualizarBloqueoDto {
  inicio?: string;
  fin?: string;
  motivo?: string;
}

export interface ResultadoBloqueo {
  bloqueoId: string;
  areaId: string;
  inicio: string;
  fin: string;
  motivo: string;
  /** Reservas que se cancelaron porque caían dentro del bloqueo */
  reservasAfectadas: number;
}

export interface FiltrosReservasAdmin {
  estado?: EstadoReserva | '';
  areaId?: string;
  from?: string;
  to?: string;
}

/** El backend manda los estados en mayúsculas pero acepta minúsculas al filtrar: se compara siempre en mayúsculas */
export function normalizarEstado(estado: string | null | undefined): EstadoReserva {
  return String(estado ?? '').trim().toUpperCase() as EstadoReserva;
}

function ms(iso: string): number {
  return new Date(iso).getTime();
}

export function esPendiente(r: Pick<Reserva, 'estado'>): boolean {
  const e = normalizarEstado(r.estado);
  return e === 'PENDIENTE_TITULAR' || e === 'PENDIENTE_ADMIN';
}

/** La reserva ya terminó (su hora de fin pasó) */
export function reservaConcluida(r: Pick<Reserva, 'fin'>, ahora: number = Date.now()): boolean {
  return ms(r.fin) <= ahora;
}

/** Cuenta para ocupar el horario: espera aprobación o ya está aprobada */
export function ocupaHorario(r: Pick<ReservaCalendario, 'estado' | 'tipo'>): boolean {
  if (r.tipo === 'BLOQUEO') return true;
  const e = normalizarEstado(r.estado);
  return e === 'PENDIENTE_TITULAR' || e === 'PENDIENTE_ADMIN' || e === 'APROBADA' || e === 'CONFIRMADA';
}

/**
 * La persona ya confirmó su asistencia. El backend no cambia el estado al confirmar: la reserva sigue "aprobada" y se llena
 * `confirmadaEn`, así que se reconoce por esa fecha (y por el estado CONFIRMADA por si el backend algún día lo usa).
 */
export function reservaEstaConfirmada(r: Pick<Reserva, 'estado' | 'confirmadaEn'>): boolean {
  const e = normalizarEstado(r.estado);
  return e === 'CONFIRMADA' || (e === 'APROBADA' && !!r.confirmadaEn);
}

/** Estado que se muestra: una reserva aprobada y ya confirmada figura como "Confirmada" */
export function estadoMostrado(r: Pick<Reserva, 'estado' | 'confirmadaEn'>): EstadoReserva {
  return reservaEstaConfirmada(r) ? 'CONFIRMADA' : normalizarEstado(r.estado);
}

/**
 * La asistencia solo se confirma entre 7 días y 72 horas antes del evento, una sola vez y solo si la reserva ya está aprobada.
 * Confirmar y no asistir cuenta como inasistencia.
 */
export function reservaEsConfirmable(r: Pick<Reserva, 'estado' | 'inicio' | 'confirmadaEn'>, ahora: number = Date.now()): boolean {
  if (normalizarEstado(r.estado) !== 'APROBADA' || reservaEstaConfirmada(r)) return false;
  const faltan = ms(r.inicio) - ahora;
  return faltan <= REGLAS_RESERVA.confirmarHastaDiasAntes * DIA_MS && faltan >= REGLAS_RESERVA.confirmarDesdeHorasAntes * HORA_MS;
}

/** Se puede cancelar mientras no haya empezado y siga viva (pendiente, aprobada o confirmada) */
export function reservaEsCancelable(r: Pick<Reserva, 'estado' | 'inicio'>, ahora: number = Date.now()): boolean {
  if (ms(r.inicio) <= ahora) return false;
  const e = normalizarEstado(r.estado);
  return e === 'PENDIENTE_TITULAR' || e === 'PENDIENTE_ADMIN' || e === 'APROBADA' || e === 'CONFIRMADA';
}

/** El administrador puede marcar como no utilizada una reserva aprobada o confirmada ya terminada */
export function reservaEsMarcableNoUtilizada(r: Pick<Reserva, 'estado' | 'fin'>, ahora: number = Date.now()): boolean {
  if (ms(r.fin) > ahora) return false;
  const e = normalizarEstado(r.estado);
  return e === 'APROBADA' || e === 'CONFIRMADA';
}

/** Vigentes: aún no terminan y siguen vivas. Es lo que el residente debe atender o esperar. */
export function reservaEsProxima(r: Pick<Reserva, 'estado' | 'fin' | 'tipo'>, ahora: number = Date.now()): boolean {
  return r.tipo !== 'BLOQUEO' && !reservaConcluida(r, ahora) && ocupaHorario({ estado: r.estado, tipo: r.tipo });
}

/** Próximas primero la más cercana; el historial, la más reciente primero */
export function ordenarProximas<T extends Pick<Reserva, 'inicio'>>(reservas: T[]): T[] {
  return [...reservas].sort((a, b) => ms(a.inicio) - ms(b.inicio));
}

export function ordenarHistorial<T extends Pick<Reserva, 'inicio'>>(reservas: T[]): T[] {
  return [...reservas].sort((a, b) => ms(b.inicio) - ms(a.inicio));
}

export function nombreCompleto(nombre?: string | null, apellidos?: string | null): string {
  return [nombre, apellidos].filter(p => !!p && p.trim()).join(' ').trim();
}

/** Deja el estado y el tipo en mayúsculas aunque el backend los mande de otra forma */
export function normalizarReserva<T extends { estado: string; tipo?: string }>(r: T): T {
  return { ...r, estado: normalizarEstado(r.estado), tipo: String(r.tipo ?? 'RESERVA').trim().toUpperCase() };
}

/** El administrador solo aprueba lo que espera su decisión; un bloqueo no se aprueba */
export function adminPuedeAprobar(r: Pick<Reserva, 'estado' | 'tipo'>): boolean {
  return r.tipo !== 'BLOQUEO' && normalizarEstado(r.estado) === 'PENDIENTE_ADMIN';
}

/** Rechaza lo pendiente, también lo que aún espera al titular de la vivienda */
export function adminPuedeRechazar(r: Pick<Reserva, 'estado' | 'tipo'>): boolean {
  const e = normalizarEstado(r.estado);
  return r.tipo !== 'BLOQUEO' && (e === 'PENDIENTE_ADMIN' || e === 'PENDIENTE_TITULAR');
}

/** Cancela una reserva ya aprobada que aún no empieza (lo pendiente se rechaza) */
export function adminPuedeCancelar(r: Pick<Reserva, 'estado' | 'tipo' | 'inicio'>, ahora: number = Date.now()): boolean {
  const e = normalizarEstado(r.estado);
  return r.tipo !== 'BLOQUEO' && (e === 'APROBADA' || e === 'CONFIRMADA') && ms(r.inicio) > ahora;
}

/** Un bloqueo que todavía no termina se puede editar o quitar; uno que ya pasó, o que ya se quitó, no */
export function adminPuedeModificarBloqueo(r: Pick<Reserva, 'tipo' | 'estado' | 'fin'>, ahora: number = Date.now()): boolean {
  return r.tipo === 'BLOQUEO' && normalizarEstado(r.estado) !== 'CANCELADA' && ms(r.fin) > ahora;
}

/** Marca como no utilizada una reserva aprobada que ya terminó */
export function adminPuedeMarcarNoUtilizada(r: Pick<Reserva, 'estado' | 'tipo' | 'fin'>, ahora: number = Date.now()): boolean {
  return r.tipo !== 'BLOQUEO' && reservaEsMarcableNoUtilizada(r, ahora);
}
