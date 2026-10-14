import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { By } from '@angular/platform-browser';
import { ResidentesListComponent } from './residentes-list.component';
import { ResidentesDetalleComponent } from '../residentes-detalle/residentes-detalle.component';
import { ResidentesService } from '../../../core/services/residentes.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { SubusuariosService } from '../../../core/services/subusuarios.service';
import { Residente } from '../../../core/models/residente.model';
import { Vivienda } from '../../../core/models/vivienda.model';

const casa: Vivienda = { id: 33, numeroCasa: 'PRUEBA-01', tipo: 'Casa', condominioId: 'c1' };
const titular: Residente = { id: 't1', nombre: 'Residente', apellidos: 'Prueba', email: 'titular@example.com', telefono: '5512345678', rol: 'residente' };
const subusuario: Residente = { id: 's1', nombre: 'Subusuario', apellidos: 'Prueba', email: 'sub@example.com', telefono: '5598765432', rol: 'residente' };
const sinCasa: Residente = { id: 'n1', nombre: 'Nuevo', apellidos: 'Vecino', email: 'nuevo@example.com', telefono: '5500000000', rol: 'residente' };

describe('ResidentesListComponent (sub-usuarios)', () => {
  let fixture: ComponentFixture<ResidentesListComponent>;
  let component: ResidentesListComponent;
  let residentes: { listar: jasmine.Spy };
  let viviendas: { obtenerMapaViviendasPorResidente: jasmine.Spy; listar: jasmine.Spy };
  let subusuarios: { mapaViviendasDeSubusuarios: jasmine.Spy; listarPorVivienda: jasmine.Spy };

  const filas = () => Array.from(fixture.nativeElement.querySelectorAll('tbody tr') as NodeListOf<HTMLElement>);
  const textoFila = (nombre: string) => filas().find(f => f.textContent!.includes(nombre))?.textContent!.replace(/\s+/g, ' ') ?? '';

  async function crear(): Promise<void> {
    fixture = TestBed.createComponent(ResidentesListComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
    await new Promise(r => setTimeout(r, 0));
    fixture.detectChanges();
  }

  beforeEach(() => {
    residentes = { listar: jasmine.createSpy('listar').and.callFake(async (sinVivienda: boolean) => sinVivienda ? [subusuario, sinCasa] : [titular, subusuario, sinCasa]) };
    viviendas = {
      obtenerMapaViviendasPorResidente: jasmine.createSpy('mapa').and.resolveTo(new Map([['t1', [casa]]])),
      listar: jasmine.createSpy('listar').and.resolveTo([casa])
    };
    subusuarios = {
      mapaViviendasDeSubusuarios: jasmine.createSpy('mapaSubs').and.resolveTo(new Map([['s1', [casa]]])),
      listarPorVivienda: jasmine.createSpy('listarPorVivienda').and.resolveTo([])
    };
    TestBed.configureTestingModule({
      imports: [ResidentesListComponent],
      providers: [
        provideRouter([]),
        { provide: ResidentesService, useValue: residentes },
        { provide: ViviendasService, useValue: viviendas },
        { provide: SubusuariosService, useValue: subusuarios },
        { provide: ActivatedRoute, useValue: { snapshot: { queryParamMap: { get: () => null, has: () => false } } } }
      ]
    });
  });

  it('muestra al sub-usuario con la casa a la que entra, no como "sin vivienda"', async () => {
    await crear();

    expect(textoFila('Subusuario')).toContain('Sub-usuario · Casa #PRUEBA-01');
    expect(textoFila('Subusuario')).not.toContain('Sin vivienda');
    expect(textoFila('Residente Prueba')).toContain('PRUEBA-01');
    expect(textoFila('Nuevo')).toContain('Sin vivienda');
  });

  it('la pestaña "Sin vivienda asignada" deja fuera a los sub-usuarios activos', async () => {
    await crear();

    await component.cambiarTab('sin-vivienda');
    fixture.detectChanges();

    expect(filas().length).toBe(1);
    expect(textoFila('Nuevo')).toContain('Sin vivienda');
    expect(component.conteoSinVivienda()).toBe(1);
  });

  it('el contador de "sin vivienda" tampoco cuenta a los sub-usuarios', async () => {
    await crear();

    expect(component.totalResidentesRegistrados()).toBe(3);
    expect(component.conteoSinVivienda()).toBe(1);
  });

  it('buscar por casa encuentra al titular y a su sub-usuario', async () => {
    await crear();

    component.onSearchChange('prueba-01');
    fixture.detectChanges();

    expect(filas().length).toBe(2);
    expect(textoFila('Nuevo')).toBe('');
  });

  it('si la consulta de sub-usuarios falla la lista sigue funcionando', async () => {
    subusuarios.mapaViviendasDeSubusuarios.and.rejectWith({ status: 500 });
    await crear();

    expect(filas().length).toBe(3);
    expect(textoFila('Residente Prueba')).toContain('PRUEBA-01');
    expect(textoFila('Subusuario')).toContain('Sin vivienda');
    expect(fixture.nativeElement.textContent).not.toContain('No fue posible cargar');
  });

  it('al desvincular desde el detalle vuelve a consultar con datos frescos', async () => {
    await crear();
    residentes.listar.calls.reset();
    viviendas.obtenerMapaViviendasPorResidente.calls.reset();

    await component.alDesvincular();

    expect(residentes.listar).toHaveBeenCalledWith(false, true);
    expect(viviendas.obtenerMapaViviendasPorResidente).toHaveBeenCalledWith(true);
  });

  it('el detalle abierto avisa y la lista se refresca', async () => {
    await crear();
    component.verDetalle(titular);
    fixture.detectChanges();
    spyOn(component, 'alDesvincular').and.resolveTo();

    const detalle = fixture.debugElement.query(By.directive(ResidentesDetalleComponent)).componentInstance as ResidentesDetalleComponent;
    detalle.desvinculado.emit();

    expect(component.alDesvincular).toHaveBeenCalled();
  });

  it('el selector de residentes por página tiene nombre accesible', async () => {
    await crear();

    const nombres = Array.from(fixture.nativeElement.querySelectorAll('select') as NodeListOf<HTMLSelectElement>).map(s => s.getAttribute('aria-label'));

    expect(nombres).toContain('Residentes por página');
  });
});
