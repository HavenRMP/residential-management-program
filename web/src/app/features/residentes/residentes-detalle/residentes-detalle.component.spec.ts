import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ResidentesDetalleComponent } from './residentes-detalle.component';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { Residente } from '../../../core/models/residente.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { SimpleChange } from '@angular/core';

describe('ResidentesDetalleComponent', () => {
  let component: ResidentesDetalleComponent;
  let fixture: ComponentFixture<ResidentesDetalleComponent>;
  let mockViviendasService: jasmine.SpyObj<ViviendasService>;

  const mockResidente: Residente = {
    id: 'res-123',
    nombre: 'Angel',
    apellidos: 'Raimond Mendoza',
    email: 'angelraimondm@gmail.com',
    telefono: '4423456789',
    rol: 'Residente',
    creadoEn: '2026-09-02T10:00:00Z'
  };

  const mockVivienda: Vivienda = {
    id: 101,
    numeroCasa: 'Casa 105',
    tipo: 'Residencial',
    condominioId: 'cond-1'
  };

  beforeEach(async () => {
    mockViviendasService = jasmine.createSpyObj('ViviendasService', [
      'obtenerViviendasDeResidente'
    ]);
    mockViviendasService.obtenerViviendasDeResidente.and.resolveTo([mockVivienda]);

    await TestBed.configureTestingModule({
      imports: [ResidentesDetalleComponent],
      providers: [
        { provide: ViviendasService, useValue: mockViviendasService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(ResidentesDetalleComponent);
    component = fixture.componentInstance;
  });

  it('debe crear el componente correctamente', () => {
    expect(component).toBeTruthy();
  });

  it('debe mostrar la información básica del residente', () => {
    component.residente = mockResidente;
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('Angel Raimond Mendoza');
    expect(compiled.textContent).toContain('angelraimondm@gmail.com');
    expect(compiled.textContent).toContain('4423456789');
    expect(compiled.textContent).toContain('res-123');
  });

  it('debe mostrar las viviendas asignadas pasadas por input', () => {
    component.residente = mockResidente;
    component.viviendas = [mockVivienda];
    component.ngOnChanges({
      viviendas: new SimpleChange(null, [mockVivienda], true)
    });
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('Casa 105');
    expect(compiled.textContent).toContain('1 vivienda');
    expect(compiled.textContent).toContain('Asignada');
  });

  it('debe mostrar el estado sin vivienda vinculada cuando la lista está vacía', () => {
    component.residente = mockResidente;
    component.viviendas = [];
    component.ngOnChanges({
      viviendas: new SimpleChange(null, [], true)
    });
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('Sin vivienda');
    expect(compiled.textContent).toContain('Sin vivienda vinculada');
  });

  it('debe emitir el evento cerrado al hacer click en el botón cerrar o presionar Escape', () => {
    spyOn(component.cerrado, 'emit');

    component.cerrar();
    expect(component.cerrado.emit).toHaveBeenCalledTimes(1);

    component.handleEscape();
    expect(component.cerrado.emit).toHaveBeenCalledTimes(2);
  });
});
