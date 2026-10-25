import { ComponentFixture, TestBed } from '@angular/core/testing';
import { CargoPagosComponent } from './cargo-pagos.component';
import { PagosService } from '../../../core/services/pagos.service';
import { CargoDetalle, PagoResumen } from '../../../core/models/pagos.model';

const pago = (id: string, extra: Partial<PagoResumen> = {}): PagoResumen => ({
  id, monto: 400, montoCubierto: 400, montoExcedente: 0, fechaPago: '2026-10-05', metodo: 'Efectivo', referencia: null,
  estado: 'Confirmado', origen: 'Admin', tieneComprobante: false, esReversa: false, pagoOriginalId: null, ...extra
});

describe('CargoPagosComponent', () => {
  let fixture: ComponentFixture<CargoPagosComponent>;
  let servicio: { obtenerCargo: jasmine.Spy };

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');

  async function abrir(): Promise<void> {
    fixture = TestBed.createComponent(CargoPagosComponent);
    fixture.componentRef.setInput('cargoId', 'c1');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = { obtenerCargo: jasmine.createSpy('obtenerCargo') };
    TestBed.configureTestingModule({
      imports: [CargoPagosComponent],
      providers: [{ provide: PagosService, useValue: servicio }]
    });
  });

  it('consulta el cargo y lista sus pagos con su estado', async () => {
    servicio.obtenerCargo.and.resolveTo({ pagos: [pago('p1'), pago('p2', { estado: 'Anulado', esReversa: true })] } as CargoDetalle);

    await abrir();

    expect(servicio.obtenerCargo).toHaveBeenCalledOnceWith('c1');
    expect(texto()).toContain('$400.00');
    expect(texto()).toContain('Confirmado');
    expect(texto()).toContain('Anulado');
    expect(texto()).toContain('(reversa)');
  });

  it('dice que el cargo no tiene pagos cuando la lista viene vacía', async () => {
    servicio.obtenerCargo.and.resolveTo({ pagos: [] } as unknown as CargoDetalle);

    await abrir();

    expect(texto()).toContain('Este cargo todavía no tiene pagos');
  });

  it('si falla la consulta lo dice y deja de cargar', async () => {
    spyOn(console, 'error');
    servicio.obtenerCargo.and.rejectWith({ status: 500 });

    await abrir();

    expect(texto()).toContain('No se pudieron cargar los pagos de este cargo');
    expect(texto()).not.toContain('Cargando pagos');
  });
});
