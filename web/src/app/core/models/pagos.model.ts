export type EstadoCargo = 'Pendiente' | 'Parcial' | 'Pagado' | 'Cancelado';
/** Lo que se muestra: un cargo abierto cuya fecha ya pasó figura como vencido */
export type EstadoEfectivoCargo = EstadoCargo | 'Vencido';
export type EstadoPago = 'PendienteConfirmacion' | 'Confirmado' | 'Rechazado' | 'Anulado';
export type MetodoPago = 'Efectivo' | 'Transferencia' | 'Deposito' | 'Otro';
export type TipoCargo = 'Renta' | 'Mantenimiento' | 'Servicio' | 'Multa' | 'Otro';
export type ResponsablePago = 'Propietario' | 'Residente';
export type OrigenPago = 'Admin' | 'Inquilino';
export type TipoMovimientoSaldo = 'Abono' | 'Aplicacion' | 'ReversoAbono' | 'ReversoAplicacion';

export const ESTADOS_CARGO: EstadoCargo[] = ['Pendiente', 'Parcial', 'Pagado', 'Cancelado'];
export const ESTADOS_PAGO: EstadoPago[] = ['PendienteConfirmacion', 'Confirmado', 'Rechazado', 'Anulado'];
export const METODOS_PAGO: MetodoPago[] = ['Transferencia', 'Deposito', 'Efectivo', 'Otro'];
export const TIPOS_CARGO: TipoCargo[] = ['Mantenimiento', 'Renta', 'Servicio', 'Multa', 'Otro'];
export const RESPONSABLES_PAGO: ResponsablePago[] = ['Residente', 'Propietario'];

export const ETIQUETAS_ESTADO_CARGO: Record<EstadoEfectivoCargo, string> = {
  Pendiente: 'Pendiente',
  Parcial: 'Pago parcial',
  Pagado: 'Pagado',
  Cancelado: 'Cancelado',
  Vencido: 'Vencido'
};

export const CLASES_ESTADO_CARGO: Record<EstadoEfectivoCargo, string> = {
  Pendiente: 'bg-indigo-50 text-indigo-700 border-indigo-200',
  Parcial: 'bg-sky-50 text-sky-700 border-sky-200',
  Pagado: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  Cancelado: 'bg-slate-100 text-slate-600 border-slate-200',
  Vencido: 'bg-rose-50 text-rose-700 border-rose-200'
};

export const ETIQUETAS_ESTADO_PAGO: Record<EstadoPago, string> = {
  PendienteConfirmacion: 'Por confirmar',
  Confirmado: 'Confirmado',
  Rechazado: 'Rechazado',
  Anulado: 'Anulado'
};

export const CLASES_ESTADO_PAGO: Record<EstadoPago, string> = {
  PendienteConfirmacion: 'bg-amber-50 text-amber-700 border-amber-200',
  Confirmado: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  Rechazado: 'bg-rose-50 text-rose-700 border-rose-200',
  Anulado: 'bg-slate-100 text-slate-600 border-slate-200'
};

export const ETIQUETAS_METODO_PAGO: Record<MetodoPago, string> = {
  Efectivo: 'Efectivo',
  Transferencia: 'Transferencia',
  Deposito: 'Depósito',
  Otro: 'Otro'
};

export const ETIQUETAS_TIPO_CARGO: Record<TipoCargo, string> = {
  Renta: 'Renta',
  Mantenimiento: 'Mantenimiento',
  Servicio: 'Servicio',
  Multa: 'Multa',
  Otro: 'Otro'
};

export const ETIQUETAS_TIPO_MOVIMIENTO: Record<TipoMovimientoSaldo, string> = {
  Abono: 'Abono por excedente',
  Aplicacion: 'Aplicado a un cargo',
  ReversoAbono: 'Reverso de abono',
  ReversoAplicacion: 'Aplicación revertida'
};

