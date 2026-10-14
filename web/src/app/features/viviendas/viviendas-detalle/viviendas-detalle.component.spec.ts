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
    subusuarios = { MAX_SUBUSUARIOS: 2, listarPorVivienda: jasmine.createSpy('listarPorVivienda').and.resolveTo([]) };
    TestBed.configureTestingModule({
      imports: [ViviendasDetalleComponent],
      providers: [
        { provide: ViviendasService, useValue: { obtenerResidentesVivienda: jasmine.createSpy().and.resolveTo([]) } },
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
