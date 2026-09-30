import { generate } from 'lean-qr';
import { toSvgDataURL } from 'lean-qr/extras/svg';

/**
 * Genera el QR de un texto como imagen SVG (data URL), lista para `<img src>` o `imageUrl` de SweetAlert.
 * Colores de alto contraste para que cualquier lector de caseta lo escanee sin problemas.
 */
export function generarQrDataUrl(texto: string, tamano: number = 240): string {
  return toSvgDataURL(generate(texto), {
    on: '#0f172a',
    off: '#ffffff',
    pad: 2,
    width: tamano,
    height: tamano
  });
}