/** Largos y topes que valida el backend; la pantalla los revisa antes de enviar */
export const LIMITES_PAGOS = {
  concepto: 200,
  motivo: { min: 5, max: 300 },
  /** Un comprobante pesa hasta 5 MB y, si es PDF, hasta 1 MB */
  comprobanteBytes: 5 * 1024 * 1024,
  comprobantePdfBytes: 1024 * 1024
} as const;

export const TIPOS_COMPROBANTE = ['image/jpeg', 'image/png', 'application/pdf'] as const;

/** Respuesta paginada del microservicio de pagos */
export interface Pagina<T> {
  items: T[];
  total: number;
  pagina: number;
  tamanoPagina: number;
}

export interface PagoResumen {
  id: string;
  monto: number;
  montoCubierto: number;
  montoExcedente: number;
  fechaPago: string;
  metodo: MetodoPago;
  referencia: string | null;
  estado: EstadoPago;
  origen: OrigenPago;
  tieneComprobante: boolean;
  esReversa: boolean;
  pagoOriginalId: string | null;
}

export interface Cargo {
  id: string;
  viviendaId: number;
  numeroCasa: string;
  plantillaId: string | null;
  /** YYYY-MM */
  periodo: string | null;
  tipo: TipoCargo;
  concepto: string;
  monto: number;
  montoPagadoConfirmado: number;
  saldoPendiente: number;
  estado: EstadoCargo;
  estadoEfectivo: EstadoEfectivoCargo;
  /** yyyy-MM-dd */
  fechaVencimiento: string;
  responsablePago: ResponsablePago;
  motivoCancelacion: string | null;
  creadoEn: string;
}

export interface CargoDetalle extends Cargo {
  pagos: PagoResumen[];
}

export interface Pago {
  id: string;
  cargoId: string;
  viviendaId: number;
  numeroCasa: string;
  cargoTipo: TipoCargo;
  cargoConcepto: string;
  monto: number;
  montoCubierto: number;
  montoExcedente: number;
  fechaPago: string;
  metodo: MetodoPago;
  referencia: string | null;
  bancoOrigen: string | null;
  estado: EstadoPago;
  origen: OrigenPago;
  tieneComprobante: boolean;
  esReversa: boolean;
  pagoOriginalId: string | null;
  motivoRechazo: string | null;
  motivoAnulacion: string | null;
  creadoEn: string;
  confirmadoEn: string | null;
  rechazadoEn: string | null;
  anuladoEn: string | null;
}

export interface Plantilla {
  id: string;
  viviendaId: number;
  numeroCasa: string;
  tipo: TipoCargo;
  concepto: string;
  monto: number;
  diaVencimiento: number;
  vigenciaInicio: string;
  vigenciaFin: string | null;
  responsablePago: ResponsablePago;
  activa: boolean;
}

export interface SaldoVivienda {
  viviendaId: number;
  numeroCasa: string;
  totalPendiente: number;
  totalVencido: number;
  totalCargosAbiertos: number;
  saldoAFavor: number;
}

export interface SaldoUsuario {
  totalPendiente: number;
  totalVencido: number;
  totalCargosAbiertos: number;
  saldoAFavor: number;
  viviendas: SaldoVivienda[];
}

export interface MovimientoSaldo {
  id: string;
  viviendaId: number | null;
  tipo: TipoMovimientoSaldo;
  monto: number;
  montoConSigno: number | null;
  pagoId: string | null;
  cargoId: string | null;
  movimientoOrigenId: string | null;
  motivo: string | null;
  creadoEn: string | null;
}

export interface ComprobanteSubido {
  ruta: string;
  hash: string;
  tamanoBytes: number;
  contentType: string;
}

/** Lo que devuelve confirmar un pago, y lo que devuelve registrar uno como administrador */
export interface ResultadoPago {
  pago: Pago;
  cargo: Cargo;
  saldoAFavor: number;
}

export interface ResultadoAnulacion {
  pagoAnulado: Pago;
  pagoReversa: Pago;
  cargo: Cargo;
  saldoAFavor: number;
}

export interface ResultadoSaldo {
  movimiento: MovimientoSaldo;
  cargo: Cargo;
  saldoAFavor: number;
}

