import {
  FormularioCargo,
  FormularioPago,
  FormularioPlantilla,
  aCargo,
  aCargoDetalle,
  aMovimientoSaldo,
  aPagina,
  aPago,
  aSaldoUsuario,
  cargoAdmitePago,
  cargoPuedeCancelarse,
  fechaLocalIso,
  formatearFechaPago,
  formatearPeriodo,
  movimientoPuedeRevertirse,
  pagoPuedeAnularse,
  periodoActual,
  redondearMonto,
  tieneMasDeDosDecimales,
  validarArchivoComprobante,
  validarCargo,
  validarMotivo,
  validarPago,
  validarPlantilla
} from './pagos.model';

describe('pagos.model', () => {
  describe('mapeo desde el backend', () => {
    it('convierte un cargo de snake_case y conserva el estado efectivo', () => {
      const cargo = aCargo({
        id: 'c1', vivienda_id: 7, numero_casa: '12', periodo: '2026-10', tipo: 'Mantenimiento', concepto: 'Cuota',
        monto: 1500, monto_pagado_confirmado: 500, saldo_pendiente: 1000, estado: 'Parcial', estado_efectivo: 'Vencido',
        fecha_vencimiento: '2026-10-10', responsable_pago: 'Residente', motivo_cancelacion: null, creado_en: '2026-10-01T00:00:00Z'
      });
      expect(cargo.viviendaId).toBe(7);
      expect(cargo.montoPagadoConfirmado).toBe(500);
      expect(cargo.saldoPendiente).toBe(1000);
      expect(cargo.estado).toBe('Parcial');
      expect(cargo.estadoEfectivo).toBe('Vencido');
      expect(cargo.motivoCancelacion).toBeNull();
    });

    it('si el backend no manda estado efectivo usa el estado del cargo', () => {
      expect(aCargo({ id: 'c', estado: 'Pagado' }).estadoEfectivo).toBe('Pagado');
    });

    it('trae los pagos de un cargo en su detalle', () => {
      const detalle = aCargoDetalle({
        id: 'c1', estado: 'Pendiente',
        pagos: [{ id: 'p1', monto: 100, monto_cubierto: 100, monto_excedente: 0, fecha_pago: '2026-10-02', metodo: 'Efectivo', estado: 'Confirmado', origen: 'Admin', tiene_comprobante: false, es_reversa: false }]
      });
      expect(detalle.pagos.length).toBe(1);
      expect(detalle.pagos[0].montoCubierto).toBe(100);
    });

    it('un pago deja en null los textos vacíos y convierte los booleanos', () => {
      const pago = aPago({ id: 'p1', cargo_id: 'c1', referencia: '', motivo_rechazo: 'Borroso', tiene_comprobante: 1, es_reversa: null });
      expect(pago.referencia).toBeNull();
      expect(pago.motivoRechazo).toBe('Borroso');
      expect(pago.tieneComprobante).toBeTrue();
      expect(pago.esReversa).toBeFalse();
    });

    it('un saldo vacío o nulo queda en cero y sin viviendas', () => {
      const saldo = aSaldoUsuario(null);
      expect(saldo.totalPendiente).toBe(0);
      expect(saldo.viviendas).toEqual([]);
    });

    it('un movimiento sin monto con signo lo deja en null', () => {
      expect(aMovimientoSaldo({ id: 'm', tipo: 'Abono', monto: 10 }).montoConSigno).toBeNull();
      expect(aMovimientoSaldo({ id: 'm', tipo: 'Aplicacion', monto: 10, monto_con_signo: -10 }).montoConSigno).toBe(-10);
    });

    it('una página sin items queda vacía con valores por defecto', () => {
      expect(aPagina(null, aPago)).toEqual({ items: [], total: 0, pagina: 1, tamanoPagina: 0 });
      const pagina = aPagina({ items: [{ id: 'a' }], total: 31, pagina: 2, tamanoPagina: 20 }, x => x.id);
      expect(pagina).toEqual({ items: ['a'], total: 31, pagina: 2, tamanoPagina: 20 });
    });
  });

  describe('qué acciones admite cada registro', () => {
    it('un cargo abierto con saldo admite un pago; uno pagado o cancelado no', () => {
      expect(cargoAdmitePago({ estado: 'Pendiente', saldoPendiente: 100 })).toBeTrue();
      expect(cargoAdmitePago({ estado: 'Parcial', saldoPendiente: 30 })).toBeTrue();
      expect(cargoAdmitePago({ estado: 'Pendiente', saldoPendiente: 0 })).toBeFalse();
      expect(cargoAdmitePago({ estado: 'Pagado', saldoPendiente: 0 })).toBeFalse();
      expect(cargoAdmitePago({ estado: 'Cancelado', saldoPendiente: 100 })).toBeFalse();
    });

    it('solo se cancela un cargo abierto', () => {
      expect(cargoPuedeCancelarse({ estado: 'Pendiente' })).toBeTrue();
      expect(cargoPuedeCancelarse({ estado: 'Parcial' })).toBeTrue();
      expect(cargoPuedeCancelarse({ estado: 'Pagado' })).toBeFalse();
      expect(cargoPuedeCancelarse({ estado: 'Cancelado' })).toBeFalse();
    });

    it('solo se anula un pago confirmado que no sea una reversa', () => {
      expect(pagoPuedeAnularse({ estado: 'Confirmado', esReversa: false })).toBeTrue();
      expect(pagoPuedeAnularse({ estado: 'Confirmado', esReversa: true })).toBeFalse();
      expect(pagoPuedeAnularse({ estado: 'PendienteConfirmacion', esReversa: false })).toBeFalse();
      expect(pagoPuedeAnularse({ estado: 'Anulado', esReversa: false })).toBeFalse();
    });

    it('solo se revierte una aplicación de saldo', () => {
      expect(movimientoPuedeRevertirse({ tipo: 'Aplicacion' })).toBeTrue();
      expect(movimientoPuedeRevertirse({ tipo: 'Abono' })).toBeFalse();
      expect(movimientoPuedeRevertirse({ tipo: 'ReversoAplicacion' })).toBeFalse();
    });
  });

  describe('dinero y fechas', () => {
    it('redondea a dos decimales y detecta más de dos', () => {
      expect(redondearMonto(0.1 + 0.2)).toBe(0.3);
      expect(tieneMasDeDosDecimales(10.5)).toBeFalse();
      expect(tieneMasDeDosDecimales(10.55)).toBeFalse();
      expect(tieneMasDeDosDecimales(10.555)).toBeTrue();
    });

    it('da la fecha y el periodo locales sin correrse por la zona horaria', () => {
      const d = new Date(2026, 9, 5, 23, 59);
      expect(fechaLocalIso(d)).toBe('2026-10-05');
      expect(periodoActual(d)).toBe('2026-10');
    });

    it('formatea una fecha sin hora sin cambiarle el día', () => {
      expect(formatearFechaPago('2026-10-05')).toContain('5');
      expect(formatearFechaPago('')).toBe('');
      expect(formatearFechaPago('no es fecha')).toBe('');
    });

    it('formatea el periodo y rechaza uno mal escrito', () => {
      expect(formatearPeriodo('2026-10')).toContain('2026');
      expect(formatearPeriodo('2026-13')).toBe('');
      expect(formatearPeriodo(null)).toBe('');
    });
  });

  describe('validarArchivoComprobante', () => {
    it('acepta JPG, PNG y PDF dentro del peso permitido', () => {
      expect(validarArchivoComprobante({ type: 'image/jpeg', size: 4 * 1024 * 1024 })).toBeNull();
      expect(validarArchivoComprobante({ type: 'image/png', size: 100 })).toBeNull();
      expect(validarArchivoComprobante({ type: 'application/pdf', size: 900 * 1024 })).toBeNull();
    });

    it('rechaza otros formatos, más de 5 MB y PDF de más de 1 MB', () => {
      expect(validarArchivoComprobante({ type: 'image/gif', size: 100 })).toContain('JPG o PNG');
      expect(validarArchivoComprobante({ type: 'image/jpeg', size: 6 * 1024 * 1024 })).toContain('5 MB');
      expect(validarArchivoComprobante({ type: 'application/pdf', size: 2 * 1024 * 1024 })).toContain('1 MB');
    });
  });

  describe('validarPago', () => {
    const base: FormularioPago = { monto: 500, fechaPago: '2026-10-05', metodo: 'Efectivo', referencia: '', bancoOrigen: '', hayComprobante: true };
    const hoy = '2026-10-10';

    it('un pago en efectivo del residente con comprobante es válido', () => {
      expect(validarPago(base, 'residente', hoy)).toBeNull();
    });

    it('rechaza monto vacío, cero o con más de dos decimales', () => {
      expect(validarPago({ ...base, monto: null }, 'admin', hoy)).toContain('monto');
      expect(validarPago({ ...base, monto: 0 }, 'admin', hoy)).toContain('monto');
      expect(validarPago({ ...base, monto: 10.123 }, 'admin', hoy)).toContain('decimales');
    });

    it('rechaza una fecha futura o vacía', () => {
      expect(validarPago({ ...base, fechaPago: '2026-10-11' }, 'admin', hoy)).toContain('futura');
      expect(validarPago({ ...base, fechaPago: '' }, 'admin', hoy)).toContain('fecha');
    });

    it('transferencia y depósito piden referencia', () => {
      expect(validarPago({ ...base, metodo: 'Transferencia' }, 'admin', hoy)).toContain('referencia');
      expect(validarPago({ ...base, metodo: 'Deposito', referencia: '  ' }, 'admin', hoy)).toContain('referencia');
      expect(validarPago({ ...base, metodo: 'Transferencia', referencia: 'ABC123' }, 'admin', hoy)).toBeNull();
    });

    it('el residente además debe dar el banco y adjuntar comprobante; el administrador no', () => {
      const transferencia: FormularioPago = { ...base, metodo: 'Transferencia', referencia: 'ABC123' };
      expect(validarPago(transferencia, 'residente', hoy)).toContain('banco');
      expect(validarPago({ ...transferencia, bancoOrigen: 'BBVA' }, 'residente', hoy)).toBeNull();
      expect(validarPago({ ...base, hayComprobante: false }, 'residente', hoy)).toContain('comprobante');
      expect(validarPago({ ...base, hayComprobante: false }, 'admin', hoy)).toBeNull();
    });
  });

  describe('validarCargo', () => {
    const base: FormularioCargo = { viviendaId: 3, tipo: 'Multa', concepto: 'Ruido', monto: 300, periodo: '', fechaVencimiento: '2026-11-01' };

    it('una multa sin periodo es válida', () => {
      expect(validarCargo(base)).toBeNull();
    });

    it('renta y mantenimiento exigen periodo', () => {
      expect(validarCargo({ ...base, tipo: 'Mantenimiento' })).toContain('periodo');
      expect(validarCargo({ ...base, tipo: 'Renta', periodo: '2026-11' })).toBeNull();
    });

    it('pide vivienda, concepto, monto y vencimiento', () => {
      expect(validarCargo({ ...base, viviendaId: null })).toContain('vivienda');
      expect(validarCargo({ ...base, concepto: '  ' })).toContain('concepto');
      expect(validarCargo({ ...base, monto: -5 })).toContain('monto');
      expect(validarCargo({ ...base, fechaVencimiento: '' })).toContain('vencimiento');
    });
  });

  describe('validarMotivo', () => {
    it('exige entre 5 y 300 caracteres sin contar espacios de los lados', () => {
      expect(validarMotivo('   ab   ')).toContain('al menos 5');
      expect(validarMotivo(null)).toContain('al menos 5');
      expect(validarMotivo('Comprobante ilegible')).toBeNull();
      expect(validarMotivo('x'.repeat(301))).toContain('300');
    });
  });

  describe('validarPlantilla', () => {
    const base: FormularioPlantilla = { concepto: 'Cuota', tipo: 'Mantenimiento', monto: 1200, diaVencimiento: 10, vigenciaInicio: '2026-11-01', vigenciaFin: '', viviendasSeleccionadas: 4 };

    it('una plantilla completa es válida', () => {
      expect(validarPlantilla(base, false)).toBeNull();
    });

    it('el día de vencimiento va de 1 a 31', () => {
      expect(validarPlantilla({ ...base, diaVencimiento: 0 }, false)).toContain('entre 1 y 31');
      expect(validarPlantilla({ ...base, diaVencimiento: 32 }, false)).toContain('entre 1 y 31');
      expect(validarPlantilla({ ...base, diaVencimiento: 10.5 }, false)).toContain('entre 1 y 31');
    });

    it('al crear pide viviendas y vigencia; al editar no', () => {
      expect(validarPlantilla({ ...base, viviendasSeleccionadas: 0 }, false)).toContain('vivienda');
      expect(validarPlantilla({ ...base, viviendasSeleccionadas: 201 }, false)).toContain('200');
      expect(validarPlantilla({ ...base, vigenciaInicio: '' }, false)).toContain('desde cuándo');
      expect(validarPlantilla({ ...base, viviendasSeleccionadas: 0, vigenciaInicio: '' }, true)).toBeNull();
    });

    it('la vigencia no termina antes de empezar', () => {
      expect(validarPlantilla({ ...base, vigenciaFin: '2026-10-01' }, false)).toContain('anterior');
      expect(validarPlantilla({ ...base, vigenciaFin: '2027-01-01' }, false)).toBeNull();
    });
  });
});
