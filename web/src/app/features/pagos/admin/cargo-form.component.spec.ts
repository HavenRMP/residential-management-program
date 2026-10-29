import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { CargoFormComponent } from './cargo-form.component';
import { PagosService } from '../../../core/services/pagos.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { Cargo, SaldoVivienda } from '../../../core/models/pagos.model';
import { ViviendaConResidentes } from '../../../core/models/vivienda.model';

const casas = [{ id: 3, numeroCasa: '3', tipo: null }, { id: 4, numeroCasa: '4', tipo: null }];
const directorioCasas: ViviendaConResidentes[] = [
  {
    id: 3, numeroCasa: '3', tipo: null, totalResidentes: 1, estaOcupada: true,
    residentes: [{ id: 'r1', nombre: 'Ana', apellidos: 'López', telefono: '5512345678' }]
  },
  { id: 4, numeroCasa: '4', tipo: null, totalResidentes: 0, estaOcupada: false, residentes: [] }
];
const saldoCasa3: SaldoVivienda = { viviendaId: 3, numeroCasa: '3', totalPendiente: 1500, totalVencido: 500, totalCargosAbiertos: 2, saldoAFavor: 300 };

describe('CargoFormComponent', () => {
  let fixture: ComponentFixture<CargoFormComponent>;
  let component: CargoFormComponent;
  let servicio: { crearCargo: jasmine.Spy; obtenerSaldoVivienda: jasmine.Spy };
  let directorio: { casas: ReturnType<typeof signal<ViviendaConResidentes[]>>; cargar: jasmine.Spy };

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
    servicio = {
      crearCargo: jasmine.createSpy('crearCargo').and.resolveTo({ id: 'nuevo' } as Cargo),
      obtenerSaldoVivienda: jasmine.createSpy('obtenerSaldoVivienda').and.resolveTo(saldoCasa3)
    };
    directorio = { casas: signal(directorioCasas), cargar: jasmine.createSpy('cargar').and.resolveTo() };
    TestBed.configureTestingModule({
      imports: [CargoFormComponent],
      providers: [
        { provide: PagosService, useValue: servicio },
        { provide: DirectorioCasasService, useValue: directorio }
      ]
    });
  });

  it('propone el periodo del mes en curso y la vivienda indicada', () => {
    abrir(4);

    expect(component.form.viviendaId).toBe(4);
    expect(component.form.periodo).toMatch(/^\d{4}-\d{2}$/);
  });

  it('al elegir una casa muestra quién vive ahí y cuánto debe', async () => {
    abrir();
    expect(campo('selector-vivienda-buscar')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('[data-test="sin-casa"]')).not.toBeNull();

    (fixture.nativeElement.querySelectorAll('[data-test="vivienda"]')[0] as HTMLButtonElement).click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(component.form.viviendaId).toBe(3);
    expect(servicio.obtenerSaldoVivienda).toHaveBeenCalledOnceWith(3);
    const resumen = (fixture.nativeElement.querySelector('[data-test="resumen-casa"]') as HTMLElement).textContent!.replace(/\s+/g, ' ');
    expect(resumen).toContain('Casa 3');
    expect(resumen).toContain('Ana López');
    expect(resumen).toContain('$1,500.00');
    expect(resumen).toContain('$500.00');
  });

  it('con la vivienda propuesta ya consulta su saldo al abrir', () => {
    abrir(3);

    expect(servicio.obtenerSaldoVivienda).toHaveBeenCalledOnceWith(3);
  });

  it('si el saldo no carga deja crear el cargo igual', async () => {
    spyOn(console, 'error');
    servicio.obtenerSaldoVivienda.and.rejectWith({ status: 500 });
    abrir(3);
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-test="saldo-casa"]')).toBeNull();
    expect(fixture.nativeElement.querySelector('[data-test="resumen-casa"]')).not.toBeNull();
  });

  it('si el directorio con residentes no carga lista las viviendas solo por su número', () => {
    directorio.casas.set([]);
    abrir();

    const filas = Array.from(fixture.nativeElement.querySelectorAll('[data-test="vivienda"]') as NodeListOf<HTMLElement>);
    expect(filas.map(f => f.textContent!.replace(/\s+/g, ' ').trim())).toEqual([
      'Casa 3 Sin residentes registrados',
      'Casa 4 Sin residentes registrados'
    ]);
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
