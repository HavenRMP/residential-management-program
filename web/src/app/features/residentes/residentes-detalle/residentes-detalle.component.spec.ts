import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ResidentesDetalleComponent } from './residentes-detalle.component';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { SubusuariosService } from '../../../core/services/subusuarios.service';
import { Residente } from '../../../core/models/residente.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { SimpleChange } from '@angular/core';

describe('ResidentesDetalleComponent', () => {
  let component: ResidentesDetalleComponent;
  let fixture: ComponentFixture<ResidentesDetalleComponent>;
  let mockViviendasService: jasmine.SpyObj<ViviendasService>;
  let mockSubusuariosService: jasmine.SpyObj<SubusuariosService>;

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
    mockSubusuariosService = jasmine.createSpyObj('SubusuariosService', ['listarPorVivienda']);
    mockSubusuariosService.listarPorVivienda.and.resolveTo([]);

    await TestBed.configureTestingModule({
      imports: [ResidentesDetalleComponent],
      providers: [
        { provide: ViviendasService, useValue: mockViviendasService },
        { provide: SubusuariosService, useValue: mockSubusuariosService }
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

  it('no debe llamar al servicio si el padre ya suministró una lista de viviendas vacía', async () => {
    component.residente = mockResidente;
    component.viviendas = [];
    await component.ngOnChanges({
      residente: new SimpleChange(null, mockResidente, true)
    });

    expect(mockViviendasService.obtenerViviendasDeResidente).not.toHaveBeenCalled();
  });

  it('debe llamar al servicio si el residente cambia y viviendas es null/undefined', async () => {
    component.residente = mockResidente;
    (component as any).viviendas = null;
    await component.ngOnChanges({
      residente: new SimpleChange(null, mockResidente, true)
    });

    expect(mockViviendasService.obtenerViviendasDeResidente).toHaveBeenCalledWith('res-123');
  });

  describe('residente que es sub-usuario de otra casa', () => {
    const texto = () => (fixture.nativeElement as HTMLElement).textContent!.replace(/\s+/g, ' ');
    const casaDelTitular: Vivienda = { id: 33, numeroCasa: 'PRUEBA-01', tipo: 'Casa', condominioId: 'cond-1' };

    function abrir(propias: Vivienda[], subusuarioDe: Vivienda[]): void {
      component.residente = mockResidente;
      component.viviendas = propias;
      component.subusuarioDe = subusuarioDe;
      component.ngOnChanges({ viviendas: new SimpleChange(null, propias, true) });
      fixture.detectChanges();
    }

    it('muestra su acceso como sub-usuario en lugar del aviso de "sin vivienda"', () => {
      abrir([], [casaDelTitular]);

      expect(texto()).toContain('Acceso como sub-usuario');
      expect(texto()).toContain('PRUEBA-01');
      expect(texto()).toContain('Sub-usuario');
      expect(texto()).not.toContain('Sin vivienda vinculada');
      expect(component.etiquetaViviendas()).toBe('Sub-usuario');
    });

    it('sin vivienda propia ni acceso como sub-usuario conserva el aviso de siempre', () => {
      abrir([], []);

      expect(texto()).toContain('Sin vivienda vinculada');
      expect(texto()).not.toContain('Acceso como sub-usuario');
      expect(component.etiquetaViviendas()).toBe('Sin vivienda');
    });

    it('con vivienda propia la etiqueta cuenta las viviendas y no menciona sub-usuario', () => {
      abrir([mockVivienda], []);

      expect(component.etiquetaViviendas()).toBe('1 vivienda');
      expect(texto()).not.toContain('Acceso como sub-usuario');
    });
  });

  describe('sub-usuarios de la vivienda', () => {
    const acceso = { id: 'sub-1', nombre: 'Luis Prueba', email: 'luis@example.com', telefono: '', parentesco: 'Familiar', activo: true, creadoEn: null };
    const pendiente = { id: 'inv-1', nombre: 'Pendiente', email: 'ana@example.com', telefono: 'Pendiente', parentesco: 'Hijo/a', activo: false, creadoEn: null };
    const texto = () => (fixture.nativeElement as HTMLElement).textContent!.replace(/\s+/g, ' ');

    async function abrir(viviendas: Vivienda[]): Promise<void> {
      component.residente = mockResidente;
      component.viviendas = viviendas;
      component.ngOnChanges({ viviendas: new SimpleChange(null, viviendas, true) });
      // ngOnChanges ya dispara la consulta; se espera a que termine antes de pintar
      await new Promise(resolve => setTimeout(resolve, 0));
      fixture.detectChanges();
    }

    it('lista los sub-usuarios activos y las invitaciones pendientes de la vivienda', async () => {
      mockSubusuariosService.listarPorVivienda.and.resolveTo([acceso, pendiente]);

      await abrir([mockVivienda]);

      expect(mockSubusuariosService.listarPorVivienda).toHaveBeenCalledWith(101);
      expect(texto()).toContain('Sub-usuarios de la vivienda');
      expect(texto()).toContain('Luis Prueba');
      expect(texto()).toContain('luis@example.com');
      expect(texto()).toContain('Activo');
      expect(texto()).toContain('Invitación pendiente');
      expect(texto()).toContain('Invitación enviada');
      expect(texto()).not.toContain('Pendiente ');
    });

    it('avisa cuando la vivienda no tiene sub-usuarios', async () => {
      await abrir([mockVivienda]);

      expect(texto()).toContain('Esta vivienda no tiene sub-usuarios.');
    });

    it('si la consulta falla lo dice sin romper el detalle', async () => {
      spyOn(console, 'error');
      mockSubusuariosService.listarPorVivienda.and.rejectWith({ status: 500 });

      await abrir([mockVivienda]);

      expect(texto()).toContain('No se pudieron cargar los sub-usuarios de esta vivienda.');
      expect(texto()).toContain('Angel Raimond Mendoza');
    });

    it('con varias viviendas muestra cada grupo con su casa y una falla no afecta a las demás', async () => {
      spyOn(console, 'error');
      const otra: Vivienda = { id: 202, numeroCasa: 'Casa 202', tipo: 'Casa', condominioId: 'cond-1' };
      mockSubusuariosService.listarPorVivienda.and.callFake(async (id: number) => {
        if (id === 202) throw { status: 500 };
        return [acceso];
      });

      await abrir([mockVivienda, otra]);

      expect(texto()).toContain('Luis Prueba');
      expect(texto()).toContain('No se pudieron cargar los sub-usuarios de esta vivienda.');
      expect(component.gruposSubusuarios().length).toBe(2);
    });

    it('no vuelve a consultar cuando el padre manda una lista nueva con las mismas viviendas', async () => {
      await abrir([mockVivienda]);
      mockSubusuariosService.listarPorVivienda.calls.reset();

      component.viviendas = [{ ...mockVivienda }];
      component.ngOnChanges({ viviendas: new SimpleChange([mockVivienda], component.viviendas, false) });
      await new Promise(resolve => setTimeout(resolve, 0));

      expect(mockSubusuariosService.listarPorVivienda).not.toHaveBeenCalled();
    });

    it('consulta de nuevo cuando cambian las viviendas', async () => {
      await abrir([mockVivienda]);
      mockSubusuariosService.listarPorVivienda.calls.reset();

      await abrir([{ ...mockVivienda, id: 202, numeroCasa: 'Casa 202' }]);

      expect(mockSubusuariosService.listarPorVivienda).toHaveBeenCalledOnceWith(202);
    });

    it('sin vivienda asignada no muestra la sección ni consulta nada', async () => {
      await abrir([]);

      expect(texto()).not.toContain('Sub-usuarios de la vivienda');
      expect(mockSubusuariosService.listarPorVivienda).not.toHaveBeenCalled();
    });
  });

  it('debe emitir el evento cerrado al hacer click en el botón cerrar o presionar Escape', () => {
    spyOn(component.cerrado, 'emit');

    component.cerrar();
    expect(component.cerrado.emit).toHaveBeenCalledTimes(1);

    component.handleEscape();
    expect(component.cerrado.emit).toHaveBeenCalledTimes(2);
  });
});
