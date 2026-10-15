import { ComponentFixture, TestBed } from '@angular/core/testing';
import { SimpleChange } from '@angular/core';
import { Subject } from 'rxjs';
import { ViviendasDetalleComponent } from './viviendas-detalle.component';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { ResidentesService } from '../../../core/services/residentes.service';
import { SubusuariosService } from '../../../core/services/subusuarios.service';
import { SubUsuarioItem } from '../../../core/models/subusuario.model';
import { Vivienda } from '../../../core/models/vivienda.model';

const casa = (id: number, numeroCasa: string): Vivienda => ({ id, numeroCasa, tipo: 'Casa' });
const sub = (id: string, extra: Partial<SubUsuarioItem> = {}): SubUsuarioItem => ({
  id, nombre: 'Rosa Luna', email: 'rosa@example.com', telefono: '5512345678', parentesco: 'Hija', activo: true, creadoEn: null, ...extra
});

describe('ViviendasDetalleComponent: sub-usuarios', () => {
  let fixture: ComponentFixture<ViviendasDetalleComponent>;
  let component: ViviendasDetalleComponent;
  let subusuarios: { MAX_SUBUSUARIOS: number; listarPorVivienda: jasmine.Spy };
  let viviendas: { obtenerResidentesVivienda: jasmine.Spy };

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');

  async function abrir(vivienda: Vivienda): Promise<void> {
    component.vivienda = vivienda;
    component.isOpen = true;
    component.ngOnChanges({ vivienda: new SimpleChange(null, vivienda, false), isOpen: new SimpleChange(false, true, false) });
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    viviendas = { obtenerResidentesVivienda: jasmine.createSpy('obtenerResidentesVivienda').and.resolveTo([]) };
    subusuarios = { MAX_SUBUSUARIOS: 2, listarPorVivienda: jasmine.createSpy('listarPorVivienda').and.resolveTo([]) };
    TestBed.configureTestingModule({
      imports: [ViviendasDetalleComponent],
      providers: [
        { provide: ViviendasService, useValue: viviendas },
        { provide: ResidentesService, useValue: { listar: jasmine.createSpy().and.resolveTo([]) } },
        { provide: SubusuariosService, useValue: subusuarios }
      ]
    });
    fixture = TestBed.createComponent(ViviendasDetalleComponent);
    component = fixture.componentInstance;
  });

  it('pide los sub-usuarios de la vivienda que se abre', async () => {
    await abrir(casa(33, 'PRUEBA-01'));

    expect(subusuarios.listarPorVivienda).toHaveBeenCalledOnceWith(33);
  });

  it('muestra cada sub-usuario con su parentesco, su estado y cuántos hay del máximo', async () => {
    subusuarios.listarPorVivienda.and.resolveTo([sub('1'), sub('2', { nombre: 'Luis', email: 'luis@example.com', parentesco: 'Hermano' })]);

    await abrir(casa(33, 'PRUEBA-01'));

    expect(texto()).toContain('Rosa Luna');
    expect(texto()).toContain('rosa@example.com');
    expect(texto()).toContain('Hija');
    expect(texto()).toContain('Luis');
    expect(texto()).toContain('2 de 2');
    expect(texto()).toContain('Activo');
  });

  it('una invitación pendiente se muestra con su correo y sin nombre', async () => {
    subusuarios.listarPorVivienda.and.resolveTo([sub('3', { nombre: '', activo: false, email: 'nuevo@example.com' })]);

    await abrir(casa(33, 'PRUEBA-01'));

    expect(texto()).toContain('nuevo@example.com');
    expect(texto()).toContain('Aún no acepta la invitación');
    expect(texto()).toContain('Invitación pendiente');
  });

  it('una vivienda sin sub-usuarios lo dice', async () => {
    await abrir(casa(33, 'PRUEBA-01'));

    expect(texto()).toContain('Esta vivienda no tiene sub-usuarios.');
    expect(texto()).toContain('0 de 2');
  });

  it('si falla la consulta lo avisa y no muestra el contador', async () => {
    spyOn(console, 'error');
    subusuarios.listarPorVivienda.and.rejectWith({ status: 500 });

    await abrir(casa(33, 'PRUEBA-01'));

    expect(texto()).toContain('No se pudieron cargar los sub-usuarios de esta vivienda.');
    expect(texto()).not.toContain('0 de 2');
  });

  it('mientras consulta muestra el estado de carga', async () => {
    const lenta = new Subject<SubUsuarioItem[]>();
    subusuarios.listarPorVivienda.and.returnValue(new Promise(resolver => lenta.subscribe(resolver)));

    component.vivienda = casa(33, 'PRUEBA-01');
    component.isOpen = true;
    component.ngOnChanges({ vivienda: new SimpleChange(null, component.vivienda, false) });
    fixture.detectChanges();

    expect(texto()).toContain('Consultando sub-usuarios...');
    expect(fixture.nativeElement.querySelector('[aria-busy=true]')).not.toBeNull();
  });

  it('al abrir otra vivienda, una respuesta lenta de la anterior no pisa la nueva', async () => {
    let resolverVieja!: (l: SubUsuarioItem[]) => void;
    subusuarios.listarPorVivienda.and.returnValues(
      new Promise<SubUsuarioItem[]>(resolver => (resolverVieja = resolver)),
      Promise.resolve([sub('9', { nombre: 'Marta Nueva', email: 'marta@example.com' })])
    );

    const primera = abrir(casa(33, 'PRUEBA-01'));
    await abrir(casa(34, 'PRUEBA-02'));
    resolverVieja([sub('1', { nombre: 'Rosa Vieja', email: 'vieja@example.com' })]);
    await primera;
    fixture.detectChanges();

    expect(texto()).toContain('Marta Nueva');
    expect(texto()).not.toContain('Rosa Vieja');
    expect(component.cargandoSubusuarios).toBeFalse();
  });
});

