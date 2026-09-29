/**
 * Formatea un número o identificador de vivienda para presentación limpia y amigable.
 * Evita prefijos redundantes como "Casa #Casa 105", "Casa Casa 105", "#Casa 105", etc.
 */
export function formatearNumeroCasa(numeroCasa?: string | null): string {
  if (!numeroCasa || !numeroCasa.trim()) return 'Unidad';
  let clean = numeroCasa.trim();

  // 1. Eliminar duplicaciones de "Casa #Casa", "Casa Casa", "#Casa", etc.
  clean = clean.replace(/^#?\s*casa\s*#?\s*(casa)?\s*/i, 'Casa ');

  // 2. Si empieza con "Casa ", devolver con mayúscula inicial
  if (/^casa\s+/i.test(clean)) {
    return clean.replace(/^casa\s+/i, 'Casa ').trim();
  }

  // 3. Si tiene un '#' suelto (ej. "#204B") o es número directo (ej. "204B")
  clean = clean.replace(/^#\s*/, '').trim();
  return clean ? `Casa #${clean}` : 'Unidad';
}
