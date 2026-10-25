import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { PagosAdminComponent } from './pagos-admin.component';
import { PagosService } from '../../../core/services/pagos.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { PlantillasCargoService } from '../../../core/services/plantillas-cargo.service';

describe('PagosAdminComponent', () => {
  let fixture: ComponentFixture<PagosAdminComponent>;
  let component: PagosAdminComponent;
  let pagos: { PAGE_SIZE: number; listarPagos: jasmine.Spy; listarCargos: jasmine.Spy; obtenerSaldoVivienda: jasmine.Spy; listarMovimientos: jasmine.Spy };
  let viviendas: { listar: jasmine.Spy };

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const pestana = (nombre: string) =>
    Array.from(fixture.nativeElement.querySelectorAll('[role="tab"]') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.includes(nombre))!;

  async function abrir(): Promise<void> {
    fixture = TestBed.createComponent(PagosAdminComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    pagos = {
      PAGE_SIZE: 20,
      listarPagos: jasmine.createSpy('listarPagos').and.resolveTo({ items: [], total: 3, pagina: 1, tamanoPagina: 1 }),
      listarCargos: jasmine.createSpy('listarCargos').and.resolveTo({ items: [], total: 0, pagina: 1, tamanoPagina: 20 }),
      obtenerSaldoVivienda: jasmine.createSpy('obtenerSaldoVivienda'),
      listarMovimientos: jasmine.createSpy('listarMovimientos')
    };
    viviendas = { listar: jasmine.createSpy('listar').and.resolveTo([{ id: 3, numeroCasa: '3', tipo: null }]) };
    TestBed.configureTestingModule({
      imports: [PagosAdminComponent],
      providers: [
        provideRouter([]),
        { provide: PagosService, useValue: pagos },
        { provide: ViviendasService, useValue: viviendas },
        { provide: PlantillasCargoService, useValue: { PAGE_SIZE: 20, listar: jasmine.createSpy('listar').and.resolveTo({ items: [], total: 0, pagina: 1, tamanoPagina: 20 }) } }
      ]
    });
  });

  it('abre en Por confirmar y muestra cuántos pagos esperan decisión', async () => {
    await abrir();

    expect(pestana('Por confirmar').getAttribute('aria-selected')).toBe('true');
    expect(fixture.nativeElement.querySelector('[data-test="insignia-por-confirmar"]').textContent).toContain('3');
    expect(fixture.nativeElement.querySelector('app-pagos-admin-lista')).not.toBeNull();
    expect(pagos.listarPagos).toHaveBeenCalledWith({ estado: 'PendienteConfirmacion' }, 1, 1);
  });

  it('sin pagos por confirmar no muestra la insignia', async () => {
    pagos.listarPagos.and.resolveTo({ items: [], total: 0, pagina: 1, tamanoPagina: 1 });

    await abrir();

    expect(fixture.nativeElement.querySelector('[data-test="insignia-por-confirmar"]')).toBeNull();
  });

  it('si falla el conteo la pantalla abre igual, sin insignia', async () => {
    spyOn(console, 'error');
    pagos.listarPagos.and.rejectWith({ status: 503 });

    await abrir();

    expect(component.porConfirmar()).toBe(0);
    expect(texto()).toContain('Pagos y cargos');
  });

  it('cada pestaña muestra su pantalla', async () => {
    await abrir();

    pestana('Cargos').click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-cargos-admin')).not.toBeNull();

    pestana('Plantillas').click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-plantillas-admin')).not.toBeNull();

    pestana('Saldos').click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-saldos-admin')).not.toBeNull();

    pestana('Pagos').click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-pagos-admin-lista')).not.toBeNull();
    expect(texto()).toContain('Historial de pagos');
  });

  it('carga las viviendas una vez para todas las pestañas', async () => {
    await abrir();

    expect(viviendas.listar).toHaveBeenCalledTimes(1);
    expect(component.viviendas().length).toBe(1);
  });

  it('si no cargan las viviendas la pantalla sigue funcionando', async () => {
    spyOn(console, 'error');
    viviendas.listar.and.rejectWith({ status: 500 });

    await abrir();

    expect(component.viviendas()).toEqual([]);
    expect(texto()).toContain('Pagos y cargos');
  });

  it('un cambio en una pestaña vuelve a contar los pagos por confirmar', async () => {
    await abrir();
    pagos.listarPagos.calls.reset();
    pagos.listarPagos.and.resolveTo({ items: [], total: 1, pagina: 1, tamanoPagina: 1 });

    await component.contarPorConfirmar();

    expect(component.porConfirmar()).toBe(1);
  });
});
