import { fechaVisitaReal, formatearFechaVisita, fusionarSinVacios, motivoVisitaNoAtendible, visitaLlegaAntesDeTiempo, ordenarVisitasProximasPrimero, ordenarVisitasRecientesPrimero, rangoFechasInvalido, rangoFechasIso, visitaPorAtender, visitaVencida } from './visita.model';

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

  describe('fechaVisitaReal', () => {
    it('una fecha normal devuelve sus milisegundos; el valor vacío del backend, una fecha ausente o inválida, null', () => {
      expect(fechaVisitaReal('2026-10-02T12:00:00Z')).toBe(new Date('2026-10-02T12:00:00Z').getTime());
      expect(fechaVisitaReal('0001-01-01T00:00:00+00:00')).toBeNull();
      expect(fechaVisitaReal('')).toBeNull();
      expect(fechaVisitaReal(null)).toBeNull();
      expect(fechaVisitaReal('basura')).toBeNull();
    });
  });

  describe('visitaVencida con la vigencia vacía del backend', () => {
    it('la vigencia en año 1 no significa que ya venció', () => {
      expect(visitaVencida({ estado: 'programada', vigenciaHasta: '0001-01-01T00:00:00+00:00' }, new Date('2026-10-02T12:00:00Z').getTime())).toBeFalse();
    });
  });

  describe('visitaPorAtender', () => {
    const ahora = new Date('2026-10-02T12:00:00Z').getTime();
    const horas = (h: number) => new Date(ahora + h * 3_600_000).toISOString();

    it('una visita en curso siempre se puede atender (para darle la salida)', () => {
      expect(visitaPorAtender({ estado: 'en_curso', fechaLlegadaEsperada: horas(-5), vigenciaHasta: horas(-3) }, ahora)).toBeTrue();
    });

    it('una programada que llega dentro de las próximas 24 horas y sigue vigente se atiende', () => {
      expect(visitaPorAtender({ estado: 'programada', fechaLlegadaEsperada: horas(0.2), vigenciaHasta: horas(2) }, ahora)).toBeTrue();
      expect(visitaPorAtender({ estado: 'programada', fechaLlegadaEsperada: horas(24), vigenciaHasta: horas(26) }, ahora)).toBeTrue();
      expect(visitaPorAtender({ estado: 'programada', fechaLlegadaEsperada: horas(-1), vigenciaHasta: horas(1) }, ahora)).toBeTrue();
    });

    it('una programada que llega en más de 24 horas no se atiende', () => {
      expect(visitaPorAtender({ estado: 'programada', fechaLlegadaEsperada: horas(30), vigenciaHasta: horas(32) }, ahora)).toBeFalse();
      expect(visitaPorAtender({ estado: 'programada', fechaLlegadaEsperada: horas(72), vigenciaHasta: horas(74) }, ahora)).toBeFalse();
    });

    it('una programada cuya vigencia ya terminó no se atiende', () => {
      expect(visitaPorAtender({ estado: 'programada', fechaLlegadaEsperada: horas(-5), vigenciaHasta: horas(-3) }, ahora)).toBeFalse();
    });

    it('con la vigencia vacía del backend se decide solo por la hora de llegada', () => {
      expect(visitaPorAtender({ estado: 'programada', fechaLlegadaEsperada: horas(1), vigenciaHasta: '0001-01-01T00:00:00+00:00' }, ahora)).toBeTrue();
      expect(visitaPorAtender({ estado: 'programada', fechaLlegadaEsperada: horas(48), vigenciaHasta: '0001-01-01T00:00:00+00:00' }, ahora)).toBeFalse();
    });

    it('finalizada, cancelada, expirada o sin estado no se atienden', () => {
      for (const estado of ['finalizada', 'cancelada', 'expirada', '']) {
        expect(visitaPorAtender({ estado, fechaLlegadaEsperada: horas(1), vigenciaHasta: horas(3) }, ahora)).toBeFalse();
      }
    });
  });

  describe('visitaLlegaAntesDeTiempo', () => {
    const ahora = new Date('2026-10-02T12:00:00Z').getTime();
    const horas = (h: number) => new Date(ahora + h * 3_600_000).toISOString();

    it('una programada y vigente que llega en más de 24 horas se puede atender, pidiendo confirmación', () => {
      expect(visitaLlegaAntesDeTiempo({ estado: 'programada', fechaLlegadaEsperada: horas(30), vigenciaHasta: horas(32) }, ahora)).toBeTrue();
      expect(visitaLlegaAntesDeTiempo({ estado: 'programada', fechaLlegadaEsperada: horas(72), vigenciaHasta: '0001-01-01T00:00:00+00:00' }, ahora)).toBeTrue();
    });

    it('una que llega dentro de las 24 horas, una vencida o con otro estado no es "antes de tiempo"', () => {
      expect(visitaLlegaAntesDeTiempo({ estado: 'programada', fechaLlegadaEsperada: horas(2), vigenciaHasta: horas(4) }, ahora)).toBeFalse();
      expect(visitaLlegaAntesDeTiempo({ estado: 'programada', fechaLlegadaEsperada: horas(-5), vigenciaHasta: horas(-3) }, ahora)).toBeFalse();
      expect(visitaLlegaAntesDeTiempo({ estado: 'cancelada', fechaLlegadaEsperada: horas(72), vigenciaHasta: horas(74) }, ahora)).toBeFalse();
      expect(visitaLlegaAntesDeTiempo({ estado: 'programada', fechaLlegadaEsperada: '', vigenciaHasta: horas(74) }, ahora)).toBeFalse();
    });
  });

  describe('motivoVisitaNoAtendible', () => {
    const ahora = new Date('2026-10-02T12:00:00Z').getTime();
    const horas = (h: number) => new Date(ahora + h * 3_600_000).toISOString();

    it('explica cada caso con palabras sencillas', () => {
      expect(motivoVisitaNoAtendible({ estado: 'programada', fechaLlegadaEsperada: horas(72), vigenciaHasta: horas(74) }, ahora)).toMatch(/^llega el .+, faltan más de 24 horas\.$/);
      expect(motivoVisitaNoAtendible({ estado: 'programada', fechaLlegadaEsperada: horas(-5), vigenciaHasta: horas(-3) }, ahora)).toBe('su vigencia ya terminó: el visitante no llegó a tiempo.');
      expect(motivoVisitaNoAtendible({ estado: 'finalizada' }, ahora)).toBe('la visita ya terminó.');
      expect(motivoVisitaNoAtendible({ estado: 'cancelada' }, ahora)).toBe('la visita fue cancelada.');
      expect(motivoVisitaNoAtendible({ estado: 'expirada' }, ahora)).toBe('la visita expiró.');
      expect(motivoVisitaNoAtendible({ estado: '' }, ahora)).toBe('la visita no está por atender (llega en más de 24 horas, ya terminó o se canceló).');
    });
  });
});
