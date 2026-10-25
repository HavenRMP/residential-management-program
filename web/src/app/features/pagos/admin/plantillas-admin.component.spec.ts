import { ComponentFixture, TestBed } from '@angular/core/testing';
import Swal from 'sweetalert2';
import { PlantillasAdminComponent } from './plantillas-admin.component';
import { PlantillasCargoService } from '../../../core/services/plantillas-cargo.service';
import { Plantilla } from '../../../core/models/pagos.model';

const plantilla = (id: string, extra: Partial<Plantilla> = {}): Plantilla => ({
  id, viviendaId: 3, numeroCasa: '3', tipo: 'Mantenimiento', concepto: `Cuota ${id}`, monto: 1200, diaVencimiento: 10,
  vigenciaInicio: '2026-11-01', vigenciaFin: null, responsablePago: 'Residente', activa: true, ...extra
});

describe('PlantillasAdminComponent', () => {
  let fixture: ComponentFixture<PlantillasAdminComponent>;
  let component: PlantillasAdminComponent;
  let servicio: { PAGE_SIZE: number; listar: jasmine.Spy; cambiarActiva: jasmine.Spy; generarCargos: jasmine.Spy };
  let swal: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const tarjetas = () => Array.from(fixture.nativeElement.querySelectorAll('[data-test="plantilla"]') as NodeListOf<HTMLElement>);
  const botonDe = (tarjeta: HTMLElement, nombre: string) =>
    Array.from(tarjeta.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.trim() === nombre);

  async function abrir(items: Plantilla[], total = items.length): Promise<void> {
    servicio.listar.and.resolveTo({ items, total, pagina: 1, tamanoPagina: 20 });
    fixture = TestBed.createComponent(PlantillasAdminComponent);
    component = fixture.componentInstance;
    component.viviendas = [{ id: 3, numeroCasa: '3', tipo: null }];
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = {
      PAGE_SIZE: 20,
      listar: jasmine.createSpy('listar'),
      cambiarActiva: jasmine.createSpy('cambiarActiva').and.resolveTo(plantilla('t1')),
      generarCargos: jasmine.createSpy('generarCargos').and.resolveTo({ creados: 8, omitidosPorYaExistir: 2, omitidosPorVigencia: 1 })
    };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({
      imports: [PlantillasAdminComponent],
      providers: [{ provide: PlantillasCargoService, useValue: servicio }]
    });
  });

  it('por defecto lista solo las plantillas activas', async () => {
    await abrir([plantilla('t1')]);

    expect(servicio.listar.calls.mostRecent().args[0]).toEqual({ viviendaId: null, tipo: '', activa: true });
    expect(tarjetas()[0].textContent).toContain('Cuota t1');
    expect(tarjetas()[0].textContent).toContain('Vence el día 10');
    expect(tarjetas()[0].textContent).toContain('sin fecha de término');
  });

  it('el filtro de estado distingue activas, inactivas y todas', async () => {
    await abrir([plantilla('t1')]);

    component.filtros.activa = 'inactivas';
    component.aplicarFiltros();
    await fixture.whenStable();
    expect(servicio.listar.calls.mostRecent().args[0].activa).toBeFalse();

    component.filtros.activa = 'todas';
    component.aplicarFiltros();
    await fixture.whenStable();
    expect(servicio.listar.calls.mostRecent().args[0].activa).toBeNull();
  });

  it('una plantilla inactiva se ve como tal y ofrece activarla', async () => {
    await abrir([plantilla('t1', { activa: false })]);

    expect(tarjetas()[0].textContent).toContain('Inactiva');
    expect(botonDe(tarjetas()[0], 'Activar')).toBeDefined();
    expect(botonDe(tarjetas()[0], 'Desactivar')).toBeUndefined();
  });

  it('dice que no hay plantillas cuando la lista viene vacía', async () => {
    await abrir([]);

    expect(fixture.nativeElement.querySelector('[data-test="sin-plantillas"]')).not.toBeNull();
  });

  it('desactivar pide confirmación y llama al servicio', async () => {
    await abrir([plantilla('t1')]);

    await component.cambiarActiva(component.items()[0]);

    expect(swal).toHaveBeenCalledWith(jasmine.objectContaining({ title: '¿Desactivar esta plantilla?' }));
    expect(servicio.cambiarActiva).toHaveBeenCalledOnceWith('t1', false);
  });

  it('si el administrador se arrepiente al desactivar no pasa nada', async () => {
    await abrir([plantilla('t1')]);
    swal.and.resolveTo({ isConfirmed: false } as any);

    await component.cambiarActiva(component.items()[0]);

    expect(servicio.cambiarActiva).not.toHaveBeenCalled();
  });

  it('activar no pide confirmación', async () => {
    await abrir([plantilla('t1', { activa: false })]);
    swal.calls.reset();

    await component.cambiarActiva(component.items()[0]);

    expect(servicio.cambiarActiva).toHaveBeenCalledOnceWith('t1', true);
    expect(swal).not.toHaveBeenCalledWith(jasmine.objectContaining({ icon: 'warning' }));
  });

  it('si el servicio falla al cambiar el estado avisa y refresca la lista', async () => {
    spyOn(console, 'error');
    await abrir([plantilla('t1')]);
    servicio.cambiarActiva.and.rejectWith({ status: 404, error: { error: 'Plantilla no encontrada.' } });
    servicio.listar.calls.reset();

    await component.cambiarActiva(component.items()[0]);

    expect(swal).toHaveBeenCalledWith(jasmine.objectContaining({ icon: 'error', text: 'Plantilla no encontrada.' }));
    expect(servicio.listar).toHaveBeenCalled();
  });

  describe('generar cargos del periodo', () => {
    it('propone el mes en curso, confirma y resume lo creado y lo omitido', async () => {
      await abrir([plantilla('t1')]);
      const cambio = jasmine.createSpy('cambio');
      component.cambio.subscribe(cambio);
      component.periodoGenerar = '2026-11';

      await component.generar();

      expect(servicio.generarCargos).toHaveBeenCalledOnceWith('2026-11');
      const resumen = swal.calls.mostRecent().args[0] as any;
      expect(resumen.title).toBe('8 cargos creados');
      expect(resumen.text).toContain('Se omitieron 3');
      expect(resumen.text).toContain('2 ya existían');
      expect(resumen.text).toContain('1 quedaron fuera de su vigencia');
      expect(cambio).toHaveBeenCalled();
      expect(component.generando()).toBeFalse();
    });

    it('si el administrador no confirma no genera nada', async () => {
      await abrir([plantilla('t1')]);
      swal.and.resolveTo({ isConfirmed: false } as any);

      await component.generar();

      expect(servicio.generarCargos).not.toHaveBeenCalled();
    });

    it('si no se creó ninguno lo dice y no avisa al encabezado', async () => {
      await abrir([plantilla('t1')]);
      servicio.generarCargos.and.resolveTo({ creados: 0, omitidosPorYaExistir: 4, omitidosPorVigencia: 0 });
      const cambio = jasmine.createSpy('cambio');
      component.cambio.subscribe(cambio);

      await component.generar();

      expect((swal.calls.mostRecent().args[0] as any).title).toBe('No se creó ningún cargo');
      expect(cambio).not.toHaveBeenCalled();
    });

    it('con el periodo vacío el botón no hace nada', async () => {
      await abrir([plantilla('t1')]);
      component.periodoGenerar = '';

      await component.generar();

      expect(servicio.generarCargos).not.toHaveBeenCalled();
    });

    it('si el backend rechaza el periodo muestra su mensaje', async () => {
      spyOn(console, 'error');
      await abrir([plantilla('t1')]);
      servicio.generarCargos.and.rejectWith({ status: 400, error: { error: 'El formato del periodo es inválido.' } });

      await component.generar();

      expect(swal).toHaveBeenCalledWith(jasmine.objectContaining({ icon: 'error', text: 'El formato del periodo es inválido.' }));
      expect(component.generando()).toBeFalse();
    });
  });

  it('nueva plantilla y editar abren el formulario correspondiente', async () => {
    await abrir([plantilla('t1')]);

    (Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.includes('Nueva plantilla')))!.click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-plantilla-form')).not.toBeNull();
    expect(component.editando()).toBeNull();

    component.cerrarFormulario();
    fixture.detectChanges();
    botonDe(tarjetas()[0], 'Editar')!.click();
    fixture.detectChanges();

    expect(component.editando()?.id).toBe('t1');
    expect(texto()).toContain('Editar plantilla');
  });

  it('al guardar cierra el formulario y recarga la lista', async () => {
    await abrir([plantilla('t1')]);
    component.abrirFormulario();
    servicio.listar.calls.reset();

    await component.alGuardar(3);

    expect(component.formularioAbierto()).toBeFalse();
    expect(swal).toHaveBeenCalledWith(jasmine.objectContaining({ toast: true, title: '3 plantillas creadas' }));
    expect(servicio.listar).toHaveBeenCalled();
  });

  it('si falla la carga muestra el mensaje con un botón para reintentar', async () => {
    spyOn(console, 'error');
    servicio.listar.and.rejectWith({ status: 503 });
    fixture = TestBed.createComponent(PlantillasAdminComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(texto()).toContain('No se pudieron cargar las plantillas');
    expect(texto()).toContain('Reintentar');
  });
});
