import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ResidentesDetalleComponent } from './residentes-detalle.component';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { SubusuariosService } from '../../../core/services/subusuarios.service';
import { Residente } from '../../../core/models/residente.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { SimpleChange } from '@angular/core';
import Swal from 'sweetalert2';

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
      'obtenerViviendasDeResidente',
      'desvincularResidente'
    ]);
    mockViviendasService.desvincularResidente.and.resolveTo();
    mockViviendasService.obtenerViviendasDeResidente.and.resolveTo([mockVivienda]);
    mockSubusuariosService = jasmine.createSpyObj('SubusuariosService', ['listarPorVivienda'], { MAX_SUBUSUARIOS: 2 });
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

  describe('desvincular de una vivienda', () => {
    const texto = () => (fixture.nativeElement as HTMLElement).textContent!.replace(/\s+/g, ' ');
    const boton = () => fixture.nativeElement.querySelector('button[aria-label^="Desvincular"]') as HTMLButtonElement | null;
    let swal: jasmine.Spy;

    function abrir(): void {
      component.residente = mockResidente;
      component.viviendas = [mockVivienda];
      component.ngOnChanges({ viviendas: new SimpleChange(null, [mockVivienda], true) });
      fixture.detectChanges();
    }

    beforeEach(() => {
      swal = spyOn(Swal, 'fire').and.callFake(((o: any) => Promise.resolve({ isConfirmed: !o.toast && o.showCancelButton === true })) as any);
    });

    it('cada vivienda asignada trae su botón Desvincular', () => {
      abrir();

      expect(boton()).not.toBeNull();
      expect(boton()!.getAttribute('aria-label')).toBe('Desvincular a Angel de Casa 105');
    });

    it('al confirmar la quita del residente, la quita de la lista y avisa al padre', async () => {
      const avisos: string[] = [];
      component.desvinculado.subscribe(() => avisos.push('refrescar'));
      abrir();

      await component.confirmarDesvinculacion(mockVivienda);
      fixture.detectChanges();

      expect(mockViviendasService.desvincularResidente).toHaveBeenCalledOnceWith(101, 'res-123');
      expect(component.viviendasAsignadas()).toEqual([]);
      expect(avisos).toEqual(['refrescar']);
      expect(texto()).toContain('Sin vivienda vinculada');
      expect((swal.calls.argsFor(0)[0] as any).text).toContain('Su cuenta no se borra');
    });

    it('si cancela la confirmación no llama al servicio ni cambia nada', async () => {
      swal.and.returnValue(Promise.resolve({ isConfirmed: false } as any));
      abrir();

      await component.confirmarDesvinculacion(mockVivienda);

      expect(mockViviendasService.desvincularResidente).not.toHaveBeenCalled();
      expect(component.viviendasAsignadas().length).toBe(1);
    });

    it('si el backend falla muestra el motivo claro, conserva la vivienda y no avisa al padre', async () => {
      spyOn(console, 'error');
      mockViviendasService.desvincularResidente.and.rejectWith({ status: 400, error: { error: 'La asignación ya no existe.' } });
      const avisos: string[] = [];
      component.desvinculado.subscribe(() => avisos.push('refrescar'));
      abrir();

      await component.confirmarDesvinculacion(mockVivienda);

      expect(component.viviendasAsignadas().length).toBe(1);
      expect(avisos).toEqual([]);
      expect(component.desvinculando()).toBeNull();
      const error = swal.calls.mostRecent().args[0] as any;
      expect(error.icon).toBe('error');
      expect(error.text).toBe('La asignación ya no existe.');
    });

    it('oculta el JSON técnico del backend con un mensaje genérico', async () => {
      spyOn(console, 'error');
      mockViviendasService.desvincularResidente.and.rejectWith({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } });
      abrir();

      await component.confirmarDesvinculacion(mockVivienda);

      expect((swal.calls.mostRecent().args[0] as any).text).toBe('No fue posible quitar la vivienda. Intenta de nuevo en unos segundos.');
    });
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
      expect(texto()).toContain('Sub-usuarios');
      expect(texto()).toContain('2 de 2');
      expect(texto()).toContain('Luis Prueba');
      expect(texto()).toContain('luis@example.com');
      expect(texto()).toContain('Activo');
      expect(texto()).not.toContain('Invitación enviada');
    });

    it('una invitación pendiente se distingue de una persona: el correo es lo principal y no se llama "Pendiente"', async () => {
      mockSubusuariosService.listarPorVivienda.and.resolveTo([pendiente]);

      await abrir([mockVivienda]);

      const fila = (fixture.nativeElement as HTMLElement).querySelector('section li') as HTMLElement;
      expect(fila.textContent!.replace(/\s+/g, ' ')).toContain('ana@example.com');
      expect(fila.textContent).toContain('Aún no acepta la invitación');
      expect(fila.textContent).toContain('Invitación pendiente');
      expect(fila.classList.contains('border-dashed')).toBeTrue();
      expect(fila.querySelector('p')!.textContent).not.toContain('Pendiente');
    });

    it('cada casa lleva sus sub-usuarios dentro de su propia tarjeta, con su cupo', async () => {
      const otra: Vivienda = { id: 202, numeroCasa: 'Casa 202', tipo: 'Casa', condominioId: 'cond-1' };
      mockSubusuariosService.listarPorVivienda.and.callFake(async (id: number) => (id === 202 ? [] : [acceso, pendiente]));

      await abrir([mockVivienda, otra]);

      const tarjetas = Array.from((fixture.nativeElement as HTMLElement).querySelectorAll('section[aria-label$="y sus sub-usuarios"]')) as HTMLElement[];
      expect(tarjetas.length).toBe(2);
      const texto1 = tarjetas[0].textContent!.replace(/\s+/g, ' ');
      const texto2 = tarjetas[1].textContent!.replace(/\s+/g, ' ');
      expect(texto1).toContain('Luis Prueba');
      expect(texto1).toContain('2 de 2');
      expect(texto1).toContain('Desvincular');
      expect(texto2).not.toContain('Luis Prueba');
      expect(texto2).toContain('Esta vivienda no tiene sub-usuarios.');
      expect(texto2).toContain('0 de 2');
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

      expect(texto()).not.toContain('Esta vivienda no tiene sub-usuarios.');
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

describe('ResidentesDetalleComponent: navegar entre residente y vivienda', () => {
  let fixture: ComponentFixture<ResidentesDetalleComponent>;
  let component: ResidentesDetalleComponent;

  const residente: Residente = { id: 'r1', nombre: 'Maria', apellidos: 'Resendiz', email: 'maria@example.com', telefono: '4423456789', rol: 'Residente' };
  const casa: Vivienda = { id: 7, numeroCasa: 'A-204', tipo: 'Casa' };
  const botonCasa = () => fixture.nativeElement.querySelector('[data-origen-detalle="vivienda-7"]') as HTMLButtonElement | null;
  const flecha = () => fixture.nativeElement.querySelector('[data-foco-inicial]') as HTMLButtonElement | null;

  async function abrir(): Promise<void> {
    fixture.componentRef.setInput('residente', residente);
    fixture.componentRef.setInput('viviendas', [casa]);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ResidentesDetalleComponent],
      providers: [
        { provide: ViviendasService, useValue: { obtenerViviendasDeResidente: () => Promise.resolve([casa]), desvincularResidente: () => Promise.resolve() } },
        { provide: SubusuariosService, useValue: { MAX_SUBUSUARIOS: 2, listarPorVivienda: () => Promise.resolve([]) } }
      ]
    }).compileComponents();
    fixture = TestBed.createComponent(ResidentesDetalleComponent);
    component = fixture.componentInstance;
  });

  it('cada vivienda es un botón con nombre accesible que pide su detalle', async () => {
    await abrir();
    const pedida = jasmine.createSpy('verVivienda');
    component.verVivienda.subscribe(pedida);

    expect(botonCasa()!.getAttribute('aria-label')).toBe('Ver el detalle de Casa #A-204');
    botonCasa()!.click();

    expect(pedida).toHaveBeenCalledOnceWith(casa);
  });

  it('abierto de forma normal no muestra la flecha de regreso', async () => {
    await abrir();
    expect(flecha()).toBeNull();
  });

  it('abierto sobre otro detalle muestra la flecha con su nombre accesible, toma el foco y regresa al tocarla', async () => {
    fixture.componentRef.setInput('conAtras', true);
    fixture.componentRef.setInput('textoAtras', 'Volver al detalle de la vivienda');
    await abrir();
    const regreso = jasmine.createSpy('atras');
    component.atras.subscribe(regreso);

    expect(flecha()!.getAttribute('aria-label')).toBe('Volver al detalle de la vivienda');
    expect(document.activeElement).toBe(flecha());
    flecha()!.click();

    expect(regreso).toHaveBeenCalledTimes(1);
  });

  it('Escape con la flecha retrocede un paso y no cierra todo', async () => {
    fixture.componentRef.setInput('conAtras', true);
    await abrir();
    const regreso = jasmine.createSpy('atras');
    const cierre = jasmine.createSpy('cerrado');
    component.atras.subscribe(regreso);
    component.cerrado.subscribe(cierre);

    window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(regreso).toHaveBeenCalledTimes(1);
    expect(cierre).not.toHaveBeenCalled();
  });

  it('Escape sin flecha cierra el detalle', async () => {
    await abrir();
    const cierre = jasmine.createSpy('cerrado');
    component.cerrado.subscribe(cierre);

    window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(cierre).toHaveBeenCalledTimes(1);
  });

  it('si otro detalle ya atendió la pulsación de Escape, este no se cierra también', async () => {
    await abrir();
    const cierre = jasmine.createSpy('cerrado');
    component.cerrado.subscribe(cierre);
    const evento = new KeyboardEvent('keydown', { key: 'Escape', cancelable: true });
    evento.preventDefault();

    window.dispatchEvent(evento);

    expect(cierre).not.toHaveBeenCalled();
  });

  it('con la flecha, Escape marca la pulsación como atendida para que ningún otro detalle la repita', async () => {
    fixture.componentRef.setInput('conAtras', true);
    await abrir();
    const evento = new KeyboardEvent('keydown', { key: 'Escape', cancelable: true });

    window.dispatchEvent(evento);

    expect(evento.defaultPrevented).toBeTrue();
  });

  it('si hay otro detalle encima ignora Escape, para que solo se cierre el de arriba', async () => {
    fixture.componentRef.setInput('inactivo', true);
    await abrir();
    const cierre = jasmine.createSpy('cerrado');
    component.cerrado.subscribe(cierre);

    window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(cierre).not.toHaveBeenCalled();
  });
});
