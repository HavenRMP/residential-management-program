import { Aviso, AvisoPrioridad } from '../models/aviso.model';

/** Más urgente primero: urgente, mantenimiento, evento, informativo */
const ORDEN_PRIORIDAD: Record<AvisoPrioridad, number> = {
  urgente: 0,
  mantenimiento: 1,
  evento: 2,
  informativo: 3
};

/** Clases de color del distintivo de cada prioridad */
export function claseBadgePrioridad(prioridad: AvisoPrioridad | undefined): string {
  switch (prioridad) {
    case 'urgente': return 'bg-rose-50 text-rose-700 border-rose-200';
    case 'mantenimiento': return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'evento': return 'bg-indigo-50 text-indigo-700 border-indigo-200';
    case 'informativo':
    default: return 'bg-slate-100 text-slate-800 border-slate-200';
  }
}

export function etiquetaPrioridad(prioridad: AvisoPrioridad | undefined): string {
  switch (prioridad) {
    case 'urgente': return 'Urgente';
    case 'mantenimiento': return 'Mantenimiento';
    case 'evento': return 'Evento';
    case 'informativo':
    default: return 'Informativo';
  }
}

/** "3 días restantes", "1 día restante" o "Expirado" */
export function tiempoRestanteAviso(aviso: Pick<Aviso, 'fechaExpiracion'>, ahora: number = Date.now()): string {
  const diff = new Date(aviso.fechaExpiracion).getTime() - ahora;
  if (diff <= 0) return 'Expirado';
  const dias = Math.ceil(diff / (1000 * 60 * 60 * 24));
  return dias === 1 ? '1 día restante' : `${dias} días restantes`;
}

/** Lo mínimo que necesita un aviso para poder ordenarse; la prioridad puede faltar (se trata como informativo) */
interface AvisoOrdenable {
  prioridad?: AvisoPrioridad;
  fechaExpiracion: string;
}

/** Ordena por prioridad (urgentes primero) y, a igual prioridad, el que vence antes primero. No muta la lista. */
export function ordenarAvisosPorPrioridad<T extends AvisoOrdenable>(avisos: T[]): T[] {
  return [...avisos].sort((a, b) => {
    const porPrioridad = ORDEN_PRIORIDAD[a.prioridad ?? 'informativo'] - ORDEN_PRIORIDAD[b.prioridad ?? 'informativo'];
    return porPrioridad !== 0
      ? porPrioridad
      : new Date(a.fechaExpiracion).getTime() - new Date(b.fechaExpiracion).getTime();
  });
}
