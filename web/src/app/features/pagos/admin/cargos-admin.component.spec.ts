import { ComponentFixture, TestBed } from '@angular/core/testing';
import Swal from 'sweetalert2';
import { CargosAdminComponent } from './cargos-admin.component';
import { PagosService } from '../../../core/services/pagos.service';
import { Cargo } from '../../../core/models/pagos.model';

const cargo = (id: string, extra: Partial<Cargo> = {}): Cargo => ({
  id, viviendaId: 3, numeroCasa: '3', plantillaId: null, periodo: '2026-10', tipo: 'Mantenimiento', concepto: `Cuota ${id}`,
  monto: 1000, montoPagadoConfirmado: 0, saldoPendiente: 1000, estado: 'Pendiente', estadoEfectivo: 'Pendiente',
  fechaVencimiento: '2026-10-10', responsablePago: 'Residente', motivoCancelacion: null, creadoEn: '2026-10-01T00:00:00Z', ...extra
});

describe('CargosAdminComponent', () => {
  let fixture: ComponentFixture<CargosAdminComponent>;
  let component: CargosAdminComponent;
  let servicio: {
    PAGE_SIZE: number; listarCargos: jasmine.Spy; cancelarCargo: jasmine.Spy; aplicarSaldo: jasmine.Spy; obtenerSaldoVivienda: jasmine.Spy; obtenerCargo: jasmine.Spy;
  };
  let swal: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const tarjetas = () => Array.from(fixture.nativeElement.querySelectorAll('[data-test="cargo"]') as NodeListOf<HTMLElement>);
  const botonDe = (tarjeta: HTMLElement, nombre: string) =>
    Array.from(tarjeta.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.trim() === nombre);

  async function abrir(items: Cargo[], total = items.length): Promise<void> {
    servicio.listarCargos.and.resolveTo({ items, total, pagina: 1, tamanoPagina: 20 });
    fixture = TestBed.createComponent(CargosAdminComponent);
    component = fixture.componentInstance;
    component.viviendas = [{ id: 3, numeroCasa: '3', tipo: null }];
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = {
      PAGE_SIZE: 20,
      listarCargos: jasmine.createSpy('listarCargos'),
      cancelarCargo: jasmine.createSpy('cancelarCargo').and.resolveTo(cargo('c1', { estado: 'Cancelado' })),
      aplicarSaldo: jasmine.createSpy('aplicarSaldo').and.resolveTo({}),
      obtenerSaldoVivienda: jasmine.createSpy('obtenerSaldoVivienda').and.resolveTo({ saldoAFavor: 300 }),
      obtenerCargo: jasmine.createSpy('obtenerCargo').and.resolveTo({ pagos: [] })
    };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({
      imports: [CargosAdminComponent],
      providers: [{ provide: PagosService, useValue: servicio }]
    });
  });

  it('lista los cargos con su casa, estado y saldo', async () => {
    await abrir([cargo('c1'), cargo('c2', { estadoEfectivo: 'Vencido', saldoPendiente: 400 })]);

    expect(tarjetas().length).toBe(2);
    expect(tarjetas()[0].textContent).toContain('Casa 3');
    expect(tarjetas()[1].textContent).toContain('Vencido');
    expect(tarjetas()[1].textContent).toContain('$400.00');
  });

  it('un cargo abierto ofrece pago, saldo a favor y cancelar; uno pagado o cancelado solo ver pagos', async () => {
    await abrir([
      cargo('abierto'),
      cargo('pagado', { estado: 'Pagado', estadoEfectivo: 'Pagado', saldoPendiente: 0 }),
      cargo('cancelado', { estado: 'Cancelado', estadoEfectivo: 'Cancelado', motivoCancelacion: 'Error de captura' })
    ]);

    expect(botonDe(tarjetas()[0], 'Registrar pago')).toBeDefined();
    expect(botonDe(tarjetas()[0], 'Aplicar saldo a favor')).toBeDefined();
    expect(botonDe(tarjetas()[0], 'Cancelar cargo')).toBeDefined();
    for (const i of [1, 2]) {
      expect(botonDe(tarjetas()[i], 'Registrar pago')).toBeUndefined();
      expect(botonDe(tarjetas()[i], 'Cancelar cargo')).toBeUndefined();
      expect(botonDe(tarjetas()[i], 'Ver pagos')).toBeDefined();
    }
    expect(tarjetas()[2].textContent).toContain('Cancelado: Error de captura');
  });

  it('filtra por vivienda, estado y solo vencidos y vuelve a la primera página', async () => {
    await abrir([cargo('c1')], 45);
    await component.irAPagina(2);
    expect(component.pagina()).toBe(2);

    component.filtros.viviendaId = 3;
    component.filtros.estado = 'Parcial';
    component.soloVencidos = true;
    component.aplicarFiltros();
    await fixture.whenStable();

    const [filtros, pagina] = servicio.listarCargos.calls.mostRecent().args;
    expect(filtros).toEqual(jasmine.objectContaining({ viviendaId: 3, estado: 'Parcial', vencido: true }));
    expect(pagina).toBe(1);
  });

  it('sin el filtro de vencidos no manda el parámetro', async () => {
    await abrir([cargo('c1')]);

    expect(servicio.listarCargos.calls.mostRecent().args[0].vencido).toBeNull();
  });

  it('dice que no hay cargos cuando la lista viene vacía', async () => {
    await abrir([]);

    expect(fixture.nativeElement.querySelector('[data-test="sin-cargos"]')).not.toBeNull();
  });

  it('registrar pago abre el formulario del administrador para ese cargo', async () => {
    await abrir([cargo('c1')]);

    botonDe(tarjetas()[0], 'Registrar pago')!.click();
    fixture.detectChanges();

    expect(component.cargoPagando()?.id).toBe('c1');
    expect(fixture.nativeElement.querySelector('app-pago-form')).not.toBeNull();
    expect(texto()).toContain('Registrar un pago');
  });

  it('nuevo cargo abre el formulario con la vivienda del filtro', async () => {
    await abrir([cargo('c1')]);
    component.filtros.viviendaId = 3;

    (Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.includes('Nuevo cargo')))!.click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-cargo-form')).not.toBeNull();
  });

  it('al registrar un pago cierra el formulario, recarga la página actual y avisa al encabezado', async () => {
    await abrir([cargo('c1')], 45);
    await component.irAPagina(2);
    const cambio = jasmine.createSpy('cambio');
    component.cambio.subscribe(cambio);
    component.cargoPagando.set(component.items()[0]);
    servicio.listarCargos.calls.reset();

    await component.alRegistrarPago();

    expect(component.cargoPagando()).toBeNull();
    expect(servicio.listarCargos.calls.mostRecent().args[1]).toBe(2);
    expect(cambio).toHaveBeenCalled();
  });

  it('cancelar manda el motivo que escribió y recarga', async () => {
    await abrir([cargo('c1')]);
    swal.and.resolveTo({ isConfirmed: true, value: 'Cargo duplicado' } as any);
    servicio.listarCargos.calls.reset();

    await component.cancelar(component.items()[0]);

    expect(servicio.cancelarCargo).toHaveBeenCalledOnceWith('c1', 'Cargo duplicado');
    expect(servicio.listarCargos).toHaveBeenCalled();
  });

  it('si el administrador se arrepiente al cancelar no pasa nada', async () => {
    await abrir([cargo('c1')]);
    swal.and.resolveTo({ isConfirmed: false } as any);

    await component.cancelar(component.items()[0]);

    expect(servicio.cancelarCargo).not.toHaveBeenCalled();
  });

  describe('aplicar saldo a favor', () => {
    it('propone el menor entre el saldo a favor y lo que debe el cargo', async () => {
      await abrir([cargo('c1', { saldoPendiente: 1000 })]);
      swal.and.resolveTo({ isConfirmed: false } as any);

      await component.aplicarSaldo(component.items()[0]);

      const opciones = swal.calls.mostRecent().args[0] as any;
      expect(servicio.obtenerSaldoVivienda).toHaveBeenCalledWith(3);
      expect(opciones.inputValue).toBe(300);
      expect(opciones.inputAttributes.max).toBe('300');
      expect(opciones.inputValidator('0')).toContain('mayor a cero');
      expect(opciones.inputValidator('300.555')).toContain('decimales');
      expect(opciones.inputValidator('301')).toContain('No puedes aplicar más de');
      expect(opciones.inputValidator('150.50')).toBeUndefined();
    });

    it('aplica el monto elegido', async () => {
      await abrir([cargo('c1')]);
      swal.and.callFake((async (opciones: any) => (opciones.input === 'number' ? { isConfirmed: true, value: '120.5' } : { isConfirmed: true })) as any);

      await component.aplicarSaldo(component.items()[0]);

      expect(servicio.aplicarSaldo).toHaveBeenCalledOnceWith('c1', 120.5);
    });

    it('si la vivienda no tiene saldo a favor lo avisa y no pide monto', async () => {
      await abrir([cargo('c1')]);
      servicio.obtenerSaldoVivienda.and.resolveTo({ saldoAFavor: 0 });

      await component.aplicarSaldo(component.items()[0]);

      expect(swal).toHaveBeenCalledWith(jasmine.objectContaining({ icon: 'info', title: 'Sin saldo a favor' }));
      expect(servicio.aplicarSaldo).not.toHaveBeenCalled();
    });

    it('si no se puede consultar el saldo avisa del error', async () => {
      spyOn(console, 'error');
      await abrir([cargo('c1')]);
      servicio.obtenerSaldoVivienda.and.rejectWith({ status: 500 });

      await component.aplicarSaldo(component.items()[0]);

      expect(swal).toHaveBeenCalledWith(jasmine.objectContaining({ icon: 'error', title: 'No se pudo consultar el saldo a favor' }));
    });
  });

  it('despliega y oculta los pagos de un cargo', async () => {
    await abrir([cargo('c1')]);

    botonDe(tarjetas()[0], 'Ver pagos')!.click();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-cargo-pagos')).not.toBeNull();

    botonDe(tarjetas()[0], 'Ocultar pagos')!.click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-cargo-pagos')).toBeNull();
  });

  it('si falla la carga muestra el mensaje con un botón para reintentar', async () => {
    spyOn(console, 'error');
    servicio.listarCargos.and.rejectWith({ status: 503 });
    fixture = TestBed.createComponent(CargosAdminComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(texto()).toContain('No se pudieron cargar los cargos');
    expect(texto()).toContain('Reintentar');
  });
});
