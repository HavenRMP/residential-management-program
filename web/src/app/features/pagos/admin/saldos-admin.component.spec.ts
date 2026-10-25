import { ComponentFixture, TestBed } from '@angular/core/testing';
import Swal from 'sweetalert2';
import { SaldosAdminComponent } from './saldos-admin.component';
import { PagosService } from '../../../core/services/pagos.service';
import { MovimientoSaldo, SaldoVivienda } from '../../../core/models/pagos.model';

const saldo: SaldoVivienda = { viviendaId: 3, numeroCasa: '3', totalPendiente: 2500, totalVencido: 1000, totalCargosAbiertos: 2, saldoAFavor: 300 };

const movimiento = (id: string, extra: Partial<MovimientoSaldo> = {}): MovimientoSaldo => ({
  id, viviendaId: 3, tipo: 'Abono', monto: 50, montoConSigno: 50, pagoId: 'p1', cargoId: null, movimientoOrigenId: null,
  motivo: null, creadoEn: '2026-10-05T10:00:00Z', ...extra
});

describe('SaldosAdminComponent', () => {
  let fixture: ComponentFixture<SaldosAdminComponent>;
  let component: SaldosAdminComponent;
  let servicio: { PAGE_SIZE: number; obtenerSaldoVivienda: jasmine.Spy; listarMovimientos: jasmine.Spy; revertirMovimiento: jasmine.Spy };
  let swal: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const tarjetas = () => Array.from(fixture.nativeElement.querySelectorAll('[data-test="movimiento"]') as NodeListOf<HTMLElement>);

  async function abrir(movimientos: MovimientoSaldo[] = [], total = movimientos.length): Promise<void> {
    servicio.listarMovimientos.and.resolveTo({ items: movimientos, total, pagina: 1, tamanoPagina: 20 });
    fixture = TestBed.createComponent(SaldosAdminComponent);
    component = fixture.componentInstance;
    component.viviendas = [{ id: 3, numeroCasa: '3', tipo: null }];
    fixture.detectChanges();
    component.elegirVivienda(3);
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = {
      PAGE_SIZE: 20,
      obtenerSaldoVivienda: jasmine.createSpy('obtenerSaldoVivienda').and.resolveTo(saldo),
      listarMovimientos: jasmine.createSpy('listarMovimientos'),
      revertirMovimiento: jasmine.createSpy('revertirMovimiento').and.resolveTo({})
    };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({
      imports: [SaldosAdminComponent],
      providers: [{ provide: PagosService, useValue: servicio }]
    });
  });

  it('antes de elegir una vivienda pide que se elija y no consulta nada', () => {
    fixture = TestBed.createComponent(SaldosAdminComponent);
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-test="sin-seleccion"]')).not.toBeNull();
    expect(servicio.obtenerSaldoVivienda).not.toHaveBeenCalled();
  });

  it('al elegir una vivienda muestra su saldo y sus movimientos', async () => {
    await abrir([movimiento('m1', { motivo: 'Excedente del pago de octubre' })]);

    const resumen = (fixture.nativeElement.querySelector('[data-test="saldo"]') as HTMLElement).textContent!.replace(/\s+/g, ' ');
    expect(resumen).toContain('$2,500.00');
    expect(resumen).toContain('$1,000.00');
    expect(resumen).toContain('$300.00');
    expect(servicio.obtenerSaldoVivienda).toHaveBeenCalledWith(3);
    expect(tarjetas().length).toBe(1);
    expect(tarjetas()[0].textContent).toContain('+$50.00');
    expect(tarjetas()[0].textContent).toContain('Abono por excedente');
    expect(tarjetas()[0].textContent).toContain('Excedente del pago de octubre');
  });

  it('una aplicación resta y es la única que se puede revertir', async () => {
    await abrir([
      movimiento('abono'),
      movimiento('aplicacion', { tipo: 'Aplicacion', monto: 200, montoConSigno: -200, cargoId: 'c1' }),
      movimiento('reverso', { tipo: 'ReversoAplicacion', monto: 200, montoConSigno: 200 })
    ]);

    expect(tarjetas()[1].textContent).toContain('−$200.00');
    const revertir = (i: number) => Array.from(tarjetas()[i].querySelectorAll('button')).find(b => b.textContent!.includes('Revertir'));
    expect(revertir(0)).toBeUndefined();
    expect(revertir(1)).toBeDefined();
    expect(revertir(2)).toBeUndefined();
  });

  it('sin monto con signo deduce si suma o resta por el tipo', async () => {
    await abrir([movimiento('a', { tipo: 'ReversoAbono', montoConSigno: null }), movimiento('b', { tipo: 'ReversoAplicacion', montoConSigno: null })]);

    expect(component.signo(component.movimientos()[0])).toBe(-1);
    expect(component.signo(component.movimientos()[1])).toBe(1);
  });

  it('dice que no hay movimientos cuando la vivienda nunca tuvo saldo a favor', async () => {
    await abrir([]);

    expect(fixture.nativeElement.querySelector('[data-test="sin-movimientos"]')).not.toBeNull();
  });

  it('filtrar por tipo vuelve a la primera página sin pedir otra vez el saldo', async () => {
    await abrir([movimiento('m1')], 45);
    await component.irAPagina(2);
    servicio.obtenerSaldoVivienda.calls.reset();

    component.elegirTipo('Aplicacion');
    await fixture.whenStable();

    const [id, pagina, tipo] = servicio.listarMovimientos.calls.mostRecent().args;
    expect([id, pagina, tipo]).toEqual([3, 1, 'Aplicacion']);
    expect(servicio.obtenerSaldoVivienda).not.toHaveBeenCalled();
  });

  it('cambiar de vivienda limpia el filtro y lo que se veía de la anterior', async () => {
    await abrir([movimiento('m1')]);
    component.elegirTipo('Abono');

    component.elegirVivienda(null);

    expect(component.tipo()).toBe('');
    expect(component.saldo()).toBeNull();
    expect(component.movimientos()).toEqual([]);
  });

  describe('revertir', () => {
    it('manda el motivo, recarga el saldo y avisa al encabezado', async () => {
      await abrir([movimiento('aplicacion', { tipo: 'Aplicacion', monto: 200, montoConSigno: -200 })]);
      swal.and.resolveTo({ isConfirmed: true, value: 'Se aplicó al cargo equivocado' } as any);
      const cambio = jasmine.createSpy('cambio');
      component.cambio.subscribe(cambio);
      servicio.obtenerSaldoVivienda.calls.reset();

      await component.revertir(component.movimientos()[0]);

      expect(servicio.revertirMovimiento).toHaveBeenCalledOnceWith('aplicacion', 'Se aplicó al cargo equivocado');
      expect(servicio.obtenerSaldoVivienda).toHaveBeenCalled();
      expect(cambio).toHaveBeenCalled();
    });

    it('el diálogo exige un motivo de al menos 5 caracteres', async () => {
      await abrir([movimiento('aplicacion', { tipo: 'Aplicacion' })]);
      swal.and.resolveTo({ isConfirmed: false } as any);

      await component.revertir(component.movimientos()[0]);

      const opciones = swal.calls.mostRecent().args[0] as any;
      expect(opciones.inputValidator('no')).toContain('al menos 5');
      expect(opciones.inputValidator('Error de captura')).toBeUndefined();
      expect(servicio.revertirMovimiento).not.toHaveBeenCalled();
    });

    it('si el backend rechaza la reversa lo dice y refresca', async () => {
      spyOn(console, 'error');
      await abrir([movimiento('aplicacion', { tipo: 'Aplicacion' })]);
      swal.and.resolveTo({ isConfirmed: true, value: 'Error de captura' } as any);
      servicio.revertirMovimiento.and.rejectWith({ status: 409, error: { error: 'El movimiento ya fue revertido.' } });
      servicio.listarMovimientos.calls.reset();

      await component.revertir(component.movimientos()[0]);

      expect(swal).toHaveBeenCalledWith(jasmine.objectContaining({ icon: 'error', text: 'El movimiento ya fue revertido.' }));
      expect(servicio.listarMovimientos).toHaveBeenCalled();
      expect(component.ocupado()).toBeNull();
    });
  });

  it('si falla la carga muestra el mensaje con un botón para reintentar', async () => {
    spyOn(console, 'error');
    servicio.obtenerSaldoVivienda.and.rejectWith({ status: 404, error: { error: 'No se encontró información de saldo para la vivienda 3.' } });
    servicio.listarMovimientos.and.resolveTo({ items: [], total: 0 });
    fixture = TestBed.createComponent(SaldosAdminComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    component.elegirVivienda(3);
    await fixture.whenStable();
    fixture.detectChanges();

    expect(texto()).toContain('No se encontró información de saldo para la vivienda 3.');
    expect(texto()).toContain('Reintentar');
  });
});
