/**
 * El recurso ya cambió o no existe (invitación respondida o cancelada desde otro lado, visita ya procesada…).
 * Se reconoce por el estado HTTP; la pantalla debe refrescar su lista en vez de insistir con la misma acción.
 */
export function esRecursoYaNoDisponible(err: any): boolean {
  return [400, 404, 409, 410].includes(err?.status);
}

/**
 * Mensaje del backend apto para mostrarse a una persona. Si trae texto técnico (el JSON crudo de Supabase,
 * un objeto serializado o un código de excepción) se usa el mensaje de respaldo.
 */
export function mensajeAmigable(err: any, respaldo: string): string {
  const texto = err?.error?.error;
  if (typeof texto !== 'string' || !texto.trim()) return respaldo;
  const parecePayloadTecnico = /^\s*[{\[]/.test(texto) || /Error desde Supabase/i.test(texto) || /"code"\s*:/.test(texto);
  return parecePayloadTecnico ? respaldo : texto;
}

/**
 * Como `mensajeAmigable`, pero si el backend no manda `{ error }` y responde con errores de validación
 * (`{ errors: { Campo: ["mensaje"] } }`) usa el primero de ellos.
 */
export function mensajeConValidacion(err: any, respaldo: string): string {
  const errores = err?.error?.errors;
  if (!err?.error?.error && errores && typeof errores === 'object') {
    const primero = Object.values(errores)[0] as string[] | undefined;
    if (typeof primero?.[0] === 'string' && primero[0].trim()) return primero[0];
  }
  return mensajeAmigable(err, respaldo);
}