export interface ResultadoGeneracion {
  creados: number;
  omitidosPorYaExistir: number;
  omitidosPorVigencia: number;
}

/** Datos para dar de alta un cargo a mano */
export interface NuevoCargoDto {
  viviendaId: number;
  tipo: TipoCargo;
  concepto: string;
  monto: number;
  /** YYYY-MM; obligatorio en renta y mantenimiento */
  periodo?: string | null;
  fechaVencimiento: string;
  responsablePago?: ResponsablePago | null;
}

/** Datos de un pago, ya sea el que reporta el residente o el que registra el administrador */
export interface NuevoPagoDto {
  cargoId: string;
  monto: number;
  fechaPago: string;
  metodo: MetodoPago;
  referencia?: string | null;
  bancoOrigen?: string | null;
  comprobante?: { ruta: string; hash: string } | null;
}

export interface NuevaPlantillaDto {
  concepto: string;
  tipo: TipoCargo;
  monto: number;
  diaVencimiento: number;
  vigenciaInicio: string;
  vigenciaFin?: string | null;
  responsablePago?: ResponsablePago | null;
  viviendas: { viviendaId: number; monto?: number | null }[];
}

export interface ActualizarPlantillaDto {
  concepto: string;
  monto: number;
  diaVencimiento: number;
  vigenciaFin?: string | null;
  responsablePago?: ResponsablePago | null;
}

export interface FiltrosCargos {
  viviendaId?: number | null;
  tipo?: TipoCargo | '';
  estado?: EstadoCargo | '';
  vencido?: boolean | null;
  periodo?: string;
  desde?: string;
  hasta?: string;
}

export interface FiltrosPagos {
  cargoId?: string;
  viviendaId?: number | null;
  estado?: EstadoPago | '';
  metodo?: MetodoPago | '';
  desde?: string;
  hasta?: string;
}

// --- Del backend (snake_case) al modelo del web ---

function num(valor: any): number {
  const n = Number(valor);
  return Number.isFinite(n) ? n : 0;
}

function texto(valor: any): string | null {
  return typeof valor === 'string' && valor !== '' ? valor : null;
}

export function aPagoResumen(r: any): PagoResumen {
  return {
    id: r.id,
    monto: num(r.monto),
    montoCubierto: num(r.monto_cubierto),
    montoExcedente: num(r.monto_excedente),
    fechaPago: r.fecha_pago,
    metodo: r.metodo,
    referencia: texto(r.referencia),
    estado: r.estado,
    origen: r.origen,
    tieneComprobante: !!r.tiene_comprobante,
    esReversa: !!r.es_reversa,
    pagoOriginalId: texto(r.pago_original_id)
  };
}

export function aCargo(r: any): Cargo {
  return {
    id: r.id,
    viviendaId: num(r.vivienda_id),
    numeroCasa: r.numero_casa ?? '',
    plantillaId: texto(r.plantilla_id),
    periodo: texto(r.periodo),
    tipo: r.tipo,
    concepto: r.concepto ?? '',
    monto: num(r.monto),
    montoPagadoConfirmado: num(r.monto_pagado_confirmado),
    saldoPendiente: num(r.saldo_pendiente),
    estado: r.estado,
    estadoEfectivo: (r.estado_efectivo || r.estado) as EstadoEfectivoCargo,
    fechaVencimiento: r.fecha_vencimiento,
    responsablePago: r.responsable_pago,
    motivoCancelacion: texto(r.motivo_cancelacion),
    creadoEn: r.creado_en
  };
}

export function aCargoDetalle(r: any): CargoDetalle {
  return { ...aCargo(r), pagos: Array.isArray(r.pagos) ? r.pagos.map(aPagoResumen) : [] };
}

