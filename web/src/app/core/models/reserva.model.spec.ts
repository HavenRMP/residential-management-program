import {
  Reserva,
  nombreCompleto,
  normalizarEstado,
  ocupaHorario,
  ordenarHistorial,
  ordenarProximas,
  reservaConcluida,
  reservaEsCancelable,
  reservaEsConfirmable,
  reservaEsMarcableNoUtilizada,
  reservaEsProxima
} from './reserva.model';

const ahora = new Date('2026-10-13T12:00:00Z').getTime();
const enHoras = (h: number) => new Date(ahora + h * 3_600_000).toISOString();

const reserva = (estado: Reserva['estado'], inicioEnHoras: number, duracionHoras = 2, extra: Partial<Reserva> = {}): Reserva => ({
  id: 'r1', areaId: 'a1', areaNombre: 'Salón', tipo: 'RESERVA', estado,
  inicio: enHoras(inicioEnHoras), fin: enHoras(inicioEnHoras + duracionHoras), ...extra
});

describe('reserva.model', () => {
  it('normaliza el estado sin importar mayúsculas ni espacios', () => {
    expect(normalizarEstado(' aprobada ')).toBe('APROBADA');
    expect(normalizarEstado('PENDIENTE_ADMIN')).toBe('PENDIENTE_ADMIN');
    expect(normalizarEstado(null)).toBe('' as any);
  });

  describe('reservaEsConfirmable', () => {
    it('solo una reserva aprobada, entre 7 días y 72 horas antes', () => {
      expect(reservaEsConfirmable(reserva('APROBADA', 5 * 24), ahora)).toBeTrue();
      expect(reservaEsConfirmable(reserva('APROBADA', 7 * 24), ahora)).toBeTrue();
      expect(reservaEsConfirmable(reserva('APROBADA', 72), ahora)).toBeTrue();
    });

    it('antes de los 7 días todavía no, y a menos de 72 horas ya no', () => {
      expect(reservaEsConfirmable(reserva('APROBADA', 7 * 24 + 1), ahora)).toBeFalse();
      expect(reservaEsConfirmable(reserva('APROBADA', 71), ahora)).toBeFalse();
    });

    it('si no está aprobada no se confirma', () => {
      for (const estado of ['PENDIENTE_TITULAR', 'PENDIENTE_ADMIN', 'CONFIRMADA', 'CANCELADA', 'RECHAZADA_ADMIN'] as const) {
        expect(reservaEsConfirmable(reserva(estado, 5 * 24), ahora)).withContext(estado).toBeFalse();
      }
    });
  });

  describe('reservaEsCancelable', () => {
    it('se cancela mientras no empiece y siga viva', () => {
      for (const estado of ['PENDIENTE_TITULAR', 'PENDIENTE_ADMIN', 'APROBADA', 'CONFIRMADA'] as const) {
        expect(reservaEsCancelable(reserva(estado, 48), ahora)).withContext(estado).toBeTrue();
      }
    });

    it('ya empezada o en un estado final no se cancela', () => {
      expect(reservaEsCancelable(reserva('APROBADA', -1), ahora)).toBeFalse();
      for (const estado of ['CANCELADA', 'CANCELADA_ADMIN', 'RECHAZADA_TITULAR', 'RECHAZADA_ADMIN', 'NO_UTILIZADA', 'FINALIZADA'] as const) {
        expect(reservaEsCancelable(reserva(estado, 48), ahora)).withContext(estado).toBeFalse();
      }
    });
  });

  describe('reservaEsMarcableNoUtilizada', () => {
    it('solo si ya terminó y estaba aprobada o confirmada', () => {
      expect(reservaEsMarcableNoUtilizada(reserva('CONFIRMADA', -5), ahora)).toBeTrue();
      expect(reservaEsMarcableNoUtilizada(reserva('APROBADA', -5), ahora)).toBeTrue();
      expect(reservaEsMarcableNoUtilizada(reserva('CONFIRMADA', -1, 2), ahora)).toBeFalse();
      expect(reservaEsMarcableNoUtilizada(reserva('PENDIENTE_ADMIN', -5), ahora)).toBeFalse();
      expect(reservaEsMarcableNoUtilizada(reserva('CANCELADA', -5), ahora)).toBeFalse();
    });
  });

  describe('próximas y horario ocupado', () => {
    it('una reserva viva que no terminó es próxima; un bloqueo o una terminada no', () => {
      expect(reservaEsProxima(reserva('APROBADA', 48), ahora)).toBeTrue();
      expect(reservaEsProxima(reserva('PENDIENTE_TITULAR', 48), ahora)).toBeTrue();
      expect(reservaEsProxima(reserva('APROBADA', -10), ahora)).toBeFalse();
      expect(reservaEsProxima(reserva('CANCELADA', 48), ahora)).toBeFalse();
      expect(reservaEsProxima(reserva('APROBADA', 48, 2, { tipo: 'BLOQUEO' }), ahora)).toBeFalse();
    });

    it('concluida compara contra la hora de fin', () => {
      expect(reservaConcluida(reserva('APROBADA', -3, 2), ahora)).toBeTrue();
      expect(reservaConcluida(reserva('APROBADA', -1, 2), ahora)).toBeFalse();
    });

    it('ocupan horario las pendientes, aprobadas, confirmadas y los bloqueos; las canceladas no', () => {
      expect(ocupaHorario({ estado: 'PENDIENTE_ADMIN', tipo: 'RESERVA' })).toBeTrue();
      expect(ocupaHorario({ estado: 'CONFIRMADA', tipo: 'RESERVA' })).toBeTrue();
      expect(ocupaHorario({ estado: 'APROBADA', tipo: 'BLOQUEO' })).toBeTrue();
      expect(ocupaHorario({ estado: 'CANCELADA', tipo: 'RESERVA' })).toBeFalse();
      expect(ocupaHorario({ estado: 'RECHAZADA_ADMIN', tipo: 'RESERVA' })).toBeFalse();
      expect(ocupaHorario({ estado: 'NO_UTILIZADA', tipo: 'RESERVA' })).toBeFalse();
    });
  });

  it('ordena las próximas de la más cercana a la más lejana y el historial al revés, sin mutar', () => {
    const a = reserva('APROBADA', 100, 2, { id: 'a' });
    const b = reserva('APROBADA', 10, 2, { id: 'b' });
    const c = reserva('APROBADA', 50, 2, { id: 'c' });
    const lista = [a, b, c];

    expect(ordenarProximas(lista).map(r => r.id)).toEqual(['b', 'c', 'a']);
    expect(ordenarHistorial(lista).map(r => r.id)).toEqual(['a', 'c', 'b']);
    expect(lista.map(r => r.id)).toEqual(['a', 'b', 'c']);
  });

  it('junta nombre y apellidos sin huecos', () => {
    expect(nombreCompleto('Ana', 'López')).toBe('Ana López');
    expect(nombreCompleto('Ana', null)).toBe('Ana');
    expect(nombreCompleto(null, undefined)).toBe('');
  });
});
