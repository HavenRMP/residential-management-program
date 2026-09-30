import { formatearFechaVisita, fusionarSinVacios } from './visita.model';

describe('visita.model', () => {
  describe('formatearFechaVisita', () => {
    it('devuelve vacío para fechas ausentes o inválidas', () => {
      expect(formatearFechaVisita(null)).toBe('');
      expect(formatearFechaVisita(undefined)).toBe('');
      expect(formatearFechaVisita('no-es-fecha')).toBe('');
    });

    it('trata como vacía la fecha por defecto de .NET que manda el backend', () => {
      expect(formatearFechaVisita('0001-01-01T00:00:00+00:00')).toBe('');
    });

    it('formatea una fecha real', () => {
      expect(formatearFechaVisita('2026-10-05T21:00:00+00:00')).toContain('2026');
    });
  });

  describe('fusionarSinVacios', () => {
    it('no pisa datos buenos con valores vacíos de la respuesta', () => {
      const actual = { estado: 'programada', numeroCasa: 'PRUEBA-01', viviendaId: 33, notas: 'x' };

      const resultado = fusionarSinVacios(actual, { estado: '', numeroCasa: '', viviendaId: 0, notas: null } as never);

      expect(resultado).toEqual(actual);
    });

    it('aplica los valores con contenido y no muta el original', () => {
      const actual = { estado: 'programada', horaEntrada: null as string | null };

      const resultado = fusionarSinVacios(actual, { estado: 'en_curso', horaEntrada: '2026-10-01T15:05:00Z' });

      expect(resultado).toEqual({ estado: 'en_curso', horaEntrada: '2026-10-01T15:05:00Z' });
      expect(actual.estado).toBe('programada');
    });
  });
});
