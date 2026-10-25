import { ComponentFixture, TestBed } from '@angular/core/testing';
import { PlantillaFormComponent } from './plantilla-form.component';
import { PlantillasCargoService } from '../../../core/services/plantillas-cargo.service';
import { Plantilla } from '../../../core/models/pagos.model';

const casas = [
  { id: 3, numeroCasa: '3', tipo: null },
  { id: 4, numeroCasa: '4', tipo: null },
  { id: 5, numeroCasa: '5', tipo: null }
];

const existente: Plantilla = {
  id: 't1', viviendaId: 3, numeroCasa: '3', tipo: 'Mantenimiento', concepto: 'Cuota', monto: 1200, diaVencimiento: 10,
  vigenciaInicio: '2026-11-01', vigenciaFin: null, responsablePago: 'Propietario', activa: true
};

describe('PlantillaFormComponent', () => {
  let fixture: ComponentFixture<PlantillaFormComponent>;
  let component: PlantillaFormComponent;
  let servicio: { crear: jasmine.Spy; actualizar: jasmine.Spy };

  const campo = (id: string) => fixture.nativeElement.querySelector('#' + id) as HTMLElement | null;
  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');

  function abrir(plantilla: Plantilla | null = null): void {
    fixture = TestBed.createComponent(PlantillaFormComponent);
    component = fixture.componentInstance;
    component.viviendas = casas;
    component.plantilla = plantilla;
    fixture.detectChanges();
  }

  function llenar(): void {
    component.form.concepto = 'Cuota de mantenimiento';
    component.form.monto = 1200;
    component.form.diaVencimiento = 10;
    component.form.vigenciaInicio = '2026-11-01';
  }

  beforeEach(() => {
    servicio = {
      crear: jasmine.createSpy('crear').and.resolveTo([{ id: 'a' }, { id: 'b' }]),
      actualizar: jasmine.createSpy('actualizar').and.resolveTo(existente)
    };
    TestBed.configureTestingModule({
      imports: [PlantillaFormComponent],
      providers: [{ provide: PlantillasCargoService, useValue: servicio }]
    });
  });

  describe('alta', () => {
    it('lista las viviendas para elegir y pide un monto común', () => {
      abrir();

      expect(texto()).toContain('Nueva plantilla de cargo');
      expect(texto()).toContain('Monto común');
      expect(fixture.nativeElement.querySelectorAll('[data-test="viviendas"] input[type="checkbox"]').length).toBe(3);
    });

    it('elegir todas y quitar todas', () => {
      abrir();

      component.alternarTodas();
      expect(component.seleccionadas().size).toBe(3);
      expect(component.todasElegidas()).toBeTrue();

      component.alternarTodas();
      expect(component.seleccionadas().size).toBe(0);
    });

    it('solo muestra el monto propio de las viviendas elegidas', () => {
      abrir();
      expect(fixture.nativeElement.querySelector('input[aria-label="Monto propio de la casa 4"]')).toBeNull();

      component.alternar(4);
      fixture.detectChanges();

      expect(fixture.nativeElement.querySelector('input[aria-label="Monto propio de la casa 4"]')).not.toBeNull();
    });

    it('no guarda sin viviendas y lo dice', async () => {
      abrir();
      llenar();

      await component.guardar();

      expect(component.error()).toContain('al menos una vivienda');
      expect(servicio.crear).not.toHaveBeenCalled();
    });

    it('rechaza un monto propio inválido y nombra la casa', async () => {
      abrir();
      llenar();
      component.alternar(4);
      component.montosPropios[4] = 10.555;

      await component.guardar();

      expect(component.error()).toContain('casa 4');
      expect(servicio.crear).not.toHaveBeenCalled();
    });

    it('crea una plantilla por vivienda elegida con su monto propio solo donde lo hay', async () => {
      abrir();
      llenar();
      const guardado = jasmine.createSpy('guardado');
      component.guardado.subscribe(guardado);
      component.alternar(3);
      component.alternar(5);
      component.montosPropios[5] = 900;

      await component.guardar();

      expect(servicio.crear).toHaveBeenCalledOnceWith({
        concepto: 'Cuota de mantenimiento', tipo: 'Mantenimiento', monto: 1200, diaVencimiento: 10, vigenciaInicio: '2026-11-01',
        vigenciaFin: null, responsablePago: 'Residente',
        viviendas: [{ viviendaId: 3, monto: null }, { viviendaId: 5, monto: 900 }]
      });
      expect(guardado).toHaveBeenCalledOnceWith(2);
      expect(component.isSaving()).toBeFalse();
    });

    it('si el backend rechaza muestra su mensaje', async () => {
      spyOn(console, 'error');
      abrir();
      llenar();
      component.alternar(3);
      servicio.crear.and.rejectWith({ status: 409, error: { error: 'Ya existe una plantilla activa para la vivienda 3.' } });

      await component.guardar();

      expect(component.error()).toBe('Ya existe una plantilla activa para la vivienda 3.');
    });
  });

  describe('edición', () => {
    it('carga los datos de la plantilla y no deja cambiar tipo, vivienda ni inicio', () => {
      abrir(existente);

      expect(texto()).toContain('Editar plantilla');
      expect(component.form.concepto).toBe('Cuota');
      expect(component.responsable).toBe('Propietario');
      expect(campo('plantilla-tipo')).toBeNull();
      expect(campo('plantilla-inicio')).toBeNull();
      expect(fixture.nativeElement.querySelector('[data-test="viviendas"]')).toBeNull();
      expect(fixture.nativeElement.querySelector('[data-test="resumen-plantilla"]').textContent).toContain('Casa 3');
    });

    it('guarda solo los campos editables y quita la vigencia final si se deja vacía', async () => {
      abrir(existente);
      const guardado = jasmine.createSpy('guardado');
      component.guardado.subscribe(guardado);
      component.form.monto = 1500;
      component.form.diaVencimiento = 5;

      await component.guardar();

      expect(servicio.actualizar).toHaveBeenCalledOnceWith('t1', {
        concepto: 'Cuota', monto: 1500, diaVencimiento: 5, vigenciaFin: null, responsablePago: 'Propietario'
      });
      expect(servicio.crear).not.toHaveBeenCalled();
      expect(guardado).toHaveBeenCalledOnceWith(1);
    });

    it('valida el día de vencimiento', async () => {
      abrir(existente);
      component.form.diaVencimiento = 40;

      await component.guardar();

      expect(component.error()).toContain('entre 1 y 31');
      expect(servicio.actualizar).not.toHaveBeenCalled();
    });
  });
});
