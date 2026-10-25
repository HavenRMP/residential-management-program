import { ComponentFixture, TestBed } from '@angular/core/testing';
import Swal from 'sweetalert2';
import { ModoListaPagos, PagosAdminListaComponent } from './pagos-admin-lista.component';
import { PagosService } from '../../../core/services/pagos.service';
import { Pago } from '../../../core/models/pagos.model';

const pago = (id: string, extra: Partial<Pago> = {}): Pago => ({
  id, cargoId: 'c1', viviendaId: 3, numeroCasa: '3', cargoTipo: 'Mantenimiento', cargoConcepto: 'Cuota de octubre', monto: 1000,
  montoCubierto: 1000, montoExcedente: 0, fechaPago: '2026-10-05', metodo: 'Transferencia', referencia: 'ABC123', bancoOrigen: 'BBVA',
  estado: 'PendienteConfirmacion', origen: 'Inquilino', tieneComprobante: true, esReversa: false, pagoOriginalId: null,
  motivoRechazo: null, motivoAnulacion: null, creadoEn: '2026-10-05T10:00:00Z', confirmadoEn: null, rechazadoEn: null, anuladoEn: null, ...extra
});

describe('PagosAdminListaComponent', () => {
  let fixture: ComponentFixture<PagosAdminListaComponent>;
  let component: PagosAdminListaComponent;
  let servicio: {
    PAGE_SIZE: number; listarPagos: jasmine.Spy; confirmarPago: jasmine.Spy; rechazarPago: jasmine.Spy;
    anularPago: jasmine.Spy; obtenerUrlComprobante: jasmine.Spy;
  };
  let swal: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const tarjetas = () => Array.from(fixture.nativeElement.querySelectorAll('[data-test="pago"]') as NodeListOf<HTMLElement>);
  const botonDe = (tarjeta: HTMLElement, nombre: string) =>
    Array.from(tarjeta.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.trim() === nombre);

  async function abrir(modo: ModoListaPagos, items: Pago[], total = items.length): Promise<void> {
    servicio.listarPagos.and.resolveTo({ items, total, pagina: 1, tamanoPagina: 20 });
    fixture = TestBed.createComponent(PagosAdminListaComponent);
    component = fixture.componentInstance;
    component.modo = modo;
    component.viviendas = [{ id: 3, numeroCasa: '3', tipo: null }];
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = {
      PAGE_SIZE: 20,
      listarPagos: jasmine.createSpy('listarPagos'),
      confirmarPago: jasmine.createSpy('confirmarPago').and.resolveTo({ pago: pago('p1', { estado: 'Confirmado' }), cargo: {}, saldoAFavor: 0 }),
      rechazarPago: jasmine.createSpy('rechazarPago').and.resolveTo(pago('p1', { estado: 'Rechazado' })),
      anularPago: jasmine.createSpy('anularPago').and.resolveTo({}),
      obtenerUrlComprobante: jasmine.createSpy('obtenerUrlComprobante').and.resolveTo('https://storage/firmada')
    };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({
      imports: [PagosAdminListaComponent],
      providers: [{ provide: PagosService, useValue: servicio }]
    });
  });

  describe('por confirmar', () => {
    it('pide solo los pagos que esperan decisión y ofrece confirmarlos o rechazarlos', async () => {
      await abrir('por-confirmar', [pago('p1')]);

      expect(servicio.listarPagos.calls.mostRecent().args[0]).toEqual({ estado: 'PendienteConfirmacion' });
      expect(fixture.nativeElement.querySelector('[data-test="filtros"]')).toBeNull();
      expect(botonDe(tarjetas()[0], 'Confirmar')).toBeDefined();
      expect(botonDe(tarjetas()[0], 'Rechazar')).toBeDefined();
      expect(botonDe(tarjetas()[0], 'Anular')).toBeUndefined();
      expect(texto()).toContain('Reportado por el residente');
    });

    it('sin pagos pendientes lo dice', async () => {
      await abrir('por-confirmar', []);

      expect(texto()).toContain('No hay pagos por confirmar');
    });

    it('confirmar pide confirmación, llama al servicio, recarga y avisa al encabezado', async () => {
      await abrir('por-confirmar', [pago('p1')]);
      const cambio = jasmine.createSpy('cambio');
      component.cambio.subscribe(cambio);
      servicio.listarPagos.calls.reset();

      botonDe(tarjetas()[0], 'Confirmar')!.click();
      await fixture.whenStable();

      expect(servicio.confirmarPago).toHaveBeenCalledOnceWith('p1');
      expect(servicio.listarPagos).toHaveBeenCalled();
      expect(cambio).toHaveBeenCalled();
      expect(swal).toHaveBeenCalledWith(jasmine.objectContaining({ toast: true, icon: 'success', title: 'Pago confirmado' }));
    });

    it('si el administrador se arrepiente al confirmar no pasa nada', async () => {
      await abrir('por-confirmar', [pago('p1')]);
      swal.and.resolveTo({ isConfirmed: false } as any);

      await component.confirmar(component.items()[0]);

      expect(servicio.confirmarPago).not.toHaveBeenCalled();
    });

    it('rechazar manda el motivo que escribió', async () => {
      await abrir('por-confirmar', [pago('p1')]);
      swal.and.resolveTo({ isConfirmed: true, value: 'Comprobante ilegible' } as any);

      await component.rechazar(component.items()[0]);

      expect(servicio.rechazarPago).toHaveBeenCalledOnceWith('p1', 'Comprobante ilegible');
    });

    it('el diálogo de rechazo exige un motivo de al menos 5 caracteres', async () => {
      await abrir('por-confirmar', [pago('p1')]);
      swal.and.resolveTo({ isConfirmed: false } as any);

      await component.rechazar(component.items()[0]);

      const opciones = swal.calls.mostRecent().args[0] as any;
      expect(opciones.inputValidator('abc')).toContain('al menos 5');
      expect(opciones.inputValidator('Comprobante ilegible')).toBeUndefined();
      expect(servicio.rechazarPago).not.toHaveBeenCalled();
    });

    it('si el servicio falla avisa y de todos modos refresca la lista', async () => {
      spyOn(console, 'error');
      await abrir('por-confirmar', [pago('p1')]);
      servicio.confirmarPago.and.rejectWith({ status: 409, error: { error: 'El pago ya fue procesado' } });
      servicio.listarPagos.calls.reset();

      await component.confirmar(component.items()[0]);

      expect(swal).toHaveBeenCalledWith(jasmine.objectContaining({ icon: 'error', title: 'No se pudo confirmar el pago', text: 'El pago ya fue procesado' }));
      expect(servicio.listarPagos).toHaveBeenCalled();
      expect(component.ocupado()).toBeNull();
    });
  });

  describe('historial', () => {
    it('muestra los filtros y solo permite anular un pago confirmado', async () => {
      await abrir('historial', [
        pago('p1', { estado: 'Confirmado' }),
        pago('p2', { estado: 'Rechazado', motivoRechazo: 'Borroso' }),
        pago('p3', { estado: 'Confirmado', esReversa: true })
      ]);

      expect(fixture.nativeElement.querySelector('[data-test="filtros"]')).not.toBeNull();
      expect(botonDe(tarjetas()[0], 'Anular')).toBeDefined();
      expect(botonDe(tarjetas()[1], 'Anular')).toBeUndefined();
      expect(tarjetas()[1].textContent).toContain('Rechazado: Borroso');
      expect(botonDe(tarjetas()[2], 'Anular')).toBeUndefined();
      expect(botonDe(tarjetas()[0], 'Confirmar')).toBeUndefined();
    });

    it('al cambiar un filtro vuelve a la primera página con ese filtro', async () => {
      await abrir('historial', [pago('p1', { estado: 'Confirmado' })], 45);
      await component.irAPagina(2);
      expect(component.pagina()).toBe(2);

      component.filtros.estado = 'Confirmado';
      component.filtros.viviendaId = 3;
      component.aplicarFiltros();
      await fixture.whenStable();

      const [filtros, pagina] = servicio.listarPagos.calls.mostRecent().args;
      expect(filtros).toEqual(jasmine.objectContaining({ estado: 'Confirmado', viviendaId: 3 }));
      expect(pagina).toBe(1);
    });

    it('no consulta si la fecha inicial es posterior a la final', async () => {
      await abrir('historial', [pago('p1')]);
      servicio.listarPagos.calls.reset();

      component.filtros.desde = '2026-10-20';
      component.filtros.hasta = '2026-10-01';
      component.aplicarFiltros();
      fixture.detectChanges();

      expect(servicio.listarPagos).not.toHaveBeenCalled();
      expect(texto()).toContain('no puede ser posterior');
    });

    it('anular exige motivo y manda el que escribió', async () => {
      await abrir('historial', [pago('p1', { estado: 'Confirmado' })]);
      swal.and.resolveTo({ isConfirmed: true, value: 'Pago duplicado' } as any);

      await component.anular(component.items()[0]);

      expect(servicio.anularPago).toHaveBeenCalledOnceWith('p1', 'Pago duplicado');
    });

    it('pagina con Anterior y Siguiente según el total', async () => {
      await abrir('historial', [pago('p1')], 45);

      expect(component.totalPaginas()).toBe(3);
      expect(texto()).toContain('45 pagos · Página 1 de 3');

      await component.irAPagina(2);
      expect(servicio.listarPagos.calls.mostRecent().args[1]).toBe(2);

      await component.irAPagina(9);
      expect(servicio.listarPagos.calls.mostRecent().args[1]).toBe(2);
    });
  });

  it('abre el comprobante con el enlace temporal del pago', async () => {
    const pestana = { opener: null, location: { href: '' }, close: jasmine.createSpy('close') };
    spyOn(window, 'open').and.returnValue(pestana as unknown as Window);
    await abrir('por-confirmar', [pago('p1')]);

    await component.verComprobante(component.items()[0]);

    expect(servicio.obtenerUrlComprobante).toHaveBeenCalledWith('p1');
    expect(pestana.location.href).toBe('https://storage/firmada');
  });

  it('si falla la carga muestra el mensaje con un botón para reintentar', async () => {
    spyOn(console, 'error');
    servicio.listarPagos.and.rejectWith({ status: 503 });
    fixture = TestBed.createComponent(PagosAdminListaComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(texto()).toContain('No se pudieron cargar los pagos');
    expect(texto()).toContain('Reintentar');
  });
});
