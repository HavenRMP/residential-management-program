import { formatearFechaVisita, fusionarSinVacios, ordenarVisitasProximasPrimero, ordenarVisitasRecientesPrimero, rangoFechasInvalido, rangoFechasIso, visitaVencida } from './visita.model';

describe('visita.model', () => {
  describe('rangoFechasIso', () => {
    it('cubre el día completo de desde y de hasta en UTC', () => {
      const r = rangoFechasIso('2026-10-01', '2026-10-03');

      expect(new Date(r.desde!).getTime()).toBe(new Date('2026-10-01T00:00:00').getTime());
      expect(new Date(r.hasta!).getTime()).toBe(new Date('2026-10-03T23:59:59.999').getTime());
    });

    it('una fecha vacía no genera filtro', () => {
      expect(rangoFechasIso('', '')).toEqual({});
      expect(rangoFechasIso('2026-10-01', '').hasta).toBeUndefined();
    });

    it('detecta un desde posterior al hasta', () => {
      expect(rangoFechasInvalido('2026-10-05', '2026-10-01')).toBeTrue();
      expect(rangoFechasInvalido('2026-10-01', '2026-10-01')).toBeFalse();
      expect(rangoFechasInvalido('', '2026-10-01')).toBeFalse();
    });
  });

  describe('visitaVencida', () => {
    const ahora = new Date('2026-10-02T12:00:00Z').getTime();

    it('una programada cuya vigencia ya terminó está vencida', () => {
      expect(visitaVencida({ estado: 'programada', vigenciaHasta: '2026-10-02T11:59:00Z' }, ahora)).toBeTrue();
    });

    it('una programada con vigencia abierta no está vencida', () => {
      expect(visitaVencida({ estado: 'programada', vigenciaHasta: '2026-10-02T12:01:00Z' }, ahora)).toBeFalse();
    });

    it('solo aplica a las programadas y tolera fechas ausentes o inválidas', () => {
      expect(visitaVencida({ estado: 'en_curso', vigenciaHasta: '2026-10-01T00:00:00Z' }, ahora)).toBeFalse();
      expect(visitaVencida({ estado: 'finalizada', vigenciaHasta: '2026-10-01T00:00:00Z' }, ahora)).toBeFalse();
      expect(visitaVencida({ estado: 'programada', vigenciaHasta: null }, ahora)).toBeFalse();
      expect(visitaVencida({ estado: 'programada', vigenciaHasta: 'basura' }, ahora)).toBeFalse();
    });
  });

  describe('ordenarVisitasProximasPrimero', () => {
    it('ordena de la llegada más cercana a la más lejana sin mutar la lista', () => {
      const lista = [
        { id: 'c', fechaLlegadaEsperada: '2026-10-05T10:00:00Z' },
        { id: 'a', fechaLlegadaEsperada: '2026-10-02T10:00:00Z' },
        { id: 'b', fechaLlegadaEsperada: '2026-10-03T10:00:00Z' }
      ];

      expect(ordenarVisitasProximasPrimero(lista).map(v => v.id)).toEqual(['a', 'b', 'c']);
      expect(lista[0].id).toBe('c');
    });
  });

  it('ordena las visitas de la llegada más reciente a la más antigua sin mutar la lista', () => {
    const lista = [
      { id: 'a', fechaLlegadaEsperada: '2026-10-01T08:00:00Z' },
      { id: 'c', fechaLlegadaEsperada: '2026-10-03T08:00:00Z' },
      { id: 'b', fechaLlegadaEsperada: '2026-10-02T08:00:00Z' }
    ];

    expect(ordenarVisitasRecientesPrimero(lista).map(v => v.id)).toEqual(['c', 'b', 'a']);
    expect(lista.map(v => v.id)).toEqual(['a', 'c', 'b']);
  });

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
