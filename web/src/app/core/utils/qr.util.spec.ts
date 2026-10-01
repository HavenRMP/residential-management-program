import { generarQrDataUrl } from './qr.util';

describe('generarQrDataUrl', () => {
  it('devuelve una imagen SVG como data URL', () => {
    expect(generarQrDataUrl('K7M2QX')).toMatch(/^data:image\/svg\+xml/);
  });

  it('es determinista y distinto para cada código', () => {
    expect(generarQrDataUrl('K7M2QX')).toBe(generarQrDataUrl('K7M2QX'));
    expect(generarQrDataUrl('K7M2QX')).not.toBe(generarQrDataUrl('AB12CD'));
  });

  it('respeta el tamaño pedido', () => {
    // La librería entrega el SVG en base64
    const svg = atob(generarQrDataUrl('K7M2QX', 180).split(',')[1]);

    expect(svg).toContain('width="180"');
    expect(svg).toContain('height="180"');
  });
});