describe('ViviendasDetalleComponent: residente asignado', () => {
  let fixture: ComponentFixture<ViviendasDetalleComponent>;
  let component: ViviendasDetalleComponent;
  let viviendas: { obtenerResidentesVivienda: jasmine.Spy };

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const boton = (t: string) =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.trim() === t);

  async function abrir(): Promise<void> {
    const vivienda = casa(33, 'PRUEBA-01');
    component.vivienda = vivienda;
    component.isOpen = true;
    component.ngOnChanges({ vivienda: new SimpleChange(null, vivienda, false) });
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    viviendas = { obtenerResidentesVivienda: jasmine.createSpy('obtenerResidentesVivienda').and.resolveTo([]) };
    TestBed.configureTestingModule({
      imports: [ViviendasDetalleComponent],
      providers: [
        { provide: ViviendasService, useValue: viviendas },
        { provide: ResidentesService, useValue: { listar: jasmine.createSpy().and.resolveTo([]) } },
        { provide: SubusuariosService, useValue: { MAX_SUBUSUARIOS: 2, listarPorVivienda: jasmine.createSpy().and.resolveTo([]) } }
      ]
    });
    fixture = TestBed.createComponent(ViviendasDetalleComponent);
    component = fixture.componentInstance;
  });

  it('una vivienda sin residente lo dice y ofrece vincular', async () => {
    await abrir();

    expect(texto()).toContain('Sin habitante registrado');
    expect(boton('Vincular')).toBeDefined();
  });

  it('si no se pudo consultar no dice que la casa está vacía ni ofrece vincular, y deja reintentar', async () => {
    spyOn(console, 'error');
    viviendas.obtenerResidentesVivienda.and.rejectWith({ status: 500 });

    await abrir();

    expect(texto()).toContain('No se pudo consultar el residente de esta vivienda.');
    expect(texto()).toContain('No disponible');
    expect(texto()).not.toContain('Sin habitante registrado');
    expect(boton('Vincular')).toBeUndefined();
    expect(boton('Vincular Residente Ahora')).toBeUndefined();

    viviendas.obtenerResidentesVivienda.and.resolveTo([{ id: 'r1', nombre: 'Ana', apellidos: 'Pérez', email: 'ana@example.com', telefono: '5512345678', rol: 'Residente' }]);
    boton('Reintentar')!.click();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(texto()).toContain('Ana Pérez');
    expect(texto()).not.toContain('No se pudo consultar el residente');
  });
});

