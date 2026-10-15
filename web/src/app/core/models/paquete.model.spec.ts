import {
  Paquete,
  empresasSeleccionables,
  estadoEfectivoPaquete,
  fechaActividadPaquete,
  llegaHoy,
  ordenarEsperadosParaCaseta,
  ordenarPaquetesEnCaseta,
  ordenarPaquetesPendientes,
  ordenarPaquetesRecientesPrimero,
  paqueteCoincideConBusqueda,
  paqueteEsPendiente,
  paqueteVencido,
  puedeModificarPaquete,
  textoVentanaPaquete
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

  describe('textoVentanaPaquete', () => {
    const dia = (d: number, h = 12) => new Date(2026, 9, d, h).toISOString();

    it('con las dos fechas muestra el rango de días', () => {
      expect(textoVentanaPaquete({ fechaEsperadaDesde: dia(12), fechaEsperadaHasta: dia(14) })).toMatch(/^Del .+ al .+$/);
    });

    it('si es el mismo día lo dice una sola vez', () => {
      expect(textoVentanaPaquete({ fechaEsperadaDesde: dia(12, 0), fechaEsperadaHasta: dia(12, 23) })).toMatch(/^El /);
    });

    it('con una sola fecha usa "Hasta el" o "A partir del"', () => {
      expect(textoVentanaPaquete({ fechaEsperadaHasta: dia(14) })).toMatch(/^Hasta el /);
      expect(textoVentanaPaquete({ fechaEsperadaDesde: dia(12) })).toMatch(/^A partir del /);
    });

    it('sin fechas válidas devuelve texto vacío', () => {
      expect(textoVentanaPaquete({})).toBe('');
      expect(textoVentanaPaquete({ fechaEsperadaDesde: '0001-01-01T00:00:00Z', fechaEsperadaHasta: 'basura' })).toBe('');
    });
  });

  describe('empresasSeleccionables', () => {
    const catalogo = [
      { id: 1, nombre: 'Amazon', activo: true, esSistema: true },
      { id: 9, nombre: ' OTRO ', activo: true, esSistema: true },
      { id: 3, nombre: 'DHL', activo: true, esSistema: true }
    ];

    it('quita "Otro" del catálogo sin distinguir mayúsculas ni espacios y conserva el resto en orden', () => {
      expect(empresasSeleccionables(catalogo).map(s => s.nombre)).toEqual(['Amazon', 'DHL']);
    });

    it('con un catálogo vacío devuelve una lista vacía', () => {
      expect(empresasSeleccionables([])).toEqual([]);
    });
  });

  describe('caseta', () => {
    // Mediodía del 12 de octubre en la hora local: así "hoy" no depende de la zona horaria de quien corre la prueba
    const mediodia = new Date(2026, 9, 12, 12).getTime();
    const dia = (d: number, h = 12) => new Date(2026, 9, d, h).toISOString();

    describe('llegaHoy', () => {
      it('una ventana que incluye hoy llega hoy', () => {
        expect(llegaHoy({ fechaEsperadaDesde: dia(10), fechaEsperadaHasta: dia(14) }, mediodia)).toBeTrue();
        expect(llegaHoy({ fechaEsperadaDesde: dia(12, 0), fechaEsperadaHasta: dia(12, 23) }, mediodia)).toBeTrue();
      });

      it('sin fechas puede llegar cualquier día, así que cuenta como hoy', () => {
        expect(llegaHoy({}, mediodia)).toBeTrue();
      });

      it('una ventana que empieza mañana o que terminó ayer no llega hoy', () => {
        expect(llegaHoy({ fechaEsperadaDesde: dia(13, 0), fechaEsperadaHasta: dia(15) }, mediodia)).toBeFalse();
        expect(llegaHoy({ fechaEsperadaDesde: dia(9), fechaEsperadaHasta: dia(11, 23) }, mediodia)).toBeFalse();
      });

      it('con solo un extremo se comporta como ventana abierta de ese lado', () => {
        expect(llegaHoy({ fechaEsperadaHasta: dia(20) }, mediodia)).toBeTrue();
        expect(llegaHoy({ fechaEsperadaDesde: dia(20) }, mediodia)).toBeFalse();
      });
    });

    describe('ordenarEsperadosParaCaseta', () => {
      it('los de hoy primero y, dentro de cada grupo, el aviso más reciente arriba', () => {
        const lista: Paquete[] = [
          { ...base, id: 'futuro', fechaEsperadaDesde: dia(20), fechaEsperadaHasta: dia(22), creadoEn: dia(1) },
          { ...base, id: 'hoy-viejo', creadoEn: dia(2) },
          { ...base, id: 'hoy-nuevo', creadoEn: dia(5) }
        ];

        const orden = ordenarEsperadosParaCaseta(lista, mediodia).map(p => p.id);

        expect(orden).toEqual(['hoy-nuevo', 'hoy-viejo', 'futuro']);
        expect(lista.map(p => p.id)).toEqual(['futuro', 'hoy-viejo', 'hoy-nuevo']);
      });
    });

    describe('ordenarPaquetesEnCaseta', () => {
      it('el que lleva más tiempo en caseta va primero', () => {
        const lista: Paquete[] = [
          { ...base, id: 'reciente', estado: 'recibido', recibidoEn: dia(11) },
          { ...base, id: 'antiguo', estado: 'recibido', recibidoEn: dia(3) },
          { ...base, id: 'sin-fecha', estado: 'recibido', creadoEn: dia(7) }
        ];

        expect(ordenarPaquetesEnCaseta(lista).map(p => p.id)).toEqual(['antiguo', 'sin-fecha', 'reciente']);
      });
    });
  });
});
