import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { signal } from '@angular/core';
import { of, throwError } from 'rxjs';
import Swal from 'sweetalert2';
import { PagosComponent } from './pagos.component';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';

const cargoCrudo = (id: string, extra: Record<string, unknown> = {}) => ({
  id, vivienda_id: 3, numero_casa: '3', tipo: 'Mantenimiento', concepto: `Cuota ${id}`, monto: 1000,
  monto_pagado_confirmado: 0, saldo_pendiente: 1000, estado: 'Pendiente', estado_efectivo: 'Pendiente',
  fecha_vencimiento: '2026-10-10', responsable_pago: 'Residente', creado_en: '2026-10-01T00:00:00Z', ...extra
});

const pagoCrudo = (id: string, extra: Record<string, unknown> = {}) => ({
  id, cargo_id: 'a', vivienda_id: 3, numero_casa: '3', cargo_tipo: 'Mantenimiento', cargo_concepto: 'Cuota a', monto: 1000,
  monto_cubierto: 1000, monto_excedente: 0, fecha_pago: '2026-10-05', metodo: 'Transferencia', estado: 'PendienteConfirmacion',
  origen: 'Inquilino', tiene_comprobante: true, es_reversa: false, creado_en: '2026-10-05T10:00:00Z', ...extra
});

const saldo = { total_pendiente: 2500, total_vencido: 1000, total_cargos_abiertos: 2, saldo_a_favor: 75, viviendas: [] };