export function aPago(r: any): Pago {
  return {
    id: r.id,
    cargoId: r.cargo_id,
    viviendaId: num(r.vivienda_id),
    numeroCasa: r.numero_casa ?? '',
    cargoTipo: r.cargo_tipo,
    cargoConcepto: r.cargo_concepto ?? '',
    monto: num(r.monto),
    montoCubierto: num(r.monto_cubierto),
    montoExcedente: num(r.monto_excedente),
    fechaPago: r.fecha_pago,
    metodo: r.metodo,
    referencia: texto(r.referencia),
    bancoOrigen: texto(r.banco_origen),
    estado: r.estado,
    origen: r.origen,
    tieneComprobante: !!r.tiene_comprobante,
    esReversa: !!r.es_reversa,
    pagoOriginalId: texto(r.pago_original_id),
    motivoRechazo: texto(r.motivo_rechazo),
    motivoAnulacion: texto(r.motivo_anulacion),
    creadoEn: r.creado_en,
    confirmadoEn: texto(r.confirmado_en),
    rechazadoEn: texto(r.rechazado_en),
    anuladoEn: texto(r.anulado_en)
  };
}

export function aPlantilla(r: any): Plantilla {
  return {
    id: r.id,
    viviendaId: num(r.vivienda_id),
    numeroCasa: r.numero_casa ?? '',
    tipo: r.tipo,
    concepto: r.concepto ?? '',
    monto: num(r.monto),
    diaVencimiento: num(r.dia_vencimiento),
    vigenciaInicio: r.vigencia_inicio,
    vigenciaFin: texto(r.vigencia_fin),
    responsablePago: r.responsable_pago,
    activa: !!r.activa
  };
}

export function aSaldoVivienda(r: any): SaldoVivienda {
  return {
    viviendaId: num(r.vivienda_id),
    numeroCasa: r.numero_casa ?? '',
    totalPendiente: num(r.total_pendiente),
    totalVencido: num(r.total_vencido),
    totalCargosAbiertos: num(r.total_cargos_abiertos),
    saldoAFavor: num(r.saldo_a_favor)
  };
}

export function aSaldoUsuario(r: any): SaldoUsuario {
  return {
    totalPendiente: num(r?.total_pendiente),
    totalVencido: num(r?.total_vencido),
    totalCargosAbiertos: num(r?.total_cargos_abiertos),
    saldoAFavor: num(r?.saldo_a_favor),
    viviendas: Array.isArray(r?.viviendas) ? r.viviendas.map(aSaldoVivienda) : []
  };
}

export function aMovimientoSaldo(r: any): MovimientoSaldo {
  return {
    id: r.id,
    viviendaId: r.vivienda_id ?? null,
    tipo: r.tipo,
    monto: num(r.monto),
    montoConSigno: r.monto_con_signo == null ? null : num(r.monto_con_signo),
    pagoId: texto(r.pago_id),
    cargoId: texto(r.cargo_id),
    movimientoOrigenId: texto(r.movimiento_origen_id),
    motivo: texto(r.motivo),
    creadoEn: texto(r.creado_en)
  };
}

export function aPagina<T>(r: any, mapear: (item: any) => T): Pagina<T> {
  const items: any[] = Array.isArray(r?.items) ? r.items : [];
  return {
    items: items.map(mapear),
    total: num(r?.total ?? items.length),
    pagina: num(r?.pagina ?? 1) || 1,
    tamanoPagina: num(r?.tamanoPagina ?? items.length)
  };
}

// --- Reglas de cada pantalla ---

/** Un cargo abierto admite que se le reporte o registre un pago */
export function cargoAdmitePago(c: Pick<Cargo, 'estado' | 'saldoPendiente'>): boolean {
  return (c.estado === 'Pendiente' || c.estado === 'Parcial') && c.saldoPendiente > 0;
}

/** Cancelar solo aplica a un cargo que sigue abierto */
export function cargoPuedeCancelarse(c: Pick<Cargo, 'estado'>): boolean {
  return c.estado === 'Pendiente' || c.estado === 'Parcial';
}

/** Solo un pago confirmado se anula, y las reversas que genera la anulación no se anulan */
export function pagoPuedeAnularse(p: Pick<Pago, 'estado' | 'esReversa'>): boolean {
  return p.estado === 'Confirmado' && !p.esReversa;
}

