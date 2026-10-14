import { AreaComun, REGLAS_RESERVA, ReservaCalendario, normalizarEstado, ocupaHorario } from '../models/reserva.model';

const MINUTO_MS = 60_000;
const DIA_MS = 24 * 60 * MINUTO_MS;

/** "08:00:00" o "08:00" → "08:00" */
export function recortarHora(hora: string | null | undefined): string {
  return (hora ?? '').slice(0, 5);
}

/** "08:30" → 510 minutos desde la medianoche */
export function minutosDelDia(hora: string): number {
  const [h, m] = recortarHora(hora).split(':').map(Number);
  return (h || 0) * 60 + (m || 0);
}

/** Cuánto se adelanta la hora de una zona respecto a UTC en un instante dado, en milisegundos */
function desfaseMs(instante: number, zona: string): number {
  const partes = new Intl.DateTimeFormat('en-US', {
    timeZone: zona, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit'
  }).formatToParts(new Date(instante));
  const valor = (tipo: string) => Number(partes.find(p => p.type === tipo)!.value);
  const comoUtc = Date.UTC(valor('year'), valor('month') - 1, valor('day'), valor('hour'), valor('minute'), valor('second'));
  return comoUtc - Math.floor(instante / 1000) * 1000;
}

/**
 * Instante (ISO en UTC) de una fecha y una hora dichas en la zona horaria del área.
 * La persona elige "10:00" como se vive en el condominio, no como lo marca el reloj de su equipo.
 */
export function instanteEnZona(fecha: string, hora: string, zona: string): string {
  const [anio, mes, dia] = fecha.split('-').map(Number);
  const [h, m] = recortarHora(hora).split(':').map(Number);
  const supuesto = Date.UTC(anio, mes - 1, dia, h, m);
  // Dos pasadas: la primera estima el desfase y la segunda lo corrige si en esa hora cambia el horario de verano
  const primero = supuesto - desfaseMs(supuesto, zona);
  return new Date(supuesto - desfaseMs(primero, zona)).toISOString();
}

/** Fecha (yyyy-MM-dd) de un instante en la zona del área */
export function fechaEnZona(iso: string | number, zona: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: zona, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(iso));
}