describe('PagosComponent', () => {
  let fixture: ComponentFixture<PagosComponent>;
  let component: PagosComponent;
  let api: jasmine.SpyObj<ApiService>;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const cargos = () => Array.from(fixture.nativeElement.querySelectorAll('[data-test="cargo"]') as NodeListOf<HTMLElement>);
  const boton = (nombre: string) =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.includes(nombre));

  async function abrir(datos: { cargos?: any[]; pagos?: any[] } = {}): Promise<void> {
    const listaCargos = datos.cargos ?? [];
    const listaPagos = datos.pagos ?? [];
    api.get.and.callFake(((url: string) => {
      if (url === '/api/saldos/mi-saldo') return of(saldo);
      if (url === '/api/cargos') return of({ items: listaCargos, total: listaCargos.length });
      if (url === '/api/pagos') return of({ items: listaPagos, total: listaPagos.length });
      return throwError(() => ({ status: 404 }));
    }) as any);
    fixture = TestBed.createComponent(PagosComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post']);
    spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({
      imports: [PagosComponent],
      providers: [
        provideRouter([]),
        { provide: ApiService, useValue: api },
        { provide: AuthService, useValue: { currentUser: signal({ id: 'u1', nombre: 'Angel', rol: 'residente' }), logout: () => undefined } }
      ]
    });
  });

  it('muestra el resumen de la cuenta con el saldo a favor y lo vencido', async () => {
    await abrir({ cargos: [cargoCrudo('a')] });

    const resumen = (fixture.nativeElement.querySelector('[data-test="resumen"]') as HTMLElement).textContent!.replace(/\s+/g, ' ');
    expect(resumen).toContain('2,500.00');
    expect(resumen).toContain('1,000.00');
    expect(resumen).toContain('75.00');
  });

  it('lista primero los cargos que vencen antes y deja los pagados en el historial', async () => {
    await abrir({
      cargos: [
        cargoCrudo('tarde', { fecha_vencimiento: '2026-11-10' }),
        cargoCrudo('pronto', { fecha_vencimiento: '2026-10-01', estado_efectivo: 'Vencido' }),
        cargoCrudo('listo', { estado: 'Pagado', estado_efectivo: 'Pagado', saldo_pendiente: 0, monto_pagado_confirmado: 1000 })
      ]
    });

    expect(cargos().map(c => c.querySelector('p')!.textContent!.trim())).toEqual(['Cuota pronto', 'Cuota tarde']);
    expect(cargos()[0].textContent).toContain('Vencido');
    expect(texto()).toContain('Por pagar (2)');
    expect(texto()).toContain('Historial de cargos (1)');

    boton('Historial de cargos')!.click();
    fixture.detectChanges();

    expect(cargos().length).toBe(1);
    expect(cargos()[0].textContent).toContain('Cuota listo');
    expect(cargos()[0].textContent).not.toContain('Reportar pago');
  });

  it('dice que no hay cargos cuando la cuenta está al corriente', async () => {
    await abrir();

    expect(fixture.nativeElement.querySelector('[data-test="sin-cargos"]')).not.toBeNull();
    expect(texto()).toContain('No tienes cargos por pagar');
  });

  it('avisa de los pagos que esperan confirmación y lo marca en su cargo', async () => {
    await abrir({ cargos: [cargoCrudo('a')], pagos: [pagoCrudo('p1')] });

    expect(fixture.nativeElement.querySelector('[data-test="aviso-por-confirmar"]').textContent).toContain('Tienes 1 pago por confirmar');
    expect(cargos()[0].textContent).toContain('esperando confirmación');
  });

  it('reportar un pago abre el formulario del cargo, solo si el cargo admite pago', async () => {
    await abrir({ cargos: [cargoCrudo('a')] });
    expect(fixture.nativeElement.querySelector('app-pago-form')).toBeNull();

    boton('Reportar pago')!.click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-pago-form')).not.toBeNull();
    expect(component.cargoPagando()?.id).toBe('a');
    expect(texto()).toContain('Reportar un pago');
  });

  it('al guardar el reporte cierra el formulario, cambia a Mis pagos y recarga', async () => {
    await abrir({ cargos: [cargoCrudo('a')] });
    component.abrirPago(component.porPagar()[0]);
    api.get.calls.reset();

    await component.alReportar();
    fixture.detectChanges();

    expect(component.cargoPagando()).toBeNull();
    expect(component.pestana()).toBe('pagos');
    expect(api.get).toHaveBeenCalledWith('/api/saldos/mi-saldo', undefined, undefined, 'pagos');
  });

  it('Mis pagos muestra el motivo del rechazo y el excedente que pasó a saldo a favor', async () => {
    await abrir({
      cargos: [cargoCrudo('a')],
      pagos: [pagoCrudo('p1', { estado: 'Rechazado', motivo_rechazo: 'Comprobante borroso' }), pagoCrudo('p2', { estado: 'Confirmado', monto_excedente: 50 })]
    });

    boton('Mis pagos')!.click();
    fixture.detectChanges();

    expect(texto()).toContain('Rechazado: Comprobante borroso');
    expect(texto()).toContain('50.00 pasaron a tu saldo a favor');
  });

  it('abre los pagos de un cargo y los oculta al volver a pulsar', async () => {
    await abrir({ cargos: [cargoCrudo('a')] });
    api.get.and.returnValue(of({
      ...cargoCrudo('a'),
      pagos: [{ id: 'p1', monto: 400, monto_cubierto: 400, monto_excedente: 0, fecha_pago: '2026-10-05', metodo: 'Efectivo', estado: 'Confirmado', origen: 'Admin', tiene_comprobante: false, es_reversa: false }]
    }));

    boton('Ver pagos')!.click();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-test="detalle-cargo"]').textContent).toContain('400.00');

    boton('Ocultar pagos')!.click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-test="detalle-cargo"]')).toBeNull();
  });

  it('si no se pueden cargar los pagos de un cargo lo dice dentro de ese cargo', async () => {
    spyOn(console, 'error');
    await abrir({ cargos: [cargoCrudo('a')] });
    api.get.and.returnValue(throwError(() => ({ status: 500 })));

    boton('Ver pagos')!.click();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-test="detalle-cargo"]').textContent).toContain('No se pudieron cargar los pagos de este cargo');
  });

  it('si falla abrir el comprobante avisa sin dejar una pestaña vacía', async () => {
    spyOn(console, 'error');
    const pestana = { opener: null, location: { href: '' }, close: jasmine.createSpy('close') };
    spyOn(window, 'open').and.returnValue(pestana as unknown as Window);
    await abrir({ cargos: [cargoCrudo('a')], pagos: [pagoCrudo('p1')] });
    api.get.and.returnValue(throwError(() => ({ status: 404, error: { error: 'Comprobante no encontrado.' } })));

    await component.verComprobante(component.pagos()[0]);

    expect(pestana.close).toHaveBeenCalled();
    expect(Swal.fire).toHaveBeenCalledWith(jasmine.objectContaining({ icon: 'error', text: 'Comprobante no encontrado.' }));
  });

  it('muestra el error de la carga con un botón para reintentar', async () => {
    spyOn(console, 'error');
    api.get.and.returnValue(throwError(() => ({ status: 503 })));
    fixture = TestBed.createComponent(PagosComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(texto()).toContain('No se pudieron cargar tus pagos');
    expect(boton('Reintentar')).toBeDefined();
  });
});
