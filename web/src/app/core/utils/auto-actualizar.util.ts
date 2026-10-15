import { DestroyRef } from '@angular/core';

/** Cada cuánto se vuelven a pedir los datos de una pantalla abierta */
export const INTERVALO_ACTUALIZACION_MS = 30_000;

/**
 * Vuelve a pedir los datos de una pantalla cada cierto tiempo, sin que la persona tenga que tocar "Actualizar".
 * - Solo trabaja mientras la pestaña está a la vista: en segundo plano no gasta peticiones.
 * - Al volver a la pestaña, si ya pasó el intervalo, actualiza de inmediato.
 * - Se detiene sola cuando se destruye el componente.
 * Devuelve la función que la detiene antes de tiempo.
 */
export function autoActualizar(destroyRef: DestroyRef, accion: () => void, cadaMs: number = INTERVALO_ACTUALIZACION_MS): () => void {
  let ultima = Date.now();

  const ejecutar = (): void => {
    ultima = Date.now();
    accion();
  };
  const alTemporizador = (): void => {
    if (document.visibilityState === 'visible') ejecutar();
  };
  const alVolver = (): void => {
    if (document.visibilityState === 'visible' && Date.now() - ultima >= cadaMs) ejecutar();
  };

  const temporizador = setInterval(alTemporizador, cadaMs);
  document.addEventListener('visibilitychange', alVolver);

  const detener = (): void => {
    clearInterval(temporizador);
    document.removeEventListener('visibilitychange', alVolver);
  };
  destroyRef.onDestroy(detener);
  return detener;
}
