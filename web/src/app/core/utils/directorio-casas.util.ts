import { ViviendaConResidentes } from '../models/vivienda.model';

/** Una fila del directorio: casa, residente y teléfono en una misma línea */
export interface FilaDirectorio {
  casaId: number;
  numeroCasa: string;
  /** null cuando la casa no tiene residentes registrados */
  nombreCompleto: string | null;
  telefono: string | null;
}

/** Minúsculas y sin acentos, para que "Pérez" se encuentre escribiendo "perez" */
export function normalizarBusqueda(texto: string): string {
  return texto.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
}

/** Deja solo dígitos y un "+" inicial, válido para un enlace tel: */
export function telefonoParaLlamar(telefono: string | null | undefined): string {
  return (telefono ?? '').replace(/[^\d+]/g, '');
}

/** Todas las personas del directorio, una fila por residente, en el orden de las casas recibidas. Las casas sin residentes no aparecen. */
export function todasLasPersonas(casas: ViviendaConResidentes[]): FilaDirectorio[] {
  return casas.flatMap(casa =>
    casa.residentes.map(r => ({
      casaId: casa.id,
      numeroCasa: casa.numeroCasa,
      nombreCompleto: `${r.nombre} ${r.apellidos}`.trim(),
      telefono: r.telefono
    }))
  );
}

/** Con consulta, las filas que coinciden; sin consulta, todas las personas del directorio. */
export function filasDelDirectorio(casas: ViviendaConResidentes[], consulta: string): FilaDirectorio[] {
  return normalizarBusqueda(consulta) ? filtrarDirectorio(casas, consulta) : todasLasPersonas(casas);
}

/**
 * Filas del directorio que coinciden con la consulta (número de casa, nombre, apellidos o teléfono).
 * Una casa sin residentes aparece como una fila sin nombre, solo si coincide por su número.
 * Sin consulta no se devuelve nada; para listar todo se usa `filasDelDirectorio`.
 */
export function filtrarDirectorio(casas: ViviendaConResidentes[], consulta: string): FilaDirectorio[] {
  const q = normalizarBusqueda(consulta);
  if (!q) return [];
  const qDigitos = q.replace(/\D/g, '');

  const filas: FilaDirectorio[] = [];
  for (const casa of casas) {
    const casaCoincide = normalizarBusqueda(casa.numeroCasa).includes(q);

    if (casa.residentes.length === 0) {
      if (casaCoincide) {
        filas.push({ casaId: casa.id, numeroCasa: casa.numeroCasa, nombreCompleto: null, telefono: null });
      }
      continue;
    }

    for (const r of casa.residentes) {
      const nombreCompleto = `${r.nombre} ${r.apellidos}`.trim();
      const nombreCoincide = normalizarBusqueda(nombreCompleto).includes(q);
      const telefonoCoincide = qDigitos.length >= 3 && telefonoParaLlamar(r.telefono).includes(qDigitos);
      if (casaCoincide || nombreCoincide || telefonoCoincide) {
        filas.push({ casaId: casa.id, numeroCasa: casa.numeroCasa, nombreCompleto, telefono: r.telefono });
      }
    }
  }
  return filas;
}
