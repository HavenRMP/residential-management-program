import { ComponentFixture, TestBed } from '@angular/core/testing';
import { CargoFormComponent } from './cargo-form.component';
import { PagosService } from '../../../core/services/pagos.service';
import { Cargo } from '../../../core/models/pagos.model';

const casas = [{ id: 3, numeroCasa: '3', tipo: null }, { id: 4, numeroCasa: '4', tipo: null }];

describe('CargoFormComponent', () => {
  let fixture: ComponentFixture<CargoFormComponent>;
  let component: CargoFormComponent;
  let servicio: { crearCargo: jasmine.Spy };

  const campo = (id: string) => fixture.nativeElement.querySelector('#' + id) as HTMLElement | null;
  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');

  function abrir(viviendaInicial: number | null = null): void {
    fixture = TestBed.createComponent(CargoFormComponent);
    component = fixture.componentInstance;
    component.viviendas = casas;
    component.viviendaInicial = viviendaInicial;
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = { crearCargo: jasmine.createSpy('crearCargo').and.resolveTo({ id: 'nuevo' } as Cargo) };
    TestBed.configureTestingModule({
      imports: [CargoFormComponent],
      providers: [{ provide: PagosService, useValue: servicio }]
    });
  });

  it('propone el periodo del mes en curso y la vivienda indicada', () => {
    abrir(4);

    expect(component.form.viviendaId).toBe(4);
    expect(component.form.periodo).toMatch(/^\d{4}-\d{2}$/);
  });

  it('marca el periodo como obligatorio solo en renta y mantenimiento', () => {
    abrir();
    expect(texto()).toContain('Periodo *');

    component.form.tipo = 'Multa';
    fixture.detectChanges();

    expect(texto()).toContain('Periodo (opcional)');
    expect(campo('cargo-periodo')).not.toBeNull();
  });

  it('no llama al servicio con datos incompletos y dice qué falta', async () => {
    abrir();

    await component.guardar();
    expect(component.error()).toContain('vivienda');

    component.form.viviendaId = 3;
    await component.guardar();
    expect(component.error()).toContain('concepto');
    expect(servicio.crearCargo).not.toHaveBeenCalled();
  });

  it('crea el cargo con los datos del formulario y avisa que quedó guardado', async () => {
    abrir(3);
    const guardado = jasmine.createSpy('guardado');
    component.guardado.subscribe(guardado);
    component.form.tipo = 'Multa';
    component.form.concepto = 'Ruido excesivo';
    component.form.monto = 300;
    component.form.periodo = '';
    component.form.fechaVencimiento = '2026-11-15';
    component.responsable = 'Propietario';

    await component.guardar();

    expect(servicio.crearCargo).toHaveBeenCalledOnceWith({
      viviendaId: 3, tipo: 'Multa', concepto: 'Ruido excesivo', monto: 300, periodo: null, fechaVencimiento: '2026-11-15', responsablePago: 'Propietario'
    });
    expect(guardado).toHaveBeenCalledOnceWith({ id: 'nuevo' } as Cargo);
    expect(component.isSaving()).toBeFalse();
  });

  it('si el backend rechaza el cargo muestra su mensaje y deja intentar de nuevo', async () => {
    spyOn(console, 'error');
    abrir(3);
    component.form.concepto = 'Cuota';
    component.form.monto = 500;
    component.form.fechaVencimiento = '2026-11-15';
    servicio.crearCargo.and.rejectWith({ status: 400, error: { error: 'El periodo es obligatorio para cargos de tipo Mantenimiento.' } });

    await component.guardar();

    expect(component.error()).toBe('El periodo es obligatorio para cargos de tipo Mantenimiento.');
    expect(component.isSaving()).toBeFalse();
  });
});
