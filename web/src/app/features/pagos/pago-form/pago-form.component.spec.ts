import { ComponentFixture, TestBed } from '@angular/core/testing';
import { PagoFormComponent } from './pago-form.component';
import { PagosService } from '../../../core/services/pagos.service';
import { Cargo, ModoPago, Pago } from '../../../core/models/pagos.model';

const cargo: Cargo = {
  id: 'c1', viviendaId: 3, numeroCasa: '3', plantillaId: null, periodo: '2026-10', tipo: 'Mantenimiento', concepto: 'Cuota de octubre',
  monto: 1000, montoPagadoConfirmado: 0, saldoPendiente: 1000, estado: 'Pendiente', estadoEfectivo: 'Pendiente',
  fechaVencimiento: '2026-10-10', responsablePago: 'Residente', motivoCancelacion: null, creadoEn: '2026-10-01T00:00:00Z'
};
const pagoGuardado = { id: 'p1', estado: 'PendienteConfirmacion' } as Pago;
const comprobante = new File(['x'], 'recibo.jpg', { type: 'image/jpeg' });

describe('PagoFormComponent', () => {
  let fixture: ComponentFixture<PagoFormComponent>;
  let component: PagoFormComponent;
  let servicio: { subirComprobante: jasmine.Spy; reportarPago: jasmine.Spy; registrarPago: jasmine.Spy };

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');

  function abrir(modo: ModoPago): void {
    fixture = TestBed.createComponent(PagoFormComponent);
    component = fixture.componentInstance;
    component.cargo = cargo;
    component.modo = modo;
    fixture.detectChanges();
  }

  /** Simula elegir el archivo en el input sin abrir el selector del sistema */
  function elegirArchivo(archivo: File): void {
    const evento = { target: { files: [archivo], value: 'recibo.jpg' } } as unknown as Event;
    component.elegirArchivo(evento);
  }

  beforeEach(() => {
    servicio = {
      subirComprobante: jasmine.createSpy('subirComprobante').and.resolveTo({ ruta: 'cond/3/a.jpg', hash: 'ab'.repeat(32), tamanoBytes: 1, contentType: 'image/jpeg' }),
      reportarPago: jasmine.createSpy('reportarPago').and.resolveTo(pagoGuardado),
      registrarPago: jasmine.createSpy('registrarPago').and.resolveTo({ pago: pagoGuardado, cargo, saldoAFavor: 0 })
    };
    TestBed.configureTestingModule({
      imports: [PagoFormComponent],
      providers: [{ provide: PagosService, useValue: servicio }]
    });
  });

  it('muestra el cargo y propone pagar todo el saldo', () => {
    abrir('residente');

    expect(texto()).toContain('Cuota de octubre');
    expect(component.form.monto).toBe(1000);
    expect(texto()).toContain('Reportar un pago');
  });

  it('el administrador ve su propio título y que el comprobante es opcional', () => {
    abrir('admin');

    expect(texto()).toContain('Registrar un pago');
    expect(texto()).toContain('Comprobante (opcional)');
  });

  it('avisa que lo que excede el saldo queda como saldo a favor', () => {
    abrir('residente');
    expect(fixture.nativeElement.querySelector('[data-test="aviso-excedente"]')).toBeNull();

    component.form.monto = 1250.5;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-test="aviso-excedente"]').textContent).toContain('250.50');
  });

  it('pide referencia y banco solo en transferencia o depósito', () => {
    abrir('residente');
    expect(fixture.nativeElement.querySelector('#pago-referencia')).not.toBeNull();

    component.form.metodo = 'Efectivo';
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('#pago-referencia')).toBeNull();
  });

  it('el residente no puede reportar sin comprobante y no se llama al servicio', async () => {
    abrir('residente');
    component.form.metodo = 'Efectivo';

    await component.guardar();

    expect(component.error()).toContain('comprobante');
    expect(servicio.subirComprobante).not.toHaveBeenCalled();
    expect(servicio.reportarPago).not.toHaveBeenCalled();
  });

  it('rechaza un archivo que no es JPG, PNG ni PDF', () => {
    abrir('residente');

    elegirArchivo(new File(['x'], 'nota.txt', { type: 'text/plain' }));

    expect(component.error()).toContain('JPG o PNG');
  });

  it('el residente sube el comprobante a la vivienda del cargo y reporta el pago con su ruta y hash', async () => {
    abrir('residente');
    const emitido = jasmine.createSpy('guardado');
    component.guardado.subscribe(emitido);
    component.form.referencia = ' ABC123 ';
    component.form.bancoOrigen = 'BBVA';
    elegirArchivo(comprobante);

    await component.guardar();

    expect(servicio.subirComprobante).toHaveBeenCalledOnceWith(comprobante, 3);
    const dto = servicio.reportarPago.calls.mostRecent().args[0];
    expect(dto).toEqual(jasmine.objectContaining({
      cargoId: 'c1', monto: 1000, metodo: 'Transferencia', referencia: ' ABC123 ', bancoOrigen: 'BBVA',
      comprobante: { ruta: 'cond/3/a.jpg', hash: 'ab'.repeat(32) }
    }));
    expect(emitido).toHaveBeenCalledOnceWith(pagoGuardado);
    expect(component.isSaving()).toBeFalse();
  });

  it('si el pago falla después de subir el archivo, el reintento no lo vuelve a subir', async () => {
    spyOn(console, 'error');
    abrir('residente');
    component.form.referencia = 'ABC123';
    component.form.bancoOrigen = 'BBVA';
    elegirArchivo(comprobante);
    servicio.reportarPago.and.rejectWith({ status: 409, error: { error: 'El cargo ya está pagado' } });

    await component.guardar();
    expect(component.error()).toBe('El cargo ya está pagado');
    expect(component.isSaving()).toBeFalse();

    servicio.reportarPago.and.resolveTo(pagoGuardado);
    await component.guardar();

    expect(servicio.subirComprobante).toHaveBeenCalledTimes(1);
    expect(servicio.reportarPago).toHaveBeenCalledTimes(2);
    expect(component.error()).toBeNull();
  });

  it('el administrador registra un pago en efectivo sin comprobante ni referencia', async () => {
    abrir('admin');
    const emitido = jasmine.createSpy('guardado');
    component.guardado.subscribe(emitido);
    component.form.metodo = 'Efectivo';
    component.form.referencia = 'se ignora';

    await component.guardar();

    expect(servicio.subirComprobante).not.toHaveBeenCalled();
    expect(servicio.reportarPago).not.toHaveBeenCalled();
    const dto = servicio.registrarPago.calls.mostRecent().args[0];
    expect(dto.referencia).toBeNull();
    expect(dto.comprobante).toBeNull();
    expect(emitido).toHaveBeenCalledOnceWith(pagoGuardado);
  });

  it('un monto inválido no llega al servicio', async () => {
    abrir('admin');
    component.form.metodo = 'Efectivo';
    component.form.monto = 0;

    await component.guardar();

    expect(component.error()).toContain('monto');
    expect(servicio.registrarPago).not.toHaveBeenCalled();
  });

  it('cerrar avisa a quien abrió el formulario', () => {
    abrir('residente');
    const cerrado = jasmine.createSpy('cerrado');
    component.cerrado.subscribe(cerrado);

    component.cerrar();

    expect(cerrado).toHaveBeenCalled();
  });
});
