/**
 * Convierte una fecha ISO a una etiqueta relativa corta en español (ej. "hace 5 min", "hace 2 h", "hace 3 días").
 */
export function tiempoRelativo(fechaIso: string): string {
  const diffMs = Date.now() - new Date(fechaIso).getTime();
  if (diffMs < 0) return 'ahora';

  const segundos = Math.floor(diffMs / 1000);
  if (segundos < 60) return 'ahora';

  const minutos = Math.floor(segundos / 60);
  if (minutos < 60) return `hace ${minutos} min`;

  const horas = Math.floor(minutos / 60);
  if (horas < 24) return `hace ${horas} h`;

  const dias = Math.floor(horas / 24);
  if (dias < 7) return `hace ${dias} d`;

  const semanas = Math.floor(dias / 7);
  if (semanas < 4) return `hace ${semanas} sem`;

  const meses = Math.floor(dias / 30);
  return meses < 1 ? 'hace 1 mes' : `hace ${meses} meses`;
}
