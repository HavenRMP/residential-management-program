/**
 * Abre en otra pestaña un archivo cuya dirección se pide por red (como el enlace temporal de un comprobante).
 * La pestaña se abre antes de esperar la respuesta, dentro del clic de la persona, porque si se abriera después
 * el navegador la tomaría por una ventana emergente y la bloquearía. Si pedir el enlace falla, la pestaña se cierra
 * y el error se propaga para que la pantalla lo avise.
 */
export async function abrirEnPestana(obtenerUrl: () => Promise<string>): Promise<void> {
  const pestana = window.open('', '_blank');
  if (pestana) pestana.opener = null;
  try {
    const url = await obtenerUrl();
    if (!url) throw new Error('El servicio no devolvió el enlace del archivo.');
    if (pestana) {
      pestana.location.href = url;
    } else {
      window.open(url, '_blank', 'noopener');
    }
  } catch (err) {
    pestana?.close();
    throw err;
  }
}