export function pagoEstaPorConfirmar(p: Pick<Pago, 'estado'>): boolean {
  return p.estado === 'PendienteConfirmacion';
}

/** El abono por excedente se puede revertir; las reversiones ya hechas no */
export function movimientoPuedeRevertirse(m: Pick<MovimientoSaldo, 'tipo'>): boolean {
  return m.tipo === 'Aplicacion';
}

export function metodoRequiereReferencia(metodo: MetodoPago): boolean {
  return metodo === 'Transferencia' || metodo === 'Deposito';
}

// --- Formato ---

const FORMATO_MONEDA = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });

export function formatearMonto(monto: number | null | undefined): string {
  return FORMATO_MONEDA.format(Number.isFinite(monto as number) ? (monto as number) : 0);
}

/** Dos decimales exactos, para no arrastrar errores de punto flotante al sumar o comparar dinero */
export function redondearMonto(monto: number): number {
  return Math.round((monto + Number.EPSILON) * 100) / 100;
}

export function tieneMasDeDosDecimales(monto: number): boolean {
  return Math.abs(monto * 100 - Math.round(monto * 100)) > 1e-6;
}

/** yyyy-MM-dd de la fecha local; una fecha sin hora no debe correrse por la zona horaria */
export function fechaLocalIso(d: Date = new Date()): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** YYYY-MM del mes de la fecha local */
export function periodoActual(d: Date = new Date()): string {
  return fechaLocalIso(d).slice(0, 7);
}

/** "5 oct 2026" a partir de yyyy-MM-dd (o de un instante ISO) */
export function formatearFechaPago(valor: string | null | undefined): string {
  if (!valor) return '';
  const solo = /^\d{4}-\d{2}-\d{2}$/.test(valor);
  const d = solo ? new Date(`${valor}T00:00:00`) : new Date(valor);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' });
}

/** "octubre de 2026" a partir de YYYY-MM */
export function formatearPeriodo(periodo: string | null | undefined): string {
  if (!periodo || !/^\d{4}-(0[1-9]|1[0-2])$/.test(periodo)) return '';
  const [anio, mes] = periodo.split('-').map(Number);
  return new Date(anio, mes - 1, 1).toLocaleDateString('es-MX', { month: 'long', year: 'numeric' });
}

// --- Validación de formularios ---

/** Revisa un comprobante antes de subirlo; devuelve el motivo si no sirve */
export function validarArchivoComprobante(archivo: Pick<File, 'type' | 'size'>): string | null {
  if (!(TIPOS_COMPROBANTE as readonly string[]).includes(archivo.type)) {
    return 'El comprobante debe ser una imagen JPG o PNG, o un PDF.';
  }
  if (archivo.size > LIMITES_PAGOS.comprobanteBytes) {
    return 'El comprobante pesa más de 5 MB.';
  }
  if (archivo.type === 'application/pdf' && archivo.size > LIMITES_PAGOS.comprobantePdfBytes) {
    return 'Un comprobante en PDF debe pesar menos de 1 MB.';
  }
  return null;
}

export type ModoPago = 'residente' | 'admin';

export interface FormularioPago {
  monto: number | null;
  fechaPago: string;
  metodo: MetodoPago;
  referencia: string;
  bancoOrigen: string;
  hayComprobante: boolean;
}

/**
 * Reglas del backend para un pago: el residente debe adjuntar comprobante y, en transferencia o depósito, dar
 * referencia y banco; el administrador solo necesita la referencia y el comprobante es opcional.
 */
