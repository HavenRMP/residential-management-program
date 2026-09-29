import { formatearNumeroCasa } from './vivienda.util';

describe('formatearNumeroCasa Util', () => {
  it('debería retornar "Unidad" si el valor es nulo o vacío', () => {
    expect(formatearNumeroCasa(null)).toBe('Unidad');
    expect(formatearNumeroCasa(undefined)).toBe('Unidad');
    expect(formatearNumeroCasa('')).toBe('Unidad');
    expect(formatearNumeroCasa('   ')).toBe('Unidad');
  });

  it('debería respetar números que ya comiencen con "Casa "', () => {
    expect(formatearNumeroCasa('Casa 105')).toBe('Casa 105');
    expect(formatearNumeroCasa('casa 204B')).toBe('Casa 204B');
  });

  it('debería eliminar prefijos duplicados como "Casa #Casa 204B"', () => {
    expect(formatearNumeroCasa('Casa #Casa 204B')).toBe('Casa 204B');
    expect(formatearNumeroCasa('Casa Casa 204B')).toBe('Casa 204B');
    expect(formatearNumeroCasa('#Casa 204B')).toBe('Casa 204B');
  });

  it('debería anteponer "Casa #" si solo viene el número o letra', () => {
    expect(formatearNumeroCasa('105')).toBe('Casa #105');
    expect(formatearNumeroCasa('#105')).toBe('Casa #105');
    expect(formatearNumeroCasa('204B')).toBe('Casa #204B');
  });
});