describe('ViviendasDetalleComponent: navegar al residente', () => {
  let fixture: ComponentFixture<ViviendasDetalleComponent>;
  let component: ViviendasDetalleComponent;

  const titular = { id: 'r1', nombre: 'Aisha', apellidos: 'Sánchez', email: 'aisha@example.com', telefono: '4151110993', rol: 'Residente' };
  const botonResidente = () => fixture.nativeElement.querySelector('[data-origen-detalle="residente"]') as HTMLButtonElement | null;
  const flecha = () => fixture.nativeElement.querySelector('[data-foco-inicial]') as HTMLButtonElement | null;

  async function abrir(): Promise<void> {
    const vivienda = casa(26, '1098');
    component.vivienda = vivienda;
    component.isOpen = true;
    component.ngOnChanges({ vivienda: new SimpleChange(null, vivienda, false), isOpen: new SimpleChange(false, true, false) });
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [ViviendasDetalleComponent],
      providers: [
        { provide: ViviendasService, useValue: { obtenerResidentesVivienda: () => Promise.resolve([titular]) } },
        { provide: ResidentesService, useValue: { listar: () => Promise.resolve([]) } },
        { provide: SubusuariosService, useValue: { MAX_SUBUSUARIOS: 2, listarPorVivienda: () => Promise.resolve([]) } }
      ]
    });
    fixture = TestBed.createComponent(ViviendasDetalleComponent);
    component = fixture.componentInstance;
  });

  it('el residente asignado es un botón con nombre accesible que pide su detalle', async () => {
    await abrir();
    const pedido = jasmine.createSpy('verResidente');
    component.verResidente.subscribe(pedido);

    expect(botonResidente()!.getAttribute('aria-label')).toBe('Ver el detalle de Aisha Sánchez');
    botonResidente()!.click();

    expect(pedido).toHaveBeenCalledOnceWith(titular);
  });

  it('abierto de forma normal no muestra la flecha de regreso', async () => {
    await abrir();
    expect(flecha()).toBeNull();
  });

  it('abierto sobre el detalle de un residente muestra la flecha, toma el foco y regresa al tocarla', async () => {
    component.conAtras = true;
    component.textoAtras = 'Volver al detalle del residente';
    await abrir();
    const regreso = jasmine.createSpy('atras');
    component.atras.subscribe(regreso);

    expect(flecha()!.getAttribute('aria-label')).toBe('Volver al detalle del residente');
    expect(document.activeElement).toBe(flecha());
    flecha()!.click();

    expect(regreso).toHaveBeenCalledTimes(1);
  });

  it('con la flecha, Escape marca la pulsación como atendida; si ya estaba atendida, no hace nada', async () => {
    component.conAtras = true;
    await abrir();
    const regreso = jasmine.createSpy('atras');
    component.atras.subscribe(regreso);

    const nueva = new KeyboardEvent('keydown', { key: 'Escape', cancelable: true });
    document.dispatchEvent(nueva);
    expect(nueva.defaultPrevented).toBeTrue();
    expect(regreso).toHaveBeenCalledTimes(1);

    const atendida = new KeyboardEvent('keydown', { key: 'Escape', cancelable: true });
    atendida.preventDefault();
    document.dispatchEvent(atendida);
    expect(regreso).toHaveBeenCalledTimes(1);
  });

  it('Escape con la flecha retrocede un paso; sin ella cierra; con otro detalle encima no hace nada', async () => {
    const regreso = jasmine.createSpy('atras');
    const cierre = jasmine.createSpy('close');
    component.atras.subscribe(regreso);
    component.close.subscribe(cierre);

    component.conAtras = true;
    await abrir();
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(regreso).toHaveBeenCalledTimes(1);
    expect(cierre).not.toHaveBeenCalled();

    component.conAtras = false;
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(cierre).toHaveBeenCalledTimes(1);

    component.inactivo = true;
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(cierre).toHaveBeenCalledTimes(1);
    expect(regreso).toHaveBeenCalledTimes(1);
  });
});
