import { ReservaCalendario } from '../models/reserva.model';
import {
  diasReservables,
  fechaEnZona,
  horaEnZona,
  instanteEnZona,
  minutosDelDia,
  problemaDeSolicitud,
  rangoLegible,
  recortarHora,
  segmentosDelDia
} from './reservas.util';

const MEXICO = 'America/Mexico_City';
const area = { horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: MEXICO };
/** Martes 13 de octubre de 2026, 12:00 en Ciudad de México (UTC-6) */
const ahora = new Date('2026-10-13T18:00:00Z').getTime();

const ocupado = (inicio: string, fin: string, extra: Partial<ReservaCalendario> = {}): ReservaCalendario => ({
  id: 'o1', areaId: 'a', areaNombre: 'Salón', tipo: 'RESERVA', estado: 'APROBADA', inicio, fin, ...extra
});

describe('reservas.util', () => {
  describe('horas', () => {
    it('recorta los segundos y convierte a minutos', () => {
      expect(recortarHora('08:00:00')).toBe('08:00');
      expect(recortarHora(null)).toBe('');
      expect(minutosDelDia('08:30:00')).toBe(510);
      expect(minutosDelDia('22:00')).toBe(1320);
    });
  });

  describe('instanteEnZona', () => {
    it('10:00 en Ciudad de México es 16:00 UTC (sin horario de verano)', () => {
      expect(instanteEnZona('2026-10-21', '10:00', MEXICO)).toBe('2026-10-21T16:00:00.000Z');
    });

    it('respeta el horario de verano de otra zona', () => {
      expect(instanteEnZona('2026-07-01', '10:00', 'America/New_York')).toBe('2026-07-01T14:00:00.000Z');
      expect(instanteEnZona('2026-01-15', '10:00', 'America/New_York')).toBe('2026-01-15T15:00:00.000Z');
    });

    it('ida y vuelta: la fecha y la hora que se dijeron son las que se leen de vuelta', () => {
      const iso = instanteEnZona('2026-10-21', '23:30', MEXICO);

      expect(fechaEnZona(iso, MEXICO)).toBe('2026-10-21');
      expect(horaEnZona(iso, MEXICO)).toBe('23:30');
    });

    it('una hora tarde en México ya es el día siguiente en UTC pero sigue siendo el mismo día en la zona', () => {
      const iso = instanteEnZona('2026-10-21', '21:00', MEXICO);

      expect(iso).toBe('2026-10-22T03:00:00.000Z');
      expect(fechaEnZona(iso, MEXICO)).toBe('2026-10-21');
    });
  });

  describe('diasReservables', () => {
    it('va de 7 a 30 días a partir de hoy en la zona del área', () => {
      expect(diasReservables(ahora, MEXICO)).toEqual({ min: '2026-10-20', max: '2026-11-12' });
    });
  });

  it('muestra el rango con día y horas en la zona del área', () => {
    const texto = rangoLegible('2026-10-21T16:00:00.000Z', '2026-10-21T18:00:00.000Z', MEXICO);

    expect(texto).toContain('10:00 a 12:00');
    expect(texto).toContain('2026');
  });

  describe('problemaDeSolicitud', () => {
    const buena = { fecha: '2026-10-21', horaInicio: '10:00', horaFin: '12:00' };

    it('una solicitud correcta no tiene problema', () => {
      expect(problemaDeSolicitud(buena, area, ahora)).toBeNull();
    });

    it('sin datos completos no marca nada todavía', () => {
      expect(problemaDeSolicitud({ fecha: '', horaInicio: '', horaFin: '' }, area, ahora)).toBeNull();
      expect(problemaDeSolicitud({ ...buena, horaFin: '' }, area, ahora)).toBeNull();
    });

    it('la hora de fin debe ser posterior a la de inicio', () => {
      expect(problemaDeSolicitud({ ...buena, horaFin: '10:00' }, area, ahora)).toContain('posterior');
      expect(problemaDeSolicitud({ ...buena, horaFin: '09:00' }, area, ahora)).toContain('posterior');
    });

    it('dura entre 30 minutos y 12 horas', () => {
      expect(problemaDeSolicitud({ ...buena, horaFin: '10:15' }, area, ahora)).toContain('30 minutos');
      expect(problemaDeSolicitud({ ...buena, horaInicio: '08:00', horaFin: '20:30' }, area, ahora)).toContain('12 horas');
      expect(problemaDeSolicitud({ ...buena, horaFin: '10:30' }, area, ahora)).toBeNull();
      expect(problemaDeSolicitud({ ...buena, horaInicio: '08:00', horaFin: '20:00' }, area, ahora)).toBeNull();
    });

    it('debe caer dentro del horario del área', () => {
      expect(problemaDeSolicitud({ ...buena, horaInicio: '07:00', horaFin: '09:00' }, area, ahora)).toBe('El área opera de 08:00 a 22:00.');
      expect(problemaDeSolicitud({ ...buena, horaInicio: '20:00', horaFin: '23:00' }, area, ahora)).toBe('El área opera de 08:00 a 22:00.');
      expect(problemaDeSolicitud({ ...buena, horaInicio: '20:00', horaFin: '22:00' }, area, ahora)).toBeNull();
    });

    it('con 7 a 30 días de anticipación, contados desde este momento', () => {
      expect(problemaDeSolicitud({ ...buena, fecha: '2026-10-19' }, area, ahora)).toContain('entre 7 y 30 días');
      // Es por instante, no por día: el 20 a las 10:00 aún no cumple 7 días completos (ahora son las 12:00 del 13)
      expect(problemaDeSolicitud({ ...buena, fecha: '2026-10-20' }, area, ahora)).toContain('entre 7 y 30 días');
      expect(problemaDeSolicitud({ fecha: '2026-10-20', horaInicio: '13:00', horaFin: '15:00' }, area, ahora)).toBeNull();
      expect(problemaDeSolicitud({ ...buena, fecha: '2026-11-12' }, area, ahora)).toBeNull();
      expect(problemaDeSolicitud({ ...buena, fecha: '2026-11-13' }, area, ahora)).toContain('entre 7 y 30 días');
      expect(problemaDeSolicitud({ ...buena, fecha: '2026-10-12' }, area, ahora)).toContain('entre 7 y 30 días');
    });

    it('un traslape con una reserva o un bloqueo se avisa; una cancelada o un horario contiguo no estorban', () => {
      const aprobada = ocupado('2026-10-21T17:00:00.000Z', '2026-10-21T19:00:00.000Z');
      const bloqueo = ocupado('2026-10-21T17:00:00.000Z', '2026-10-21T19:00:00.000Z', { tipo: 'BLOQUEO' });
      const cancelada = ocupado('2026-10-21T17:00:00.000Z', '2026-10-21T19:00:00.000Z', { estado: 'CANCELADA' });
      const contigua = ocupado('2026-10-21T18:00:00.000Z', '2026-10-21T20:00:00.000Z');

      expect(problemaDeSolicitud(buena, area, ahora, [aprobada])).toContain('ocupado');
      expect(problemaDeSolicitud(buena, area, ahora, [bloqueo])).toContain('ocupado');
      expect(problemaDeSolicitud(buena, area, ahora, [cancelada])).toBeNull();
      expect(problemaDeSolicitud(buena, area, ahora, [contigua])).toBeNull();
    });
  });

  describe('segmentosDelDia', () => {
    it('ubica cada reserva sobre el horario de operación en porcentaje', () => {
      // El área opera 14 horas (08:00 a 22:00). 10:00 a 12:00 empieza a las 2 h y dura 2 h.
      const segmentos = segmentosDelDia('2026-10-21', area, [
        ocupado('2026-10-21T16:00:00.000Z', '2026-10-21T18:00:00.000Z', { numeroCasa: 'A-1' })
      ]);

      expect(segmentos.length).toBe(1);
      expect(segmentos[0].izquierda).toBeCloseTo((2 / 14) * 100, 5);
      expect(segmentos[0].ancho).toBeCloseTo((2 / 14) * 100, 5);
      expect(segmentos[0].etiqueta).toBe('10:00 a 12:00');
      expect(segmentos[0].detalle).toBe('Casa A-1');
      expect(segmentos[0].pendiente).toBeFalse();
    });

    it('marca los bloqueos con su motivo y las pendientes como tales', () => {
      const segmentos = segmentosDelDia('2026-10-21', area, [
        ocupado('2026-10-21T20:00:00.000Z', '2026-10-21T21:00:00.000Z', { tipo: 'BLOQUEO', motivo: 'Mantenimiento' }),
        ocupado('2026-10-21T16:00:00.000Z', '2026-10-21T17:00:00.000Z', { estado: 'PENDIENTE_ADMIN' })
      ]);

      expect(segmentos.map(s => s.tipo)).toEqual(['RESERVA', 'BLOQUEO']);
      expect(segmentos[0].pendiente).toBeTrue();
      expect(segmentos[1].detalle).toBe('Bloqueado: Mantenimiento');
    });

    it('deja fuera lo cancelado, lo de otros días y lo que cae fuera del horario', () => {
      const segmentos = segmentosDelDia('2026-10-21', area, [
        ocupado('2026-10-21T16:00:00.000Z', '2026-10-21T18:00:00.000Z', { estado: 'CANCELADA' }),
        ocupado('2026-10-22T16:00:00.000Z', '2026-10-22T18:00:00.000Z'),
        ocupado('2026-10-21T08:00:00.000Z', '2026-10-21T10:00:00.000Z')
      ]);

      expect(segmentos).toEqual([]);
    });

    it('recorta un tramo que se sale del horario de operación', () => {
      // 21:00 a 23:30 hora de México: solo cuenta hasta el cierre de las 22:00
      const segmentos = segmentosDelDia('2026-10-21', area, [ocupado('2026-10-22T03:00:00.000Z', '2026-10-22T05:30:00.000Z')]);

      expect(segmentos.length).toBe(1);
      expect(segmentos[0].izquierda + segmentos[0].ancho).toBeCloseTo(100, 5);
    });
  });
});