export function validarPago(f: FormularioPago, modo: ModoPago, hoy: string = fechaLocalIso()): string | null {
  if (f.monto == null || !Number.isFinite(f.monto) || f.monto <= 0) return 'Escribe un monto mayor a cero.';
  if (tieneMasDeDosDecimales(f.monto)) return 'El monto no puede tener más de dos decimales.';
  if (!f.fechaPago) return 'Indica la fecha del pago.';
  if (f.fechaPago > hoy) return 'La fecha del pago no puede ser futura.';
  if (metodoRequiereReferencia(f.metodo)) {
    if (!f.referencia.trim()) return `La referencia es obligatoria para un pago por ${ETIQUETAS_METODO_PAGO[f.metodo].toLowerCase()}.`;
    if (modo === 'residente' && !f.bancoOrigen.trim()) return 'Indica el banco de origen.';
  }
  if (modo === 'residente' && !f.hayComprobante) return 'Adjunta el comprobante del pago.';
  return null;
}

export interface FormularioCargo {
  viviendaId: number | null;
  tipo: TipoCargo;
  concepto: string;
  monto: number | null;
  periodo: string;
  fechaVencimiento: string;
}

export function cargoRequierePeriodo(tipo: TipoCargo): boolean {
  return tipo === 'Renta' || tipo === 'Mantenimiento';
}

export function validarCargo(f: FormularioCargo): string | null {
  if (!f.viviendaId) return 'Elige la vivienda.';
  if (!f.concepto.trim()) return 'Escribe el concepto del cargo.';
  if (f.concepto.trim().length > LIMITES_PAGOS.concepto) return `El concepto no puede pasar de ${LIMITES_PAGOS.concepto} caracteres.`;
  if (f.monto == null || !Number.isFinite(f.monto) || f.monto <= 0) return 'Escribe un monto mayor a cero.';
  if (tieneMasDeDosDecimales(f.monto)) return 'El monto no puede tener más de dos decimales.';
  if (cargoRequierePeriodo(f.tipo) && !f.periodo) return `El periodo es obligatorio para un cargo de ${ETIQUETAS_TIPO_CARGO[f.tipo].toLowerCase()}.`;
  if (!f.fechaVencimiento) return 'Indica la fecha de vencimiento.';
  return null;
}

/** El motivo de rechazar, anular o revertir debe tener entre 5 y 300 caracteres */
export function validarMotivo(motivo: string | null | undefined): string | null {
  const largo = (motivo ?? '').trim().length;
  if (largo < LIMITES_PAGOS.motivo.min) return `El motivo debe tener al menos ${LIMITES_PAGOS.motivo.min} caracteres.`;
  if (largo > LIMITES_PAGOS.motivo.max) return `El motivo no puede pasar de ${LIMITES_PAGOS.motivo.max} caracteres.`;
  return null;
}

export interface FormularioPlantilla {
  concepto: string;
  tipo: TipoCargo;
  monto: number | null;
  diaVencimiento: number | null;
  vigenciaInicio: string;
  vigenciaFin: string;
  viviendasSeleccionadas: number;
}

export function validarPlantilla(f: FormularioPlantilla, esEdicion: boolean): string | null {
  if (!f.concepto.trim()) return 'Escribe el concepto.';
  if (f.concepto.trim().length > LIMITES_PAGOS.concepto) return `El concepto no puede pasar de ${LIMITES_PAGOS.concepto} caracteres.`;
  if (f.monto == null || !Number.isFinite(f.monto) || f.monto <= 0) return 'Escribe un monto mayor a cero.';
  if (tieneMasDeDosDecimales(f.monto)) return 'El monto no puede tener más de dos decimales.';
  if (f.diaVencimiento == null || !Number.isInteger(f.diaVencimiento) || f.diaVencimiento < 1 || f.diaVencimiento > 31) {
    return 'El día de vencimiento debe estar entre 1 y 31.';
  }
  if (!esEdicion) {
    if (!f.vigenciaInicio) return 'Indica desde cuándo aplica.';
    if (f.viviendasSeleccionadas < 1) return 'Elige al menos una vivienda.';
    if (f.viviendasSeleccionadas > 200) return 'Una plantilla admite hasta 200 viviendas.';
  }
  if (f.vigenciaFin && f.vigenciaInicio && f.vigenciaFin < f.vigenciaInicio) return 'El fin de la vigencia no puede ser anterior al inicio.';
  return null;
}
