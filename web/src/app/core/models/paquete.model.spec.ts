import {
  Paquete,
  estadoEfectivoPaquete,
  fechaActividadPaquete,
  ordenarPaquetesPendientes,
  ordenarPaquetesRecientesPrimero,
  paqueteCoincideConBusqueda,
  paqueteEsPendiente,
  paqueteVencido,
  puedeModificarPaquete
} from './paquete.model';

const base: Paquete = { id: 'p1', viviendaId: 33, destinatarioNombre: 'Angel Gómez', estado: 'esperado' };
const ahora = new Date('2026-10-12T12:00:00Z').getTime();

describe('paquete.model', () => {
  describe('paqueteVencido', () => {
    it('un esperado cuya ventana ya terminó está vencido', () => {
      expect(paqueteVencido({ estado: 'esperado', fechaEsperadaHasta: '2026-10-12T11:59:00Z' }, ahora)).toBeTrue();
    });

    it('un esperado con ventana abierta o sin ventana no está vencido', () => {
      expect(paqueteVencido({ estado: 'esperado', fechaEsperadaHasta: '2026-10-12T12:01:00Z' }, ahora)).toBeFalse();
      expect(paqueteVencido({ estado: 'esperado', fechaEsperadaHasta: null }, ahora)).toBeFalse();
    });

    it('solo aplica a los esperados y tolera fechas inválidas o la fecha vacía de .NET', () => {
      expect(paqueteVencido({ estado: 'recibido', fechaEsperadaHasta: '2026-10-01T00:00:00Z' }, ahora)).toBeFalse();
      expect(paqueteVencido({ estado: 'esperado', fechaEsperadaHasta: 'basura' }, ahora)).toBeFalse();
      expect(paqueteVencido({ estado: 'esperado', fechaEsperadaHasta: '0001-01-01T00:00:00Z' }, ahora)).toBeFalse();
    });
  });

  describe('estado efectivo y permisos', () => {
    it('un esperado vencido se muestra como vencido y sale de pendientes', () => {
      const vencido = { ...base, fechaEsperadaHasta: '2026-10-11T00:00:00Z' };

      expect(estadoEfectivoPaquete(vencido, ahora)).toBe('vencido');
      expect(paqueteEsPendiente(vencido, ahora)).toBeFalse();
    });

    it('esperado y recibido son pendientes; el resto es historial', () => {
      expect(paqueteEsPendiente({ ...base, estado: 'esperado' }, ahora)).toBeTrue();
      expect(paqueteEsPendiente({ ...base, estado: 'recibido' }, ahora)).toBeTrue();
      for (const estado of ['entregado', 'cancelado', 'vencido', 'devuelto'] as const) {
        expect(paqueteEsPendiente({ ...base, estado }, ahora)).toBeFalse();
      }
    });

    it('solo un esperado vigente se puede modificar', () => {
      expect(puedeModificarPaquete({ ...base, estado: 'esperado' }, ahora)).toBeTrue();
      expect(puedeModificarPaquete({ ...base, estado: 'esperado', fechaEsperadaHasta: '2026-10-11T00:00:00Z' }, ahora)).toBeFalse();
      for (const estado of ['recibido', 'entregado', 'cancelado', 'vencido', 'devuelto'] as const) {
        expect(puedeModificarPaquete({ ...base, estado }, ahora)).toBeFalse();
      }
    });
  });

  describe('orden', () => {
    const esperado = { ...base, id: 'e', creadoEn: '2026-10-12T10:00:00Z' };
    const viejo = { ...base, id: 'v', creadoEn: '2026-10-10T10:00:00Z' };
    const enCaseta = { ...base, id: 'c', estado: 'recibido' as const, creadoEn: '2026-10-09T10:00:00Z', recibidoEn: '2026-10-11T08:00:00Z' };

    it('los que están en caseta van primero y luego el más reciente', () => {
      expect(ordenarPaquetesPendientes([viejo, esperado, enCaseta], ahora).map(p => p.id)).toEqual(['c', 'e', 'v']);
    });

    it('no muta la lista original', () => {
      const lista = [viejo, esperado];
      ordenarPaquetesPendientes(lista, ahora);
      expect(lista.map(p => p.id)).toEqual(['v', 'e']);
    });

    it('la actividad toma la entrega, luego la recepción y luego el alta', () => {
      expect(fechaActividadPaquete({ entregadoEn: '2026-10-12T00:00:00Z', recibidoEn: '2026-10-11T00:00:00Z', creadoEn: '2026-10-10T00:00:00Z' }))
        .toBe(new Date('2026-10-12T00:00:00Z').getTime());
      expect(fechaActividadPaquete({ recibidoEn: '2026-10-11T00:00:00Z', creadoEn: '2026-10-10T00:00:00Z' }))
        .toBe(new Date('2026-10-11T00:00:00Z').getTime());
      expect(fechaActividadPaquete({})).toBe(0);
    });

    it('el historial va del más reciente al más antiguo', () => {
      const entregadoAyer = { ...base, id: 'a', estado: 'entregado' as const, entregadoEn: '2026-10-11T00:00:00Z' };
      const entregadoHoy = { ...base, id: 'h', estado: 'entregado' as const, entregadoEn: '2026-10-12T00:00:00Z' };

      expect(ordenarPaquetesRecientesPrimero([entregadoAyer, entregadoHoy]).map(p => p.id)).toEqual(['h', 'a']);
    });
  });

  describe('búsqueda', () => {
    const paquete: Paquete = { ...base, servicioNombre: 'Mercado Libre', numeroGuia: 'ML-9845', descripcion: 'Caja de zapatos', numeroCasa: 'PRUEBA-01' };

    it('encuentra por empresa, guía, destinatario, descripción o casa', () => {
      for (const texto of ['mercado', 'ml-98', 'angel', 'zapatos', 'prueba-01']) {
        expect(paqueteCoincideConBusqueda(paquete, texto)).withContext(texto).toBeTrue();
      }
    });

    it('ignora mayúsculas y acentos', () => {
      expect(paqueteCoincideConBusqueda(paquete, 'GOMEZ')).toBeTrue();
      expect(paqueteCoincideConBusqueda(paquete, 'Gómez')).toBeTrue();
    });

    it('un texto vacío deja pasar todo y uno ajeno no', () => {
      expect(paqueteCoincideConBusqueda(paquete, '   ')).toBeTrue();
      expect(paqueteCoincideConBusqueda(paquete, 'fedex')).toBeFalse();
    });
  });
});
