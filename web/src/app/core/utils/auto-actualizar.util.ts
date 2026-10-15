import { DestroyRef, Injector, NgZone } from '@angular/core';

/** Cada cuánto se vuelven a pedir los datos de una pantalla abierta */
export const INTERVALO_ACTUALIZACION_MS = 30_000;

/**
 * Vuelve a pedir los datos de una pantalla cada cierto tiempo, sin que la persona tenga que tocar "Actualizar".
 * - Solo trabaja mientras la pestaña está a la vista: en segundo plano no gasta peticiones.
 * - Al volver a la pestaña, si ya pasó el intervalo, actualiza de inmediato.
 * - Se detiene sola cuando se destruye el componente.
 * - El temporizador corre fuera de la zona de Angular para no mantener la pantalla "ocupada" (por ejemplo en pruebas).
 * Se le pasa el `Injector` del componente. Devuelve la función que la detiene antes de tiempo.
 */
export function autoActualizar(injector: Injector, accion: () => void, cadaMs: number = INTERVALO_ACTUALIZACION_MS): () => void {
  const zona = injector.get(NgZone);
  let ultima = Date.now();

  const ejecutar = (): void => {
    ultima = Date.now();
    zona.run(accion);
  };
  const alTemporizador = (): void => {
    if (document.visibilityState === 'visible') ejecutar();
  };
  const alVolver = (): void => {
    if (document.visibilityState === 'visible' && Date.now() - ultima >= cadaMs) ejecutar();
  };

  let temporizador: ReturnType<typeof setInterval>;
  zona.runOutsideAngular(() => {
    temporizador = setInterval(alTemporizador, cadaMs);
    document.addEventListener('visibilitychange', alVolver);
  });

  const detener = (): void => {
    clearInterval(temporizador);
    document.removeEventListener('visibilitychange', alVolver);
  };
  injector.get(DestroyRef).onDestroy(detener);
  return detener;
}