/** Hora (HH:mm) de un instante en la zona del área */
export function horaEnZona(iso: string | number, zona: string): string {
  return new Intl.DateTimeFormat('en-GB', { timeZone: zona, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(new Date(iso));
}

/** "mar 21 oct 2026" en la zona del área */
export function diaLegible(iso: string, zona: string): string {
  return new Intl.DateTimeFormat('es-MX', { timeZone: zona, weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(iso));
}

/** "mar 21 oct 2026 · 10:00 a 12:00"; si cruza de día muestra ambos días */
export function rangoLegible(inicio: string, fin: string, zona: string): string {
  const mismoDia = fechaEnZona(inicio, zona) === fechaEnZona(fin, zona);
  return mismoDia
    ? `${diaLegible(inicio, zona)} · ${horaEnZona(inicio, zona)} a ${horaEnZona(fin, zona)}`
    : `${diaLegible(inicio, zona)} ${horaEnZona(inicio, zona)} a ${diaLegible(fin, zona)} ${horaEnZona(fin, zona)}`;
}

/** Primer y último día (yyyy-MM-dd) que se pueden elegir según los 7 a 30 días de anticipación */
export function diasReservables(ahora: number, zona: string): { min: string; max: string } {
  return {
    min: fechaEnZona(ahora + REGLAS_RESERVA.diasMinimos * DIA_MS, zona),
    max: fechaEnZona(ahora + REGLAS_RESERVA.diasMaximos * DIA_MS, zona)
  };
}

export interface SolicitudReserva {
  fecha: string;
  horaInicio: string;
  horaFin: string;
}

/**
 * Primer problema de una solicitud, con las mismas reglas que aplica el backend, para avisar antes de enviar.
 * Devuelve null si todo cuadra; el backend sigue siendo quien decide.
 */
export function problemaDeSolicitud(
  s: SolicitudReserva,
  area: Pick<AreaComun, 'horaApertura' | 'horaCierre' | 'zonaHoraria'>,
  ahora: number,
  ocupados: Pick<ReservaCalendario, 'inicio' | 'fin' | 'estado' | 'tipo'>[] = []
): string | null {
  if (!s.fecha || !s.horaInicio || !s.horaFin) return null;
  const zona = area.zonaHoraria;
  const inicio = new Date(instanteEnZona(s.fecha, s.horaInicio, zona)).getTime();
  const fin = new Date(instanteEnZona(s.fecha, s.horaFin, zona)).getTime();

  if (fin <= inicio) return 'La hora de fin debe ser posterior a la de inicio.';
  const minutos = (fin - inicio) / MINUTO_MS;
  if (minutos < REGLAS_RESERVA.minutosMinimos) return `La reserva debe durar al menos ${REGLAS_RESERVA.minutosMinimos} minutos.`;
  if (minutos > REGLAS_RESERVA.horasMaximas * 60) return `La reserva puede durar hasta ${REGLAS_RESERVA.horasMaximas} horas.`;

  const apertura = minutosDelDia(area.horaApertura);
  const cierre = minutosDelDia(area.horaCierre);
  if (minutosDelDia(s.horaInicio) < apertura || minutosDelDia(s.horaFin) > cierre) {
    return `El área opera de ${recortarHora(area.horaApertura)} a ${recortarHora(area.horaCierre)}.`;
  }

  if (inicio < ahora + REGLAS_RESERVA.diasMinimos * DIA_MS || inicio > ahora + REGLAS_RESERVA.diasMaximos * DIA_MS) {
    return `Se reserva con entre ${REGLAS_RESERVA.diasMinimos} y ${REGLAS_RESERVA.diasMaximos} días de anticipación.`;
  }

  const choca = ocupados.some(o => ocupaHorario(o) && inicio < new Date(o.fin).getTime() && fin > new Date(o.inicio).getTime());
  if (choca) return 'Ese horario ya está ocupado. Elige otro.';
  return null;
}

export interface SegmentoLinea {
  /** Posición y ancho en porcentaje del horario de operación del día */
  izquierda: number;
  ancho: number;
  tipo: 'RESERVA' | 'BLOQUEO';
  pendiente: boolean;
  etiqueta: string;
  detalle: string;
}

/**
 * Lo que ya ocupa el área ese día, listo para dibujar sobre su horario de operación.
 * Solo se pintan los tramos que caen dentro de la apertura y el cierre.
 */
export function segmentosDelDia(
  fecha: string,
  area: Pick<AreaComun, 'horaApertura' | 'horaCierre' | 'zonaHoraria'>,
  ocupados: ReservaCalendario[]
): SegmentoLinea[] {
  const zona = area.zonaHoraria;
  const apertura = minutosDelDia(area.horaApertura);
  const total = minutosDelDia(area.horaCierre) - apertura;
  if (total <= 0) return [];

  return ocupados
    .filter(o => ocupaHorario(o))
    .map(o => {
      // Minutos desde la medianoche de ese día, en la zona del área (un tramo de otro día se recorta al borde)
      const desdeMedianoche = (iso: string) => {
        const dia = fechaEnZona(iso, zona);
        if (dia < fecha) return 0;
        if (dia > fecha) return 24 * 60;
        return minutosDelDia(horaEnZona(iso, zona));
      };
      const desde = Math.max(desdeMedianoche(o.inicio), apertura);
      const hasta = Math.min(desdeMedianoche(o.fin), apertura + total);
      return { o, desde, hasta };
    })
    .filter(x => x.hasta > x.desde)
    .map(({ o, desde, hasta }) => ({
      izquierda: ((desde - apertura) / total) * 100,
      ancho: ((hasta - desde) / total) * 100,
      tipo: o.tipo,
      pendiente: normalizarEstado(o.estado).startsWith('PENDIENTE'),
      etiqueta: `${horaEnZona(o.inicio, zona)} a ${horaEnZona(o.fin, zona)}`,
      detalle: o.tipo === 'BLOQUEO' ? `Bloqueado${o.motivo ? ': ' + o.motivo : ''}` : o.numeroCasa ? `Casa ${o.numeroCasa}` : 'Reservado'
    }))
    .sort((a, b) => a.izquierda - b.izquierda);
}
